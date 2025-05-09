//
//  NotchlyViewModel.swift
//  Notchly
//
//  Created by Mason Blumling on 5/3/25.
//

import Combine
import SwiftUI
import os.log

/// Main view model that manages the notch window state, transitions, and configuration.
@MainActor
public final class NotchlyViewModel: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared singleton for global access.
    static let shared = NotchlyViewModel()
    
    // MARK: - Notch State Types
    
    /// Enum representing all visual states of the notch.
    enum NotchState {
        case collapsed         /// Default idle state
        case expanded          /// Fully expanded, showing main content
        case mediaActivity     /// Compact media activity (artwork + bars)
        case calendarActivity  /// Compact calendar alert
    }
    
    // MARK: - Published Properties
    
    /// Current visual state of the notch.
    @Published var state: NotchState = .collapsed
    
    /// Published shape configuration (width, corner radius, etc.) based on current state.
    @Published var configuration: NotchlyConfiguration = .default
    
    @Published var hasNotch: Bool = false
    @Published public var isNotchEnabled: Bool = true
    
    /// Window management
    public var windowController: NSWindowController?
    
    /// UI State
    @Published public var ignoreHoverOnboarding = false
    @Published public var isVisible: Bool = false
    @Published public var isMouseInside: Bool = false
    @Published public var isMediaPlaying: Bool = false
    @Published public var calendarHasLiveActivity: Bool = false
    @Published private var isCompletingIntro: Bool = false
    @Published var isInIntroSequence = false
    
    // MARK: - Private Properties
    
    var subscription: AnyCancellable?
    var subscriptions = Set<AnyCancellable>()
    var debounceWorkItem: DispatchWorkItem?
    var currentScreen: NSScreen?
    
    // MARK: - Sleep/Wake State Management

    var isHandlingSleepWake = false
    var wakeRestoreTask: Task<Void, Error>?
    var wakeRestoreTimerTask: Task<Void, Error>?
    
    // MARK: - Animation
    
    /// Unified animation used for notch transitions.
    var animation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        } else {
            return .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupStateObservation()
        setupSystemEventObservers()
        setupHoverObserver()
    }
    
    deinit {
        wakeRestoreTask?.cancel()
        wakeRestoreTimerTask?.cancel()
    }

    // MARK: - State Management
    
    /// Updates the notch state based on hover, media, and calendar input.
    /// Priority: calendar > expanded > media > collapsed
    func update(expanded: Bool, mediaActive: Bool, calendarActive: Bool) {
        let oldState = state

        /// Determine new state and configuration
        let newState: NotchState
        let newConfig: NotchlyConfiguration

        if calendarActive {
            newState = .calendarActivity
            newConfig = .activity
        } else if expanded {
            newState = .expanded
            newConfig = .large
        } else if mediaActive {
            newState = .mediaActivity
            newConfig = .activity
        } else {
            newState = .collapsed
            newConfig = .default
        }

        /// Log only if the state is actually changing
        if oldState != newState {
            NotchlyLogger.notice("🔁 Notch state changing: \(oldState) → \(newState)", category: .ui)
        }

        /// Use the shared animation for consistency across all state transitions
        let transitionAnimation = animation
        withAnimation(transitionAnimation) {
            /// IMPORTANT: Set configuration FIRST in a single animation block
            configuration = newConfig
            /// Then update state
            state = newState
        }
    }
    
    // MARK: - Public API
    
    /// Show the notch on the specified or current screen
    public func show(on screen: NSScreen? = nil) {
        guard isNotchEnabled else {
            NotchlyLogger.debug("⚠️ Notchly is Disabled, ignoring show()", category: .general)
            return
        }
        
        Task { @MainActor in
            let target = screen
            ?? NSScreen.screenWithMouse
            ?? NSScreen.largestScreen
            ?? NSScreen.main
            ?? NSScreen.screens.first
            guard let screen = target else { return }
            
            deinitializeWindow()
            await initializeWindow(screen: screen)
            windowController?.window?.orderFrontRegardless()
            isVisible = true
        }
    }
    
    /// Hide the notch panel
    public func hide() {
        deinitializeWindow()
        isVisible = false
    }
    
    public func enable() {
        isNotchEnabled = true
        show()
    }
    
    public func disable() {
        isNotchEnabled = false
        hide()
    }
    
    /// Updated window positioning that respects background opacity setting
    func updateWindowAppearance() {
        guard let window = windowController?.window else { return }
        
        /// Apply background opacity if window panel supports it
        if let panel = window as? NotchlyWindowPanel {
            panel.applyBackgroundOpacity(NotchlySettings.shared.backgroundOpacity)
        }
    }
}

// MARK: - Compatibility Extension
extension NotchlyViewModel {
    /// Bridge property to maintain compatibility with existing NotchlyView
    var notchly: NotchlyViewModel { self }
}
