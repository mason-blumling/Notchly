//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// Expanded media player content (no album art).
/// Includes track info, media controls, and scrubber.
/// Album art is handled by the parent UnifiedMediaPlayerView.
struct NotchlyMediaPlayer: View {
    var isExpanded: Bool
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor

    var body: some View {
        ZStack {
            if let track = mediaMonitor.nowPlaying {
                VStack(alignment: .leading, spacing: 10) {
                    TrackInfoView(track: track)

                    MediaControlsView(
                        isPlaying: mediaMonitor.isPlaying,
                        onPrevious: { mediaMonitor.previousTrack() },
                        onPlayPause: { mediaMonitor.togglePlayPause() },
                        onNext: { mediaMonitor.nextTrack() }
                    )
                    .padding(.top, 8)

                    TrackScrubberView(
                        currentTime: mediaMonitor.currentTime,
                        duration: track.duration,
                        isPlaying: mediaMonitor.isPlaying,
                        onScrubChanged: { newTime in
                            mediaMonitor.isScrubbing = true
                            mediaMonitor.currentTime = newTime
                        },
                        onScrubEnded: {
                            mediaMonitor.isScrubbing = false
                            let time = mediaMonitor.currentTime
                            mediaMonitor.seekTo(time: time)
                            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                                Task { await mediaMonitor.updateMediaState() }
                            }
                        }
                    )
                }
                .id("expandedContent")
                .transition(.opacity.combined(with: .scale))
            } else {
                MediaPlayerIdleView()
            }
        }
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                mediaMonitor.updateMediaState()
            }
        }
    }
}
