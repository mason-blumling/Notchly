//
//  NotchlyApp.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI
import Combine

// MARK: - Application Entry Point

@main
struct NotchlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // Delegate to manage app lifecycle

    var body: some Scene {
        // 🔥 Settings scene is currently empty
        Settings {
            EmptyView() // Placeholder for future settings UI
        }
    }
}

// MARK: - App Delegate

/// Handles the initialization and configuration of the Notchly app.
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!
    var notchly: Notchly!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        Task { @MainActor in
            // Create the non-generic notch controller
            let tempNotchly = Notchly()
            self.notchly = tempNotchly

            // Initialize and show on the main screen
            if let screen = NSScreen.main {
                await tempNotchly.initializeWindow(screen: screen)
                tempNotchly.isVisible = true
            }
        }
    }
}

// MARK: - Sample Content View

/// A placeholder content view for testing the hover state.
struct ContentView: View {
    var body: some View {
        VStack { Text("HI") }
    }
}
