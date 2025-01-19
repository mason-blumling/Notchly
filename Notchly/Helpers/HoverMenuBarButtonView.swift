//
//  HoverMenuBarButtonView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/19/25.
//
//  This file defines a custom NSView, HoverMenuBarButtonView, which detects mouse hover events.
//  Using NSTrackingArea, it enables dynamic UI interactions by executing closures when
//  the mouse enters or exits the view.
//

import AppKit

/// A custom NSView that detects mouse hover events using NSTrackingArea.
/// It allows dynamic actions to be executed via closures when the mouse enters or exits the view.
/// - Note: This is used to determine if the curser entered the tracking space OR the window that appears
///         after the entry to ensure that the window does not disappear when navigating into it
class HoverMenuBarButtonView: NSView {
    
    // MARK: - Properties
    
    /// Closure executed when the mouse enters the view's bounds.
    var onMouseEnter: (() -> Void)?

    /// Closure executed when the mouse exits the view's bounds.
    var onMouseExit: (() -> Void)?
    
    // MARK: - Tracking Area Management

    /// Updates the view's tracking areas to detect hover events.
    /// Called automatically by the system when the view's bounds change.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove all existing tracking areas to ensure no duplicates
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        // Create a new tracking area that matches the view's bounds
        let trackingArea = NSTrackingArea(
            rect: bounds, // The area to monitor for mouse events
            options: [.mouseEnteredAndExited, .activeAlways], // Detect entry and exit events
            owner: self, // The owner responsible for handling the events
            userInfo: nil // No additional user info needed
        )

        // Add the new tracking area to the view
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Mouse Events
    
    /// Called when the mouse enters the view's bounds.
    ///
    /// - Parameter event: The mouse event associated with entering the view.
    override func mouseEntered(with event: NSEvent) {
        onMouseEnter?() // Execute the onMouseEnter closure, if defined
    }

    /// Called when the mouse exits the view's bounds.
    ///
    /// - Parameter event: The mouse event associated with exiting the view.
    override func mouseExited(with event: NSEvent) {
        onMouseExit?() // Execute the onMouseExit closure, if defined
    }
}
