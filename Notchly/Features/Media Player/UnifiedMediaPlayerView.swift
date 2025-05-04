//
//  UnifiedMediaPlayerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// A dynamic media player view that morphs between idle, activity, and expanded states.
/// Displays album art, audio bars, and full controls depending on playback and hover state.
struct UnifiedMediaPlayerView: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    var isExpanded: Bool
    var namespace: Namespace.ID
    @State private var backgroundGlowColor: Color = .clear
    @State private var showBars = false

    @ObservedObject private var coordinator = NotchlyViewModel.shared

    // MARK: - Player State Enum

    private enum PlayerState: Equatable { case none, idle, activity, expanded }

    // MARK: - Derived State

    private var playerState: PlayerState {
        guard mediaMonitor.nowPlaying != nil else {
            return isExpanded ? .idle : .none
        }
        return mediaMonitor.isPlaying
            ? (isExpanded ? .expanded : .activity)
            : (isExpanded ? .expanded : .none)
    }

    private var artworkSize: CGFloat {
        let expandedSize: CGFloat = 100
        let activitySize: CGFloat = 24
        
        // Use state directly for more stable sizing
        switch coordinator.state {
        case .expanded:
            return expandedSize
        case .mediaActivity, .calendarActivity:
            return activitySize
        case .collapsed:
            // For collapsed state, interpolate based on width
            let expandedWidth = NotchlyConfiguration.large.width
            let activityWidth = NotchlyConfiguration.activity.width
            let currentWidth = coordinator.configuration.width
            
            if currentWidth <= activityWidth {
                return activitySize
            } else if currentWidth >= expandedWidth {
                return expandedSize
            } else {
                let progress = (currentWidth - activityWidth) / (expandedWidth - activityWidth)
                let clampedProgress = max(0, min(1, progress))
                return activitySize + (expandedSize - activitySize) * clampedProgress
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            /// Glow background (only in expanded state)
            if playerState == .expanded {
                expandedBackgroundGlow()
                    .opacity(backgroundGlowOpacity)
            }

            Group {
                switch playerState {
                case .none:
                    Color.clear
                        .frame(width: 1, height: 1)
                        .opacity(0.0)

                case .idle:
                    MediaPlayerIdleView()

                case .activity, .expanded:
                    mediaContentView()
                }
            }
        }
        .animation(coordinator.animation, value: coordinator.configuration)
        .onChange(of: mediaMonitor.nowPlaying?.artwork) { _, new in
            updateGlowColor(from: new)
        }
    }

    // MARK: - Expanded Glow Background

    private func expandedBackgroundGlow() -> some View {
        HStack(spacing: 0) {
            RenderSafeView {
                GlowingBlobView(blobColor: backgroundGlowColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.trailing, 120)
                    .scaleEffect(y: 1.2)
                    .blur(radius: 40)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.75),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.5)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            Spacer()
        }
    }

    private var backgroundGlowOpacity: Double {
        let expandedWidth = NotchlyConfiguration.large.width
        let activityWidth = NotchlyConfiguration.activity.width
        let currentWidth = coordinator.configuration.width

        if currentWidth >= expandedWidth {
            return 1.0
        } else if currentWidth <= activityWidth {
            return 0.0
        } else {
            let progress = (currentWidth - activityWidth) / (expandedWidth - activityWidth)
            return Double(progress)
        }
    }

    // MARK: - Main Media Content

    private func mediaContentView() -> some View {
        HStack(spacing: 0) {
            if let track = mediaMonitor.nowPlaying {
                /// Fixed left padding - no longer changes with state
                Spacer()
                    .frame(width: 16)
                
                /// Artwork container with consistent alignment
                ZStack(alignment: .bottomTrailing) {
                    /// Single artwork view that scales and animates between states
                    artworkView(for: track)
                        .frame(width: artworkSize, height: artworkSize)
                        .matchedGeometryEffect(id: "actualArtwork", in: namespace)
                    
                    /// App logo - always present but opacity changes
                    let logoName = track.appName.lowercased() == "spotify"
                        ? "spotify-Universal"
                        : "appleMusic-Universal"

                    Image(logoName)
                        .resizable()
                        .frame(width: playerState == .expanded ? 40 : 10, height: playerState == .expanded ? 40 : 10)
                        .offset(x: 10, y: 10)
                        .opacity(playerState == .expanded ? 1 : 0)
                }
                .frame(width: artworkSize, height: artworkSize)
                .animation(coordinator.animation, value: artworkSize)
                
                if playerState == .activity {
                    /// Activity: Audio bars with fixed positioning
                    Spacer(minLength: 8)
                        .frame(maxWidth: .infinity)
                    
                    AudioBarsView()
                        .frame(width: 30, height: 24)
                        .opacity(activityContentOpacity)
                        .offset(x: 2)

                    Spacer()
                        .frame(width: 16)
                } else {
                    /// Expanded: Media player with fixed positioning
                    Spacer(minLength: 8)
                    
                    VStack(alignment: .leading) {
                        NotchlyMediaPlayer(mediaMonitor: mediaMonitor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(expandedContentOpacity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                        .frame(width: 16)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var expandedContentOpacity: Double {
        let expandedWidth: CGFloat = NotchlyConfiguration.large.width
        let currentWidth = coordinator.configuration.width
        let progress = (currentWidth - NotchlyConfiguration.default.width) / (expandedWidth - NotchlyConfiguration.default.width)
        return Double(max(0, min(1, progress)))
    }

    private var activityContentOpacity: Double {
        let activityWidth = NotchlyConfiguration.activity.width
        let defaultWidth = NotchlyConfiguration.default.width
        let currentWidth = coordinator.configuration.width

        if currentWidth <= defaultWidth {
            return 0
        } else if currentWidth >= activityWidth {
            return coordinator.state == .expanded ? 0 : 1
        } else {
            let progress = (currentWidth - defaultWidth) / (activityWidth - defaultWidth)
            return Double(max(0, min(1, progress)))
        }
    }

    // MARK: - Artwork View

    @ViewBuilder
    private func artworkView(for track: NowPlayingInfo) -> some View {
        if let artwork = track.artwork, artwork.size != .zero {
            ArtworkView(
                artwork: artwork,
                isExpanded: playerState == .expanded,
                action: openAppForTrack
            )
            .cornerRadius(playerState == .expanded ? 10 : 4)
            // Remove individual animation, let the container handle it
        } else {
            RoundedRectangle(cornerRadius: playerState == .expanded ? 10 : 4)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: playerState == .expanded ? 40 : 10))
                )
        }
    }

    // MARK: - Glow Color Utility

    private func updateGlowColor(from image: NSImage?) {
        if let image,
           let dom = image.dominantColor(),
           let vib = dom.vibrantColor() {
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundGlowColor = Color(nsColor: vib)
            }
        } else {
            backgroundGlowColor = .gray.opacity(0.25)
        }
    }

    // MARK: - External App Launch

    private func openAppForTrack() {
        let urlScheme = mediaMonitor.activePlayerName.lowercased() == "spotify"
            ? "spotify://"
            : (mediaMonitor.activePlayerName.lowercased() == "podcasts"
               ? "podcasts://"
               : "music://")

        if let url = URL(string: urlScheme) {
            NSWorkspace.shared.open(url)
        }
    }
}
