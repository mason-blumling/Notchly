//
//  NotchlyStatusBarItem.swift
//  Notchly
//
//  Created by Mason Blumling on 5/6/25.
//

import AppKit
import SwiftUI

/// Manager class for the Notchly status bar item and menu
class NotchlyStatusBarItem: NSObject, NSMenuDelegate {

    // MARK: - Properties

    /// Immutable reference to the status item
    let statusItem: NSStatusItem
    private var statusBarMenu: NSMenu

    // MARK: - Initialization

    override init() {
        print("🔄 Creating status bar item...")
        self.statusItem = NSStatusBar.system.statusItem(withLength: 22)
        self.statusBarMenu = NSMenu(title: "Notchly Menu")

        super.init()

        setupMenu()
        configureStatusItem()
        statusItem.isVisible = true
        print("✅ Status bar item created")
    }
    
    // MARK: - Configuration
    
    private func configureStatusItem() {
        guard let button = statusItem.button else {
            print("⚠️ Failed to get button from status item")
            return
        }

        if let generatedIcon = StatusBarIconGenerator.createGeneratedIcon() {
            button.image = generatedIcon
            print("✅ Button configured with SwiftUI-generated Notchly icon")
        } else {
            button.title = "N"
            print("⚠️ Failed to render SwiftUI icon, using fallback title")
        }

        button.action = #selector(handleStatusItemClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    private func setupMenu() {
        statusBarMenu.delegate = self

        // Create menu items
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        )
        
        let showHideItem = NSMenuItem(
            title: "Show/Hide Notchly",
            action: #selector(toggleNotchlyVisibility),
            keyEquivalent: "s"
        )
        
        let quitItem = NSMenuItem(
            title: "Quit Notchly",
            action: #selector(quitNotchly),
            keyEquivalent: "q"
        )
        
        /// Set target for menu items
        preferencesItem.target = self
        checkForUpdatesItem.target = self
        showHideItem.target = self
        quitItem.target = self
        
        /// Add items to menu
        statusBarMenu.addItem(preferencesItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(checkForUpdatesItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(showHideItem)
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.items.first(where: { $0.action == #selector(toggleNotchlyVisibility) }) {
            let isEnabled = NotchlyViewModel.shared.isNotchEnabled
            item.title = isEnabled ? "Disable Notchly" : "Enable Notchly"
        }
    }

    // MARK: - Actions
    
    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
        // Show menu regardless of click type
        statusItem.menu = statusBarMenu
        sender.performClick(nil)

        // Reset menu to nil after click (so left-click works again)
        DispatchQueue.main.async {
            self.statusItem.menu = nil
        }
    }
    
    @objc func openPreferences(_ sender: Any) {
        print("⚙️ Opening preferences window")
        NotchlySettingsWindowController.shared.showWindow()
    }
    
    @objc func checkForUpdates(_ sender: Any) {
        print("🔍 Check for updates clicked")
        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "Update checking will be implemented with Sparkle in a future update."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func toggleNotchlyVisibility(_ sender: Any) {
        print("🔄 Toggle Notchly enable/disable clicked")
        Task { @MainActor in
            let viewModel = NotchlyViewModel.shared
            if viewModel.isNotchEnabled {
                viewModel.disable()
            } else {
                viewModel.enable()
            }
        }
    }
    
    @objc func quitNotchly(_ sender: Any) {
        NSApplication.shared.terminate(nil)
    }
}
