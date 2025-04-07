//
//  UnifiedMediaPlayerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

// MARK: - UnifiedMediaPlayerView
// This view holds both the compact (activity) and detailed media player layouts persistently,
// but only shows content when media is playing.
//  • If no media is playing, nothing is shown.
//  • When media is playing and the notch is not expanded, the compact layout (activity) is shown.
//  • When media is playing and the notch is expanded, the detailed view (StrippedNotchlyMediaPlayer) is shown.
// The parent (NotchlyView) controls the overall frame.
struct UnifiedMediaPlayerView: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    var isExpanded: Bool // corresponds to notchly.isMouseInside

    // Local namespace for geometry morphing.
    @Namespace var mediaPlayerNamespace

    // Define the possible states.
    enum PlayerState: Equatable {
        case idle, activity, expanded
    }

    // Compute the current state:
    // • idle: if no media is playing OR if media is paused.
    // • activity: media is playing and notch is not expanded.
    // • expanded: media is playing and notch is expanded.
    var playerState: PlayerState {
        if mediaMonitor.nowPlaying == nil || !mediaMonitor.isPlaying {
            return .idle
        } else {
            return isExpanded ? .expanded : .activity
        }
    }
    
    // Unified animation.
    var unifiedAnimation: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }
    
    var body: some View {
        // If state is idle, show an empty view.
        if playerState == .idle {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                if let track = mediaMonitor.nowPlaying {
                    // Album Art
                    Group {
                        if playerState == .expanded {
                            ArtworkContainerView(
                                track: track,
                                isExpanded: true,
                                action: { openAppForTrack() },
                                backgroundGlowColor: .constant(.clear) // You can pass a binding if needed
                            )
                        } else {
                            ArtworkView(
                                artwork: track.artwork,
                                isExpanded: false,
                                action: { openAppForTrack() }
                            )
                        }
                    }
                    .frame(width: playerState == .activity ? 24 : 100,
                           height: playerState == .activity ? 24 : 100)
                    .padding(.leading, playerState == .activity ? 20 : 5)
                    .matchedGeometryEffect(id: "albumArt", in: mediaPlayerNamespace)
                    .animation(unifiedAnimation, value: playerState)

                    // Right-side container.
                    ZStack {
                        // Compact Layout: audio bars
                        HStack {
                            Spacer()
                            AudioBarsView()
                                .frame(width: 30, height: 24)
                        }
                        .opacity(playerState == .activity ? 1 : 0)
                        .animation(unifiedAnimation, value: playerState)

                        // Expanded Layout: detailed player UI
                        NotchlyMediaPlayer(isExpanded: isExpanded, mediaMonitor: mediaMonitor)
                            .opacity(playerState == .expanded ? 1 : 0)
                            .animation(unifiedAnimation, value: playerState)
                    }
                    .frame(maxWidth: .infinity, alignment: playerState == .activity ? .trailing : .leading)
                    .padding(.horizontal, 12)
                }
            }
            // The parent NotchlyView still sets the overall frame.
            .matchedGeometryEffect(id: "mediaPlayerContainer", in: mediaPlayerNamespace)
            .animation(unifiedAnimation, value: playerState)
        }
    }

    // MARK: - Helper for opening the corresponding media app
    func openAppForTrack() {
        let lower = mediaMonitor.activePlayerName.lowercased()
        let appURL: String = {
            if lower == "spotify" { return "spotify://" }
            else if lower == "podcasts" { return "podcasts://" }
            else { return "music://" }
        }()
        if let url = URL(string: appURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
