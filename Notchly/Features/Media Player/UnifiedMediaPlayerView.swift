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

    private enum PlayerState: Equatable { case none, idle, activity, expanded }

    private var playerState: PlayerState {
        guard mediaMonitor.nowPlaying != nil else {
            return isExpanded ? .idle : .none
        }
        return mediaMonitor.isPlaying
            ? (isExpanded ? .expanded : .activity)
            : (isExpanded ? .expanded : .none)
    }

    /// Calculate artwork size based on Notch config
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

    var body: some View {
        ZStack {
            /// Glow background for expanded state
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
            .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
        }
        .animation(coordinator.animation, value: coordinator.configuration)
        .onChange(of: mediaMonitor.nowPlaying?.artwork) { _, new in
            updateGlowColor(from: new)
        }
    }

    private func expandedBackgroundGlow() -> some View {
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

    private func mediaContentView() -> some View {
        HStack(spacing: 0) {
            if let track = mediaMonitor.nowPlaying {
                /// In activity state, we need to center the content properly
                if playerState == .activity {
                    HStack(spacing: 12) {
                        /// Fixed spacing from left edge
                        Spacer()
                            .frame(width: 5)
                        
                        /// Artwork
                        artworkView(for: track)
                            .frame(width: artworkSize, height: artworkSize)
                        
                        /// Flexible spacer pushes audio bars to the right
                        Spacer()
                        
                        /// Audio bars
                        AudioBarsView()
                            .frame(width: 30, height: 24)
                        
                        /// Fixed spacing from right edge
                        Spacer()
                            .frame(width: 5)
                    }
                } else {
                    /// Expanded state layout
                    artworkView(for: track)
                        .frame(width: artworkSize, height: artworkSize)
                        .padding(.leading, playerState == .expanded ? 16 : 8)
                    
                    Spacer(minLength: 8)
                    
                    if playerState == .expanded {
                        NotchlyMediaPlayer(mediaMonitor: mediaMonitor)
                            .padding(.trailing, 16)
                            .opacity(playerState == .expanded ? 1 : 0)
                    }
                }
            }
        }
        /// Single animation for the entire view content
        .animation(coordinator.animation, value: coordinator.configuration)
    }

    @ViewBuilder
    private func artworkView(for track: NowPlayingInfo) -> some View {
        if let artwork = track.artwork, artwork.size != .zero {
            ArtworkView(
                artwork: artwork,
                isExpanded: artworkSize > 50,  /// Use size to determine if expanded
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
    
    /// Extracts vibrant glow color from album artwork
    private func updateGlowColor(from image: NSImage?) {
        if let image = image,
           let dom = image.dominantColor(),
           let vib = dom.vibrantColor() {
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundGlowColor = Color(nsColor: vib)
            }
        } else {
            backgroundGlowColor = .gray.opacity(0.25)
        }
    }

    /// Opens the current track's app (Music, Spotify, Podcasts)
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

///// A dynamic media player view that morphs between idle, activity, and expanded states.
///// Displays album art, audio bars, and full controls depending on playback and hover state.
//struct UnifiedMediaPlayerView: View {
//    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
//    var isExpanded: Bool
//    var namespace: Namespace.ID
//    @State private var backgroundGlowColor: Color = .clear
//    @State private var showBars = false
//    @State private var previousState: PlayerState?
//    @State private var transitionState: PlayerState?
//    
//    // Transition coordinator for unified animations
//    @ObservedObject private var coordinator = NotchlyTransitionCoordinator.shared
//
//    // Defines the visual state of the media player based on playback + hover
//    private enum PlayerState: Equatable {
//        case none, idle, activity, expanded
//    }
//
//    // Current state based on playback + expansion
//    private var playerState: PlayerState {
//        guard mediaMonitor.nowPlaying != nil else {
//            return isExpanded ? .idle : .none
//        }
//        return mediaMonitor.isPlaying
//            ? (isExpanded ? .expanded : .activity)
//            : (isExpanded ? .expanded : .none)
//    }
//
//    // Use the coordinator's animation for every state change
//    private var animation: Animation { coordinator.animation }
//
//    var body: some View {
//        // Use the effective state including transition state if needed
//        let currentState = transitionState ?? playerState
//        
//        ZStack {
//            // Expanded: Show ambient glow background
//            if currentState == .expanded {
//                HStack(spacing: 0) {
//                    RenderSafeView {
//                        LavaLampGlowView(blobColor: backgroundGlowColor)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .padding(.trailing, 120)
//                            .scaleEffect(y: 1.2)
//                            .blur(radius: 40)
//                            .mask(
//                                LinearGradient(
//                                    gradient: Gradient(stops: [
//                                        .init(color: .black, location: 0.0),
//                                        .init(color: .black, location: 0.75),
//                                        .init(color: .clear, location: 1.0)
//                                    ]),
//                                    startPoint: .leading,
//                                    endPoint: .trailing
//                                )
//                            )
//                            .opacity(0.5)
//                            .matchedGeometryEffect(id: "albumGlow", in: namespace)
//                            .allowsHitTesting(false)
//                    }
//                    Spacer()
//                }
//            }
//
//            Group {
//                switch currentState {
//                case .none:
//                    Color.clear
//                        .frame(width: 1, height: 1)
//                        .opacity(0.0)
//                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
//
//                case .idle:
//                    MediaPlayerIdleView()
//                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
//
//                case .activity, .expanded:
//                    mediaContentView(for: currentState)
//                        .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
//                }
//            }
//            .transition(.opacity.combined(with: .scale(scale: 0.95)))
//        }
//        .frame(
//            width: currentState == .none ? 0 : nil,
//            height: currentState == .none ? 0 : nil
//        )
//        .clipped()
//        // Single animation for the entire view
//        .animation(animation, value: playerState)
//        .animation(animation, value: transitionState)
//        .onChange(of: playerState) { oldState, newState in
//            if oldState == .expanded && newState == .activity {
//                // Set transition state to maintain expanded state temporarily
//                withAnimation(animation) {
//                    transitionState = oldState
//                }
//                
//                // Delayed transition to new state to synchronize with shape
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
//                    withAnimation(animation) {
//                        transitionState = nil
//                    }
//                }
//            } else {
//                // For other transitions, clear any lingering transition state
//                transitionState = nil
//            }
//        }
//        .onChange(of: mediaMonitor.nowPlaying?.artwork) { _, new in
//            updateGlowColor(from: new)
//        }
//    }
//
//    /// Content container that adapts based on player state
//    private func mediaContentView(for state: PlayerState) -> some View {
//        // A single HStack that maintains consistent spacing throughout animations
//        HStack(spacing: 0) {
//            if let track = mediaMonitor.nowPlaying {
//                // 1. Left padding that grows/shrinks with the shape
//                Spacer()
//                    .frame(width: 20)
//                    
//                // 2. Artwork container with external app icon
//                ZStack(alignment: .bottomTrailing) {
//                    // Main artwork
//                    artworkContent(for: track)
//                        .frame(
//                            width: state == .activity ? 24 : 100,
//                            height: state == .activity ? 24 : 100
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: state == .activity ? 4 : 10))
//                        .matchedGeometryEffect(id: "albumArt", in: namespace)
//                    
//                    // External app icon for expanded state only
//                    if state == .expanded {
//                        Image(track.appName.lowercased() == "spotify" ?
//                            "spotify-Universal" : "appleMusic-Universal")
//                            .resizable()
//                            .frame(width: 40, height: 40)
//                            .offset(x: 12, y: 12) // Position icon outside artwork
//                            .matchedGeometryEffect(id: "appLogo", in: namespace)
//                    }
//                }
//                .onTapGesture(perform: openAppForTrack)
//                
//                // 3. Dynamic content area based on state
//                if state == .activity {
//                    // In activity state, push audio bars to the right edge
//                    Spacer()
//                    
//                    // Audio bars always at the right edge
//                    AudioBarsView()
//                        .frame(width: 30, height: 24)
//                        
//                    // Consistent right padding
//                    Spacer()
//                        .frame(width: 16)
//                } else if state == .expanded {
//                    // Small spacing after artwork
//                    Spacer()
//                        .frame(width: 16)
//                    
//                    // Media player in expanded state
//                    NotchlyMediaPlayer(mediaMonitor: mediaMonitor)
//                    
//                    // Right padding in expanded view
//                    Spacer()
//                        .frame(width: 16)
//                }
//            }
//        }
//        // The critical part: single animation applied to the entire HStack
//        .animation(animation, value: state)
//    }
//
//    @ViewBuilder
//    private func artworkContent(for track: NowPlayingInfo) -> some View {
//        // Basic artwork with no app logo
//        if let image = track.artwork, image.size != NSZeroSize {
//            Image(nsImage: image)
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//        } else {
//            Image("music.note")
//                .resizable()
//                .aspectRatio(contentMode: .fill)
//        }
//    }
//
//    /// Extracts vibrant glow color from album artwork
//    private func updateGlowColor(from image: NSImage?) {
//        if let image = image,
//           let dom = image.dominantColor(),
//           let vib = dom.vibrantColor() {
//            withAnimation(.easeInOut(duration: 0.3)) {
//                backgroundGlowColor = Color(nsColor: vib)
//            }
//        } else {
//            backgroundGlowColor = .gray.opacity(0.25)
//        }
//    }
//
//    /// Opens the current track's app (Music, Spotify, Podcasts)
//    private func openAppForTrack() {
//        let urlScheme = mediaMonitor.activePlayerName.lowercased() == "spotify"
//            ? "spotify://"
//            : (mediaMonitor.activePlayerName.lowercased() == "podcasts"
//               ? "podcasts://"
//               : "music://")
//        if let url = URL(string: urlScheme) {
//            NSWorkspace.shared.open(url)
//        }
//    }
//}
