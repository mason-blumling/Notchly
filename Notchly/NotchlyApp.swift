//
//  NotchlyApp.swift
//  Notchly
//
//  Created by Mason Blumling on 12/10/24.
//
//  This file serves as the entry point for the Notchly macOS app.
//  It defines the main app structure, initializes the menu bar controller,
//  and specifies the primary scene for the app.
//

import SwiftUI

@main
struct NotchlyApp: App {
    // MARK: - Properties
    
    /// The menu bar controller manages the app's menu bar item and its associated functionality.
    @StateObject private var menuBarController = MenuBarController()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            /// The main content view of the app.
            ContentView()
        }
    }
}
