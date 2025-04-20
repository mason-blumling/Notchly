//
//  NotchlyApp.swift
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

    var notchly: Notchly<AnyView>!
    var appEnvironment: AppEnvironment!

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self // Register shared instance

        Task { @MainActor in
            self.appEnvironment = AppEnvironment()

            var tempNotchly: Notchly<AnyView>!
            tempNotchly = Notchly {
                AnyView(
                    NotchlyContainerView(notchly: tempNotchly)
                        .foregroundStyle(.white)
                )
            }
            self.notchly = tempNotchly

            if let screen = NSScreen.main {
                self.notchly.initializeWindow(screen: screen)
                self.notchly.isVisible = true
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
