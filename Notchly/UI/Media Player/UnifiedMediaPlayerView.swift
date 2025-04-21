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

    // Defines the visual state of the media player based on playback + hover
    private enum PlayerState { case none, idle, activity, expanded }

    // Current state based on playback + expansion
    private var playerState: PlayerState {
        guard mediaMonitor.nowPlaying != nil else {
            return isExpanded ? .idle : .none
        }
        return mediaMonitor.isPlaying
            ? (isExpanded ? .expanded : .activity)
            : (isExpanded ? .expanded : .none)
    }

    // Unified animation used for transitions
    private var animation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        } else {
            return .easeInOut(duration: 0.4)
        }
    }

    var body: some View {
        ZStack {
            // Expanded: Show ambient glow background
            if playerState == .expanded {
                HStack(spacing: 0) {
                    RenderSafeView {
                        LavaLampGlowView(blobColor: backgroundGlowColor)
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
                            .matchedGeometryEffect(id: "albumGlow", in: namespace)
                            .allowsHitTesting(false)
                    }
                    Spacer()
                }
            }

            Group {
                switch playerState {
                case .none:
                    Color.clear
                        .frame(width: 1, height: 1)
                        .opacity(0.0)
                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)

                case .idle:
                    MediaPlayerIdleView()
                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)

                case .activity, .expanded:
                    mediaContentView
                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(animation, value: playerState)
        }
        .frame(
            width: playerState == .none ? 0 : nil,
            height: playerState == .none ? 0 : nil
        )
        .clipped()
        .animation(animation, value: playerState)
        .onAppear {
            updateGlowColor(from: mediaMonitor.nowPlaying?.artwork?.copy() as? NSImage)
        }
        .onChange(of: mediaMonitor.nowPlaying?.artwork) { _, newArtwork in
            updateGlowColor(from: newArtwork)
        }
    }

    /// Content container that adapts based on player state
    private var mediaContentView: some View {
        HStack(spacing: 0) {
            if let track = mediaMonitor.nowPlaying {
                // Album art (compact or large)
                artworkView(for: track)
                    .frame(width: playerState == .activity ? 24 : 100,
                           height: playerState == .activity ? 24 : 100)
                    .padding(.leading, 8)
                    .animation(animation, value: playerState)

                Spacer(minLength: 8)

                switch playerState {
                case .activity:
                    // Audio bars (compact state only)
                    ZStack {
                        AudioBarsView()
                            .frame(width: 30, height: 24)
                            .scaleEffect(playerState == .activity ? 1 : 0.8, anchor: .center)
                            .opacity(playerState == .activity ? 1 : 0)
                            .animation(animation, value: playerState)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    .frame(width: 30, height: 24)
                    .clipped()
                    .onAppear {
                        withAnimation(NotchlyAnimations.notchExpansion) {
                            showBars = true
                        }
                    }
                    .onDisappear {
                        showBars = false
                    }

                case .expanded:
                    // Full track info, controls, scrubber
                    NotchlyMediaPlayer(mediaMonitor: mediaMonitor)

                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    /// Displays artwork differently depending on player state
    @ViewBuilder private func artworkView(for track: NowPlayingInfo) -> some View {
        if playerState == .expanded {
            ArtworkContainerView(
                track: track,
                isExpanded: true,
                action: openAppForTrack,
                backgroundGlowColor: $backgroundGlowColor,
                namespace: namespace
            )
        } else if playerState == .activity {
            ArtworkView(
                artwork: track.artwork,
                isExpanded: false,
                action: openAppForTrack
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                Image((track.appName.lowercased() == "spotify") ? "spotify-Universal" : "appleMusic-Universal")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .opacity(0)
                    .matchedGeometryEffect(id: "appLogo", in: namespace)
            )
        }
    }

    /// Extracts vibrant glow color from album artwork
    private func updateGlowColor(from image: NSImage?) {
        if let image = image,
           let dominant = image.dominantColor(),
           let vibrant = dominant.vibrantColor() {
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundGlowColor = Color(nsColor: vibrant)
            }
        } else {
            backgroundGlowColor = Color.gray.opacity(0.25)
        }
    }

    /// Opens the current track's app (Music, Spotify, Podcasts)
    private func openAppForTrack() {
        let urlScheme = (mediaMonitor.activePlayerName.lowercased() == "spotify") ? "spotify://" :
                        (mediaMonitor.activePlayerName.lowercased() == "podcasts") ? "podcasts://" : "music://"
        if let url = URL(string: urlScheme) {
            NSWorkspace.shared.open(url)
        }
    }
}
