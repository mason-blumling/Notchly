//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 2/25/25.
//

import SwiftUI
import AppKit

struct NotchlyMediaPlayer: View {
    var isExpanded: Bool
    @State private var nowPlaying: NowPlayingTrack? = nil // No track playing initially
    @State private var isHovering = false

    var body: some View {
        HStack {
            if let track = nowPlaying {
                playingView(track: track)
                    .transition(.opacity.combined(with: .scale))
            } else {
                idleView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: NotchlyConfiguration.large.width * 0.45,
               height: NotchlyConfiguration.large.height * 0.6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.9)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: isExpanded)
        .shadow(radius: 4)
    }
    
    // MARK: - Idle State
    private func idleView() -> some View {
        VStack(spacing: 10) {
            Text("No app seems to be running")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Wanna open one?")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray.opacity(0.7))
            
            HStack(spacing: 20) {
                AppIconButton(icon: "applemusic", appURL: "music://")
                AppIconButton(icon: "spotify", appURL: "spotify://")
                AppIconButton(icon: "podcasts", appURL: "podcasts://")
            }
        }
        .padding(.top, 10)
    }
    
    struct AppIconButton: View {
        let icon: String
        let appURL: String
        @State private var isHovering = false // 🔥 Local hover state

        var body: some View {
            Button(action: { openApp(appURL) }) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: isHovering ? 5 : 2) // 🔥 Dynamic shadow effect
                    .scaleEffect(isHovering ? 1.1 : 1.0) // 🔥 Slight zoom on hover
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
            }
            .buttonStyle(PlainButtonStyle()) // Removes default button styling
            .onHover { hovering in
                isHovering = hovering
            }
        }

        private func openApp(_ url: String) {
            if let appURL = URL(string: url) {
                NSWorkspace.shared.open(appURL)
            }
        }
    }
    
    // MARK: - Playing State
    private func playingView(track: NowPlayingTrack) -> some View {
        HStack(spacing: 10) {
            albumArtView(track: track)
            trackInfoView(track: track)
            Spacer()
            playbackControls()
        }
        .padding(.horizontal, 12)
    }

    private func albumArtView(track: NowPlayingTrack) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(track.albumArt)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Image(track.source.icon)
                .resizable()
                .frame(width: 18, height: 18)
                .clipShape(Circle())
                .offset(x: -4, y: -4)
        }
    }

    private func trackInfoView(track: NowPlayingTrack) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: 110, alignment: .leading)
    }

    private func playbackControls() -> some View {
        HStack(spacing: 12) {
            playbackButton(systemName: "backward.fill", action: previousTrack)
            playbackButton(systemName: "playpause.fill", action: togglePlayPause)
            playbackButton(systemName: "forward.fill", action: nextTrack)
        }
    }

    private func playbackButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16, weight: .bold))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - App Opening & Playback Actions
    private func openApp(_ url: String) {
        if let appURL = URL(string: url) {
            NSWorkspace.shared.open(appURL)
        }
    }

    private func previousTrack() { print("⏮ Previous track") }
    private func togglePlayPause() { print("⏯ Play/Pause track") }
    private func nextTrack() { print("⏭ Next track") }
}

// MARK: - Supporting Models
struct NowPlayingTrack {
    var title: String
    var artist: String
    var albumArt: String
    var source: MusicSource
}

enum MusicSource {
    case appleMusic
    case spotify
    case podcasts

    var icon: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .podcasts: return "Podcasts"
        }
    }
}

// MARK: - Preview
struct NotchlyMediaPlayer_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Idle State Preview
            NotchlyMediaPlayer(isExpanded: true)
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.blue)

            // Playing State Preview
            NotchlyMediaPlayer(isExpanded: true)
                .onAppear {
                    // Simulating a playing track for the preview
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NotificationCenter.default.post(name: .mockNowPlayingTrack, object: NowPlayingTrack(
                            title: "Dibi Dibi Rek",
                            artist: "Ismaël Lô",
                            albumArt: "album_art_placeholder",
                            source: .appleMusic
                        ))
                    }
                }
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.blue)
        }
    }
}

// MARK: - Mock Notification for Testing
extension Notification.Name {
    static let mockNowPlayingTrack = Notification.Name("mockNowPlayingTrack")
}
