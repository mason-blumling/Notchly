//
//  NotchlyApp.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI
import Combine
import EventKit

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

        print("🚀 Notchly App is Launching...")
        AppDelegate.shared = self

        /// Initialize the status bar item
        DispatchQueue.main.async {
            self.statusBarItem = NotchlyStatusBarItem()
            print("Status Bar Item Initialized")
        }

        Task { @MainActor in
            /// Create the view model
            self.viewModel = NotchlyViewModel.shared
            print("ViewModel Initialized")

            /// Initialize the environment (with new proactive initialization)
            AppEnvironment.shared.initialize()
            print("Environment Initialized")

            /// Initialize and show on the main screen
            if let screen = NSScreen.main {
                await self.viewModel.initializeWindow(screen: screen)
                print("Window Initialized on Main Screen")

                /// Handle first launch logic
                self.handleFirstLaunch()
            } else {
                print("⚠️ No Main Screen Found")
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
            print("Normal Launch Complete")
            return
        }
        
        /// First launch - show the intro sequence
        print("First Launch Detected - Showing Intro")
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
