//
//  TrackInfoView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI

// MARK: - TrackInfoView

/// Displays the track title and artist name.
/// Title uses a marquee animation for long text.
struct TrackInfoView: View {
    let track: NowPlayingInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            /// Marquee title
            MarqueeText(
                text: track.title,
                font: .system(size: 16, weight: .bold),
                color: .white,
                fadeWidth: 50,
                animationSpeed: 6.0,
                pauseDuration: 0.5
            )
            .id(track.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            /// Artist label
            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

struct TrackInfoView_Previews: PreviewProvider {
    static var previews: some View {
        TrackInfoView(track: NowPlayingInfo(
            title: "Super Long Song Title That Keeps Going",
            artist: "Famous Artist",
            album: "Test Album",
            duration: 180,
            elapsedTime: 60,
            isPlaying: true,
            artwork: nil,
            appName: "Music"
        ))
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
