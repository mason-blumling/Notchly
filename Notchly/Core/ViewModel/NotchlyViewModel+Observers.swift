//
//  NotchlyViewModel+Observers.swift
//  Notchly
//
//  Created by Mason Blumling on 5/11/25.
//

import SwiftUI
import AppKit
import os

// MARK: - Setup & Observers Extension
@MainActor
extension NotchlyViewModel {
    func setupStateObservation() {
        /// Sync configuration any time the state changes
        $state
            .combineLatest($ignoreHoverOnboarding, $isInIntroSequence)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, isOnboarding, isInIntro in
                guard let self = self else { return }
                
                /// Skip automatic configuration if we're in intro sequence
                if isInIntro {
                    return
                }
                
                let newConfig: NotchlyConfiguration
                
                /// Special case: if we're in expanded state during onboarding, use intro config
                if state == .expanded && isOnboarding {
                    newConfig = .intro
                } else {
                    /// Normal state mapping
                    switch state {
                    case .expanded:
                        newConfig = .large
                    case .mediaActivity, .calendarActivity:
                        newConfig = .activity
                    case .collapsed:
                        newConfig = .default
                    }
                }
                
                /// Only animate if the configuration is actually changing
                if self.configuration != newConfig {
                    withAnimation(self.animation) {
                        self.configuration = newConfig
                    }
                }
            }
            .store(in: &subscriptions)
    }
    
    func setupSystemEventObservers() {
        setupScreenParameterChangeObserver()
        setupSleepWakeObservers()
    }
    
    private func setupScreenParameterChangeObserver() {
        /// Enhanced screen parameter change handling
        subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main) // Add debounce
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                Task { @MainActor in
                    /// Skip if we're already handling sleep/wake
                    guard !self.isHandlingSleepWake else { return }
                    
                    /// Get current and new screen
                    let newScreen = NSScreen.screenWithMouse
                        ?? NSScreen.largestScreen
                        ?? NSScreen.main
                    
                    /// Check if screen has actually changed
                    if let screen = newScreen, screen != self.currentScreen {
                        NotchlyLogger.notice("🖥️ Screen changed - reinitializing window", category: .ui)
                        self.deinitializeWindow()
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        await self.initializeWindow(screen: screen)
                    }
                }
            }
    }
    
    private func setupSleepWakeObservers() {
        /// Handle system sleep notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                /// Skip if already handling
                guard !self.isHandlingSleepWake else { return }
                
                self.isHandlingSleepWake = true
                NotchlyLogger.notice("💤 System going to sleep - suspending services", category: .lifecycle)
                
                /// Cancel any wake restore task that might be running
                self.wakeRestoreTask?.cancel()
                self.wakeRestoreTask = nil
                self.wakeRestoreTimerTask?.cancel()
                self.wakeRestoreTimerTask = nil
                
                /// First hide window to prevent ghost windows on wake
                self.hide()
                
                /// Then suspend calendar updates
                AppEnvironment.shared.calendarManager.suspendUpdates()
                
                /// Reset handling flag after a short delay
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0s
                self.isHandlingSleepWake = false
            }
        }
        
        /// Handle system wake notification
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            
            /// Use a shorter initial delay to start the wake process
            Task { @MainActor in
                /// Mark that we're handling a wake event
                self.isHandlingSleepWake = true
                
                /// Initial delay before attempting screen access
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                /// Reload calendar events
                AppEnvironment.shared.calendarManager.reloadEvents()
                
                /// Use progressive restoration approach
                self.refreshWindowAfterWake()
                
                /// Reset sleep/wake flag
                self.isHandlingSleepWake = false
            }
        }
    }

    func setupHoverObserver() {
        /// Hover drives our single source of truth
        $isMouseInside
            .sink { [weak self] inside in
                guard let self = self else { return }
                
                Task { @MainActor in
                    guard !self.ignoreHoverOnboarding else { return }
                    
                    self.update(
                        expanded: inside,
                        mediaActive: self.isMediaPlaying,
                        calendarActive: self.calendarHasLiveActivity
                    )
                }
            }
            .store(in: &subscriptions)
    }
    
    func debounceHover(_ hovering: Bool) {
        /// Get the hover sensitivity from settings (higher value = longer delay)
        let sensitivity = NotchlySettings.shared.hoverSensitivity
        let debounceDelay = sensitivity /// Use sensitivity value directly as delay
        
        let existingItem = debounceWorkItem
        existingItem?.cancel()
        
        let newItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                guard hovering != self.isMouseInside else { return }
                
                withAnimation(self.animation) {
                    self.isMouseInside = hovering
                    self.update(
                        expanded: hovering,
                        mediaActive: self.isMediaPlaying,
                        calendarActive: self.calendarHasLiveActivity
                    )
                }
            }
        }
        
        debounceWorkItem = newItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: newItem)
    }
}
