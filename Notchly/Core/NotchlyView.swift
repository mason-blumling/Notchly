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
    @ObservedObject private var settings = NotchlySettings.shared
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
        IntroView {
            coordinator.completeIntro()
        }
        .id("introView")
    }

    // MARK: - Live Activity Logic

    /// Determines whether the calendar live activity alert should show.
    private var shouldShowCalendarLiveActivity: Bool {
        let settings = NotchlySettings.shared
        
        /// First check settings permissions
        guard settings.enableCalendar && settings.enableCalendarAlerts else {
            return false
        }
        
        /// Then check the standard conditions
        return coordinator.state != .expanded &&
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
        GeometryReader { geometry in
            ZStack(alignment: .top) {
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
                    viewModel.debounceHover(hovering)
                }
                .position(x: geometry.size.width / 2, y: coordinator.configuration.height / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onChange(of: coordinator.state) { _, newState in
            mediaMonitor.setExpanded(newState == .expanded)
        }
        .onAppear {
            setupSubscriptionsWithSettings()
        }
    }
    
    // MARK: - Content Views
    
    // Replace expandedContent method in NotchlyView.swift with this one:

    private func expandedContent(in layout: NotchlyLayoutGuide) -> some View {
        HStack(alignment: .top, spacing: 0) {
            /// Only show media player if the media app is enabled
            if isMediaAppEnabled(mediaMonitor.activePlayerName) {
                UnifiedMediaPlayerView(
                    mediaMonitor: mediaMonitor,
                    isExpanded: true,
                    namespace: notchAnimation
                )
                .frame(
                    width: layout.leftContentFrame.width,
                    height: layout.leftContentFrame.height
                )
            } else {
                /// Show placeholder if current media app is disabled
                Color.clear
                    .frame(
                        width: layout.leftContentFrame.width,
                        height: layout.leftContentFrame.height
                    )
            }

            /// Only show calendar if enabled
            if settings.enableCalendar {
                NotchlyCalendarView(calendarManager: calendarManager)
                    .frame(
                        width: layout.rightContentFrame.width,
                        height: layout.rightContentFrame.height
                    )
            } else {
                /// Show placeholder if calendar is disabled
                VStack {
                    Text("Calendar disabled")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(
                    width: layout.rightContentFrame.width,
                    height: layout.rightContentFrame.height
                )
            }
        }
        .frame(width: layout.bounds.width)
        .opacity(expandedContentOpacity)
    }

    private func collapsedContent(in layout: NotchlyLayoutGuide) -> some View {
        Group {
            if isMediaAppEnabled(mediaMonitor.activePlayerName) {
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
            } else {
                /// Empty view if media app is disabled
                Color.clear
                    .frame(
                        width: layout.bounds.width,
                        height: layout.bounds.height
                    )
            }
        }
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
    
    
    /**
     Updates setupSubscriptions to respect user settings.
     The key parts to integrate are the checks for enabled features.
     */
    private func setupSubscriptionsWithSettings() {
        /// Only start monitoring calendar if we're not in the intro and have permission
        if !shouldShowIntro && NotchlySettings.shared.enableCalendar {
            calendarActivityMonitor.evaluateLiveActivity()
        }

        /// Respond to live activity changes (with settings check)
        calendarActivityMonitor.$isLiveActivityVisible
            .removeDuplicates()
            .sink { [self] isActive in
                guard NotchlySettings.shared.enableCalendarAlerts else { return }
                
                self.viewModel.calendarHasLiveActivity = isActive
                self.forceCollapseForCalendar = true

                /// Step 1: Collapse into calendar activity (or media if calendar alert ends)
                self.coordinator.update(
                    expanded: false,
                    mediaActive: self.mediaMonitor.isPlaying,
                    calendarActive: isActive
                )

                /// Step 2: After delay, show media if appropriate
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()
                ) {
                    self.forceCollapseForCalendar = false
                    let mediaPlaying = self.mediaMonitor.isPlaying &&
                                       self.isMediaAppEnabled(self.mediaMonitor.activePlayerName)

                    self.coordinator.update(
                        expanded: false,
                        mediaActive: mediaPlaying,
                        calendarActive: false
                    )
                    self.showMediaAfterCalendar = mediaPlaying && !isActive
                }
            }
            .store(in: &cancellables)

        /// Respond to media playback changes (with settings check)
        mediaMonitor.$isPlaying
            .sink { [self] playing in
                // Check if this media app is enabled in settings
                let isEnabled = self.isMediaAppEnabled(self.mediaMonitor.activePlayerName)
                let effectivePlaying = playing && isEnabled
                
                self.viewModel.isMediaPlaying = effectivePlaying

                if self.coordinator.state != .expanded {
                    self.coordinator.update(
                        expanded: false,
                        mediaActive: effectivePlaying,
                        calendarActive: self.calendarActivityMonitor.upcomingEvent != nil
                    )
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     Helper to check if a media app is enabled in settings
     */
    private func isMediaAppEnabled(_ appName: String) -> Bool {
        let settings = NotchlySettings.shared
        let appNameLower = appName.lowercased()
        
        if appNameLower.contains("music") || appNameLower.contains("apple") {
            return settings.enableAppleMusic
        } else if appNameLower.contains("spotify") {
            return settings.enableSpotify
        } else if appNameLower.contains("podcast") {
            return settings.enablePodcasts
        }
        
        return true // Default to enabled if unknown
    }
}
