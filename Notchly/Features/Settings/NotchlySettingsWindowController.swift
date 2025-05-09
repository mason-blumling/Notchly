//
//  NotchlySettingsWindowController.swift
//  Notchly
//
//  Created by Mason Blumling on 5/8/25.
//

import AppKit
import SwiftUI

/// A window controller for displaying and managing Notchly settings with enhanced visual styling
class NotchlySettingsWindowController: NSWindowController {
    
    // MARK: - Shared Instance
    
    /// Shared instance for singleton pattern
    static let shared = NotchlySettingsWindowController()
    
    // MARK: - Properties
    
    /// Whether the settings window is currently visible
    private(set) var isWindowVisible = false
    
    // MARK: - Initialization
    
    private init() {
        /// Create stylized window with proper dimensions for the redesigned settings UI
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        /// Configure window appearance
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Notchly Preferences"
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        /// Apply visual styling to match Notchly aesthetic
        window.backgroundColor = NSColor.windowBackgroundColor
        window.isMovableByWindowBackground = false
        window.titleVisibility = .visible
        
        /// Set minimum window size while allowing growth for accessibility
        window.minSize = NSSize(width: 780, height: 520)
        window.maxSize = NSSize(width: 1200, height: 800)
        
        /// Use the SwiftUI settings view as the window content
        let settingsView = NotchlySettingsView()
        window.contentView = NSHostingView(rootView: settingsView)

        super.init(window: window)
        
        /// Handle window close notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
        
        /// Set up visual effects for titlebar
        configureWindowAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Window Appearance
    
    private func configureWindowAppearance() {
        guard let window = window else { return }
        
        /// Create a subtle gradient in titlebar to match Notchly styling
        if let titlebar = window.standardWindowButton(.closeButton)?.superview?.superview {
            titlebar.wantsLayer = true
            
            /// Configure appearance based on user's theme
            updateTitlebarAppearance()
            
            /// Listen for appearance changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateTitlebarAppearance),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }
        
        /// Ensure window buttons have proper styling
        window.standardWindowButton(.closeButton)?.wantsLayer = true
        window.standardWindowButton(.miniaturizeButton)?.wantsLayer = true
    }
    
    @objc private func updateTitlebarAppearance() {
        guard let window = window,
              let titlebar = window.standardWindowButton(.closeButton)?.superview?.superview else { return }
        
        /// Apply subtle gradient to titlebar
        let isDarkMode = window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        if isDarkMode {
            titlebar.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.8).cgColor
        } else {
            titlebar.layer?.backgroundColor = NSColor(calibratedWhite: 0.95, alpha: 0.8).cgColor
        }
    }
    
    // MARK: - Public Methods
    
    /// Shows the settings window
    func showWindow() {
        if let window = window, !window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            /// Apply visual effects when showing window
            updateTitlebarAppearance()
            
            /// Center window on screen with animation
            window.center()
            window.alphaValue = 0.0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 1.0
            }
            
            isWindowVisible = true
        }
    }
    
    /// Closes the settings window with animation
    func closeWindow() {
        if let window = window, window.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 0.0
            } completionHandler: {
                window.close()
                window.alphaValue = 1.0
                self.isWindowVisible = false
            }
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
