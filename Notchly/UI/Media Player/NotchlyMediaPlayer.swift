//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// This is your NotchlyMediaPlayer minus the album art and shape.
/// We only show track info, controls, scrubber. The album art is handled by UnifiedMediaPlayerView.
struct NotchlyMediaPlayer: View {
    var isExpanded: Bool
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor

    var body: some View {
        ZStack {
            if let track = mediaMonitor.nowPlaying {
                VStack(alignment: .leading, spacing: 10) {
                    // Track Info
                    TrackInfoView(track: track)

                    // Media Controls
                    MediaControlsView(
                        isPlaying: mediaMonitor.isPlaying,
                        onPrevious: { mediaMonitor.previousTrack() },
                        onPlayPause: { mediaMonitor.togglePlayPause() },
                        onNext: { mediaMonitor.nextTrack() }
                    )
                    .padding(.top, 8)

                    // Scrubber
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
                            let monitor = mediaMonitor
                            monitor.seekTo(time: monitor.currentTime)
                            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                                Task { await monitor.updateMediaState() }
                            }
                        }
                    )
                }
                .transition(.opacity.combined(with: .scale))
                .id("expandedContent")
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
