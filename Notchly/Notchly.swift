//
//  Notchly.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import Combine
import SwiftUI

// MARK: - Notchly

public class Notchly<Content>: ObservableObject where Content: View {

    // MARK: - Public Properties

    public var windowController: NSWindowController? // Allow users to modify the NSPanel
    
    // Content Properties
    @Published var content: () -> Content
    @Published var contentUUID: UUID
    @Published var isVisible: Bool = false // Controls fade in/out animation
    
    // Notch Size Properties
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 40

    // MARK: - Private Properties

    @Published var isMouseInside: Bool = false // Prevents auto-hide when mouse is inside
    private var workItem: DispatchWorkItem?
    private var subscription: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Animations

    var animation: Animation {
        if #available(macOS 14.0, *) {
            Animation.spring(.bouncy(duration: 0.4))
        } else {
            Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    // MARK: - Initializer

    public init(contentID: UUID = .init(), @ViewBuilder content: @escaping () -> Content) {
        self.contentUUID = contentID
        self.content = content
        
        // Observe screen changes
        self.subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = NSScreen.screens.first else { return }
                self.initializeWindow(screen: screen)
            }
        
        // Observe hover changes
        $isMouseInside
            .sink { [weak self] inside in
                self?.handleHover(expand: inside)
            }
            .store(in: &subscriptions)
    }
}

// MARK: - Public Methods

public extension Notchly {
    
    func initializeWindow(screen: NSScreen) {
        if windowController == nil {
            print("Creating the notch window...")

            // 🔥 Fixed large window size
            let maxWidth: CGFloat = 600
            let maxHeight: CGFloat = 500

            let frame = NSRect(
                x: screen.frame.midX - (maxWidth / 2),
                y: screen.frame.maxY - maxHeight,  // 🔥 Always locked at the top
                width: maxWidth,
                height: maxHeight
            )

            let view = NSHostingView(rootView: NotchView(notchly: self).foregroundStyle(.white))

            let panel = NotchlyWindowPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )

            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            panel.setFrame(frame, display: true)
            panel.setFrameOrigin(NSPoint(x: frame.origin.x, y: screen.frame.maxY - frame.height))
            panel.contentView = view
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.orderFrontRegardless()

            windowController = NSWindowController(window: panel)
        }
    }

    func handleHover(expand: Bool) {
        DispatchQueue.main.async {
            withAnimation(self.animation) {
                self.resizeNotch(expanded: expand)
            }
        }
    }

    func resizeNotch(expanded: Bool) {
        let targetWidth: CGFloat = expanded ? 500 : 200
        let targetHeight: CGFloat = expanded ? 250 : 40

        withAnimation(animation) {
            notchWidth = targetWidth
            notchHeight = targetHeight
        }
    }
    
    func setContent(contentID: UUID = .init(), content: @escaping () -> Content) {
        self.content = content
        self.contentUUID = contentID
    }
    
    func show(on screen: NSScreen = NSScreen.screens[0]) {
        guard let window = windowController?.window else { return }
        window.orderFrontRegardless()
        isVisible = true
    }
    
    func hide() {
        isVisible = false
    }
}
