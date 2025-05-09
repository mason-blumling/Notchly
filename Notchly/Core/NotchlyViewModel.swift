//
//  NotchlyViewModel.swift
//  Notchly
//
//  Created by Mason Blumling on 5/3/25.
//

import Combine
import SwiftUI

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
    
    private var subscription: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var debounceWorkItem: DispatchWorkItem?
    var currentScreen: NSScreen?
    
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
    
    // MARK: - State Management
    
    /// Updates the notch state based on hover, media, and calendar input.
    /// Priority: calendar > expanded > media > collapsed
    func update(expanded: Bool, mediaActive: Bool, calendarActive: Bool) {
        print("📊 State Update - expanded: \(expanded), mediaActive: \(mediaActive), calendarActive: \(calendarActive)")
        
        /// Use the shared animation for consistency across all state transitions
        let transitionAnimation = animation
        
        if calendarActive {
            print("📅 Setting calendar activity state")
            withAnimation(transitionAnimation) {
                /// IMPORTANT: Set configuration FIRST in a single animation block
                configuration = .activity
                /// Then update state
                state = .calendarActivity
            }
        }
        else if expanded {
            withAnimation(transitionAnimation) {
                configuration = .large
                state = .expanded
            }
        }
        else if mediaActive {
            withAnimation(transitionAnimation) {
                configuration = .activity
                state = .mediaActivity
            }
        }
        else {
            withAnimation(transitionAnimation) {
                configuration = .default
                state = .collapsed
            }
        }
    }
    
    // MARK: - Window Management
    
    /// Creates and shows the floating panel on the given screen
    public func initializeWindow(screen: NSScreen) async {
        guard windowController == nil else { return }
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
        
        let view = NSHostingView(rootView: environmentInjectedContainerView())
        
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
        panel.orderFrontRegardless()
        
        print("🪟 Initialized notch window on screen: \(screen.localizedName) with \(offset)% offset")
        windowController = NSWindowController(window: panel)
    }
    
    /// Closes and clears the floating panel
    private func deinitializeWindow() {
        print("🧼 Deinitializing notch window...")
        windowController?.window?.orderOut(nil)
        windowController?.window?.close()
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
        
        print("🔄 Recentering shape with \(offset)% offset: config width=\(configuration.width), window width=\(window.frame.width)")
    }
    
    private func detectNotchPresence(on screen: NSScreen?) {
        if #available(macOS 12.0, *), let screen = screen {
            hasNotch = screen.safeAreaInsets.top > 0
        } else {
            hasNotch = false
        }
    }
    
    // MARK: - Public API
    
    /// Show the notch on the specified or current screen
    public func show(on screen: NSScreen? = nil) {
        guard isNotchEnabled else {
            print("⚠️ Notchly is Disabled, ignoring show()")
            return
        }
        
        let target = screen
        ?? NSScreen.screenWithMouse
        ?? NSScreen.largestScreen
        ?? NSScreen.screens.first
        guard let screen = target else { return }
        
        Task { @MainActor in
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
    
    // MARK: - Private Setup Methods
    
    private func setupStateObservation() {
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
    
    private func setupSystemEventObservers() {
        /// Observe screen changes
        subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newScreen = NSScreen.screenWithMouse
                ?? NSScreen.largestScreen
                ?? NSScreen.main
                if newScreen != self.currentScreen {
                    Task { @MainActor in
                        self.deinitializeWindow()
                        await self.initializeWindow(screen: newScreen!)
                    }
                }
            }
        
        /// Suspend calendar on sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                AppEnvironment.shared.calendarManager.suspendUpdates()
            }
        }
        
        /// Reload on wake
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                AppEnvironment.shared.calendarManager.reloadEvents()
                self.update(
                    expanded: self.isMouseInside,
                    mediaActive: self.isMediaPlaying,
                    calendarActive: self.calendarHasLiveActivity
                )
                
                let newScreen = NSScreen.screenWithMouse
                ?? NSScreen.largestScreen
                ?? NSScreen.main
                if newScreen != self.currentScreen {
                    self.deinitializeWindow()
                    await self.initializeWindow(screen: newScreen!)
                }
            }
        }
    }
    
    private func setupHoverObserver() {
        /// Hover drives our single source of truth
        $isMouseInside
            .sink { [weak self] inside in
                guard let self = self, !self.ignoreHoverOnboarding else { return }
                Task { @MainActor in
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
        
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: debounceWorkItem!)
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

/// Compatibility extension for NotchlyView
extension NotchlyViewModel {
    /// Bridge property to maintain compatibility with existing NotchlyView
    var notchly: NotchlyViewModel { self }
}
