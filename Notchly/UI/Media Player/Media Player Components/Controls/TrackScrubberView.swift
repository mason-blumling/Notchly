//
//  TrackScrubberView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI

/// A view that displays a scrubber for media playback with draggable progress and time indicators.
struct TrackScrubberView: View {
    var currentTime: TimeInterval
    var duration: TimeInterval
    var isPlaying: Bool
    var onScrubChanged: (TimeInterval) -> Void
    var onScrubEnded: () -> Void

    private var hasValidDuration: Bool {
        duration > 1.0
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 3)

                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: progressRatio() * geometry.size.width,
                            height: 3
                        )
                        .animation(isPlaying ? .linear(duration: 0.5) : .none, value: currentTime)

                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.white)
                        .offset(x: progressRatio() * geometry.size.width - 4)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                let newTime = duration * percentage
                                onScrubChanged(newTime)
                            }
                            .onEnded { _ in
                                onScrubEnded()
                            }
                        )
                }
            }
            .frame(height: 10)

            HStack {
                if hasValidDuration {
                    Text(formatTime(currentTime))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("-" + formatTime(max(0, duration - currentTime)))
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func progressRatio() -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(max(0, min(currentTime / duration, 1)))
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TrackScrubberView_Previews: PreviewProvider {
    static var previews: some View {
        TrackScrubberView(
            currentTime: 30,
            duration: 200,
            isPlaying: true,
            onScrubChanged: { _ in },
            onScrubEnded: {}
        )
        .frame(width: 300)
        .background(Color.black)
    }
}
