//
//  UnifiedMediaPlayerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

struct UnifiedMediaPlayerView: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    var isExpanded: Bool
    var namespace: Namespace.ID
    @State private var backgroundGlowColor: Color = .clear

    private enum PlayerState { case none, idle, activity, expanded }

    private var playerState: PlayerState {
        guard let _ = mediaMonitor.nowPlaying else {
            return isExpanded ? .idle : .none
        }
        return mediaMonitor.isPlaying ? (isExpanded ? .expanded : .activity) : (isExpanded ? .expanded : .none)
    }

    private var animation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        } else {
            return .easeInOut(duration: 0.4)
        }
    }

    var body: some View {
        ZStack {
            switch playerState {
            case .none:
                EmptyView()

            case .idle:
                MediaPlayerIdleView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)

            case .activity, .expanded:
                mediaContentView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .matchedGeometryEffect(id: "mediaPlayerContainer", in: namespace)
            }
        }
        .frame(width: playerState == .none ? 0 : nil,
               height: playerState == .none ? 0 : nil)
        .clipped()
        .animation(animation, value: playerState)
    }

    private var mediaContentView: some View {
        HStack(spacing: 0) {
            if let track = mediaMonitor.nowPlaying {
                artworkView(for: track)
                    .frame(width: playerState == .activity ? 24 : 100,
                           height: playerState == .activity ? 24 : 100)
                    .padding(.leading, 5)
                    .animation(animation, value: playerState)

                Spacer(minLength: 8)

                switch playerState {
                case .activity:
                    AudioBarsView()
                        .frame(width: 30, height: 24)
                        .scaleEffect(playerState == .activity ? 1 : 0.8, anchor: .leading)
                        .opacity(playerState == .activity ? 1 : 0)
                        .animation(animation, value: playerState)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                        .clipped()
                case .expanded:
                    NotchlyMediaPlayer(mediaMonitor: mediaMonitor)
                default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 12)
    }

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
            .overlay(
                Image((track.appName.lowercased() == "spotify") ? "spotify-Universal" : "appleMusic-Universal")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .opacity(0) // <– invisible match target
                    .matchedGeometryEffect(id: "appLogo", in: namespace)
            )
        }
    }

    private func openAppForTrack() {
        let urlScheme = (mediaMonitor.activePlayerName.lowercased() == "spotify") ? "spotify://" :
                        (mediaMonitor.activePlayerName.lowercased() == "podcasts") ? "podcasts://" : "music://"
        if let url = URL(string: urlScheme) {
            NSWorkspace.shared.open(url)
        }
    }
}
