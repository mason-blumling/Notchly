//
//  NotchlyTestingHelper.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI
import EventKit
import AppKit
import os.log

/// A helper class that provides testing utilities for Notchly
class NotchlyTestingHelper {
    
    /// Singleton instance
    static let shared = NotchlyTestingHelper()
    
    /// Bundle identifier for the app
    private let bundleID = Bundle.main.bundleIdentifier ?? "com.apple.Notchly"
    
    /// Keys that we want to preserve during reset
    private let preservedKeys = [
        "NSWindow Frame",
        "TB Is Shown",
        "NSStatusItem",
        "NSSplitView"
    ]
    
    /// Keep a weak reference to AppDelegate
    private weak var appDelegate: AppDelegate?
    
    /// Set up testing for AppDelegate
    func setupForAppDelegate(_ delegate: AppDelegate) {
        self.appDelegate = delegate
        setupKeyboardShortcut()
    }
    
    /// Set up keyboard shortcut for testing menu
    private func setupKeyboardShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            /// Command+Option+T for test menu
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.option) &&
               event.keyCode == 17 { // T key
                if let delegate = self?.appDelegate {
                    delegate.showDevTestingMenu()
                }
                return nil
            }
            return event
        }
    }
    
    /// Present a testing menu to reset different aspects of the app
    func showTestingMenu(for delegate: AppDelegate) {
        let menu = NSMenu(title: "Notchly Testing")
        
        let introItem = NSMenuItem(title: "Reset Intro Experience", action: #selector(resetIntroExperience), keyEquivalent: "1")
        introItem.target = self
        menu.addItem(introItem)
        
        let calendarItem = NSMenuItem(title: "Reset Calendar Permissions", action: #selector(resetCalendarPermissions), keyEquivalent: "2")
        calendarItem.target = self
        menu.addItem(calendarItem)
        
        let settingsItem = NSMenuItem(title: "Reset App Settings", action: #selector(resetAppSettings), keyEquivalent: "3")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let resetAllItem = NSMenuItem(title: "Reset Everything & Quit", action: #selector(resetEverything), keyEquivalent: "0")
        resetAllItem.target = self
        menu.addItem(resetAllItem)
        
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    /// Reset only the intro experience flag
    @objc func resetIntroExperience() {
        UserDefaults.standard.removeObject(forKey: "com.notchly.hasShownIntro")
        UserDefaults.standard.removeObject(forKey: "hasSeenFirstLaunch")
        NotchlyLogger.debug("✅ Intro experience reset — restart app to see intro", category: .general)
        showRestartRecommendation("Intro experience reset")
    }
    
    /// Reset calendar permissions using TCC database
    @objc func resetCalendarPermissions() {
        /// First approach - through Calendar framework
        resetEKEventStorePermissions()
        
        /// Second approach - show instructions
        let alert = NSAlert()
        alert.messageText = "Calendar Permissions Reset"
        alert.informativeText = "To fully reset calendar permissions, please also go to System Settings > Privacy & Security > Calendar and remove Notchly from the list."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openPrivacySettings()
        }
    }
    
    /// Reset app settings but preserve window positions
    @objc func resetAppSettings() {
        /// Save values we want to preserve
        var preservedValues = [String: Any]()
        
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            /// Only preserve specific settings like window positions
            if preservedKeys.contains(where: { key.hasPrefix($0) }) {
                preservedValues[key] = defaults.object(forKey: key)
            }
        }
        
        /// Reset the flag to trigger defaults initialization
        defaults.removeObject(forKey: "notchlySettingsInitialized")
        
        /// Reset calendar selections
        defaults.removeObject(forKey: "selectedCalendarIDs")
        
        /// Reset specific settings
        defaults.removeObject(forKey: "enableCalendar")
        defaults.removeObject(forKey: "enableCalendarAlerts")
        defaults.removeObject(forKey: "enableWeather")
        defaults.removeObject(forKey: "alertTiming")
        
        for (key, value) in preservedValues {
            defaults.set(value, forKey: key)
        }
        
        NotchlyLogger.debug("✅ App settings reset — restart app to reinitialize", category: .general)
        showRestartRecommendation("App settings reset")
    }
    
    /// Reset everything for a clean slate
    @objc func resetEverything() {
        let alert = NSAlert()
        alert.messageText = "Reset Everything?"
        alert.informativeText = "This will reset ALL Notchly settings, permissions, and user data. The app will quit and need to be restarted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset & Quit")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            /// Save window frame positions
            var windowFrames = [String: Any]()
            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                if key.contains("NSWindow Frame") {
                    windowFrames[key] = UserDefaults.standard.object(forKey: key)
                }
            }
            
            /// Clear all defaults
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            resetEKEventStorePermissions()
            
            /// Restore window frames
            for (key, value) in windowFrames {
                UserDefaults.standard.set(value, forKey: key)
            }
            
            /// Quit the app
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Reset EventKit permissions
    private func resetEKEventStorePermissions() {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { _, _ in
            NotchlyLogger.debug("✅ Calendar permission state refreshed", category: .general)
        }
    }
    
    /// Open System Settings to Privacy & Security
    private func openPrivacySettings() {
        var urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        
        if #available(macOS 13, *) {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Show a restart recommendation alert
    private func showRestartRecommendation(_ title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "It's recommended to restart Notchly to apply the changes. Would you like to restart now?"
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let task = Process()
                task.launchPath = "/bin/sh"
                task.arguments = ["-c", "sleep 0.2; open \"\(Bundle.main.bundlePath)\""]
                try? task.run()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

// MARK: - SwiftUI Integration

/// A view modifier to add testing features to any view
struct TestingHelpersViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            /// SwiftUI integration is now handled through AppDelegate
        }
    }
}

/// A convenience extension to apply the testing modifier
extension View {
    func withTestingHelpers() -> some View {
        self.modifier(TestingHelpersViewModifier())
    }
}
