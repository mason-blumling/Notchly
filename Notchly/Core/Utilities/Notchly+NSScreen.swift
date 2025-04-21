//
//  Notchly+NSScreen.swift
//  Notchly
//
//  Created by Mason Blumling on 4/20/25.
//

import AppKit

extension NSScreen {
    /// Returns the screen that currently contains the mouse cursor.
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        })
    }

    /// Returns the screen with the largest frame (for fallback)
    static var largestScreen: NSScreen? {
        return NSScreen.screens.max(by: { $0.frame.width < $1.frame.width })
    }
}
