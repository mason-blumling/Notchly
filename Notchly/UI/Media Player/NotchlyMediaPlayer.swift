//
//  NotchlyMediaPlayer.swift
//  Notchly
//
//  Created by Mason Blumling on 2/25/25.
//

import SwiftUI
import AppKit

struct NotchlyMediaPlayer: View {
    private let progressBarHeight: CGFloat = 1.0 // Sleek progress bar height
    var isExpanded: Bool
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    @State private var isHovering = false
    @State private var backgroundGlowColor: Color = .clear
    @State private var glowIntensity: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            if let track = mediaMonitor.nowPlaying {
                albumArtView(track: track)
                    .frame(width: 100) // Fixed width for artwork
                    .padding(.leading, 5)
                VStack(alignment: .leading, spacing: 10) {
                    trackInfoView(track: track)

                    // Playback controls
                    playbackControls()
                        .padding(.top, 8) // Increased spacing between controls and progress bar

                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 3)

                                // Active progress bar
                                Capsule()
                                    .fill(Color.white)
                                    .frame(
                                        width: track.duration > 0 ? max(0, min(CGFloat(mediaMonitor.currentTime / track.duration), 1)) * geometry.size.width : 0,
                                        height: 3
                                    )
                                    .animation(mediaMonitor.isPlaying ? .linear(duration: 0.5) : .none, value: mediaMonitor.currentTime)

                                // Draggable scrubber
                                Circle()
                                    .frame(width: 8, height: 8) // Reduced size of scrubber
                                    .foregroundColor(.white)
                                    .offset(x: CGFloat(mediaMonitor.currentTime / track.duration) * geometry.size.width - 4) // Adjusted offset for new size
                                    .gesture(DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            mediaMonitor.isScrubbing = true // 🔥 Stop automatic updates

                                            let percentage = track.duration > 0 ? max(0, min(1, value.location.x / geometry.size.width)) : 0
                                            mediaMonitor.currentTime = track.duration * percentage
                                        }
                                        .onEnded { _ in
                                            mediaMonitor.isScrubbing = false // 🔥 Resume updates
                                            mediaMonitor.seekTo(time: mediaMonitor.currentTime)

                                            // 🔥 Ensure immediate sync after seeking
                                            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
                                                mediaMonitor.fetchNowPlaying()
                                            }
                                        }
                                    )
                            }
                        }
                        .frame(height: 10)

                        // Time labels
                        HStack {
                            Text(formattedTime(mediaMonitor.currentTime))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)

                            Spacer()

                            Text("-\(formattedTime(track.duration - mediaMonitor.currentTime))")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 12)

                }
                .padding(.horizontal, 12)
            } else {
                idleView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .frame(width: NotchlyConfiguration.large.width * 0.45,
               height: NotchlyConfiguration.large.height + 20) // Extend to bottom of the notch
        .padding(.top, 10)  // Shift the media player down slightly
        .padding(.leading, 20)  // Move the media player slightly to the right
        .background(RoundedRectangle(cornerRadius: 12).fill(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .shadow(radius: 4)
        .onChange(of: mediaMonitor.nowPlaying) { newTrack in
            if let newTrack = newTrack {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // Debounce update
                    mediaMonitor.currentTime = newTrack.elapsedTime
                }
            }
        }
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
    private func albumArtView(track: NowPlayingInfo) -> some View {
        ZStack {
            // Subtle and abstract glow effect only around album artwork
            Circle()
                .fill(backgroundGlowColor.opacity(0.4))
                .frame(width: 100, height: 100) // Increased for larger artwork
                .blur(radius: 20)
                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true))
            
            Button(action: { openAppForTrack(track) }) {
                if let nsImage = track.artwork {
                    // 🎨 Album Art
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100) // Updated to 100x100
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            updateGlowColor(with: nsImage)
                        }
                        .buttonStyle(PlainButtonStyle())
                }
                else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100) // Updated to 100x100
                        .foregroundColor(.white.opacity(0.8))
                        .buttonStyle(PlainButtonStyle())
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Overlay icon indicating the app
            Image("applemusic")
                .resizable()
                .frame(width: 35, height: 35)
                .foregroundColor(.white)
                .padding(5)
                .background(Color.clear)
                .clipShape(Circle())
                .offset(x: 40, y: 40) // Positioning the overlay icon
        }
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowIntensity)
    }

    private func openAppForTrack(_ track: NowPlayingInfo) {
        let appURL: String

        if mediaMonitor.activePlayer == "Spotify" {
            appURL = "spotify://"
        } else {
            appURL = "music://"
        }

        if let url = URL(string: appURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func trackInfoView(track: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) { // Adjusted spacing
            MarqueeText(
                text: track.title,
                font: .system(size: 16, weight: .bold), // Increased font size for title
                color: .white,
                fadeWidth: 50,       // Adjust fade width as needed
                animationSpeed: 6.0, // Adjust scrolling speed as desired
                pauseDuration: 0.5   // Pause before fade out starts
            )
            .id(track.title)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading) // Adjust as needed for your layout
    }

    private func playbackControls() -> some View {
        HStack(spacing: 32) { // Improved spacing for better alignment
            playbackButton(systemName: "backward.fill") {
                mediaMonitor.previousTrack()
                restartTimerAfterSkip()
            }
            playbackButton(systemName: mediaMonitor.isPlaying ? "pause.fill" : "play.fill") {
                mediaMonitor.togglePlayPause()
                restartTimerAfterSkip()
            }
            playbackButton(systemName: "forward.fill") {
                mediaMonitor.nextTrack()
                restartTimerAfterSkip()
            }
        }
        .font(.system(size: 20, weight: .bold)) // Increased button size for sharper look
        .frame(maxWidth: .infinity, alignment: .center) // Center-align playback controls
    }

    private func restartTimerAfterSkip() {
        if let track = mediaMonitor.nowPlaying {
            mediaMonitor.currentTime = track.elapsedTime
        }
    }

    private func playbackButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white.opacity(0.8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updateGlowColor(with image: NSImage?) {
        guard image != nil else {
            backgroundGlowColor = Color.gray.opacity(0.2) // Default subtle color
            return
        }
        // Extract dominant color from the image (improve logic later)
        backgroundGlowColor = Color.red.opacity(0.8) // Placeholder for now
    }
}

// MARK: - Preview
struct NotchlyMediaPlayer_Previews: PreviewProvider {
    static var previews: some View {
        let mediaMonitor = MediaPlaybackMonitor.shared // ✅ Create a mock instance

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
                            artwork: nil,
                            appName: ""
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
