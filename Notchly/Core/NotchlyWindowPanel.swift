//
//  NotchlyWindowPanel.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import AppKit

/// `NotchlyWindowPanel` is a custom `NSPanel` subclass that acts as the main floating panel
/// for Notchly. It ensures the window remains anchored at the top and prevents unintended movement.
class NotchlyWindowPanel: NSPanel {

    // MARK: - Initializer

    /// Initializes the custom Notchly window panel.
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        configurePanel()
    }

    // MARK: - Panel Configuration

    /// Configures the panel settings to maintain expected behavior.
    private func configurePanel() {
        self.hasShadow = false               // 🔥 Removes shadow for a clean UI
        self.backgroundColor = .clear        // 🔥 Ensures a transparent background
        self.level = .screenSaver            // 🔥 Keeps the panel above most other windows
        self.collectionBehavior = .canJoinAllSpaces // 🔥 Allows it to remain across multiple Spaces
    }

    // MARK: - Window Behavior Overrides

    /// Allows the window to become the key window.
    override var canBecomeKey: Bool {
        true
    }

    /// Overrides `setFrameOrigin` to prevent accidental movement and keep the notch pinned at the top.
    override func setFrameOrigin(_ point: NSPoint) {
        guard let screen = self.screen ?? NSScreen.main else { return }

        let lockedY = screen.frame.maxY - self.frame.height // 🔥 Always align to the screen’s top edge
        super.setFrameOrigin(NSPoint(x: point.x, y: lockedY))
    }
}
