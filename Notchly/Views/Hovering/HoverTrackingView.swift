//
//  HoverTrackingView.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `HoverTrackingView`, a custom `NSView` subclass.
//  It tracks mouse entry and exit events within the designated hover area and communicates
//  with the `MenuBarController` to manage the popover's visibility.
//

import AppKit

// MARK: - HoverTrackingView

/// A custom view that tracks mouse events within the hover area.
class HoverTrackingView: NSView {

    // MARK: - Properties

    /// A weak reference to the `MenuBarController` for managing the popover's state.
    weak var menuBarController: MenuBarController?

    // MARK: - Initializers

    /// Initializes the `HoverTrackingView` with a specified frame and controller.
    ///
    /// - Parameters:
    ///   - frame: The frame for the tracking view.
    ///   - controller: The `MenuBarController` responsible for managing the hover and popover logic.
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
        print("Mouse entered hover area")
        menuBarController?.hoverState = .hoverArea
        menuBarController?.showPopover()
    }

    override func mouseExited(with event: NSEvent) {
        print("Mouse exited hover area")
        if menuBarController?.hoverState == .hoverArea {
            menuBarController?.hoverState = .none
            menuBarController?.debounceHideOverlay()
        }
    }
}
