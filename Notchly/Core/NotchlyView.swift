//
//  NotchlyView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI
import Combine

/// The SwiftUI container that renders the entire Notchly UI:
/// Includes the expanding notch shape, media player, calendar, and live activities.
struct NotchlyView: View {
    // MARK: - Dependencies

    @ObservedObject var viewModel: NotchlyViewModel
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

    @ObservedObject private var coordinator = NotchlyViewModel.shared

    // MARK: - Init

    init(viewModel: NotchlyViewModel) {
        self.viewModel = viewModel
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }

    // MARK: - First Time Launch

    /// Determines if the intro should be shown instead of normal content
    var shouldShowIntro: Bool {
        coordinator.state == .expanded && coordinator.ignoreHoverOnboarding
    }
    
    /// Creates the intro view that replaces normal content during onboarding
    @ViewBuilder
    func introContent() -> some View {
        // The intro view now handles its own configuration updates
        IntroView {
            // Called when intro completes
            coordinator.completeIntro()
        }
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

                NotchlyShapeView(
                    configuration: coordinator.configuration,
                    state: coordinator.state,
                    animation: coordinator.animation
                ) { layout in
                    ZStack(alignment: .top) {
                        /// Check if we should show intro
                        if shouldShowIntro {
                            introContent()
                        } else {
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
                                expandedContent(in: layout)
                            /// 🟡 Collapsed or Activity State (media preview)
                            } else {
                                collapsedContent(in: layout)
                            }
                        }
                    }
                }
                .onHover { hovering in
                    guard !viewModel.ignoreHoverOnboarding else { return }
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
    
    // MARK: - Content Views
    
    private func expandedContent(in layout: NotchlyLayoutGuide) -> some View {
        HStack(alignment: .top, spacing: 0) {
            UnifiedMediaPlayerView(
                mediaMonitor: mediaMonitor,
                isExpanded: true,
                namespace: notchAnimation
            )
            .frame(
                width: layout.leftContentFrame.width,
                height: layout.leftContentFrame.height
            )

            NotchlyCalendarView(calendarManager: calendarManager)
                .frame(
                    width: layout.rightContentFrame.width,
                    height: layout.rightContentFrame.height
                )
        }
        .frame(width: layout.bounds.width)
        .opacity(expandedContentOpacity)
    }
    
    private func collapsedContent(in layout: NotchlyLayoutGuide) -> some View {
        UnifiedMediaPlayerView(
            mediaMonitor: mediaMonitor,
            isExpanded: false,
            namespace: notchAnimation
        )
        .frame(
            width: layout.bounds.width,
            height: layout.bounds.height,
            alignment: .leading
        )
        .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : activityContentOpacity)
    }

    // MARK: - Hover Handling

    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem {
            guard hovering != viewModel.isMouseInside else { return }
            withAnimation(coordinator.animation) {
                viewModel.isMouseInside = hovering
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
        /// Only start monitoring calendar if we're not in the intro and have permission
        if !shouldShowIntro {
            calendarActivityMonitor.evaluateLiveActivity()
        }

        /// Respond to live activity changes
        calendarActivityMonitor.$isLiveActivityVisible
            .removeDuplicates()
            .sink { isActive in
                viewModel.calendarHasLiveActivity = isActive
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
                viewModel.isMediaPlaying = playing

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
