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
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor  // ✅ Tracks media updates

    @State private var isHovering = false

    var body: some View {
        HStack {
            if let track = mediaMonitor.nowPlaying { // ✅ Use mediaMonitor.nowPlaying directly
                playingView(track: track)
                    .transition(.opacity.combined(with: .scale))
            } else {
                idleView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            print("📺 NotchlyMediaPlayer LOADED ✅ Monitoring nowPlaying state...")
        }
        .frame(width: NotchlyConfiguration.large.width * 0.45,
               height: NotchlyConfiguration.large.height * 0.6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.9)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
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
        @State private var isHovering = false

        var body: some View {
            Button(action: { openApp(appURL) }) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: isHovering ? 5 : 2)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
            }
            .buttonStyle(PlainButtonStyle())
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
    private func playingView(track: NowPlayingInfo) -> some View {
        HStack(spacing: 10) {
            albumArtView(track: track)
            trackInfoView(track: track)
            Spacer()
            playbackControls()
        }
        .padding(.horizontal, 12)
    }

    private func albumArtView(track: NowPlayingInfo) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let nsImage = track.artwork {
                Image(nsImage: nsImage) // ✅ Convert NSImage to SwiftUI Image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "music.note") // ✅ Fallback image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white.opacity(0.8))
            }

            // ✅ Show correct app icon in the bottom-right corner
            if let appIcon = getMusicSource(from: track.sourceApp)?.icon {
                Image(appIcon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
                    .offset(x: -4, y: -4)
            }
        }
    }

    private func trackInfoView(track: NowPlayingInfo) -> some View {
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
            playbackButton(systemName: "backward.fill", action: mediaMonitor.previousTrack)
            playbackButton(systemName: "playpause.fill", action: mediaMonitor.togglePlayPause)
            playbackButton(systemName: "forward.fill", action: mediaMonitor.nextTrack)
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

    // MARK: - Helper Function
    private func getMusicSource(from bundleID: String) -> MusicSource? {
        let normalizedBundleID = bundleID.lowercased() // Normalize for safety
        
        if normalizedBundleID.contains("music") { return .appleMusic }
        if normalizedBundleID.contains("spotify") { return .spotify }
        if normalizedBundleID.contains("podcast") { return .podcasts }
        
        return nil // No match
    }
}

// MARK: - Supporting Models
enum MusicSource {
    case appleMusic
    case spotify
    case podcasts

    var icon: String {
        switch self {
        case .appleMusic: return "applemusic"
        case .spotify: return "spotify"
        case .podcasts: return "podcasts"
        }
    }
}

// MARK: - Preview
struct NotchlyMediaPlayer_Previews: PreviewProvider {
    static var previews: some View {
        let mediaMonitor = MediaPlaybackMonitor() // ✅ Create a mock instance

        VStack {
            // Idle State Preview
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor)
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.blue)

            // Playing State Preview
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NotificationCenter.default.post(name: .mockNowPlayingTrack, object: NowPlayingInfo(
                            title: "Dibi Dibi Rek",
                            artist: "Ismaël Lô",
                            album: "Album Placeholder",
                            duration: 200,
                            elapsedTime: 10,
                            isPlaying: true,
                            sourceApp: "com.apple.Music",
                            artwork: nil
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
