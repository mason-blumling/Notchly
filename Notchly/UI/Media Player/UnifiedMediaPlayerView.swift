//
//  UnifiedMediaPlayerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// Holds both compact and expanded player views, seamlessly morphing between them.
struct UnifiedMediaPlayerView: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    var isExpanded: Bool

    @Namespace private var mediaPlayerNamespace

    private enum PlayerState {
        case idle, activity, expanded
    }

    private var playerState: PlayerState {
        if mediaMonitor.nowPlaying == nil || !mediaMonitor.isPlaying {
            return .idle
        }
        return isExpanded ? .expanded : .activity
    }

    private var animation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        } else {
            return .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    var body: some View {
        if playerState == .idle {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                if let track = mediaMonitor.nowPlaying {
                    // MARK: - Album Art
                    Group {
                        if playerState == .expanded {
                            ArtworkContainerView(
                                track: track,
                                isExpanded: true,
                                action: openAppForTrack,
                                backgroundGlowColor: .constant(.clear)
                            )
                        } else {
                            ArtworkView(
                                artwork: track.artwork,
                                isExpanded: false,
                                action: openAppForTrack
                            )
                        }
                    }
                    .frame(width: playerState == .activity ? 24 : 100,
                           height: playerState == .activity ? 24 : 100)
                    .padding(.leading, playerState == .activity ? 20 : 5)
                    .matchedGeometryEffect(id: "albumArt", in: mediaPlayerNamespace)
                    .animation(animation, value: playerState)

                    // MARK: - Right-Side Content
                    ZStack {
                        // Compact: Animated audio bars
                        HStack {
                            Spacer()
                            AudioBarsView()
                                .frame(width: 30, height: 24)
                        }
                        .opacity(playerState == .activity ? 1 : 0)
                        .animation(animation, value: playerState)

                        // Expanded: Full controls and scrubber
                        NotchlyMediaPlayer(isExpanded: isExpanded, mediaMonitor: mediaMonitor)
                            .opacity(playerState == .expanded ? 1 : 0)
                            .animation(animation, value: playerState)
                    }
                    .frame(maxWidth: .infinity, alignment: playerState == .activity ? .trailing : .leading)
                    .padding(.horizontal, 12)
                }
            }
            .matchedGeometryEffect(id: "mediaPlayerContainer", in: mediaPlayerNamespace)
            .animation(animation, value: playerState)
        }
    }

    // MARK: - Open App
    private func openAppForTrack() {
        let urlScheme: String = {
            switch mediaMonitor.activePlayerName.lowercased() {
            case "spotify": return "spotify://"
            case "podcasts": return "podcasts://"
            default: return "music://"
            }
        }()
        if let url = URL(string: urlScheme) {
            NSWorkspace.shared.open(url)
        }
    }
}
