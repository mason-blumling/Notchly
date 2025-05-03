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
    var displayTimes: (elapsed: String, remaining: String)
    var onScrubChanged: (TimeInterval) -> Void
    var onScrubEnded: () -> Void

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
                        .animation(nil, value: currentTime)

                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.white)
                        .offset(x: progressRatio() * geometry.size.width - 4)
                        .animation(nil, value: currentTime)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let pct = max(0, min(1, value.location.x / geometry.size.width))
                                let t = duration * pct
                                onScrubChanged(t)
                            }
                            .onEnded { _ in onScrubEnded() }
                        )
                }
            }
            .frame(height: 10)

            // Use the pre-formatted times directly without animation
            HStack {
                Text(displayTimes.elapsed)
                    .animation(nil)  // Disable animation on the text itself
                Spacer()
                Text(displayTimes.remaining)
                    .animation(nil)  // Disable animation on the text itself
            }
            .font(.system(size: 10))
            .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
    }

    private func progressRatio() -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(max(0, min(currentTime / duration, 1)))
    }
}
