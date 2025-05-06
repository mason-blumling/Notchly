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
        let newState: NotchState
        
        if calendarActive {
            newState = .calendarActivity
        } else if expanded {
            newState = .expanded
        } else if mediaActive {
            newState = .mediaActivity
        } else {
            newState = .collapsed
        }
        
        withAnimation(animation) {
            state = newState
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
        
        /// Calculate the center position accounting for screen width
        let centerX = screen.frame.origin.x + (screen.frame.width / 2)
        
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
        
        print("🪟 Initialized notch window on screen: \(screen.localizedName)")
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
        
        /// Reposition window to be exactly centered on screen
        let centerX = screen.frame.midX
        let adjustedX = centerX - (configuration.width / 2)
        let lockedY = screen.frame.maxY - window.frame.height
        
        window.setFrameOrigin(NSPoint(x: adjustedX, y: lockedY))
        
        print("🔄 Recentering shape: config width=\(configuration.width), window width=\(window.frame.width)")
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
        isVisible = false
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
                
                withAnimation(self.animation) {
                    self.configuration = newConfig
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
}

/// Compatibility extension for NotchlyView
extension NotchlyViewModel {
    /// Bridge property to maintain compatibility with existing NotchlyView
    var notchly: NotchlyViewModel { self }
}
