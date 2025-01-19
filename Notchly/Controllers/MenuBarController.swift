//
//  MenuBarController.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `MenuBarController` class, which manages the hover area in the menu bar and the popover's behavior.
//  It handles the creation of a hover window, showing and hiding the popover, and maintaining state for mouse interactions.
//

import AppKit
import SwiftUI
import EventKit

// MARK: - MenuBarController

/// A class that controls the menu bar hover area and manages the popover's visibility and behavior.
class MenuBarController: ObservableObject {

    // MARK: - Properties

    /// The grouped calendar events.
    @Published private var groupedEvents: [Date: [EKEvent]] = [:]

    /// An instance of `CalendarManager` to manage events.
    private let calendarManager = CalendarManager()

    /// A transparent hover window to detect mouse events in the menu bar area.
    private var hoverWindow: NSWindow?

    /// The popover displayed when hovering over the designated area.
    var popover: NSPopover?

    /// Tracks whether the mouse is currently inside the popover.
    var isMouseInPopover = false

    /// Tracks whether the mouse is currently in the hover area.
    var isMouseInHoverArea = false

    /// A timer to debounce hiding the popover.
    var debounceTimer: Timer?

    // MARK: - Initialization

    /// Initializes the `MenuBarController` and sets up the hover area and popover.
    init() {
        setupHoverArea()
        setupPopover()
    }

    // MARK: - Setup Methods

    /// Configures the hover area as a transparent window in the menu bar.
    private func setupHoverArea() {
        guard let screen = NSScreen.main else { return }

        let screenWidth = screen.frame.width
        let hoverWidth: CGFloat = 200.0
        let hoverHeight: CGFloat = 30.0
        let hoverX = (screenWidth / 2) - (hoverWidth / 2)
        let hoverY = screen.frame.height - hoverHeight

        let hoverRect = NSRect(x: hoverX, y: hoverY, width: hoverWidth, height: hoverHeight)

        hoverWindow = HoverWindow(
            contentRect: hoverRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        hoverWindow?.isOpaque = false
        hoverWindow?.backgroundColor = .clear
        hoverWindow?.ignoresMouseEvents = false
        hoverWindow?.level = .statusBar
        hoverWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        hoverWindow?.hasShadow = false
        hoverWindow?.contentView = HoverTrackingView(frame: hoverRect, controller: self)
        hoverWindow?.makeKeyAndOrderFront(nil)
        print("Hover area set up at: \(hoverRect)")
    }
    
    private func setupPopover() {
        popover = NSPopover()

        // Initial placeholder content view with pill dimensions
        popover?.contentViewController = NSHostingController(
            rootView: Text("Loading...")
                .frame(width: 300, height: 50) // Adjusted to "pill" size
                .background(Color.black)       // Add a black background for the pill
                .cornerRadius(25)              // Rounded corners for pill shape
        )

        calendarManager.requestAccess { granted in
            guard granted else { print("Access to calendar denied"); return }

            let now = Date()
            guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }
            let events = self.calendarManager.fetchEvents(startDate: now, endDate: oneWeekLater)

            DispatchQueue.main.async { [self] in
                groupedEvents = self.calendarManager.groupEventsByDate(events)
                print("Grouped Events for Popover: \(groupedEvents)")

                // Update the content view with the final design
                popover?.contentViewController = NSHostingController(
                    rootView: MenuBarPopoverView(controller: self, content: {
                        PopoverContentView(groupedEvents: self.groupedEvents)
                            .frame(width: 400, height: 200) // Ensure dimensions match popoverRect
                            .background(Color.black)       // Match the pill style
                            .cornerRadius(25)
                    })
                )
            }
        }

        popover?.behavior = .applicationDefined
    }

    // MARK: - Popover Methods

    func showPopover() {
        guard let screen = NSScreen.main, let hoverWindow = hoverWindow else {
            print("Error: Unable to access screen or hover window.")
            return
        }

        // Adjust Y-position to align with the top of the screen
        let screenHeight = screen.frame.height
        let menuBarHeight: CGFloat = 22.0 // Standard macOS menu bar height
        let hoverX = hoverWindow.frame.origin.x
        let hoverY = screenHeight - menuBarHeight - 200.0 // Place above the menu bar, accounting for height

        let popoverWidth: CGFloat = 400.0
        let popoverHeight: CGFloat = 200.0
        let popoverRect = NSRect(
            x: hoverX,
            y: hoverY,
            width: popoverWidth,
            height: popoverHeight
        )

        print("Calculated popoverRect: \(popoverRect)")

        if let popover = popover, !popover.isShown {
            popover.contentSize = NSSize(width: popoverWidth, height: popoverHeight)
            popover.show(relativeTo: hoverWindow.contentView!.bounds,
                         of: hoverWindow.contentView!,
                         preferredEdge: .maxY)
            print("Popover shown at: \(popoverRect)")
        }
    }

    /// Hides the currently visible popover.
    func hidePopover() {
        if let popover = popover {
            popover.performClose(nil)
            print("Popover hidden")
        }
    }
}
