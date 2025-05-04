//
//  NotchlyApp+FirstLaunch.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI

// Update the AppDelegate applicationDidFinishLaunching method
extension AppDelegate {
    func applicationDidFinishLaunchingWithIntro(_ notification: Notification) {
        AppDelegate.shared = self

        Task { @MainActor in
            /// Create the view model
            self.viewModel = NotchlyViewModel.shared

            /// Initialize and show on the main screen
            if let screen = NSScreen.main {
                await self.viewModel.initializeWindow(screen: screen)
                
                // Handle first launch logic
                self.handleFirstLaunch()
            }
        }
    }
}
