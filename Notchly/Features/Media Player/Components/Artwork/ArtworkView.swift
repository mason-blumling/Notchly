//
//  ArtworkView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

// MARK: - Conditional Modifier Extension

extension View {
    /// Applies the given transformation if the condition is true.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool,
                                          transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - ArtworkView

/// Displays the album artwork for the media player.
/// - If a valid `NSImage` is provided, displays that image.
/// - If no image is provided, falls back to a system music note icon.
/// - If `isExpanded` is true and an `action` is provided, the artwork becomes tappable.
struct ArtworkView: View {
    var artwork: NSImage?
    var isExpanded: Bool = false
    var action: (() -> Void)? = nil

    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared

    // MARK: - Body

    var body: some View {
        Group {
            if let image = artwork, image.size != NSZeroSize {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Image("music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }
        }
        .if(isExpanded && action != nil) { view in
            Button(action: { action?() }) {
                view
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95))) /// Smooth entry/exit
        .animation(coordinator.animation, value: isExpanded)      /// Match system animation curve
    }
}
