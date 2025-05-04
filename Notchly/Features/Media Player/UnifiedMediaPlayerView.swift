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

    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared

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

        let expandedWidth = NotchlyConfiguration.large.width
        let activityWidth = NotchlyConfiguration.activity.width
        let currentWidth = coordinator.configuration.width

        if currentWidth >= expandedWidth {
            return expandedSize
        } else if currentWidth <= activityWidth {
            return activitySize
        } else {
            let progress = (currentWidth - activityWidth) / (expandedWidth - activityWidth)
            return activitySize + (expandedSize - activitySize) * progress
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
                // Left padding that adjusts based on state
                Spacer()
                    .frame(width: playerState == .expanded ? 16 : 15)
                
                // Single artwork view that scales and animates between states
                artworkView(for: track)
                    .frame(width: artworkSize, height: artworkSize)
                    .matchedGeometryEffect(id: "artworkElement", in: namespace)
                
                /// Content that changes based on state
                if playerState == .activity {
                    /// Activity: Audio bars with controlled spacing
                    Spacer()
                        .frame(maxWidth: .infinity) // This will push audio bars to the right, but not too far
                    
                    AudioBarsView()
                        .frame(width: 30, height: 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    
                    Spacer()
                        .frame(width: 15) // Right padding to prevent cutoff
                } else if playerState == .expanded {
                    // Expanded: Show media controls
                    Spacer(minLength: 8)
                    
                    NotchlyMediaPlayer(mediaMonitor: mediaMonitor)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    
                    Spacer()
                        .frame(width: 16)
                }
            }
        }
        .animation(coordinator.animation, value: playerState)
    }

    // MARK: - Artwork View

    @ViewBuilder
    private func artworkView(for track: NowPlayingInfo) -> some View {
        Group {
            if let artwork = track.artwork, artwork.size != .zero {
                ArtworkView(
                    artwork: artwork,
                    isExpanded: artworkSize > 50,
                    action: openAppForTrack
                )
                .clipShape(RoundedRectangle(cornerRadius: playerState == .expanded ? 10 : 4))
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
        .id(track.appName + track.title) // Ensure view identity changes with track changes
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
