//
//  MenuBarPopoverView.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `MenuBarPopoverView`, a SwiftUI component that embeds an `NSView`.
//  It integrates AppKit tracking functionality into the popover to handle mouse events.

import SwiftUI

/// A SwiftUI component that embeds an `NSView` to enable tracking mouse events inside the popover.
struct MenuBarPopoverView<Content: View>: NSViewRepresentable {

    // MARK: - Properties
    weak var controller: MenuBarController?
    let content: () -> Content

    // MARK: - NSViewRepresentable Methods
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()

        // Configure containerView
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        // Configure trackingView (used to monitor curser enter/exit)
        let trackingView = PopoverTrackingView(frame: .zero, controller: controller!)
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.wantsLayer = true
        trackingView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(trackingView, positioned: .below, relativeTo: nil)

        // Configure SwiftUI Content
        let hostingController = NSHostingController(
            rootView: content()
                .background(Color.black)
                .zIndex(1) // Ensure it's on top
        )
        let hostedView = hostingController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostedView)

        // Apply Constraints
        NSLayoutConstraint.activate([
            trackingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            trackingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            hostedView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Optional update logic
    }
}
