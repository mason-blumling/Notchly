//
//  NotchlyViewModel+Window.swift
//  Notchly
//
//  Created by Mason Blumling on 5/11/25.
//

import SwiftUI
import AppKit
import os

// MARK: - Window Management Extension
@MainActor
extension NotchlyViewModel {
    /// Creates and shows the floating panel on the given screen
    public func initializeWindow(screen: NSScreen) async {
        guard windowController == nil else {
            NotchlyLogger.debug("⚠️ Window already exists, skipping initialization", category: .ui)
            return
        }
        
        currentScreen = screen
        
        /// Detect notch BEFORE calculating position
        detectNotchPresence(on: screen)

        let maxWidth: CGFloat = 800
        let maxHeight: CGFloat = 500
        
        /// Apply horizontal offset from settings
        let offset = NotchlySettings.shared.horizontalOffset
        let screenWidth = screen.frame.width
        let offsetPoints = (screenWidth * offset) / 100 /// Convert percentage to points
        
        /// Calculate the center position with the user's offset preference
        let centerX = screen.frame.origin.x + (screen.frame.width / 2) + offsetPoints
        
        /// Position the window with the notch shape centered, not the overall frame
        let frame = NSRect(
            x: centerX - (maxWidth / 2),
            y: screen.frame.origin.y + screen.frame.height - maxHeight,
            width: maxWidth, height: maxHeight
        )
        
        /// Create hosting view
        let view = NSHostingView(rootView: environmentInjectedContainerView())
        
        /// Create panel with specific configuration
        let panel = NotchlyWindowPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true
        )
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        
        /// Create the window controller before showing panel
        windowController = NSWindowController(window: panel)
        
        /// Critical: Ensure panel is visible by calling both methods
        DispatchQueue.main.async {
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }
        
        NotchlyLogger.debug("🪟 Initialized notch window on screen: \(screen.localizedName) with \(offset)% offset", category: .general)
    }

    /// Closes and clears the floating panel
    func deinitializeWindow() {
        NotchlyLogger.debug("🧼 Deinitializing notch window...", category: .general)
        
        /// Safety check to avoid crashes with invalid window references
        guard let window = windowController?.window else {
            windowController = nil
            return
        }
        
        /// Use main thread for UI operations
        DispatchQueue.main.async {
            window.orderOut(nil)
            window.close()
        }
        
        windowController = nil
    }
    
    /// Environment injection helper
    func environmentInjectedContainerView() -> some View {
        NotchlyView(viewModel: self)
            .environmentObject(AppEnvironment.shared)
            .foregroundColor(.white)
    }
    
    func recenterShape() {
        guard let window = windowController?.window,
              let screen = currentScreen else { return }
        
        /// Apply horizontal offset from settings (percentage of screen width)
        let offset = NotchlySettings.shared.horizontalOffset
        let screenWidth = screen.frame.width
        let offsetPoints = (screenWidth * offset) / 100 // Convert percentage to points
        
        /// Calculate center position with offset
        let centerX = screen.frame.midX + offsetPoints
        let adjustedX = centerX - (window.frame.width / 2)
        let lockedY = screen.frame.maxY - window.frame.height
        
        /// Apply the position
        window.setFrameOrigin(NSPoint(x: adjustedX, y: lockedY))
        
        NotchlyLogger.debug("🔄 Recentering shape with \(offset)% offset: config width=\(configuration.width), window width=\(window.frame.width)", category: .general)
    }
    
    private func detectNotchPresence(on screen: NSScreen?) {
        if #available(macOS 12.0, *), let screen = screen {
            hasNotch = screen.safeAreaInsets.top > 0
        } else {
            hasNotch = false
        }
    }
}
