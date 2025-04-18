//
//  MediaPlayerLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

// MARK: - MediaPlayerLiveActivityView: Combines album art and animated audio bars.
struct MediaPlayerLiveActivityView: View {
    /// Optional album artwork passed from the media monitor.
    var albumArt: NSImage?

    var body: some View {
        LiveActivityView(
            leftContent: {
                // If album artwork is available and valid, show it; otherwise, fallback to a placeholder.
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
                // Audio bars animation.
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
