//
//  Notchly.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import Combine
import SwiftUI

/// `Notchly` manages the floating notch logic and state.
public class Notchly<Content>: ObservableObject where Content: View {
    public var windowController: NSWindowController?

    @Published var content: () -> Content
    @Published var contentUUID: UUID
    @Published var isVisible: Bool = false
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 35
    @Published var configuration: NotchlyConfiguration = .default
    @Published var isMouseInside: Bool = false
    @Published var isMediaPlaying: Bool = false
    @Published var calendarHasLiveActivity: Bool = false

    private var workItem: DispatchWorkItem?
    private var subscription: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()

    var animation: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }
    
    @MainActor
    func environmentInjectedContainerView() -> some View {
        NotchlyContainerView(notchly: self)
            .environmentObject(AppEnvironment.shared)
            .foregroundStyle(.white)
    }

    public init(contentID: UUID = .init(), @ViewBuilder content: @escaping () -> Content) {
        self.contentUUID = contentID
        self.content = content

        self.subscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = NSScreen.screens.first else { return }
                Task { @MainActor in
                    await self.initializeWindow(screen: screen)
                }
            }

        $isMouseInside
            .sink { [weak self] inside in
                self?.handleHover(expand: inside)
            }
            .store(in: &subscriptions)

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                AppEnvironment.shared.mediaMonitor.pausePolling()
                AppEnvironment.shared.calendarManager.suspendUpdates()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                AppEnvironment.shared.mediaMonitor.resumePolling()
                AppEnvironment.shared.calendarManager.reloadEvents()
                self?.handleHover(expand: self?.isMouseInside ?? false)
                AppEnvironment.shared.mediaMonitor.updateMediaState()
            }
        }
    }

    @MainActor
    public func initializeWindow(screen: NSScreen) async {
        guard windowController == nil else { return }
        let maxWidth: CGFloat = 800
        let maxHeight: CGFloat = 500

        let frame = NSRect(
            x: screen.frame.midX - (maxWidth / 2),
            y: screen.frame.maxY - maxHeight,
            width: maxWidth,
            height: maxHeight
        )

        let view = NSHostingView(rootView: self.environmentInjectedContainerView())

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

        self.windowController = NSWindowController(window: panel)
    }

    public func handleHover(expand: Bool) {
        DispatchQueue.main.async {
            withAnimation(self.animation) {
                self.resizeNotch(expanded: expand)
            }
        }
    }

    public func resizeNotch(expanded: Bool) {
        let targetConfig: NotchlyConfiguration = {
            if expanded {
                return .large
            } else if isMediaPlaying || calendarHasLiveActivity {
                return .activity
            } else {
                return .default
            }
        }()

        withAnimation(animation) {
            self.configuration = targetConfig
            self.notchWidth = targetConfig.width
            self.notchHeight = targetConfig.height
        }
    }

    public func setContent(contentID: UUID = .init(), content: @escaping () -> Content) {
        self.content = content
        self.contentUUID = contentID
    }

    public func show(on screen: NSScreen = NSScreen.screens[0]) {
        guard let window = windowController?.window else { return }
        window.orderFrontRegardless()
        isVisible = true
    }

    public func hide() {
        isVisible = false
    }
}
