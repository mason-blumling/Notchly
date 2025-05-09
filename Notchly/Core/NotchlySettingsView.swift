//
//  NotchlySettingsView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/8/25.
//

import SwiftUI
import EventKit

struct NotchlySettingsView: View {
    @StateObject private var settings = NotchlySettings.shared
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.presentationMode) var presentationMode
    
    // For tabs
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case media = "Media"
        case calendar = "Calendar"
        case weather = "Weather"
        case about = "About"
        
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
    
    // Calendar loading
    @State private var availableCalendars: [EKCalendar] = []
    @State private var isLoadingCalendars: Bool = false
    @State private var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    HStack {
                        Image(systemName: tab.iconName)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .frame(width: 24)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = tab
                    }
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 140, idealWidth: 180)
            
            // Main Content
            VStack(spacing: 0) {
                // Content header
                ZStack {
                    Text(selectedTab.rawValue)
                        .font(.headline)
                        .padding()
                }
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Divider().opacity(0.5),
                    alignment: .bottom
                )
                
                // Content area
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Bottom actions bar with save button
                HStack {
                    Spacer()
                    
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Divider().opacity(0.5),
                    alignment: .top
                )
            }
            .frame(minWidth: 450, idealWidth: 550, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Notchly Preferences")
        .frame(width: 700, height: 500)
        .onAppear {
            loadCalendars()
            checkCalendarPermission()
        }
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Startup") {
                Toggle("Launch Notchly at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(SwitchToggleStyle())
            }
            
            SettingsSection(title: "Position") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Horizontal Offset")
                        .font(.subheadline)
                    
                    HStack {
                        Slider(value: $settings.horizontalOffset, in: -20...20, step: 1)
                            .frame(maxWidth: .infinity)
                        
                        Text("\(Int(settings.horizontalOffset))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                    
                    Text("Adjusts the notch position left or right from center")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            SettingsSection(title: "Hover Behavior") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hover Sensitivity")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Fast")
                            .font(.caption)
                        
                        Slider(value: $settings.hoverSensitivity, in: 0.05...0.3, step: 0.05)
                            .frame(maxWidth: .infinity)
                        
                        Text("Slow")
                            .font(.caption)
                    }
                    
                    Text("How quickly Notchly responds to your cursor")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Appearance Settings
    
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Theme") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Appearance Mode")
                        .font(.subheadline)
                    
                    Picker("", selection: $settings.appearanceMode) {
                        ForEach(NotchlySettings.AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
            }
            
            SettingsSection(title: "Colors") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Use System Accent Color", isOn: $settings.useSystemAccent)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if !settings.useSystemAccent {
                        ColorPicker("Custom Accent Color", selection: $settings.accentColor)
                    }
                }
            }
            
            SettingsSection(title: "Transparency") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Background Opacity")
                        .font(.subheadline)
                    
                    HStack {
                        Text("Transparent")
                            .font(.caption)
                        
                        Slider(value: $settings.backgroundOpacity, in: 0.5...1.0, step: 0.05)
                            .frame(maxWidth: .infinity)
                        
                        Text("Solid")
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Media Settings
    
    private var mediaSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Media Sources") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Apple Music", isOn: $settings.enableAppleMusic)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Toggle("Spotify", isOn: $settings.enableSpotify)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Toggle("Podcasts", isOn: $settings.enablePodcasts)
                        .toggleStyle(SwitchToggleStyle())
                }
            }
            
            SettingsSection(title: "Interactions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When artwork is clicked:")
                        .font(.subheadline)
                    
                    Picker("", selection: $settings.artworkClickAction) {
                        ForEach(NotchlySettings.ArtworkClickAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
            }
            
            SettingsSection(title: "Visual Effects") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show Background Glow", isOn: $settings.enableBackgroundGlow)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Toggle("Show Audio Visualization", isOn: $settings.showAudioBars)
                        .toggleStyle(SwitchToggleStyle())
                }
            }
        }
    }
    
    // MARK: - Calendar Settings
    
    private var calendarSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Calendar Integration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Toggle("Enable Calendar", isOn: $settings.enableCalendar)
                            .toggleStyle(SwitchToggleStyle())
                        
                        Spacer()
                        
                        if calendarPermissionStatus != .fullAccess {
                            Button("Request Access") {
                                requestCalendarAccess()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingCalendars)
                        }
                    }
                    
                    if calendarPermissionStatus != .fullAccess {
                        Text("Calendar access is required to show your events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(calendarPermissionStatus != .fullAccess)
            
            if settings.enableCalendar && calendarPermissionStatus == .fullAccess {
                SettingsSection(title: "Visible Calendars") {
                    ZStack {
                        if isLoadingCalendars {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else if availableCalendars.isEmpty {
                            Text("No calendars found")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                        CalendarRow(
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
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                }
                
                SettingsSection(title: "Event Alerts") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Event Alerts", isOn: $settings.enableCalendarAlerts)
                            .toggleStyle(SwitchToggleStyle())
                        
                        if settings.enableCalendarAlerts {
                            Text("Show alerts before event:")
                                .font(.subheadline)
                                .padding(.top, 4)
                            
                            HStack {
                                ForEach([15, 5, 1], id: \.self) { minutes in
                                    Toggle("\(minutes)m", isOn: Binding(
                                        get: { settings.alertTiming.contains(minutes) },
                                        set: { isOn in
                                            if isOn {
                                                if !settings.alertTiming.contains(minutes) {
                                                    settings.alertTiming.append(minutes)
                                                }
                                            } else {
                                                settings.alertTiming.removeAll { $0 == minutes }
                                            }
                                        }
                                    ))
                                    .toggleStyle(CheckboxToggleStyle())
                                }
                            }
                        }
                    }
                }
                
                SettingsSection(title: "Display Options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper(
                            "Show up to \(settings.maxEventsToDisplay) events",
                            value: $settings.maxEventsToDisplay,
                            in: 1...10
                        )
                        
                        Toggle("Show Event Organizer", isOn: $settings.showEventOrganizer)
                            .toggleStyle(SwitchToggleStyle())
                        
                        Toggle("Show Event Location", isOn: $settings.showEventLocation)
                            .toggleStyle(SwitchToggleStyle())
                        
                        Toggle("Show Event Attendees", isOn: $settings.showEventAttendees)
                            .toggleStyle(SwitchToggleStyle())
                    }
                }
            }
        }
        .disabled(calendarPermissionStatus != .fullAccess && settings.enableCalendar)
    }
    
    // MARK: - Weather Settings
    
    private var weatherSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Weather Display") {
                Toggle("Show Weather in Notchly", isOn: $settings.enableWeather)
                    .toggleStyle(SwitchToggleStyle())
            }
            
            if settings.enableWeather {
                SettingsSection(title: "Temperature Unit") {
                    Picker("", selection: $settings.weatherUnit) {
                        ForEach(NotchlySettings.WeatherUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .labelsHidden()
                }
                
                SettingsSection(title: "Location") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Use Current Location") {
                            // Request location permissions when implemented
                        }
                        .buttonStyle(.bordered)
                        
                        Text("Notchly uses your location only for weather forecasts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            // App logo
            NotchlyLogoShape()
                .fill(AngularGradient.notchly(offset: 0))
                .frame(width: 80, height: 80)
                .padding(.bottom, 10)
            
            Text("Notchly")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("© 2025 Mason Blumling")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
            
            Divider()
                .padding(.vertical, 10)
            
            Text("Notchly transforms your MacBook notch into an\nintuitive hub for your music and calendar.")
                .font(.body)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Button("Website") {
                    openURL("https://notchly.app")
                }
                .buttonStyle(.bordered)
                
                Button("Support") {
                    openURL("https://notchly.app/support")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
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
            await AppEnvironment.shared.calendarManager.requestAccess { granted in
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

// MARK: - Angular Gradient Extension

extension AngularGradient {
    static func notchly(offset: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 0.941, green: 0.42, blue: 0.455),  // Red
                Color(red: 0.95, green: 0.55, blue: 0.34),    // Orange
                Color(red: 0.95, green: 0.77, blue: 0.34),    // Yellow
                Color(red: 0.46, green: 0.81, blue: 0.44),    // Green
                Color(red: 0.34, green: 0.67, blue: 0.95),    // Blue
                Color(red: 0.62, green: 0.37, blue: 0.92),    // Purple
                Color(red: 0.941, green: 0.42, blue: 0.455)   // Back to red
            ]),
            center: .center,
            angle: .degrees(offset)
        )
    }
}

// MARK: - Supporting Views

/// A section with a title and content
struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
                .padding(.leading, 4)
            
            Divider()
                .padding(.top, 4)
        }
    }
}

/// Calendar row for selection
struct CalendarRow: View {
    var calendar: EKCalendar
    var isSelected: Bool
    var onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)
            
            Text(calendar.title)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .toggleStyle(SwitchToggleStyle())
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .frame(height: 30)
    }
}
