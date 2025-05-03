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
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor

    @State private var appear = false

    var body: some View {
        ZStack {
            if let track = mediaMonitor.nowPlaying {
                VStack(alignment: .leading, spacing: 10) {
                    TrackInfoView(track: track)

                    MediaControlsView(
                        isPlaying: mediaMonitor.isPlaying,
                        onPrevious: mediaMonitor.previousTrack,
                        onPlayPause: mediaMonitor.togglePlayPause,
                        onNext: mediaMonitor.nextTrack
                    )
                    .padding(.top, 8)

                    TrackScrubberView(
                        currentTime: mediaMonitor.currentTime,
                        duration: track.duration,
                        displayTimes: mediaMonitor.displayTimes,  // Pass the synchronized times
                        onScrubChanged: { newTime in
                            mediaMonitor.isScrubbing = true
                            mediaMonitor.currentTime = newTime
                        },
                        onScrubEnded: {
                            mediaMonitor.isScrubbing = false
                            mediaMonitor.seekTo(time: mediaMonitor.currentTime)
                        }
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.clear)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.95)
                .animation(.easeOut(duration: 0.35), value: appear)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .onAppear {
                    appear = true
                }
                .onDisappear {
                    appear = false
                }
            }
        }
    }
}
