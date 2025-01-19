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
        // Create and add an NSTrackingArea for detecting mouse movement events.
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Mouse Event Handlers

    /// Handles mouse entry into the popover area.
    /// - Parameter event: The mouse event that triggered this method.
    override func mouseEntered(with event: NSEvent) {
        print("Mouse entered popover")
        menuBarController?.isMouseInPopover = true
    }

    /// Handles mouse exit from the popover area.
    /// - Parameter event: The mouse event that triggered this method.
    /// - Note: `debounceTimer` is utilized for a quick entry-exit to ensure the animation/window does not lag behind
    override func mouseExited(with event: NSEvent) {
        print("Mouse exited popover")
        menuBarController?.isMouseInPopover = false

        // Schedule the debounce timer to hide the popover if the mouse is no longer in any active area.
        menuBarController?.debounceTimer?.invalidate()
        menuBarController?.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !(self.menuBarController?.isMouseInHoverArea ?? false) {
                self.menuBarController?.hidePopover()
            }
        }
    }
}
