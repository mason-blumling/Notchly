//
//  Notchly.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import Combine
import SwiftUI

/// `Notchly` manages the floating notch logic and state.
///
/// Handles window initialization, hover-driven expansion/collapse,
/// and system sleep/wake events to refresh calendar and media state.
public final class Notchly: ObservableObject {
    /// Controller for the floating panel window
    public var windowController: NSWindowController?

    /// When true, hover events are ignored (used during onboarding)
    @Published public var ignoreHoverOnboarding = false

    /// Whether the notch window is currently visible
    @Published public var isVisible: Bool = false
    /// Tracks mouse hover state over the notch (expansion trigger)
    @Published public var isMouseInside: Bool = false
    /// Indicates active media playback (affects notch sizing)
    @Published public var isMediaPlaying: Bool = false
    /// Indicates an active calendar live activity
    @Published public var calendarHasLiveActivity: Bool = false

    // MARK: - Private State

    private var subscription: AnyCancellable?            // Observes screen changes
    private var subscriptions = Set<AnyCancellable>()    // Holds Combine subscriptions
    private var currentScreen: NSScreen?                 // Tracks current screen hosting the notch

    // MARK: - Environment injection

    @MainActor
    func environmentInjectedContainerView() -> some View {
        NotchlyContainerView(notchly: self)
            .environmentObject(AppEnvironment.shared)
            .foregroundColor(.white)
    }
    // MARK: - Initialization

    public init() {
        // 1) Observe screen changes…
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

        // 2) Hover drives our single source of truth in the coordinator
        $isMouseInside
            .sink { [weak self] inside in
                guard let self = self, !self.ignoreHoverOnboarding else { return }
                Task { @MainActor in
                    NotchlyTransitionCoordinator.shared.update(
                        expanded:      inside,
                        mediaActive:   self.isMediaPlaying,
                        calendarActive:self.calendarHasLiveActivity
                    )
                }
            }
            .store(in: &subscriptions)

        // 3) Suspend calendar on sleep…
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                AppEnvironment.shared.calendarManager.suspendUpdates()
            }
        }

        // 4) Reload on wake…
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                AppEnvironment.shared.calendarManager.reloadEvents()
                AppEnvironment.shared.mediaMonitor.updateMediaState()
                NotchlyTransitionCoordinator.shared.update(
                    expanded:      self.isMouseInside,
                    mediaActive:   self.isMediaPlaying,
                    calendarActive:self.calendarHasLiveActivity
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

    // MARK: - Window Lifecycle

    /// Creates and shows the floating panel on the given screen
    @MainActor
    public func initializeWindow(screen: NSScreen) async {
        guard windowController == nil else { return }
        currentScreen = screen

        let maxWidth: CGFloat = 800
        let maxHeight: CGFloat = 500

        let frame = NSRect(
            x: screen.frame.origin.x + (screen.frame.width - maxWidth) / 2,
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
    @MainActor
    private func deinitializeWindow() {
        print("🧼 Deinitializing notch window...")
        windowController?.window?.orderOut(nil)
        windowController?.window?.close()
        windowController = nil
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
}
