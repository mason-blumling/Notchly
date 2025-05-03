//
//  TrackScrubberView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI

/// A view that displays a scrubber for media playback.
struct TrackScrubberView: View {
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    // Progress track
                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: mediaMonitor.progress * geometry.size.width,
                            height: 3
                        )

                    // Scrubber handle
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.white)
                        .offset(x: mediaMonitor.progress * geometry.size.width - 4)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    mediaMonitor.isScrubbing = true
                                    let pct = max(0, min(1, value.location.x / geometry.size.width))
                                    let newTime = mediaMonitor.duration * pct
                                    mediaMonitor.seekTo(time: newTime)
                                }
                                .onEnded { _ in
                                    mediaMonitor.isScrubbing = false
                                    mediaMonitor.seekTo(time: mediaMonitor.currentTime)
                                }
                        )
                }
            }
            .frame(height: 10)

            // Time labels
            HStack {
                Text(mediaMonitor.elapsedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(mediaMonitor.remainingTime)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
    }
}
