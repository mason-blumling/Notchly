//
//  NotchlySettingsView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/8/25.
//

import SwiftUI
import EventKit

/// A modern, polished settings interface for Notchly that maintains all existing functionality
/// while providing a more visually refined user experience that aligns with Notchly's design language.
struct NotchlySettingsView: View {
    @StateObject private var settings = NotchlySettings.shared
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.presentationMode) var presentationMode
    
    /// Environment color scheme for dark/light mode adaptability
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Tab Definition
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case media = "Media"
        case calendar = "Calendar"
        case weather = "Weather"
        case about = "About"
        
        var id: String { self.rawValue }
        
        var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .media: return "music.note"
            case .calendar: return "calendar"
            case .weather: return "cloud.sun"
            case .about: return "info.circle"
            }
        }
    }
    
    // MARK: - Calendar Loading State
    
    @State private var availableCalendars: [EKCalendar] = []
    @State private var isLoadingCalendars: Bool = false
    @State private var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined
    
    // MARK: - Design Constants
    
    private let cornerRadius: CGFloat = 12
    private let sectionSpacing: CGFloat = 24
    private let contentSpacing: CGFloat = 12
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .gray : Color(.secondaryLabelColor)
    }
    
    private var accentGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.blue, .purple]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - Sidebar
            sidebarView
                .frame(width: 200)
                .background(Color(NSColor.windowBackgroundColor))
            
            // MARK: - Main Content
            VStack(spacing: 0) {
                /// Content header
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
                        .background(
                            colorScheme == .dark ?
                                Color(NSColor.windowBackgroundColor).opacity(0.5) :
                                Color(NSColor.controlBackgroundColor).opacity(0.2)
                        )
                        .overlay(
                            Divider().opacity(0.3),
                            alignment: .bottom
                        )
                    
                    HStack {
                        Image(systemName: selectedTab.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentGradient)
                        
                        Text(selectedTab.rawValue)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(foregroundColor)
                    }
                    .padding(.leading, 20)
                }
                
                /// Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        switch selectedTab {
                        case .general:
                            generalSettings
                        case .appearance:
                            appearanceSettings
                        case .media:
                            mediaSettings
                        case .calendar:
                            calendarSettings
                        case .weather:
                            weatherSettings
                        case .about:
                            aboutView
                        }
                    }
                    .padding([.horizontal, .top], 30)
                    .padding(.bottom, 50)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                /// Bottom actions bar
                ZStack {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60)
                        .background(
                            colorScheme == .dark ?
                                Color(NSColor.windowBackgroundColor).opacity(0.7) :
                                Color(NSColor.controlBackgroundColor).opacity(0.3)
                        )
                        .overlay(
                            Divider().opacity(0.3),
                            alignment: .top
                        )
                    
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(ModernButtonStyle(isPrimary: false))
                    .keyboardShortcut(.escape, modifiers: [])
                }
            }
        }
        .onAppear {
            loadCalendars()
            checkCalendarPermission()
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            /// Sidebar header with logo
            VStack(spacing: 8) {
                NotchlyLogoShape()
                    .fill(AngularGradient.notchly(offset: 0))
                    .frame(width: 36, height: 36)
                
                Text("Notchly")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(foregroundColor)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .background(
                Rectangle()
                    .fill(Color.clear)
                    .frame(maxWidth: .infinity)
                    .background(
                        colorScheme == .dark ?
                            Color(NSColor.windowBackgroundColor).opacity(0.7) :
                            Color(NSColor.controlBackgroundColor).opacity(0.3)
                    )
                    .overlay(
                        Divider().opacity(0.5),
                        alignment: .bottom
                    )
            )
            
            /// Tab list
            List {
                ForEach(SettingsTab.allCases) { tab in
                    tabRowView(tab)
                }
            }
            .listStyle(SidebarListStyle())
            .overlay(
                Divider().opacity(0.3),
                alignment: .leading
            )
        }
    }
    
    private func tabRowView(_ tab: SettingsTab) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tab.iconName)
                .font(.system(size: 14))
                .frame(width: 20)
                .foregroundColor(selectedTab == tab ? .accentColor : secondaryTextColor)
            
            Text(tab.rawValue)
                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                .foregroundColor(selectedTab == tab ? foregroundColor : secondaryTextColor)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            ZStack {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        }
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            /// Startup
            SettingsSectionView(title: "Startup", icon: "power") {
                ToggleRow(
                    title: "Launch Notchly at login",
                    description: "Start Notchly automatically when you log in to your Mac",
                    isOn: $settings.launchAtLogin
                )
            }
            
            /// Position
            SettingsSectionView(title: "Position", icon: "arrow.left.and.right") {
                SliderRow(
                    title: "Horizontal Offset",
                    description: "Adjusts the notch position left or right from center",
                    value: $settings.horizontalOffset,
                    range: -20...20,
                    step: 1,
                    valueFormatter: { "\(Int($0))%" }
                )
            }
            
            /// Hover behavior
            SettingsSectionView(title: "Hover Behavior", icon: "hand.point.up.fill") {
                VStack(spacing: contentSpacing) {
                    HStack {
                        Text("Hover Sensitivity")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Text("Fast")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                        
                        CustomSlider(
                            value: $settings.hoverSensitivity,
                            range: 0.05...0.3,
                            step: 0.05
                        )
                        .frame(maxWidth: .infinity)
                        
                        Text("Slow")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Text("How quickly Notchly responds to your cursor")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            // Theme
            SettingsSectionView(title: "Theme", icon: "paintpalette") {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Text("Appearance Mode")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Picker("", selection: $settings.appearanceMode) {
                        ForEach(NotchlySettings.AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
            
            /// Colors
            SettingsSectionView(title: "Colors", icon: "eyedropper") {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    ToggleRow(
                        title: "Use System Accent Color",
                        description: "Match Notchly's accent color with your system settings",
                        isOn: $settings.useSystemAccent
                    )
                    
                    if !settings.useSystemAccent {
                        HStack {
                            Text("Custom Accent Color")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Spacer()
                            
                            ColorPicker("", selection: $settings.accentColor)
                                .labelsHidden()
                                .scaleEffect(0.8)
                                .frame(width: 30)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            /// Transparency
            SettingsSectionView(title: "Transparency", icon: "slider.horizontal.below.rectangle") {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    HStack {
                        Text("Background Opacity")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        Text("Transparent")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                        
                        CustomSlider(
                            value: $settings.backgroundOpacity,
                            range: 0.5...1.0,
                            step: 0.05
                        )
                        .frame(maxWidth: .infinity)
                        
                        Text("Solid")
                            .font(.system(size: 12))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Media Settings
    
    private var mediaSettings: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            /// Media sources
            SettingsSectionView(title: "Media Sources", icon: "music.note.list") {
                VStack(spacing: contentSpacing) {
                    ToggleRow(
                        icon: "applemusic",
                        title: "Apple Music",
                        description: "Show Apple Music playback controls",
                        isOn: $settings.enableAppleMusic
                    )
                    
                    Divider().padding(.vertical, 4)
                    
                    ToggleRow(
                        icon: "spotify",
                        title: "Spotify",
                        description: "Show Spotify playback controls",
                        isOn: $settings.enableSpotify
                    )
                    
                    Divider().padding(.vertical, 4)
                    
                    ToggleRow(
                        icon: "podcast",
                        title: "Podcasts",
                        description: "Show Podcasts playback controls",
                        isOn: $settings.enablePodcasts
                    )
                }
            }
            
            /// Interactions
            SettingsSectionView(title: "Interactions", icon: "hand.tap") {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    Text("When artwork is clicked:")
                        .font(.system(size: 14, weight: .semibold))
                    
                    SegmentedPicker(
                        selection: $settings.artworkClickAction,
                        options: NotchlySettings.ArtworkClickAction.allCases
                    ) { action in
                        Text(action.rawValue)
                            .font(.system(size: 13))
                    }
                }
                .padding(.vertical, 4)
            }
            
            /// Visual effects
            SettingsSectionView(title: "Visual Effects", icon: "sparkles") {
                VStack(spacing: contentSpacing) {
                    ToggleRow(
                        icon: "paintpalette.fill",  // Updated icon for background glow
                        title: "Show Background Glow",
                        description: "Display color-adaptive glow behind album artwork",
                        isOn: $settings.enableBackgroundGlow
                    )
                    
                    Divider().padding(.vertical, 4)
                    
                    ToggleRow(
                        icon: "waveform",
                        title: "Show Audio Visualization",
                        description: "Display animated audio bars when music is playing",
                        isOn: $settings.showAudioBars
                    )
                }
            }
        }
    }
    
    // MARK: - Calendar Settings
    
    private var calendarSettings: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            /// Calendar integration
            SettingsSectionView(title: "Calendar Integration", icon: "calendar.badge.clock") {
                VStack(spacing: contentSpacing) {
                    HStack {
                        Toggle(isOn: $settings.enableCalendar) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("Show your upcoming calendar events")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        
                        Spacer()
                        
                        if calendarPermissionStatus != .fullAccess {
                            Button("Request Access") {
                                requestCalendarAccess()
                            }
                            .buttonStyle(ModernButtonStyle(isPrimary: true))
                            .disabled(isLoadingCalendars)
                        }
                    }
                    
                    if calendarPermissionStatus != .fullAccess {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            
                            Text("Calendar access is required to show your events")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .disabled(calendarPermissionStatus != .fullAccess)
            
            if settings.enableCalendar && calendarPermissionStatus == .fullAccess {
                /// Visible calendars
                SettingsSectionView(title: "Visible Calendars", icon: "list.bullet.rectangle") {
                    ZStack {
                        if isLoadingCalendars {
                            VStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 100)
                                
                                Text("Loading calendars...")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                            }
                        } else if availableCalendars.isEmpty {
                            Text("No calendars found")
                                .font(.system(size: 13))
                                .foregroundColor(secondaryTextColor)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ScrollView {
                                VStack(spacing: 2) {
                                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                        EnhancedCalendarRow(
                                            calendar: calendar,
                                            isSelected: settings.selectedCalendarIDs.contains(calendar.calendarIdentifier),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    settings.selectedCalendarIDs.insert(calendar.calendarIdentifier)
                                                } else {
                                                    settings.selectedCalendarIDs.remove(calendar.calendarIdentifier)
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(maxHeight: 200)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(NSColor.textBackgroundColor).opacity(0.3))
                            )
                        }
                    }
                }
                
                /// Event alerts
                SettingsSectionView(title: "Event Alerts", icon: "bell") {
                    VStack(spacing: contentSpacing) {
                        ToggleRow(
                            title: "Enable Event Alerts",
                            description: "Get notified before upcoming calendar events",
                            isOn: $settings.enableCalendarAlerts
                        )
                        
                        if settings.enableCalendarAlerts {
                            Divider().padding(.vertical, 4)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Show alerts before event:")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                HStack(spacing: 20) {
                                    ForEach([15, 5, 1], id: \.self) { minutes in
                                        AlertMinuteOption(
                                            minutes: minutes,
                                            isSelected: settings.alertTiming.contains(minutes),
                                            onToggle: { isSelected in
                                                if isSelected {
                                                    if !settings.alertTiming.contains(minutes) {
                                                        settings.alertTiming.append(minutes)
                                                    }
                                                } else {
                                                    settings.alertTiming.removeAll { $0 == minutes }
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                
                /// Display options
                SettingsSectionView(title: "Display Options", icon: "text.viewfinder") {
                    VStack(spacing: contentSpacing) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Maximum Events")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("Show up to \(settings.maxEventsToDisplay) events")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    if settings.maxEventsToDisplay > 1 {
                                        settings.maxEventsToDisplay -= 1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .padding(8)
                                }
                                .buttonStyle(StepperButtonStyle())
                                .disabled(settings.maxEventsToDisplay <= 1)
                                
                                Text("\(settings.maxEventsToDisplay)")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .frame(width: 36, alignment: .center)
                                
                                Button(action: {
                                    if settings.maxEventsToDisplay < 20 {
                                        settings.maxEventsToDisplay += 1
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .padding(8)
                                }
                                .buttonStyle(StepperButtonStyle())
                                .disabled(settings.maxEventsToDisplay >= 20)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        ToggleRow(
                            icon: "person",
                            title: "Show Event Organizer",
                            description: "Display who organized each event",
                            isOn: $settings.showEventOrganizer
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ToggleRow(
                            icon: "mappin.and.ellipse",
                            title: "Show Event Location",
                            description: "Display event locations when available",
                            isOn: $settings.showEventLocation
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        ToggleRow(
                            icon: "person.2",
                            title: "Show Event Attendees",
                            description: "Display attendee status for each event",
                            isOn: $settings.showEventAttendees
                        )
                    }
                }
            }
        }
        .disabled(calendarPermissionStatus != .fullAccess && settings.enableCalendar)
    }
    
    // MARK: - Weather Settings
    
    private var weatherSettings: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            /// Weather display
            SettingsSectionView(title: "Weather Display", icon: "cloud.sun") {
                VStack(spacing: contentSpacing) {
                    ToggleRow(
                        title: "Show Weather in Notchly",
                        description: "Display current weather conditions",
                        isOn: $settings.enableWeather
                    )
                    
                    /// Experimental notice
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .imageScale(.small)
                        
                        Text("Weather functionality is experimental and still in development")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            }
            
            if settings.enableWeather {
                /// Temperature unit
                SettingsSectionView(title: "Temperature Unit", icon: "thermometer") {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        SegmentedPicker(
                            selection: $settings.weatherUnit,
                            options: NotchlySettings.WeatherUnit.allCases
                        ) { unit in
                            HStack {
                                Image(systemName: unit == .celsius ? "c.circle.fill" : "f.circle.fill")
                                    .imageScale(.small)
                                Text(unit.rawValue)
                            }
                            .font(.system(size: 13))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                /// Location
                SettingsSectionView(title: "Location", icon: "location") {
                    VStack(alignment: .leading, spacing: contentSpacing) {
                        Button("Use Current Location") {
                            // Implementation pending
                        }
                        .buttonStyle(ModernButtonStyle(isPrimary: true))
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(secondaryTextColor)
                                .imageScale(.small)
                            
                            Text("Notchly uses your location only for weather forecasts")
                                .font(.system(size: 12))
                                .foregroundColor(secondaryTextColor)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.orange)
                                .imageScale(.medium)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Coming Soon")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.orange)
                                
                                Text("Additional weather features including forecasts, weather maps, and custom location support will be added in future updates.")
                                    .font(.system(size: 12))
                                    .foregroundColor(secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        VStack(spacing: 24) {
            /// App logo
            VStack(spacing: 14) {
                NotchlyLogoShape()
                    .fill(AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360)))
                    .frame(width: 100, height: 100)
                
                Text("Notchly")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Version 2.5.1")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.top, 20)
            
            /// Description
            VStack(spacing: 20) {
                Text("Notchly transforms your MacBook notch into an\nintuitive hub for your music and calendar.")
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                
                Text("© 2025 Mason Blumling")
                    .font(.system(size: 13))
                    .foregroundColor(secondaryTextColor)
            }
            
            // Links
            HStack(spacing: 20) {
                LinkButton(title: "Website", icon: "globe", action: {
                    openURL("https://notchly.app")
                })
                
                LinkButton(title: "Support", icon: "questionmark.circle", action: {
                    openURL("https://notchly.app/support")
                })
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func loadCalendars() {
        isLoadingCalendars = true
        
        Task {
            let eventStore = EKEventStore()
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess:
                availableCalendars = eventStore.calendars(for: .event)
            default:
                availableCalendars = []
            }
            
            DispatchQueue.main.async {
                isLoadingCalendars = false
            }
        }
    }
    
    private func checkCalendarPermission() {
        calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    private func requestCalendarAccess() {
        isLoadingCalendars = true
        
        Task {
            AppEnvironment.shared.calendarManager.requestAccess { granted in
                DispatchQueue.main.async {
                    self.isLoadingCalendars = false
                    self.checkCalendarPermission()
                    if granted {
                        self.loadCalendars()
                    }
                }
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Section View

struct SettingsSectionView<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: () -> Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            /// Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(.bottom, 4)
            
            /// Content Container
            content()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ?
                              Color(NSColor.textBackgroundColor).opacity(0.07) :
                              Color(NSColor.textBackgroundColor).opacity(0.5))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                            radius: 2,
                            x: 0,
                            y: 1
                        )
                )
        }
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    var icon: String? = nil
    var title: String
    var description: String
    @Binding var isOn: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
        }
    }
}

// MARK: - Slider Row

struct SliderRow: View {
    var title: String
    var description: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var valueFormatter: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text(valueFormatter(value))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.accentColor)
                    .monospacedDigit()
                    .frame(minWidth: 40)
            }
            
            CustomSlider(value: $value, range: range, step: step)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(Color(.secondaryLabelColor))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Custom Slider

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                /// Track
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                    .frame(height: 4)
                
                /// Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(16, getThumbPosition(in: geometry.size.width)), height: 4)
                
                /// Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                    .offset(x: getThumbPosition(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                updateValue(at: value.location.x, in: geometry.size.width)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .padding(.horizontal, 2)
            .frame(height: 24)
            .contentShape(Rectangle())
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        let location = NSEvent.mouseLocation
                        let convertedPoint = geometry.frame(in: .global).contains(location)
                            ? NSEvent.mouseLocation.x - geometry.frame(in: .global).minX
                            : 0
                        
                        updateValue(at: convertedPoint, in: geometry.size.width)
                    }
            )
        }
        .frame(height: 24)
    }
    
    private func getThumbPosition(in width: CGFloat) -> CGFloat {
        let percent = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(CGFloat(percent) * width, width))
    }
    
    private func updateValue(at position: CGFloat, in width: CGFloat) {
        let percent = max(0, min(position / width, 1.0))
        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
        
        // Round to nearest step
        let roundedValue = round(newValue / step) * step
        value = max(range.lowerBound, min(roundedValue, range.upperBound))
    }
}

// MARK: - Segmented Picker

struct SegmentedPicker<T: Hashable, Content: View>: View {
    @Binding var selection: T
    let options: [T]
    let content: (T) -> Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                let option = options[index]
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    content(option)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == option ?
                                Color.accentColor.opacity(0.15) :
                                Color.clear
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(selection == option ? .accentColor : .primary.opacity(0.7))
                
                if index < options.count - 1 {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Enhanced Calendar Row

struct EnhancedCalendarRow: View {
    var calendar: EKCalendar
    var isSelected: Bool
    var onToggle: (Bool) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
            
            // Calendar title
            Text(calendar.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            // Toggle switch
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ?
                      (colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.08)) :
                      Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Alert Minute Option

struct AlertMinuteOption: View {
    let minutes: Int
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            VStack(spacing: 6) {
                Text("\(minutes)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                
                Text(minutes == 1 ? "minute" : "minutes")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor.opacity(0.8) : .gray)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ?
                          Color.accentColor.opacity(0.15) :
                          (colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

// MARK: - Button Styles

struct ModernButtonStyle: ButtonStyle {
    var isPrimary: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPrimary ? Color.accentColor : Color.gray.opacity(0.15))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundColor(isPrimary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct StepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.primary)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Link Button

struct LinkButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(
                        isHovering ?
                        Color.accentColor.opacity(0.15) :
                        (colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.1))
                    )
            )
            .foregroundColor(.accentColor)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Gradient Extension

extension AngularGradient {
    static func notchly(offset: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 0.941, green: 0.42, blue: 0.455),  /// Red
                Color(red: 0.95, green: 0.55, blue: 0.34),    /// Orange
                Color(red: 0.95, green: 0.77, blue: 0.34),    /// Yellow
                Color(red: 0.46, green: 0.81, blue: 0.44),    /// Green
                Color(red: 0.34, green: 0.67, blue: 0.95),    /// Blue
                Color(red: 0.62, green: 0.37, blue: 0.92),    /// Purple
                Color(red: 0.941, green: 0.42, blue: 0.455)   /// Back to red
            ]),
            center: .center,
            angle: .degrees(offset)
        )
    }
}
