//
//  ArtworkContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// Displays album artwork with matched geometry, optional glow syncing, and app badge overlay.
/// Used in the expanded media player state.
struct ArtworkContainerView: View {
    var track: NowPlayingInfo
    var isExpanded: Bool = false
    var action: (() -> Void)? = nil
    @Binding var backgroundGlowColor: Color
    var glowIntensity: CGFloat = 1.0
    var namespace: Namespace.ID
    
    @State private var showGlow: Bool = false

    var body: some View {
        ZStack {
            // Album artwork with tap interaction (if provided)
            ArtworkView(
                artwork: track.artwork,
                isExpanded: isExpanded,
                action: action
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .matchedGeometryEffect(id: "albumArt", in: namespace)
            .onAppear {
                updateGlowColor(with: track.artwork)
                withAnimation(.easeOut(duration: 0.3)) {
                    showGlow = true
                }
            }
            .onDisappear {
                showGlow = false
            }

            // App icon overlay (Spotify or Apple Music)
            let logoName = (track.appName.lowercased() == "spotify") ? "spotify-Universal" : "appleMusic-Universal"
            Image(logoName)
                .resizable()
                .frame(width: 40, height: 40)
                .offset(x: 40, y: 40)
                .matchedGeometryEffect(id: "appLogo", in: namespace)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.3), value: isExpanded)
        }
        .frame(width: 100, height: 100)
    }

    /// Extracts the glow color from the provided artwork and applies it to the background binding
    private func updateGlowColor(with image: NSImage?) {
        if let safeImage = image?.copy() as? NSImage,
           let dominant = safeImage.dominantColor(),
           let vibrant = dominant.vibrantColor() {
            backgroundGlowColor = Color(nsColor: vibrant)
        } else {
            backgroundGlowColor = Color.gray.opacity(0.25)
        }
    }
}
