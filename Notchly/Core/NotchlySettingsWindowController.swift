//
//  NotchlySettingsWindowController.swift
//  Notchly
//
//  Created by Mason Blumling on 5/8/25.
//

import AppKit
import SwiftUI

/// A window controller for displaying and managing Notchly settings
class NotchlySettingsWindowController: NSWindowController {
    
    // MARK: - Shared Instance
    
    /// Shared instance for singleton pattern
    static let shared = NotchlySettingsWindowController()
    
    // MARK: - Properties
    
    /// Whether the settings window is currently visible
    private(set) var isWindowVisible = false
    
    // MARK: - Initialization
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Notchly Preferences"
        window.titlebarAppearsTransparent = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set minimum window size
        window.minSize = NSSize(width: 700, height: 500)
        
        // Use the SwiftUI settings view as the window content
        let settingsView = NotchlySettingsView()
        window.contentView = NSHostingView(rootView: settingsView)

        super.init(window: window)
        
        // Handle window close notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Shows the settings window
    func showWindow() {
        if let window = window, !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            isWindowVisible = true
        }
    }
    
    /// Closes the settings window
    func closeWindow() {
        if let window = window, window.isVisible {
            window.close()
            isWindowVisible = false
        }
    }
    
    /// Toggle visibility of the settings window
    func toggleWindow() {
        if isWindowVisible {
            closeWindow()
        } else {
            showWindow()
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func windowWillClose(_ notification: Notification) {
        isWindowVisible = false
    }
}
