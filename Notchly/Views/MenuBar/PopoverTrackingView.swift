//
//  PopoverTrackingView.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `PopoverTrackingView`, a custom `NSView` subclass.
//  It tracks mouse events inside the popover to manage its visibility.
//

import AppKit

// MARK: - PopoverTrackingView

/// A custom view that tracks mouse events inside the popover.
class PopoverTrackingView: NSView {

    // MARK: - Properties

    /// A weak reference to the `MenuBarController` for managing hover and popover visibility.
    weak var menuBarController: MenuBarController?

    // MARK: - Initializers

    /// Initializes the `PopoverTrackingView` with a specified frame and controller.
    ///
    /// - Parameters:
    ///   - frame: The frame for the tracking view.
    ///   - controller: The `MenuBarController` that handles popover state.
    init(frame: NSRect, controller: MenuBarController) {
        self.menuBarController = controller
        super.init(frame: frame)

        // MARK: Add Tracking Area
        // Define the area within the view that tracks mouse events.
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], // Added `.inVisibleRect`
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Mouse Event Handlers

    override func mouseEntered(with event: NSEvent) {
        print("Mouse entered popover")
        menuBarController?.hoverState = .overlay
        menuBarController?.debounceTimer?.invalidate()
    }

    override func mouseExited(with event: NSEvent) {
        print("Mouse exited popover")
        if menuBarController?.hoverState == .overlay {
            menuBarController?.hoverState = .none
            menuBarController?.debounceHideOverlay()
        }
    }
}
