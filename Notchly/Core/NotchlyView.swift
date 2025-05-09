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
    @State private var viewAppeared = false

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

    // MARK: - Computed Properties
    
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
                /// Main notch content
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
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.animation(NotchlyAnimations.liveActivityTransition),
                                        removal: .opacity.animation(NotchlyAnimations.liveActivityTransition.delay(0.2))
                                    )
                                )
                                .zIndex(999)
                                /// Add a check for calendar activity state here
                                .onAppear {
                                    if coordinator.state != .calendarActivity {
                                        withAnimation(NotchlyAnimations.liveActivityTransition) {
                                            coordinator.configuration = .activity
                                            coordinator.state = .calendarActivity
                                        }
                                    }
                                }
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
            /// Track appearance for stability
            viewAppeared = true
            
            NotchlyLogger.notice("📱 NotchlyView appeared", category: .ui)
            
            /// Delay subscription setup until view is fully rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotchlyLogger.info("📝 Setting up Notchly view subscriptions", category: .ui)
                self.setupSubscriptions()
            }
            
            /// Ensure the state is consistent with actual configuration
            if coordinator.state == .expanded {
                mediaMonitor.startTimer()
            }
        }
        .onDisappear {
            viewAppeared = false
            NotchlyLogger.notice("📱 NotchlyView disappeared", category: .ui)
            
            /// Pause monitoring when view is not visible
            mediaMonitor.stopTimer()
        }
        /// Add explicit monitoring of calendar activity flag
        .onChange(of: coordinator.calendarHasLiveActivity) { _, isActive in
            if !isActive && coordinator.state == .calendarActivity {
                /// Calendar activity is gone but shape is still in activity state
                /// We need to transition to the appropriate state
                let shouldShowMedia = mediaMonitor.isPlaying &&
                                     isMediaAppEnabled(mediaMonitor.activePlayerName)
                
                withAnimation(NotchlyAnimations.liveActivityTransition) {
                    if shouldShowMedia {
                        coordinator.configuration = .activity
                        coordinator.state = .mediaActivity
                    } else {
                        coordinator.configuration = .default
                        coordinator.state = .collapsed
                    }
                }
            }
        }
    }
    
    // MARK: - Content Views

    private func expandedContent(in layout: NotchlyLayoutGuide) -> some View {
        HStack(alignment: .top, spacing: 0) {
            /// Only show media player if the media app is enabled
            if isMediaAppEnabled(mediaMonitor.activePlayerName) {
                UnifiedMediaPlayerView(
                    mediaMonitor: mediaMonitor,
                    isExpanded: true,
                    namespace: notchAnimation
                )
                .frame(width: layout.leftContentFrame.width, height: layout.leftContentFrame.height)
            } else {
                /// Show placeholder if current media app is disabled
                Color.clear
                    .frame(width: layout.leftContentFrame.width, height: layout.leftContentFrame.height)
            }

            /// Only show calendar if enabled
            if settings.enableCalendar {
                /// Dynamically choose between calendar styles based on user preference
                if settings.calendarStyle == .block {
                    /// Original Block Calendar UI
                    NotchlyCalendarView(calendarManager: calendarManager)
                        .frame(width: layout.rightContentFrame.width, height: layout.rightContentFrame.height)
                } else {
                    /// New Timeline Calendar UI
                    NotchlyTimelineCalendarIntegrator(calendarManager: calendarManager)
                        .frame(width: layout.rightContentFrame.width, height: layout.rightContentFrame.height)
                }
            } else {
                /// Show placeholder if calendar is disabled
                VStack {
                    Text("Calendar disabled")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(width: layout.rightContentFrame.width, height: layout.rightContentFrame.height)
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
                .frame(width: layout.bounds.width, height: layout.bounds.height, alignment: .leading)
                .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : activityContentOpacity)
                .animation(NotchlyAnimations.liveActivityTransition, value: shouldShowCalendarLiveActivity || showMediaAfterCalendar)
            } else {
                /// Empty view if media app is disabled
                Color.clear
                    .frame(width: layout.bounds.width, height: layout.bounds.height)
            }
        }
    }

    // MARK: - Subscriptions

    /// Sets up improved subscription handling for live activities
    func setupSubscriptions() {
        /// Clear previous subscriptions to avoid duplicates
        cancellables.removeAll()
        
        /// First check if calendar is enabled and we have permissions
        let calendarEnabled = NotchlySettings.shared.enableCalendar
        let hasPermission = calendarManager.hasCalendarPermission()

        if !shouldShowIntro && calendarEnabled && hasPermission {
            NotchlyLogger.info("📅 Setting up calendar activity subscription...", category: .calendar)
            setupCalendarActivitySubscription()
        } else if !hasPermission && calendarEnabled {
            NotchlyLogger.notice("⚠️ Calendar enabled but permission not granted", category: .calendar)
        }
        
        /// Set up media playback monitoring
        setupMediaMonitoring()
        
        /// Add listeners for sleep/wake cycle to properly manage subscriptions
        NotificationCenter.default.publisher(for: NSWorkspace.willSleepNotification)
            .sink { _ in
                /// Pause any animations or timers
                self.mediaMonitor.stopTimer()
                
                /// Clear any active calendar notifications
                self.calendarActivityMonitor.reset()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .sink { _ in
                /// Short delay before restarting media monitoring
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    /// Only restart if the view is still visible
                    if self.viewAppeared && self.coordinator.state == .expanded {
                        self.mediaMonitor.startTimer()
                    }
                }
            }
            .store(in: &cancellables)

        /// Monitor for window changes to ensure we always have up-to-date content
        NotificationCenter.default.publisher(for: Notification.Name("NotchlyWindowRefreshed"))
            .sink { _ in
                /// Restart timer if expanded
                if self.coordinator.state == .expanded {
                    self.mediaMonitor.startTimer()
                }
            }
            .store(in: &cancellables)
        
        /// Add a listener for calendar permission changes
        NotificationCenter.default.publisher(for: Notification.Name("NotchlyCalendarPermissionChanged"))
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates(by: { $0.userInfo?["status"] as? Int == $1.userInfo?["status"] as? Int })
            .sink { notification in
                /// Check if we got permission that we didn't have before
                if let userInfo = notification.userInfo,
                   let granted = userInfo["granted"] as? Bool,
                   granted {
                    NotchlyLogger.notice("📅 Calendar permission now granted, setting up subscription", category: .calendar)
                    self.setupCalendarActivitySubscription()
                }
            }
            .store(in: &cancellables)
    }

    /// Set up a debounced subscription to calendar activity changes
    private func setupCalendarActivitySubscription() {
        calendarActivityMonitor.$isLiveActivityVisible
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { isActive in
                let settings = NotchlySettings.shared
                
                /// Only apply changes when enabled in settings
                guard settings.enableCalendarAlerts else {
                    NotchlyLogger.debug("📅 Calendar alerts disabled in settings", category: .calendar)
                    return
                }

                /// Prevent responding to changes during app startup
                guard self.viewModel.isVisible else {
                    NotchlyLogger.debug("📅 Ignoring calendar change during initialization", category: .calendar)
                    return
                }
                
                /// Only proceed if this is a real state change
                guard self.viewModel.calendarHasLiveActivity != isActive else {
                    return
                }

                NotchlyLogger.info("📅 Calendar activity visibility changing to: \(isActive)", category: .calendar)

                if isActive {
                    NotchlyLogger.notice("📅 Calendar activity becoming visible", category: .calendar)
                    self.forceCollapseForCalendar = true
                    self.showMediaAfterCalendar = false
                    
                    /// Update view model's state flag
                    self.viewModel.calendarHasLiveActivity = isActive
                    
                    /// FIX: Use consistent animation and force shape expansion before content appears
                    DispatchQueue.main.async {
                        /// Important: wrap both changes in a single animation block
                        withAnimation(NotchlyAnimations.liveActivityTransition) {
                            /// Critical fix: Directly set configuration FIRST
                            self.coordinator.configuration = .activity
                            /// Then change state
                            self.coordinator.state = .calendarActivity
                        }
                    }
                } else {
                    NotchlyLogger.notice("📅 Calendar activity dismissing", category: .calendar)

                    let shouldShowMedia = self.mediaMonitor.isPlaying &&
                                          self.isMediaAppEnabled(self.mediaMonitor.activePlayerName)

                    /// Update view model's state flag
                    self.viewModel.calendarHasLiveActivity = isActive
                    
                    /// Use consistent animation timing for shape transition
                    DispatchQueue.main.async {
                        withAnimation(NotchlyAnimations.liveActivityTransition) {
                            if shouldShowMedia {
                                /// Directly set configuration FIRST
                                self.coordinator.configuration = .activity
                                self.coordinator.state = .mediaActivity
                            } else {
                                /// Directly set configuration FIRST
                                self.coordinator.configuration = .default
                                self.coordinator.state = .collapsed
                            }
                        }
                    }
                    
                    /// After animation completes, cleanup
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if shouldShowMedia {
                            self.showMediaAfterCalendar = true
                        }
                        self.forceCollapseForCalendar = false
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Set up media monitoring as a separate function
    private func setupMediaMonitoring() {
        /// Respond to media playback changes (with settings check)
        mediaMonitor.$isPlaying
            .sink { playing in
                /// Check if this media app is enabled in settings
                let isEnabled = self.isMediaAppEnabled(self.mediaMonitor.activePlayerName)
                let effectivePlaying = playing && isEnabled
                self.viewModel.isMediaPlaying = effectivePlaying

                /// Only attempt a state update if we're not in expanded mode and not showing a calendar notification
                if self.coordinator.state != .expanded && !self.viewModel.calendarHasLiveActivity {
                    /// Use the centralized update method
                    self.coordinator.update(
                        expanded: false,
                        mediaActive: effectivePlaying,
                        calendarActive: self.calendarActivityMonitor.isLiveActivityVisible
                    )
                }
            }
            .store(in: &cancellables)
            
        /// Add listener for media settings changes
        NotificationCenter.default.publisher(for: SettingsChangeType.media.notificationName)
            .sink { _ in
                /// Refresh UI based on media settings changes
                /// Only update if we're not expanded and not showing calendar
                if self.coordinator.state != .expanded && !self.viewModel.calendarHasLiveActivity {
                    self.coordinator.update(
                        expanded: false,
                        mediaActive: self.mediaMonitor.isPlaying &&
                                     self.isMediaAppEnabled(self.mediaMonitor.activePlayerName),
                        calendarActive: self.calendarActivityMonitor.isLiveActivityVisible
                    )
                }
            }
            .store(in: &cancellables)
    }

    /// Helper to check if a media app is enabled in settings
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

        return true /// Default to enabled if unknown
    }
}
