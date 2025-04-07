//
//  ArtworkContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

struct ArtworkContainerView: View {
    var track: NowPlayingInfo
    var isExpanded: Bool = false
    var action: (() -> Void)? = nil
    @Binding var backgroundGlowColor: Color
    var glowIntensity: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background animated glow blobs
            LavaLampGlowView(blobColor: backgroundGlowColor)
                .frame(width: NotchlyConfiguration.large.width * 0.55,
                       height: NotchlyConfiguration.large.height - 10)
                .opacity(0.5)

            // Main artwork
            ArtworkView(
                artwork: track.artwork,
                isExpanded: isExpanded,
                action: action
            )
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear {
                updateGlowColor(with: track.artwork)
            }
            .onChange(of: track.artwork) { _, newValue in
                updateGlowColor(with: newValue)
            }

            // App logo overlay
            let logoName = (track.appName.lowercased() == "spotify") ? "spotify-Universal" : "appleMusic-Universal"
            Image(logoName)
                .resizable()
                .frame(width: 40, height: 40)
                .padding(5)
                .background(Color.clear)
                .clipShape(Circle())
                .offset(x: 40, y: 40)
                .foregroundColor(.white)
        }
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowIntensity)
    }

    private func updateGlowColor(with image: NSImage?) {
        if let image = image,
           let dominant = image.dominantColor(),
           let vibrant = dominant.vibrantColor() {
            backgroundGlowColor = Color(nsColor: vibrant)
        } else {
            backgroundGlowColor = Color.gray.opacity(0.2)
        }
    }
}

struct ArtworkContainerView_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkContainerView(
            track: NowPlayingInfo(
                title: "Sample Track",
                artist: "Sample Artist",
                album: "Sample Album",
                duration: 180,
                elapsedTime: 30,
                isPlaying: true,
                artwork: NSImage(named: "SampleArtwork"),
                appName: "Music"
            ),
            isExpanded: true,
            action: { print("Tapped artwork") },
            backgroundGlowColor: .constant(.blue)
        )
        .frame(width: 200, height: 200)
        .previewLayout(.sizeThatFits)
    }
}
