//
//  HoverWindow.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `HoverWindow`, a custom `NSWindow` subclass.
//  It is used to create a transparent hover window that detects mouse events in the menu bar.
//

import AppKit

// MARK: - HoverWindow

/// A custom window that represents the hover area in the menu bar.
/// This window is transparent, always visible, and capable of detecting mouse events.
/// It acts as a virtual dotted line to determine curser entry or exit (to aide in triggering UI appearance)
class HoverWindow: NSWindow {

    // MARK: - Lifecycle Methods

    /// Makes the hover window the key window and displays it on the screen.
    /// Sets the window properties for interaction and visibility in the menu bar area.
    ///
    /// - Parameter sender: The object that triggered this action, if applicable.
    override func makeKeyAndOrderFront(_ sender: Any?) {
        self.level = .statusBar             // Ensures the window appears at the menu bar level.
        self.ignoresMouseEvents = false    // Allows the window to detect mouse events.
        self.isOpaque = false              // Makes the window transparent.
        self.orderFrontRegardless()        // Ensures the window appears, even if the app is not active.
        print("Hover window is visible.")  // Debugging log to confirm visibility.
    }
}
