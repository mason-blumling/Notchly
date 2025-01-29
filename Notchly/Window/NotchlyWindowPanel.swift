//
//  NotchlyWindowPanel.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import AppKit

class NotchlyWindowPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        self.hasShadow = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.collectionBehavior = .canJoinAllSpaces
    }

    override var canBecomeKey: Bool {
        true
    }
    
    override func setFrameOrigin(_ point: NSPoint) {
        // 🔥 Prevent the window from floating/moving
        guard let screen = NSScreen.main else { return }
        let lockedY = screen.frame.maxY - self.frame.height
        super.setFrameOrigin(NSPoint(x: point.x, y: lockedY))
    }
}
