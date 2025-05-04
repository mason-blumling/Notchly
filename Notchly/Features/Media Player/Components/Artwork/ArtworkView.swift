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
/// - If a valid artwork is provided, it displays that image with a resizable fill mode.
/// - Otherwise, it falls back to a placeholder image ("music.note").
/// - When `isExpanded` is true and an `action` is provided, the view is wrapped in a Button to allow tap interaction.
struct ArtworkView: View {
    var artwork: NSImage?
    var isExpanded: Bool = false
    var action: (() -> Void)? = nil
    
    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared
    
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
        /// Use transition consistent with our animation system
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(coordinator.animation, value: isExpanded)
    }
}
