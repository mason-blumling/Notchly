//
//  NotchlyApp.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI
import Combine
import EventKit
import os.log

// MARK: - Application Entry Point

@main
struct NotchlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate /// Delegate to manage app lifecycle

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
    var viewModel: NotchlyViewModel!

    /// Strong reference to status bar manager (critical to prevent deallocation)
    private var statusBarItem: NotchlyStatusBarItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        /// Uncomment this line when you want to test the intro flows
        /// UserDefaults.standard.removeObject(forKey: "com.notchly.hasShownIntro")

        NotchlyLogger.lifecycle("🚀 Notchly app is launching...")
        AppDelegate.shared = self

        /// Initialize the status bar item
        DispatchQueue.main.async {
            self.statusBarItem = NotchlyStatusBarItem()
            NotchlyLogger.lifecycle("Status bar item initialized")
        }

        Task { @MainActor in
            /// Create the view model
            self.viewModel = NotchlyViewModel.shared
            NotchlyLogger.lifecycle("View model initialized")

            /// Initialize the environment (with new proactive initialization)
            AppEnvironment.shared.initialize()
            NotchlyLogger.lifecycle("App environment initialized")

            /// Initialize and show on the main screen
            if let screen = NSScreen.main {
                await self.viewModel.initializeWindow(screen: screen)
                NotchlyLogger.lifecycle("Notchly window initialized on main screen")

                /// Handle first launch logic
                self.handleFirstLaunch()
            } else {
                NotchlyLogger.lifecycle("⚠️ No main screen found")
            }
        }

        /// Set up testing keyboard shortcut with helper
        NotchlyTestingHelper.shared.setupForAppDelegate(self)
    }

    /// This method stays in AppDelegate because it's core app functionality
    @MainActor
    func handleFirstLaunch() {
        guard viewModel.isFirstLaunch else {
            /// Normal launch - ensure we're in collapsed state
            viewModel.state = .collapsed
            viewModel.isVisible = true
            NotchlyLogger.lifecycle("Normal launch complete")
            return
        }

        /// First launch - show the intro sequence
        NotchlyLogger.lifecycle("First launch detected – showing intro sequence")
        showIntroSequence()
    }

    /// This method stays in AppDelegate because it's core app functionality
    @MainActor
    private func showIntroSequence() {
        Task { @MainActor in
            viewModel.state = .collapsed
            viewModel.isVisible = true
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            viewModel.showIntro()
        }
    }

    /// Just this menu-triggering method stays in AppDelegate
    @objc func showDevTestingMenu() {
        NotchlyTestingHelper.shared.showTestingMenu(for: self)
    }
}
