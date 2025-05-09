//
//  NotchlySettings.swift
//  Notchly
//
//  Created by Mason Blumling on 5/8/25.
//

import SwiftUI
import Combine
import EventKit
import ServiceManagement

// MARK: - Notification Consolidation

/// Define a single enum for all settings change types
enum SettingsChangeType: String {
    case appearance
    case media
    case calendar
    case backgroundOpacity
    case backgroundGlow
    case visualization
    case artwork
    case horizontalOffset
    
    /// Convert to notification name
    var notificationName: Notification.Name {
        return Notification.Name("NotchlySettings.\(self.rawValue)Changed")
    }
}

/// Centralized settings model for Notchly
/// Handles persistence, default values, and publishes changes to interested components
@MainActor
class NotchlySettings: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance for global access
    static let shared = NotchlySettings()

    /// Post a settings change notification with optional user info
    private func notifySettingsChanged(_ type: SettingsChangeType, userInfo: [String: Any]? = nil) {
        NotificationCenter.default.post(
            name: type.notificationName,
            object: self,
            userInfo: userInfo
        )
    }
    
    // MARK: - General Settings
    
    /// Launch Notchly when system starts
    @Published var launchAtLogin: Bool {
        didSet {
            saveSettings()
            updateLoginItem()
        }
    }
    
    /// Horizontal position offset from center (percentage)
    @Published var horizontalOffset: Double {
        didSet {
            saveSettings()
            NotchlyViewModel.shared.recenterShape()
        }
    }
    
    /// How sensitive the hover detection is (lower = more sensitive)
    @Published var hoverSensitivity: Double {
        didSet {
            saveSettings()
        }
    }
    
    // MARK: - Appearance Settings
    
    /// Appearance mode preference
    @Published var appearanceMode: AppearanceMode {
        didSet {
            saveSettings()
            applyAppearanceMode()
        }
    }
    
    /// Custom accent color (ignored if useSystemAccent is true)
    @Published var accentColor: Color {
        didSet {
            saveSettings()
        }
    }
    
    /// Use system accent color instead of custom
    @Published var useSystemAccent: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Background opacity for the notch
    @Published var backgroundOpacity: Double {
        didSet {
            saveSettings()
            notifySettingsChanged(.backgroundOpacity, userInfo: ["opacity": backgroundOpacity])
        }
    }
    
    // MARK: - Media Player Settings
    
    /// Enable Apple Music integration
    @Published var enableAppleMusic: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.media, userInfo: [
                "enableAppleMusic": enableAppleMusic,
                "enableSpotify": enableSpotify,
                "enablePodcasts": enablePodcasts
            ])
        }
    }
    
    /// Enable Spotify integration
    @Published var enableSpotify: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.media, userInfo: [
                "enableAppleMusic": enableAppleMusic,
                "enableSpotify": enableSpotify,
                "enablePodcasts": enablePodcasts
            ])
        }
    }
    
    /// Enable Podcasts integration
    @Published var enablePodcasts: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.media, userInfo: [
                "enableAppleMusic": enableAppleMusic,
                "enableSpotify": enableSpotify,
                "enablePodcasts": enablePodcasts
            ])
        }
    }
    
    /// Action to take when artwork is clicked
    @Published var artworkClickAction: ArtworkClickAction {
        didSet {
            saveSettings()
            notifySettingsChanged(.artwork, userInfo: ["action": artworkClickAction.rawValue])
        }
    }

    /// Enable the background glow effect
    @Published var enableBackgroundGlow: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.backgroundGlow, userInfo: ["enabled": enableBackgroundGlow])
        }
    }

    /// Show audio visualization bars when playing
    @Published var showAudioBars: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.visualization, userInfo: ["showAudioBars": showAudioBars])
        }
    }
    
    // MARK: - Calendar Settings
    
    /// Enable calendar integration
    @Published var enableCalendar: Bool {
        didSet {
            saveSettings()
            
            if enableCalendar {
                /// If enabling, load/refresh events using non-async version
                loadAvailableCalendarsAndRefresh()
            } else {
                /// If disabling, clear events
                Task { @MainActor in
                    AppEnvironment.shared.calendarManager.clearEvents()
                    disableCalendarLiveActivity()
                }
            }
        }
    }
    
    /// Selected calendar IDs to display
    @Published var selectedCalendarIDs: Set<String> {
        didSet {
            saveSettings()
            Task { @MainActor in
                await refreshCalendarEvents()
            }
        }
    }
    
    @Published var calendarStyle: CalendarStyle {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    /// Show calendar live activity alerts
    @Published var enableCalendarAlerts: Bool {
        didSet {
            saveSettings()
            if !enableCalendarAlerts {
                disableCalendarLiveActivity()
            }
        }
    }
    
    /// Show canceled events in calendar views
    @Published var showCanceledEvents: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    /// Time before event to show alert (in minutes)
    @Published var alertTiming: [Int] {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    /// Maximum number of events to display in expanded view
    @Published var maxEventsToDisplay: Int {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }

    /// Show event organizer in event details
    @Published var showEventOrganizer: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    /// Show event location in event details
    @Published var showEventLocation: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    /// Show event attendees in event details
    @Published var showEventAttendees: Bool {
        didSet {
            saveSettings()
            notifySettingsChanged(.calendar)
        }
    }
    
    // MARK: - Weather Settings
    
    /// Enable weather display
    @Published var enableWeather: Bool {
        didSet {
            saveSettings()
        }
    }
    
    /// Weather unit (Celsius or Fahrenheit)
    @Published var weatherUnit: WeatherUnit {
        didSet {
            saveSettings()
        }
    }
    
    @MainActor
    func handleCalendarPermissionGranted() async {
        /// Update the permission status internally
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("📊 Settings received permission update: \(currentStatus.rawValue)")
        
        /// If we have permission now, load available calendars
        if currentStatus == .fullAccess {
            /// Load available calendars and events
            await loadAvailableCalendars()
        }
    }
    
    // MARK: - Types
    
    /// Appearance mode options
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        
        var id: String { self.rawValue }
    }
    
    /// Artwork click actions
    enum ArtworkClickAction: String, CaseIterable, Identifiable {
        case openApp = "Open App"
        case playPause = "Play/Pause"
        case openAlbum = "Open Album"
        case doNothing = "Do Nothing"
        
        var id: String { self.rawValue }
    }
    
    /// Weather unit options
    enum WeatherUnit: String, CaseIterable, Identifiable {
        case celsius = "Celsius"
        case fahrenheit = "Fahrenheit"
        
        var id: String { self.rawValue }
    }
    
    /// Calendar Style options
    enum CalendarStyle: String, CaseIterable, Identifiable {
        case block = "Block"
        case timeline = "Timeline"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Private Properties
    
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let settingsKey = "com.notchly.userSettings"
    
    // MARK: - Initialization
    
    private init() {
        /// Load settings or use defaults
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.horizontalOffset = defaults.double(forKey: "horizontalOffset")
        self.hoverSensitivity = defaults.double(forKey: "hoverSensitivity")
        
        /// Appearance
        if let appearanceString = defaults.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: appearanceString) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
        
        /// Convert stored RGB to Color
        let red = defaults.double(forKey: "accentColorRed")
        let green = defaults.double(forKey: "accentColorGreen")
        let blue = defaults.double(forKey: "accentColorBlue")
        
        if red > 0 || green > 0 || blue > 0 {
            self.accentColor = Color(red: red, green: green, blue: blue)
        } else {
            self.accentColor = Color.blue
        }
        
        self.useSystemAccent = defaults.bool(forKey: "useSystemAccent")
        self.backgroundOpacity = defaults.double(forKey: "backgroundOpacity")
        
        /// Media Player
        self.enableAppleMusic = defaults.bool(forKey: "enableAppleMusic")
        self.enableSpotify = defaults.bool(forKey: "enableSpotify")
        self.enablePodcasts = defaults.bool(forKey: "enablePodcasts")
        
        if let actionString = defaults.string(forKey: "artworkClickAction"),
           let action = ArtworkClickAction(rawValue: actionString) {
            self.artworkClickAction = action
        } else {
            self.artworkClickAction = .openApp
        }
        
        self.enableBackgroundGlow = defaults.bool(forKey: "enableBackgroundGlow")
        self.showAudioBars = defaults.bool(forKey: "showAudioBars")
        
        /// Calendar
        self.enableCalendar = defaults.bool(forKey: "enableCalendar")
        self.showCanceledEvents = defaults.bool(forKey: "showCanceledEvents")

        if let savedIDs = defaults.stringArray(forKey: "selectedCalendarIDs") {
            self.selectedCalendarIDs = Set(savedIDs)
        } else {
            self.selectedCalendarIDs = []
        }
        
        self.enableCalendarAlerts = defaults.bool(forKey: "enableCalendarAlerts")
        
        if let savedTimings = defaults.array(forKey: "alertTiming") as? [Int] {
            self.alertTiming = savedTimings
        } else {
            self.alertTiming = [15, 5] /// Default is 15 and 5 minutes
        }
        
        self.maxEventsToDisplay = defaults.integer(forKey: "maxEventsToDisplay")
        self.showEventOrganizer = defaults.bool(forKey: "showEventOrganizer")
        self.showEventLocation = defaults.bool(forKey: "showEventLocation")
        self.showEventAttendees = defaults.bool(forKey: "showEventAttendees")
        
        if let styleString = defaults.string(forKey: "calendarStyle"),
           let style = CalendarStyle(rawValue: styleString) {
            self.calendarStyle = style
        } else {
            self.calendarStyle = .block // Default to existing view
        }

        /// Weather
        self.enableWeather = defaults.bool(forKey: "enableWeather")
        
        if let unitString = defaults.string(forKey: "weatherUnit"),
           let unit = WeatherUnit(rawValue: unitString) {
            self.weatherUnit = unit
        } else {
            self.weatherUnit = .celsius
        }
        
        /// Apply default values if first launch
        if isFirstLaunch() {
            Task { @MainActor in
                await applyDefaultSettings()
            }
        }
        
        /// Apply settings immediately
        applyAppearanceMode()
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        /// Store all settings values
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(horizontalOffset, forKey: "horizontalOffset")
        defaults.set(hoverSensitivity, forKey: "hoverSensitivity")
        
        /// Appearance
        defaults.set(appearanceMode.rawValue, forKey: "appearanceMode")
        
        /// Store Color as RGB components
        if let components = NSColor(accentColor).cgColor.components {
            defaults.set(components[0], forKey: "accentColorRed")
            defaults.set(components[1], forKey: "accentColorGreen")
            defaults.set(components[2], forKey: "accentColorBlue")
        }
        
        defaults.set(useSystemAccent, forKey: "useSystemAccent")
        defaults.set(backgroundOpacity, forKey: "backgroundOpacity")
        
        /// Media Player
        defaults.set(enableAppleMusic, forKey: "enableAppleMusic")
        defaults.set(enableSpotify, forKey: "enableSpotify")
        defaults.set(enablePodcasts, forKey: "enablePodcasts")
        defaults.set(artworkClickAction.rawValue, forKey: "artworkClickAction")
        defaults.set(enableBackgroundGlow, forKey: "enableBackgroundGlow")
        defaults.set(showAudioBars, forKey: "showAudioBars")
        
        /// Calendar
        defaults.set(enableCalendar, forKey: "enableCalendar")
        defaults.set(Array(selectedCalendarIDs), forKey: "selectedCalendarIDs")
        defaults.set(enableCalendarAlerts, forKey: "enableCalendarAlerts")
        defaults.set(alertTiming, forKey: "alertTiming")
        defaults.set(maxEventsToDisplay, forKey: "maxEventsToDisplay")
        defaults.set(showEventOrganizer, forKey: "showEventOrganizer")
        defaults.set(showEventLocation, forKey: "showEventLocation")
        defaults.set(showEventAttendees, forKey: "showEventAttendees")
        defaults.set(calendarStyle.rawValue, forKey: "calendarStyle")
        defaults.set(showCanceledEvents, forKey: "showCanceledEvents")

        /// Weather
        defaults.set(enableWeather, forKey: "enableWeather")
        defaults.set(weatherUnit.rawValue, forKey: "weatherUnit")
        
        /// Mark that we have saved settings at least once
        defaults.set(true, forKey: "notchlySettingsInitialized")
    }
    
    private func isFirstLaunch() -> Bool {
        !defaults.bool(forKey: "notchlySettingsInitialized")
    }
    
    // MARK: - Default Settings
    @MainActor
    private func applyDefaultSettings() async {
        /// General
        launchAtLogin = true
        horizontalOffset = 0.0
        hoverSensitivity = 0.1
        
        /// Appearance
        appearanceMode = .system
        accentColor = Color.blue
        useSystemAccent = true
        backgroundOpacity = 1.0
        
        /// Media Player
        enableAppleMusic = true
        enableSpotify = true
        enablePodcasts = false
        artworkClickAction = .openApp
        enableBackgroundGlow = true
        showAudioBars = true
        
        /// Calendar
        enableCalendar = true
        enableCalendarAlerts = true
        alertTiming = [15, 5]
        maxEventsToDisplay = 15
        showEventOrganizer = true
        showEventLocation = true
        showEventAttendees = true
        showCanceledEvents = false

        /// Weather
        enableWeather = true
        weatherUnit = .fahrenheit
        
        /// Add all calendars by default
        await loadAvailableCalendars()
        
        /// Save all the defaults
        saveSettings()
    }
    
    // MARK: - Settings Application
    
    private func applyAppearanceMode() {
        /// Apply appearance mode changes to the application
        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if launchAtLogin {
                do {
                    try service.register()
                } catch {
                    NotchlyLogger.error("Failed to register login item: \(error.localizedDescription)", category: .lifecycle)
                }
            } else {
                do {
                    try service.unregister()
                } catch {
                    NotchlyLogger.error("Failed to unregister login item: \(error.localizedDescription)", category: .lifecycle)
                }
            }
        } else {
            /// Safely unwrap the shared file list
            guard let loginItemsRef = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeUnretainedValue(), nil)?.takeUnretainedValue() else {
                NotchlyLogger.error("Failed to create login items list", category: .lifecycle)
                return
            }
            
            if launchAtLogin {
                let appURL = Bundle.main.bundleURL as CFURL
                LSSharedFileListInsertItemURL(
                    loginItemsRef,
                    kLSSharedFileListItemLast.takeUnretainedValue(),
                    nil,
                    nil,
                    appURL,
                    nil,
                    nil
                )
            } else {
                if let loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil)?.takeUnretainedValue() as? [LSSharedFileListItem] {
                    for item in loginItems {
                        let itemURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeUnretainedValue()
                        
                        if let url = itemURL as URL?, url == Bundle.main.bundleURL {
                            LSSharedFileListItemRemove(loginItemsRef, item)
                        }
                    }
                }
            }
        }
    }

    func loadAvailableCalendarsAndRefresh() {
        Task { @MainActor in
            await loadAvailableCalendars()
        }
    }

    @MainActor
    func updateEnableCalendarSetting(_ value: Bool) async {
        /// Store the previous value to detect changes
        let previousValue = enableCalendar
        
        /// Update the stored value
        enableCalendar = value
        saveSettings()
        
        /// If enabling for the first time, check permission
        if value && !previousValue {
            /// Check current permission status
            let currentStatus = EKEventStore.authorizationStatus(for: .event)
            
            if currentStatus != .fullAccess {
                /// If we don't have permission, request it
                NotchlyLogger.calendar("🔄 Requesting calendar permission after enabling calendar feature")
                AppEnvironment.shared.calendarManager.requestAccess { [weak self] success in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        if success {
                            NotchlyLogger.calendar("✅ Calendar permission granted after enabling feature")
                            await self.loadAvailableCalendars()
                            /// Also refresh the UI
                            NotificationCenter.default.post(
                                name: SettingsChangeType.calendar.notificationName,
                                object: nil,
                                userInfo: ["permissionGranted": true]
                            )
                        } else {
                            NotchlyLogger.calendar("❌ Calendar permission denied after enabling feature")
                            /// Notify that permission was denied
                            NotificationCenter.default.post(
                                name: SettingsChangeType.calendar.notificationName,
                                object: nil,
                                userInfo: ["permissionDenied": true]
                            )
                        }
                    }
                }
            } else {
                /// If we already have permission, just load calendars
                await loadAvailableCalendars()
                await refreshCalendarEvents()
            }
        } else if !value && previousValue {
            /// If disabling, clear events
            AppEnvironment.shared.calendarManager.clearEvents()
            disableCalendarLiveActivity()
        }
        
        /// Always notify that calendar setting changed
        NotificationCenter.default.post(
            name: SettingsChangeType.calendar.notificationName,
            object: nil,
            userInfo: ["enabled": value]
        )
    }

    @MainActor
    func loadAvailableCalendars() async {
        let calendarManager = AppEnvironment.shared.calendarManager
        
        /// First check if we have calendar permission
        if calendarManager.hasCalendarPermission() {
            /// We have permission, load calendars
            let calendars = calendarManager.getAllCalendars()
            
            /// Only set all calendars to selected if we're initializing for the first time or if selection is empty
            if selectedCalendarIDs.isEmpty || isFirstLaunch() {
                selectedCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
                /// Force a save of the selected IDs
                saveSettings()
            }
        } else {
            /// No permission, don't try to load
            NotchlyLogger.calendar("⚠️ Cannot load calendars - no permission")
            if !selectedCalendarIDs.isEmpty {
                /// Clear selections if we don't have permission anymore
                selectedCalendarIDs = []
                saveSettings()
            }
        }
    }
    
    func handleCalendarPermissionChange(isGranted: Bool) {
        if isGranted {
            /// Permission was granted, load calendars
            Task { @MainActor in
                await loadAvailableCalendars()
            }

            /// Update any UI by posting a notification
            NotificationCenter.default.post(
                name: SettingsChangeType.calendar.notificationName,
                object: nil
            )
            
            /// No need to change enableCalendar as the user has already set it
        } else {
            /// Permission denied, show warning
            NotchlyLogger.calendar("⚠️ Calendar permission was denied")

            /// Post notification to UI can update accordingly
            NotificationCenter.default.post(
                name: SettingsChangeType.calendar.notificationName,
                object: nil,
                userInfo: ["permissionDenied": true]
            )
        }
    }
    
    @MainActor
    func refreshCalendarEvents() async {
        /// Only proceed if calendar is enabled and we have permission
        guard enableCalendar && EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            NotchlyLogger.calendar("📅 Skipping calendar refresh: Calendar is disabled or no permission")
            return
        }
        
        NotchlyLogger.calendar("📅 Refreshing calendar events with selected IDs: \(selectedCalendarIDs.count)")

        /// Wait for the reload to complete
        await AppEnvironment.shared.calendarManager.reloadSelectedCalendars(selectedCalendarIDs)
        
        /// Notify that calendar data has changed
        notifySettingsChanged(.calendar, userInfo: ["dataRefreshed": true])
    }
    
    private func disableCalendarLiveActivity() {
        /// Disable any active calendar alerts
        Task { @MainActor in
            AppEnvironment.shared.calendarActivityMonitor.reset()
        }
    }
    
    private func updateMediaPlayerSettings() {
        notifySettingsChanged(.media, userInfo: [
            "enableAppleMusic": enableAppleMusic,
            "enableSpotify": enableSpotify,
            "enablePodcasts": enablePodcasts
        ])
    }
}
