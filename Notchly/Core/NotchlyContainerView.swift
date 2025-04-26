//
//  NotchlyContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI
import Combine

/// The visual SwiftUI container for the Notchly floating UI.
/// Displays the expanding/collapsing notch, calendar, media, and live activities.
struct NotchlyContainerView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>
    @EnvironmentObject var appEnvironment: AppEnvironment

    @Namespace private var notchAnimation

    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showMediaAfterCalendar: Bool = false
    @State private var forceCollapseForCalendar = false

    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor

    private var mediaMonitor: MediaPlaybackMonitor { appEnvironment.mediaMonitor }
    private var calendarManager: CalendarManager { appEnvironment.calendarManager }

    // Central transition coordinator drives all sizing & animations
    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared

    init(notchly: Notchly<Content>) {
        self.notchly = notchly
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }

    /// When the notch is collapsed and there’s an upcoming event.
    private var shouldShowCalendarLiveActivity: Bool {
        !notchly.isMouseInside &&
        calendarActivityMonitor.upcomingEvent != nil &&
        !calendarActivityMonitor.timeRemainingString.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                ZStack {
                    // MARK: — Background notch shape
                    NotchlyShape(
                        bottomCornerRadius: coordinator.configuration.bottomCornerRadius,
                        topCornerRadius:    coordinator.configuration.topCornerRadius
                    )
                    .fill(NotchlyTheme.background)
                    .frame(
                        width:  coordinator.configuration.width,
                        height: coordinator.configuration.height
                    )
                    .shadow(color: NotchlyTheme.shadow, radius: coordinator.configuration.shadowRadius)
                    .animation(coordinator.animation, value: coordinator.configuration)

                    // MARK: — Calendar live-activity overlay
                    Group {
                        if shouldShowCalendarLiveActivity {
                            CalendarLiveActivityView(
                                activityMonitor: calendarActivityMonitor,
                                namespace: notchAnimation
                            )
                            .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(999)
                        }
                    }
                    .frame(
                        width:  coordinator.configuration.width,
                        height: coordinator.configuration.height
                    )
                    .animation(NotchlyAnimations.notchExpansion, value: shouldShowCalendarLiveActivity)

                    // MARK: — Media + Calendar HStack
                    HStack(alignment: .center, spacing: 6) {
                        Spacer().frame(width: 4)

                        UnifiedMediaPlayerView(
                            mediaMonitor: mediaMonitor,
                            isExpanded:  notchly.isMouseInside,
                            namespace:   notchAnimation
                        )
                        .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                        .frame(
                            width:  notchly.isMouseInside
                                ? coordinator.configuration.width * 0.42
                                : coordinator.configuration.width,
                            height: notchly.isMouseInside
                                ? coordinator.configuration.height - 5
                                : coordinator.configuration.height
                        )
                        .padding(.leading, 4)
                        .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : 1)
                        .scaleEffect(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0.95 : 1)
                        .animation(coordinator.animation, value: shouldShowCalendarLiveActivity)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                        Spacer().frame(width: 5)

                        NotchlyCalendarView(
                            calendarManager: calendarManager,
                            isExpanded:     notchly.isMouseInside
                        )
                        .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                        .frame(
                            width:  notchly.isMouseInside
                                ? coordinator.configuration.width * 0.50
                                : 0,
                            height: notchly.isMouseInside
                                ? coordinator.configuration.height - 5
                                : 0
                        )
                        .padding(.trailing, 4)
                        .opacity(notchly.isMouseInside ? 1 : 0)
                        .clipped()
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                        .animation(NotchlyAnimations.quickTransition, value: notchly.isMouseInside)
                    }
                    .frame(width: coordinator.configuration.width)
                    .padding(.horizontal, 4)
                }
                .clipShape(
                    NotchlyShape(
                        bottomCornerRadius: coordinator.configuration.bottomCornerRadius,
                        topCornerRadius:    coordinator.configuration.topCornerRadius
                    )
                )
                .onHover { hovering in
                    // 1) Drive coordinator
                    coordinator.update(
                        expanded:      hovering,
                        mediaActive:   mediaMonitor.isPlaying,
                        calendarActive: calendarActivityMonitor.upcomingEvent != nil
                    )

                    // 2) Debounced toggle of notchly.isMouseInside
                    debounceHover(hovering)
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            // Request calendar access
            calendarManager.requestAccess { granted in
                if granted {
                    calendarActivityMonitor.evaluateLiveActivity()
                }
            }

            // Observe calendar live-activity
            calendarActivityMonitor.$isLiveActivityVisible
                .removeDuplicates()
                .sink { isActive in
                    notchly.calendarHasLiveActivity = isActive
                    forceCollapseForCalendar = true

                    coordinator.update(
                        expanded:      false,
                        mediaActive:   mediaMonitor.isPlaying,
                        calendarActive: isActive
                    )

                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()
                    ) {
                        forceCollapseForCalendar = false
                        let mediaPlaying = mediaMonitor.isPlaying

                        coordinator.update(
                            expanded:      true,
                            mediaActive:   mediaPlaying,
                            calendarActive: isActive
                        )
                        showMediaAfterCalendar = mediaPlaying && !isActive
                    }
                }
                .store(in: &cancellables)

            // Observe media playback
            mediaMonitor.$isPlaying
                .sink { playing in
                    notchly.isMediaPlaying = playing

                    if !notchly.isMouseInside {
                        coordinator.update(
                            expanded:      false,
                            mediaActive:   playing,
                            calendarActive: calendarActivityMonitor.upcomingEvent != nil
                        )
                    }
                }
                .store(in: &cancellables)
        }
    }

    /// Debounce flipping of `notchly.isMouseInside` so your hover logic still works
    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem {
            guard hovering != notchly.isMouseInside else { return }

            withAnimation(coordinator.animation) {
                notchly.isMouseInside = hovering
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: debounceWorkItem!)
    }
}
