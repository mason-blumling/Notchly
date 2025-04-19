//
//  MediaPlayerLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

/// Displays a compact media live activity: album art on the left, animated audio bars on the right.
/// Used when the notch is in the "activity" state while media is playing.
struct MediaPlayerLiveActivityView: View {
    /// Optional album artwork passed from the media monitor.
    var albumArt: NSImage?

    var body: some View {
        LiveActivityView(
            leftContent: {
                // Show album artwork if available, else fallback to placeholder.
                if let albumArt = albumArt, albumArt.size != NSZeroSize {
                    Image(nsImage: albumArt)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image("music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            },
            rightContent: {
                // Animated waveform for audio playback.
                AudioBarsView()
                    .scaleEffect(1.0, anchor: .trailing)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 1.1, anchor: .trailing).combined(with: .opacity)
                    ))
            }
        )
    }
}

struct MediaPlayerLiveActivityView_Previews: PreviewProvider {
    static var previews: some View {
        MediaPlayerLiveActivityView(albumArt: nil)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
