//
//  Notchly.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import Combine
import SwiftUI

// MARK: - Notchly (Main Class)

/// `Notchly` is responsible for managing the floating notch UI component.
/// It handles hover-based expansion, resizing, and dynamic content rendering.
public class Notchly<Content>: ObservableObject where Content: View {

    // MARK: - Window Properties

    /// The main window controller that manages the floating notch window.
    public var windowController: NSWindowController?

    // MARK: - Notch Content

    /// The SwiftUI content displayed inside the notch.
    @Published var content: () -> Content
    
    /// A unique identifier for the current content (to force UI updates).
    @Published var contentUUID: UUID

    /// Controls the visibility of the notch.
    @Published var isVisible: Bool = false

    // MARK: - Notch Size & Hover State

    /// Default notch dimensions (small state).
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 35

    /// Use configuration instead of raw values
    @Published var configuration: NotchlyConfiguration = NotchPresets.defaultNotch

    /// Tracks whether the mouse is currently inside the notch.
    @Published var isMouseInside: Bool = false
    
    // MARK: - Private Properties

    /// Prevents unnecessary updates by debouncing resize operations.
    private var workItem: DispatchWorkItem?

    /// Subscription to monitor screen changes.
    private var subscription: AnyCancellable?

    /// Collection of subscriptions to manage memory properly.
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Animations

    /// Defines the hover and expansion animations.
    var animation: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    // MARK: - Initializer

    /// Initializes a `Notchly` instance with a dynamic SwiftUI content view.
    public init(contentID: UUID = .init(), @ViewBuilder content: @escaping () -> Content) {
        self.contentUUID = contentID
        self.content = content
        
        // Monitor screen parameter changes to adjust window positioning.
        self.subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = NSScreen.screens.first else { return }
                self.initializeWindow(screen: screen)
            }
        
        // Observe hover state changes and trigger notch expansion or collapse.
        $isMouseInside
            .sink { [weak self] inside in
                self?.handleHover(expand: inside)
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Public Methods

public extension Notchly {
    
    /// Initializes and displays the floating notch window on a given screen.
    func initializeWindow(screen: NSScreen) {
        guard windowController == nil else { return } // Prevent duplicate windows

        print("Creating the notch window...")

        // 🔥 Define a fixed maximum size for the window (prevents resizing)
        let maxWidth: CGFloat = 600
        let maxHeight: CGFloat = 500

        // Calculate position: Always anchored to the top center of the screen.
        let frame = NSRect(
            x: screen.frame.midX - (maxWidth / 2),
            y: screen.frame.maxY - maxHeight,
            width: maxWidth,
            height: maxHeight
        )

        // Create the SwiftUI hosting view containing the notch
        let view = NSHostingView(rootView: NotchView(notchly: self).foregroundStyle(.white))

        // Configure the floating panel
        let panel = NotchlyWindowPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        // Prevent accidental movement and enforce proper positioning
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.setFrame(frame, display: true)
        panel.setFrameOrigin(NSPoint(x: frame.origin.x, y: screen.frame.maxY - frame.height))
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .screenSaver
        panel.orderFrontRegardless()

        // Store the window reference
        windowController = NSWindowController(window: panel)
    }

    /// Handles hover interactions and triggers notch expansion or contraction.
    func handleHover(expand: Bool) {
        DispatchQueue.main.async {
            withAnimation(self.animation) {
                self.resizeNotch(expanded: expand)
            }
        }
    }

    /// Dynamically resizes the notch based on hover state.
    func resizeNotch(expanded: Bool) {
        let targetWidth: CGFloat = expanded ? 500 : 200
        let targetHeight: CGFloat = expanded ? 250 : 40

        withAnimation(animation) {
            notchWidth = targetWidth
            notchHeight = targetHeight
        }
    }
    
    func updateConfiguration(to newConfiguration: NotchlyConfiguration) {
        withAnimation(animation) {
            self.configuration = newConfiguration
        }
    }
    
    /// Updates the notch content dynamically.
    func setContent(contentID: UUID = .init(), content: @escaping () -> Content) {
        self.content = content
        self.contentUUID = contentID
    }
    
    /// Forces the notch to be visible on the given screen.
    func show(on screen: NSScreen = NSScreen.screens[0]) {
        guard let window = windowController?.window else { return }
        window.orderFrontRegardless()
        isVisible = true
    }
    
    /// Hides the notch window.
    func hide() {
        isVisible = false
    }
}
