//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 2/25/25.
//

import SwiftUI
import AppKit

/// A SwiftUI view that displays a media player for macOS using the MacBook notch area.
/// It presents either an idle view (if no media is playing) or a detailed media player UI
/// (with album art, track info, a scrubber, and playback controls).
struct NotchlyMediaPlayer: View {
    // MARK: - Properties
    private let progressBarHeight: CGFloat = 1.0 // Sleek progress bar height
    var isExpanded: Bool
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    
    // Local state for hover effects and background glow.
    @State private var isHovering = false
    @State private var backgroundGlowColor: Color = .clear
    @State private var glowIntensity: CGFloat = 1.0
    
    /// Computed property to determine whether we have a valid duration (i.e. >1s).
    private var hasValidDuration: Bool {
        mediaMonitor.duration > 1.0
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            // If the active player is Podcasts, show a fallback view.
            if mediaMonitor.activePlayerName.lowercased() == "podcasts" {
                PodcastsFallbackView()
                    .frame(width: NotchlyConfiguration.large.width * 0.45,
                           height: NotchlyConfiguration.large.height + 20)
            } else {
                if let track = mediaMonitor.nowPlaying {
                    // Display album artwork and track info.
                    albumArtView(track: track)
                        .frame(width: 100)
                        .padding(.leading, 5)
                    VStack(alignment: .leading, spacing: 10) {
                        trackInfoView(track: track)
                        
                        // Playback controls (play, pause, next, previous).
                        playbackControls()
                            .padding(.top, 8)
                        
                        // Scrubber and time labels.
                        VStack(spacing: 4) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track.
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 3)
                                    
                                    // Active progress bar.
                                    Capsule()
                                        .fill(Color.white)
                                        .frame(
                                            width: track.duration > 0
                                                ? max(0, min(mediaMonitor.currentTime / track.duration, 1)) * geometry.size.width
                                                : 0,
                                            height: 3
                                        )
                                        .animation(
                                            mediaMonitor.isPlaying ? .linear(duration: 0.5) : .none,
                                            value: mediaMonitor.currentTime
                                        )
                                    
                                    // Draggable scrubber.
                                    Circle()
                                        .frame(width: 8, height: 8)
                                        .foregroundColor(.white)
                                        .offset(x: CGFloat(mediaMonitor.currentTime / track.duration) * geometry.size.width - 4)
                                        .gesture(DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                // Lock currentTime to user input while scrubbing.
                                                mediaMonitor.isScrubbing = true
                                                let percentage = track.duration > 0
                                                    ? max(0, min(1, value.location.x / geometry.size.width))
                                                    : 0
                                                mediaMonitor.currentTime = track.duration * percentage
                                            }
                                            .onEnded { _ in
                                                mediaMonitor.isScrubbing = false
                                                let monitor = mediaMonitor // Capture locally.
                                                monitor.seekTo(time: monitor.currentTime)
                                                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                                                    Task { await monitor.updateMediaState() }
                                                }
                                            }
                                        )
                                }
                            }
                            .frame(height: 10)
                            
                            // Time labels computed directly from mediaMonitor.currentTime.
                            HStack {
                                if hasValidDuration {
                                    Text(formattedTime(mediaMonitor.currentTime))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("-\(formattedTime(max(0, track.duration - mediaMonitor.currentTime)))")
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
                    .padding(.horizontal, 12)
                } else {
                    // Idle view if no media is playing.
                    idleView()
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .frame(width: NotchlyConfiguration.large.width * 0.45,
               height: NotchlyConfiguration.large.height + 20)
        .padding(.top, 10)
        .padding(.leading, 20)
        .background(RoundedRectangle(cornerRadius: 12).fill(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .shadow(radius: 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("🛠 Manually triggering updateMediaState() from NotchlyMediaPlayer")
                mediaMonitor.updateMediaState()
            }
        }
    }
    
    // MARK: - Idle View
    private func idleView() -> some View {
        VStack(spacing: 10) {
            Text("No app seems to be running")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            Text("Wanna open one?")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray.opacity(0.7))
            HStack(spacing: 20) {
                AppIconButton(icon: "appleMusic-Universal", appURL: "music://")
                AppIconButton(icon: "spotify-Universal", appURL: "spotify://")
                AppIconButton(icon: "podcasts-Universal", appURL: "podcasts://")
            }
        }
        .padding(.top, 10)
    }
    
    // MARK: - App Icon Button
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
    
    // MARK: - Album Art and Glow
    private func albumArtView(track: NowPlayingInfo) -> some View {
        ZStack {
            Circle()
                .fill(backgroundGlowColor.opacity(0.4))
                .frame(width: 100, height: 100)
                .blur(radius: 20)
                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowIntensity)
            
            Button(action: { openAppForTrack(track) }) {
                if let nsImage = track.artwork {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            updateGlowColor(with: nsImage)
                        }
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .buttonStyle(PlainButtonStyle())

            /// Determine the logo based on the active player.
            let logoName = (mediaMonitor.activePlayerName.lowercased() == "spotify") ? "spotify-Universal" : "appleMusic-Universal"
            Image(logoName)
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.white)
                .padding(5)
                .background(Color.clear)
                .clipShape(Circle())
                .offset(x: 40, y: 40)
        }
    }
    
    private func openAppForTrack(_ track: NowPlayingInfo) {
        let appURL: String = (mediaMonitor.activePlayerName.lowercased() == "spotify") ? "spotify://" : ((mediaMonitor.activePlayerName.lowercased() == "podcasts") ? "podcasts://" : "music://")
        if let url = URL(string: appURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Track Info
    private func trackInfoView(track: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
            
            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Playback Controls
    private func playbackControls() -> some View {
        HStack(spacing: 32) {
            playbackButton(systemName: "backward.fill") {
                mediaMonitor.previousTrack()
            }
            playbackButton(systemName: mediaMonitor.isPlaying ? "pause.fill" : "play.fill") {
                mediaMonitor.togglePlayPause()
            }
            playbackButton(systemName: "forward.fill") {
                mediaMonitor.nextTrack()
            }
        }
        .font(.system(size: 20, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    /// A helper to generate a playback button.
    private func playbackButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white.opacity(0.8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Time Formatting
    /// Formats a TimeInterval (in seconds) into a string "M:SS".
    private func formattedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Glow Color Update
    /// Updates the background glow color extracted from the album artwork.
    private func updateGlowColor(with image: NSImage?) {
        guard image != nil else {
            backgroundGlowColor = Color.gray.opacity(0.2)
            return
        }
        // TODO: Replace with actual color extraction logic.
        backgroundGlowColor = Color.red.opacity(0.8)
    }
}

// MARK: - Preview
struct NotchlyMediaPlayer_Previews: PreviewProvider {
    static var previews: some View {
        let mediaMonitor = MediaPlaybackMonitor.shared
        VStack {
            // Idle state preview.
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor)
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.blue)
            
            // Playing state preview with a mock notification.
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NotificationCenter.default.post(
                            name: .mockNowPlayingTrack,
                            object: NowPlayingInfo(
                                title: "Dibi Dibi Rek",
                                artist: "Ismaël Lô",
                                album: "Album Placeholder",
                                duration: 200,
                                elapsedTime: 10,
                                isPlaying: true,
                                artwork: nil,
                                appName: ""
                            )
                        )
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
