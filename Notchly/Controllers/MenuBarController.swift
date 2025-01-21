//
//  MenuBarController.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `MenuBarController` class, which manages the hover area in the menu bar and the overlay's behavior.
//  It handles the creation of a hover window, showing and hiding the overlay, and maintaining state for mouse interactions.
//

import AppKit
import SwiftUI
import EventKit

enum HoverState {
    case none
    case hoverArea
    case overlay
}

// MARK: - MenuBarController

/// A class that controls the menu bar hover area and manages the overlay's visibility and behavior.
class MenuBarController: ObservableObject {

    // MARK: - Properties

    /// The grouped calendar events.
    @Published private var groupedEvents: [Date: [EKEvent]] = [:]

    /// An instance of `CalendarManager` to manage events.
    private let calendarManager = CalendarManager()

    /// A transparent hover window to detect mouse events in the menu bar area.
    private var hoverWindow: NSWindow?

    var hoverState: HoverState = .none

    /// The overlay window displayed when hovering over the designated area.
    private var overlayWindow: NSWindow?

    /// A timer to debounce hiding the overlay.
    var debounceTimer: Timer?

    // MARK: - Initialization

    /// Initializes the `MenuBarController` and sets up the hover area and overlay.
    init() {
        setupHoverArea()
        setupOverlay()
    }

    // MARK: - Setup Methods

    private func setupHoverArea() {
        guard let screen = NSScreen.main else { return }

        let screenWidth = screen.frame.width
        let hoverWidth: CGFloat = 200.0
        let hoverHeight: CGFloat = 35.0
        let hoverX = (screenWidth / 2) - (hoverWidth / 2)
        let hoverY = screen.frame.height - hoverHeight

        let hoverRect = NSRect(x: hoverX, y: hoverY, width: hoverWidth, height: hoverHeight)
        print("Hover rect dimensions: \(hoverRect)")

        hoverWindow = HoverWindow(
            contentRect: hoverRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        hoverWindow?.isOpaque = false
        hoverWindow?.backgroundColor = .red
        hoverWindow?.ignoresMouseEvents = false
        hoverWindow?.level = .statusBar
        hoverWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        hoverWindow?.hasShadow = false
        hoverWindow?.contentView = HoverTrackingView(frame: hoverRect, controller: self)
        hoverWindow?.makeKeyAndOrderFront(nil)
        hoverWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]

        print("Hover area set up at: \(hoverRect)")
    }

