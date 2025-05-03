//  NotchlyContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI
import Combine

/// The visual SwiftUI container for the Notchly floating UI.
/// Displays the expanding/collapsing notch, calendar, media, and live activities.
struct NotchlyContainerView: View {
    @ObservedObject var notchly: Notchly
    @EnvironmentObject var appEnvironment: AppEnvironment

    @Namespace private var notchAnimation

    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showMediaAfterCalendar: Bool = false
    @State private var forceCollapseForCalendar = false

    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor

    private var mediaMonitor: MediaPlaybackMonitor { appEnvironment.mediaMonitor }
    private var calendarManager: CalendarManager { appEnvironment.calendarManager }

    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared

    init(notchly: Notchly) {
        self.notchly = notchly
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }

    private var shouldShowCalendarLiveActivity: Bool {
        coordinator.state != .expanded &&
        calendarActivityMonitor.upcomingEvent != nil &&
        !calendarActivityMonitor.timeRemainingString.isEmpty
    }

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
                            // Calendar live-activity overlay
                            if shouldShowCalendarLiveActivity {
                                CalendarLiveActivityView(
                                    activityMonitor: calendarActivityMonitor,
                                    namespace: notchAnimation
                                )
                                .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                                .transition(.opacity.combined(with: .scale))
                                .zIndex(999)
                                .animation(NotchlyAnimations.notchExpansion, value: shouldShowCalendarLiveActivity)
                            }
                            
                            // Media + Calendar content with explicit sizing
                            if coordinator.state == .expanded {
                                // In expanded state, use HStack with explicit frames
                                HStack(alignment: .top, spacing: 0) {
                                    // Media player (left side)
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
                                    
                                    // Calendar (right side)
                                    NotchlyCalendarView(calendarManager: calendarManager)
                                        .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                                        .frame(
                                            width: layout.rightContentFrame.width,
                                            height: layout.rightContentFrame.height
                                        )
                                        .padding(.trailing, 8)
                                }
                                .frame(width: layout.bounds.width)
                            } else {
                                // Collapsed or activity state
                                UnifiedMediaPlayerView(
                                    mediaMonitor: mediaMonitor,
                                    isExpanded: false,
                                    namespace: notchAnimation
                                )
                                .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                                .frame(
                                    width: layout.bounds.width,
                                    height: layout.bounds.height
                                )
                                .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : 1)
                                .scaleEffect(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0.95 : 1)
                                .animation(coordinator.animation, value: shouldShowCalendarLiveActivity)
                            }
                        }
                    }
                    .onHover { hovering in
                        guard !notchly.ignoreHoverOnboarding else { return }
                        coordinator.update(
                            expanded: hovering,
                            mediaActive: mediaMonitor.isPlaying,
                            calendarActive: calendarActivityMonitor.upcomingEvent != nil
                        )
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
    
    private func setupSubscriptions() {
        calendarManager.requestAccess { granted in
            if granted {
                calendarActivityMonitor.evaluateLiveActivity()
            }
        }
        
        calendarActivityMonitor.$isLiveActivityVisible
            .removeDuplicates()
            .sink { isActive in
                notchly.calendarHasLiveActivity = isActive
                forceCollapseForCalendar = true

                // 1) Immediately go into calendarActivity (or mediaActivity if no calendar)
                coordinator.update(
                    expanded: false,
                    mediaActive: mediaMonitor.isPlaying,
                    calendarActive: isActive
                )

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()
                ) {
                    forceCollapseForCalendar = false
                    let mediaPlaying = mediaMonitor.isPlaying

                    // 2) Stay collapsed into mediaActivity rather than expanding
                    coordinator.update(
                        expanded: false,
                        mediaActive: mediaPlaying,
                        calendarActive: false
                    )
                    showMediaAfterCalendar = mediaPlaying && !isActive
                }
            }
            .store(in: &cancellables)
        
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
