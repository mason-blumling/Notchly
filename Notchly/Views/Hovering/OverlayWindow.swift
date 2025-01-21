//
//  OverlayWindow.swift
//  Notchly
//
//  Created by Mason Blumling on 1/20/25.
//

import AppKit

class OverlayWindow: NSWindow {
    weak var controller: MenuBarController?
    private var trackingArea: NSTrackingArea?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Makes the hover window the key window and displays it on the screen.
    /// Sets the window properties for interaction and visibility in the menu bar area.
    ///
    /// - Parameter sender: The object that triggered this action, if applicable.
    override func makeKeyAndOrderFront(_ sender: Any?) {
        self.level = .statusBar             // Ensures the window appears at the menu bar level.
        self.ignoresMouseEvents = false    // Allows the window to detect mouse events.
        self.acceptsMouseMovedEvents = true
        self.isOpaque = false              // Makes the window transparent.
        self.orderFrontRegardless()        // Ensures the window appears, even if the app is not active.
        print("Hover window is visible.")  // Debugging log to confirm visibility.
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        guard let contentView = self.contentView else { return }
        let locationInView = contentView.convert(event.locationInWindow, from: nil)
        let hitView = contentView.hitTest(locationInView)

        print("Mouse down at: \(locationInView), hitView: \(String(describing: hitView))")
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        guard let contentView = self.contentView else { return }

        if let trackingArea = trackingArea {
            contentView.removeTrackingArea(trackingArea)
        }

        let bounds = contentView.bounds
        print("Overlay tracking area bounds: \(bounds)")

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        print("Mouse entered overlay at location: \(event.locationInWindow)")
        controller?.mouseEnteredOverlay()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        print("Mouse exited overlay at location: \(event.locationInWindow)")
        controller?.mouseExitedOverlay()
    }
}
