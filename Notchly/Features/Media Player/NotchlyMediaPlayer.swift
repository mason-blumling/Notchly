//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

/// Displays the expanded media player content with proper timer lifecycle handling.
/// This view includes track info, media controls, and scrubber synced to playback state.
struct NotchlyMediaPlayer: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    @State private var appear = false

    var body: some View {
        ZStack {
            if let track = mediaMonitor.nowPlaying {
                VStack(alignment: .leading, spacing: 10) {
                    
                    /// Track metadata (title, artist, album, etc.)
                    TrackInfoView(track: track)

                    /// Playback control buttons
                    MediaControlsView(
                        isPlaying: mediaMonitor.isPlaying,
                        onPrevious: mediaMonitor.previousTrack,
                        onPlayPause: mediaMonitor.togglePlayPause,
                        onNext: mediaMonitor.nextTrack
                    )
                    .padding(.top, 8)

                    /// Progress bar and time labels
                    TrackScrubberView(mediaMonitor: mediaMonitor)
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
                    mediaMonitor.startTimer() /// Start live progress updates
                }
                .onDisappear {
                    appear = false
                    mediaMonitor.stopTimer() /// Stop timers to reduce CPU usage
                }
            }
        }
    }
}
