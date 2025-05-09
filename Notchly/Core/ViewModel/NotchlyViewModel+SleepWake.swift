//
//  NotchlyViewModel+SleepWake.swift
//  Notchly
//
//  Created by Mason Blumling on 5/11/25.
//

import SwiftUI
import AppKit
import os

// MARK: - Sleep/Wake Window Management Extension
@MainActor
extension NotchlyViewModel {
    /// Public method to force window refresh
    public func refreshWindow() {
        Task { @MainActor in
            NotchlyLogger.notice("🔄 Manually refreshing Notchly window", category: .ui)
            
            /// Cancel any existing restore task
            wakeRestoreTask?.cancel()
            wakeRestoreTask = nil
            
            /// Clear sleep/wake handling state
            isHandlingSleepWake = false
            
            /// Determine target screen
            let targetScreen = NSScreen.screenWithMouse
                ?? NSScreen.largestScreen
                ?? NSScreen.main
                ?? NSScreen.screens.first
            
            guard let screen = targetScreen else {
                NotchlyLogger.error("❌ No screen available for refresh", category: .ui)
                return
            }
            
            /// Recreate window
            deinitializeWindow()
            
            /// Brief pause
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            /// Create new window
            await initializeWindow(screen: screen)
            
            /// Ensure visible
            if let window = windowController?.window {
                DispatchQueue.main.async {
                    window.orderFrontRegardless()
                }
            }
            isVisible = true
            
            /// Update state
            update(
                expanded: isMouseInside,
                mediaActive: isMediaPlaying,
                calendarActive: calendarHasLiveActivity
            )
            
            /// Notify that window was refreshed
            NotificationCenter.default.post(
                name: Notification.Name("NotchlyWindowRefreshed"),
                object: nil
            )
        }
    }

    @MainActor
    func refreshWindowAfterWake() {
        /// Cancel any existing wake restore task
        wakeRestoreTask?.cancel()
        wakeRestoreTimerTask?.cancel()
        
        /// Create a new task for wake restoration with retry mechanism
        wakeRestoreTask = Task { @MainActor in
            do {
                NotchlyLogger.notice("🔄 Starting wake restoration sequence", category: .lifecycle)
                
                /// Clear sleep/wake handling state
                isHandlingSleepWake = false
                
                /// Wait for display system to stabilize
                NotchlyLogger.debug("🔄 Waiting for display system to stabilize...", category: .lifecycle)
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                
                /// First attempt
                if await tryRestoreWindow() {
                    return
                }
                
                /// Second attempt after delay
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0s
                NotchlyLogger.debug("🔄 First restore attempt failed, trying again...", category: .lifecycle)
                if await tryRestoreWindow() {
                    return
                }
                
                /// Third attempt after longer delay
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2.0s
                NotchlyLogger.debug("🔄 Second restore attempt failed, final attempt...", category: .lifecycle)
                if await tryRestoreWindow() {
                    return
                }
                
                /// Last resort - brute force window creation
                NotchlyLogger.notice("🔄 All standard attempts failed, using fallback method", category: .lifecycle)
                await emergencyWindowRestore()
                
            } catch {
                if error is CancellationError {
                    NotchlyLogger.debug("⚠️ Wake restoration cancelled", category: .lifecycle)
                } else {
                    NotchlyLogger.error("❌ Wake restoration error: \(error.localizedDescription)", category: .lifecycle)
                    
                    /// Try emergency restore if something went wrong
                    await emergencyWindowRestore()
                }
            }
        }
    }
    
    /// Attempts to restore the window after wake
    private func tryRestoreWindow() async -> Bool {
        /// Get a valid screen
        let screen = NSScreen.screenWithMouse ?? NSScreen.largestScreen ?? NSScreen.main ?? NSScreen.screens.first
        
        guard let targetScreen = screen else {
            NotchlyLogger.error("❌ No valid screen found for window restoration", category: .lifecycle)
            return false
        }
        
        /// Clear existing window
        deinitializeWindow()
        
        do {
            /// Brief pause
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            
            /// Create window on target screen
            await initializeWindow(screen: targetScreen)
            
            /// Make sure it's visible
            if let window = windowController?.window {
                DispatchQueue.main.async {
                    window.orderFrontRegardless()
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
            /// Mark as visible and update state
            isVisible = true
            update(
                expanded: isMouseInside,
                mediaActive: isMediaPlaying,
                calendarActive: calendarHasLiveActivity
            )
            
            /// Notify that window was restored
            NotificationCenter.default.post(
                name: Notification.Name("NotchlyWindowRefreshed"),
                object: nil
            )
            
            NotchlyLogger.notice("✅ Window successfully restored after wake", category: .lifecycle)
            return true
        } catch {
            NotchlyLogger.error("❌ Error during window restoration: \(error.localizedDescription)", category: .lifecycle)
            return false
        }
    }

    /// Last resort window restoration that waits for system to fully stabilize
    private func emergencyWindowRestore() async {
        do {
            /// Wait longer for display system to fully stabilize
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3.0s
            
            /// Force rebuild from scratch
            deinitializeWindow()
            
            /// Use main screen as safest option
            let targetScreen = NSScreen.main ?? NSScreen.screens.first
            
            guard let screen = targetScreen else {
                NotchlyLogger.error("❌ Emergency restore failed - no screens available", category: .lifecycle)
                return
            }
            
            /// Create new window
            await initializeWindow(screen: screen)
            
            /// Ensure it's visible
            if let window = windowController?.window {
                DispatchQueue.main.async {
                    window.orderFrontRegardless()
                }
            }
            
            isVisible = true
            update(
                expanded: isMouseInside,
                mediaActive: isMediaPlaying,
                calendarActive: calendarHasLiveActivity
            )
            
            /// Notify of window refresh
            NotificationCenter.default.post(
                name: Notification.Name("NotchlyWindowRefreshed"),
                object: nil
            )
            
            NotchlyLogger.notice("✅ Emergency window restoration successful", category: .lifecycle)
        } catch {
            NotchlyLogger.error("❌ Emergency window restoration failed: \(error.localizedDescription)", category: .lifecycle)
        }
    }
}
