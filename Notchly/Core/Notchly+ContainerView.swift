//
//  Notchly+ContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI
import Combine

/// The SwiftUI container that renders the entire Notchly UI:
/// Includes the expanding notch shape, media player, calendar, and live activities.
struct NotchlyContainerView: View {
    // MARK: - Dependencies

    @ObservedObject var notchly: Notchly
    @EnvironmentObject var appEnvironment: AppEnvironment

    @Namespace private var notchAnimation

    // MARK: - Local State

    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showMediaAfterCalendar: Bool = false
    @State private var forceCollapseForCalendar = false

    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor

    private var mediaMonitor: MediaPlaybackMonitor { appEnvironment.mediaMonitor }
    private var calendarManager: CalendarManager { appEnvironment.calendarManager }

    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared

    // MARK: - Init

    init(notchly: Notchly) {
        self.notchly = notchly
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }

    // MARK: - Live Activity Logic

    /// Determines whether the calendar live activity alert should show.
    private var shouldShowCalendarLiveActivity: Bool {
        coordinator.state != .expanded &&
        calendarActivityMonitor.upcomingEvent != nil &&
        !calendarActivityMonitor.timeRemainingString.isEmpty
    }

    /// Controls opacity for expanded content based on notch animation progress.
    private var expandedContentOpacity: Double {
        let expandedWidth: CGFloat = NotchlyConfiguration.large.width
        let currentWidth = coordinator.configuration.width
        let progress = (currentWidth - NotchlyConfiguration.default.width) / (expandedWidth - NotchlyConfiguration.default.width)
        return Double(max(0, min(1, progress)))
    }

    /// Controls visibility of activity content (e.g., media preview) during transitions.
    private var activityContentOpacity: Double {
        let activityWidth = NotchlyConfiguration.activity.width
        let defaultWidth = NotchlyConfiguration.default.width
        let currentWidth = coordinator.configuration.width

        if currentWidth <= defaultWidth {
            return 0
        } else if currentWidth >= activityWidth {
            return coordinator.state == .expanded ? 0 : 1
        } else {
            let progress = (currentWidth - defaultWidth) / (activityWidth - defaultWidth)
            return Double(max(0, min(1, progress)))
        }
    }

    // MARK: - View Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                NotchlyShapeContainer(
                    configuration: coordinator.configuration,
                    state: coordinator.state,
                    animation: coordinator.animation
                ) { layout in
                    ZStack(alignment: .top) {
                        /// 🟣 Calendar Live Activity alert
                        if shouldShowCalendarLiveActivity {
                            CalendarLiveActivityView(
                                activityMonitor: calendarActivityMonitor,
                                namespace: notchAnimation
                            )
                            .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(999)
                        }

                        /// 🟢 Expanded State (media + calendar content)
                        if coordinator.state == .expanded {
                            HStack(alignment: .top, spacing: 0) {
                                UnifiedMediaPlayerView(
                                    mediaMonitor: mediaMonitor,
                                    isExpanded: true,
                                    namespace: notchAnimation
                                )
                                .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                                .frame(
                                    width: layout.leftContentFrame.width,
                                    height: layout.leftContentFrame.height
                                )
                                .padding(.leading, 8)

                                NotchlyCalendarView(calendarManager: calendarManager)
                                    .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                                    .frame(
                                        width: layout.rightContentFrame.width,
                                        height: layout.rightContentFrame.height
                                    )
                                    .padding(.trailing, 8)
                            }
                            .frame(width: layout.bounds.width)
                            .opacity(expandedContentOpacity)

                        /// 🟡 Collapsed or Activity State (media preview)
                        } else {
                            UnifiedMediaPlayerView(
                                mediaMonitor: mediaMonitor,
                                isExpanded: false,
                                namespace: notchAnimation
                            )
                            .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                            .frame(
                                width: layout.bounds.width,
                                height: layout.bounds.height,
                                alignment: .leading
                            )
                            .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : activityContentOpacity)
                        }
                    }
                }
                .onHover { hovering in
                    guard !notchly.ignoreHoverOnboarding else { return }
                    debounceHover(hovering)
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: coordinator.state) { _, newState in
            mediaMonitor.setExpanded(newState == .expanded)
        }
        .onAppear {
            setupSubscriptions()
        }
    }

    // MARK: - Hover Handling

    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem {
            guard hovering != notchly.isMouseInside else { return }
            withAnimation(coordinator.animation) {
                notchly.isMouseInside = hovering
                coordinator.update(
                    expanded: hovering,
                    mediaActive: mediaMonitor.isPlaying,
                    calendarActive: calendarActivityMonitor.upcomingEvent != nil
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: debounceWorkItem!)
    }

    // MARK: - Subscriptions

    private func setupSubscriptions() {
        /// Request calendar permission and evaluate upcoming events
        calendarManager.requestAccess { granted in
            if granted {
                calendarActivityMonitor.evaluateLiveActivity()
            }
        }

        /// Respond to live activity changes
        calendarActivityMonitor.$isLiveActivityVisible
            .removeDuplicates()
            .sink { isActive in
                notchly.calendarHasLiveActivity = isActive
                forceCollapseForCalendar = true

                /// Step 1: Collapse into calendar activity (or media if calendar alert ends)
                coordinator.update(
                    expanded: false,
                    mediaActive: mediaMonitor.isPlaying,
                    calendarActive: isActive
                )

                /// Step 2: After delay, show media if appropriate
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()
                ) {
                    forceCollapseForCalendar = false
                    let mediaPlaying = mediaMonitor.isPlaying

                    coordinator.update(
                        expanded: false,
                        mediaActive: mediaPlaying,
                        calendarActive: false
                    )
                    showMediaAfterCalendar = mediaPlaying && !isActive
                }
            }
            .store(in: &cancellables)

        /// Respond to media playback changes
        mediaMonitor.$isPlaying
            .sink { playing in
                notchly.isMediaPlaying = playing

                if coordinator.state != .expanded {
                    coordinator.update(
                        expanded: false,
                        mediaActive: playing,
                        calendarActive: calendarActivityMonitor.upcomingEvent != nil
                    )
                }
            }
            .store(in: &cancellables)
    }
}
