//
//  NotchlyPermissionsView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/9/25.
//

import SwiftUI
import EventKit
import AppKit

/// A dedicated tab for managing and requesting permissions needed by Notchly.
/// This view shows current status of permissions and provides actions to request access.
struct NotchlyPermissionsView: View {
    // MARK: - Environment & State
    
    @Environment(\.colorScheme) private var colorScheme
    
    /// Permission States
    @State private var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined
    @State private var scriptingPermissionStatus: PermissionStatus = .unknown
    
    /// Loading States
    @State private var isCheckingCalendar = false
    @State private var isCheckingScripting = false
    
    // MARK: - Permission Status Type
    
    enum PermissionStatus {
        case unknown      /// Status not yet determined
        case checking     /// Actively checking permission state
        case granted      /// Permission has been granted
        case denied       /// Permission has been denied
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            permissionsExplanation
            
            /// Calendar Permission Section
            PermissionSectionView(
                title: "Calendar Access",
                description: "Notchly needs calendar access to display your upcoming events and provide timely alerts.",
                icon: "calendar",
                status: mapCalendarStatus(calendarPermissionStatus),
                isChecking: isCheckingCalendar,
                actionTitle: "Request Access",
                action: requestCalendarAccess
            )
            
            /// Automation/Scripting Permission Section
            PermissionSectionView(
                title: "Automation Control",
                description: "Required to control media playback in Music, Spotify, and Podcasts apps.",
                icon: "music.note",
                status: scriptingPermissionStatus,
                isChecking: isCheckingScripting,
                actionTitle: "Request Access",
                action: requestScriptingAccess
            )
            
            /// System Preferences Button
            systemPreferencesButton
            
            Spacer()
        }
        .padding(.bottom, 30)
        .onAppear {
            AppEnvironment.shared.checkCalendarPermissionStatus()
            checkAllPermissions()
        }
    }
    
    // MARK: - Components
    
    /// Explanation header for the permissions tab
    private var permissionsExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notchly requires certain permissions to provide its core functionality. You can grant or manage these permissions below.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// Button to open System Preferences
    private var systemPreferencesButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 8)
            
            Button(action: openSystemPreferences) {
                HStack(spacing: 8) {
                    Image(systemName: "gear")
                        .imageScale(.medium)
                    
                    Text("Open System Settings")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("You can also manage app permissions in System Settings > Privacy & Security.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    // MARK: - Permission Checks
    
    /// Check all permission states
    private func checkAllPermissions() {
        checkCalendarPermission()
        checkScriptingPermission()
    }
    
    /// Map EKAuthorizationStatus to our PermissionStatus for consistent display
    private func mapCalendarStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .unknown
        default:
            return .denied
        }
    }
    
    // MARK: - Calendar Permission
    
    private func checkCalendarPermission() {
        calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    private func requestCalendarAccess() {
        isCheckingCalendar = true
        
        AppEnvironment.shared.requestCalendarPermission { granted in
            DispatchQueue.main.async {
                self.isCheckingCalendar = false
                /// Always re-check the permission status after request
                self.checkCalendarPermission()
                
                /// If granted, also notify Settings model to update its state and load calendars
                if granted {
                    Task { @MainActor in
                        /// Update calendar settings
                        await NotchlySettings.shared.handleCalendarPermissionGranted()
                        
                        /// Force enable calendar in settings if permission was just granted
                        /// and it's currently disabled
                        if !NotchlySettings.shared.enableCalendar {
                            await NotchlySettings.shared.updateEnableCalendarSetting(true)
                        }
                    }
                }
                
                /// Post notification to update any UI components
                NotificationCenter.default.post(
                    name: SettingsChangeType.calendar.notificationName,
                    object: nil,
                    userInfo: ["permissionChanged": true, "permissionGranted": granted]
                )
            }
        }
    }

    // MARK: - Scripting Permission
    
    private func checkScriptingPermission() {
        isCheckingScripting = true
        
        Task {
            let result = await checkScriptingAccessStatus()
            DispatchQueue.main.async {
                self.scriptingPermissionStatus = result ? .granted : .denied
                self.isCheckingScripting = false
            }
        }
    }
    
    private func checkScriptingAccessStatus() async -> Bool {
        /// Use a non-blocking check script to avoid UI freezes
        let checkScript = NSAppleScript(source: """
            try
                tell application "System Events"
                    return true -- Permission already granted
                end tell
            on error
                return false -- Permission needed
            end try
        """)
        
        var checkError: NSDictionary?
        let result = checkScript?.executeAndReturnError(&checkError)
        
        return result?.booleanValue ?? false
    }
    
    private func requestScriptingAccess() {
        isCheckingScripting = true
        
        Task {
            // Request automation permission with a lightweight approach
            let requestScript = NSAppleScript(source: """
                tell application "System Events"
                    -- Simple command that triggers permission dialog
                    set frontApp to name of first process
                end tell
            """)
            
            requestScript?.executeAndReturnError(nil)
            
            // Check again after a short delay
            try? await Task.sleep(nanoseconds: 750_000_000) // 0.75 seconds
            
            let newStatus = await checkScriptingAccessStatus()
            
            DispatchQueue.main.async {
                self.scriptingPermissionStatus = newStatus ? .granted : .denied
                self.isCheckingScripting = false
            }
        }
    }
    
    // MARK: - System Preferences
    
    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Section View

struct PermissionSectionView: View {
    var title: String
    var description: String
    var icon: String
    var status: NotchlyPermissionsView.PermissionStatus
    var isChecking: Bool
    var actionTitle: String
    var action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon, title and description
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(statusColor.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
            
            // Status and action
            HStack {
                HStack(spacing: 6) {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                    }
                    
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                }
                
                Spacer()
                
                if status != .granted && !isChecking {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(PermissionActionButtonStyle())
                }
            }
        }
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
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if isChecking {
            return "Checking..."
        }
        
        switch status {
        case .granted:
            return "Access Granted"
        case .denied:
            return "Access Denied"
        case .unknown, .checking:
            return "Not Determined"
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .unknown, .checking:
            return "questionmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .unknown, .checking:
            return .orange
        }
    }
}

// MARK: - Button Style

struct PermissionActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .foregroundColor(.white)
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
