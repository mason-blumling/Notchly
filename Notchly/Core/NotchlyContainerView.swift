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
    
    // Central transition coordinator drives all sizing & animations
    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared
    
    init(notchly: Notchly) {
        self.notchly = notchly
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }
    
    /// When the notch is collapsed and there’s an upcoming event.
    private var shouldShowCalendarLiveActivity: Bool {
        coordinator.state != .expanded &&
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
                    if shouldShowCalendarLiveActivity {
                        CalendarLiveActivityView(
                            activityMonitor: calendarActivityMonitor,
                            namespace: notchAnimation
                        )
                        .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(999)
                        .frame(
                            width:  coordinator.configuration.width,
                            height: coordinator.configuration.height
                        )
                        .animation(NotchlyAnimations.notchExpansion, value: shouldShowCalendarLiveActivity)
                    }
                    
                    // MARK: — Media + Calendar HStack
                    HStack(alignment: .center, spacing: 6) {
                        Spacer().frame(width: 4)
                        
                        UnifiedMediaPlayerView(
                            mediaMonitor: mediaMonitor,
                            isExpanded:  coordinator.state == .expanded,
                            namespace:   notchAnimation
                        )
                        .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                        .frame(
                            width:  coordinator.state == .expanded
                            ? coordinator.configuration.width * 0.42
                            : coordinator.configuration.width,
                            height: coordinator.state == .expanded
                            ? coordinator.configuration.height - 5
                            : coordinator.configuration.height
                        )
                        .padding(.leading, 4)
                        .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : 1)
                        .scaleEffect(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0.95 : 1)
                        .animation(coordinator.animation, value: shouldShowCalendarLiveActivity)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        
                        Spacer().frame(width: 5)
                        
                        NotchlyCalendarView(calendarManager: calendarManager)
                            .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                            .frame(
                                width:  coordinator.state == .expanded
                                ? coordinator.configuration.width * 0.50
                                : 0,
                                height: coordinator.state == .expanded
                                ? coordinator.configuration.height - 5
                                : 0
                            )
                            .padding(.trailing, 4)
                            .opacity(coordinator.state == .expanded ? 1 : 0)
                        // **removed .clipped()** rely on container clipShape
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                            .animation(NotchlyAnimations.quickTransition, value: coordinator.state == .expanded)
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
                    guard !notchly.ignoreHoverOnboarding else { return }
                    
                    coordinator.update(
                        expanded:      hovering,
                        mediaActive:   mediaMonitor.isPlaying,
                        calendarActive: calendarActivityMonitor.upcomingEvent != nil
                    )
                    debounceHover(hovering)
                }
                
                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
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
            
            mediaMonitor.$isPlaying
                .sink { playing in
                    notchly.isMediaPlaying = playing
                    if coordinator.state != .expanded {
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
