//
//  NotchlyWindowPanel.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import AppKit

/// Custom floating NSPanel for Notchly's notch UI.
/// Ensures the notch window remains pinned to the top of the screen, always visible.
class NotchlyWindowPanel: NSPanel {

    // MARK: - Initializer

    /// Initializes the floating notch panel with custom behavior.
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

    /// Applies configuration settings for visibility, layering, and appearance.
    private func configurePanel() {
        self.hasShadow = false                      /// Avoid glow/shadow behind the notch shape
        self.backgroundColor = .clear               /// Use full transparency (composited by NotchlyShape)
        self.level = .screenSaver                   /// Float above normal windows and menu bar
        self.collectionBehavior = .canJoinAllSpaces /// Persist across desktop Spaces
    }

    // MARK: - Window Behavior Overrides

    /// Allow the panel to become the key window (if needed for interaction).
    override var canBecomeKey: Bool {
        true
    }

    /// Prevent any vertical drift — keeps the notch aligned to the top of the screen at all times.
    override func setFrameOrigin(_ point: NSPoint) {
        guard let screen = self.screen ?? NSScreen.main else { return }

        let lockedY = screen.frame.maxY - self.frame.height
        super.setFrameOrigin(NSPoint(x: point.x, y: lockedY))
    }
}

extension NotchlyWindowPanel {
    /// Applies the user's background opacity setting to the panel
    /// - Parameter opacity: The opacity level (0.0 to 1.0)
    func applyBackgroundOpacity(_ opacity: Double) {
        /// The panel itself is transparent, but we need to inform the
        /// NotchlyShape renderer about the opacity value
        /// Post a notification that can be observed by the shape renderer
        NotificationCenter.default.post(
            name: SettingsChangeType.backgroundOpacity.notificationName,
            object: self,
            userInfo: ["opacity": opacity]
        )
    }
}