    private func setupOverlay() {
        guard let screen = NSScreen.main else { return }

        let overlayWidth: CGFloat = 400.0
        let overlayHeight: CGFloat = 200.0
        let overlayX = (screen.frame.width - overlayWidth) / 2
        let overlayY = screen.frame.height - overlayHeight - 22 // Adjust for menu bar height

        let overlayRect = NSRect(x: overlayX, y: overlayY, width: overlayWidth, height: overlayHeight)
        print("Overlay rect dimensions: \(overlayRect)")

        overlayWindow = OverlayWindow(
            contentRect: overlayRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlayWindow?.isOpaque = false
        overlayWindow?.backgroundColor = .clear
        overlayWindow?.level = .floating
        overlayWindow?.hasShadow = true
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        overlayWindow?.ignoresMouseEvents = false
        overlayWindow?.acceptsMouseMovedEvents = true
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        overlayWindow?.makeKeyAndOrderFront(nil) // Display the overlay for debugging
        overlayWindow?.orderOut(nil) // Hide initially

        // Adjust content for debugging visibility
        overlayWindow?.contentView = NSHostingView(
            rootView: Text("Overlay Visible")
                .frame(width: overlayWidth, height: overlayHeight)
                .background(Color.green.opacity(0.8)) // Semi-transparent background for debugging
        )

        print("Overlay window set up at: \(overlayRect)")
    }
    
    
//    /// Configures the hover area as a transparent window in the menu bar.
//    private func setupHoverArea() {
//        guard let screen = NSScreen.main else { return }
//
//        let screenWidth = screen.frame.width
//        let hoverWidth: CGFloat = 200.0
//        let hoverHeight: CGFloat = 35.0
//        let hoverX = (screenWidth / 2) - (hoverWidth / 2)
//        let hoverY = screen.frame.height - hoverHeight
//
//        let hoverRect = NSRect(x: hoverX, y: hoverY, width: hoverWidth, height: hoverHeight)
//
//        hoverWindow = HoverWindow(
//            contentRect: hoverRect,
//            styleMask: .borderless,
//            backing: .buffered,
//            defer: false
//        )
//
//        hoverWindow?.isOpaque = false
//        hoverWindow?.backgroundColor = .clear
//        hoverWindow?.ignoresMouseEvents = false
//        hoverWindow?.level = .statusBar
//        hoverWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
//        hoverWindow?.hasShadow = false
//        hoverWindow?.contentView = HoverTrackingView(frame: hoverRect, controller: self)
//        hoverWindow?.makeKeyAndOrderFront(nil)
//        print("Hover area set up at: \(hoverRect)")
//    }
//
//    private func setupOverlay() {
//        guard let screen = NSScreen.main else { return }
//
//        let overlayWidth: CGFloat = 400.0
//        let overlayHeight: CGFloat = 200.0
//        let overlayX = (screen.frame.width - overlayWidth) / 2
//        let overlayY = screen.frame.height - overlayHeight - 22 // Place above menu bar
//
//        let overlayRect = NSRect(x: overlayX, y: overlayY, width: overlayWidth, height: overlayHeight)
//
//        overlayWindow = OverlayWindow(
//            contentRect: overlayRect,
//            styleMask: .borderless,
//            backing: .buffered,
//            defer: false
//        )
//
//        guard let overlayWindow = overlayWindow as? OverlayWindow else { return }
//
//        overlayWindow.controller = self
//        overlayWindow.isOpaque = false
//        overlayWindow.backgroundColor = .clear
//        overlayWindow.level = .statusBar
//        overlayWindow.hasShadow = true
//        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .stationary]
//        overlayWindow.ignoresMouseEvents = false
//        overlayWindow.acceptsMouseMovedEvents = true
//
//        // Allow interactions
//        overlayWindow.makeKeyAndOrderFront(nil)
//        overlayWindow.orderOut(nil) // Initially hide
//        print("Overlay window set up at: \(overlayRect)")
//
//        overlayWindow.contentView = NSHostingView(
//            rootView: Text("Loading...")
//                .frame(width: overlayWidth, height: overlayHeight)
//                .background(Color.black)
//                .cornerRadius(25)
//        )
//
//        calendarManager.requestAccess { granted in
//            guard granted else {
//                print("Access to calendar denied")
//                return
//            }
//
//            let now = Date()
//            guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }
//            let events = self.calendarManager.fetchEvents(startDate: now, endDate: oneWeekLater)
//
//            DispatchQueue.main.async {
//                self.groupedEvents = self.calendarManager.groupEventsByDate(events)
//                print("Grouped Events for Overlay: \(self.groupedEvents)")
//
//                overlayWindow.contentView = NSHostingView(
//                    rootView: PopoverContentView(groupedEvents: self.groupedEvents)
//                        .frame(width: overlayWidth, height: overlayHeight)
//                        .background(Color.black)
//                        .cornerRadius(25)
//                )
//            }
//        }
//    }

    // MARK: - Overlay Methods

    func showPopover() {
        guard let overlayWindow = overlayWindow else {
            print("Error: Overlay window not initialized.")
            return
        }
        print("Attempting to show overlay window...")
        overlayWindow.orderFront(nil)
        overlayWindow.isOpaque = true
        print("Overlay window shown.")
    }

    func hidePopover() {
        guard let overlayWindow = overlayWindow else {
            print("Error: Overlay window not initialized.")
            return
        }
        print("Attempting to hide overlay window...")
        overlayWindow.orderOut(nil)
        print("Overlay window hidden.")
    }

    func mouseEnteredHoverArea() {
        print("Mouse entered hover area.")
        hoverState = .hoverArea
        showPopover()
    }

    func mouseExitedHoverArea() {
        print("Mouse exited hover area.")
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.hoverState == .hoverArea {
                self.hoverState = .none
                self.hidePopover()
            }
        }
    }

    func mouseEnteredOverlay() {
        print("Mouse entered overlay.")
        hoverState = .overlay
        debounceTimer?.invalidate() // Cancel hiding
    }

    func mouseExitedOverlay() {
        print("Mouse exited overlay.")
        if hoverState == .overlay {
            hoverState = .none // Reset hover state when exiting the overlay
            debounceHideOverlay()
        }
    }

    // Hide the overlay if the hover state is `.none`.
    func debounceHideOverlay() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.hoverState == .none {
                self.hidePopover()
            }
        }
    }
}
