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
    @ObservedObject var mediaMonitor: MediaPlaybackMonitor
    @State private var currentElapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isHovering = false
    @State private var backgroundGlowColor: Color = .clear
    @State private var glowIntensity: CGFloat = 1.0

    var body: some View {
        HStack {
            if let track = mediaMonitor.nowPlaying {
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
               height: NotchlyConfiguration.large.height)
        .background(RoundedRectangle(cornerRadius: 12).fill(.clear))
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                albumArtView(track: track)
                    .padding(.leading, 5) // Shift artwork slightly left
                trackInfoView(track: track)
                Spacer()
                playbackControls()
            }
            .padding(.horizontal, 12)

            // Interactive Progress Bar with padding
            Slider(value: Binding(
                get: { currentElapsedTime },
                set: { newValue in
                    currentElapsedTime = newValue
                    mediaMonitor.seekTo(time: currentElapsedTime)
                }
            ), in: 0...track.duration)
            .tint(Color.white) // Ensures a bright, pure white color
            .frame(height: 2) // Modern and minimal thickness
            .padding(.horizontal, 12)

            // Time Labels
            HStack {
                Text(formattedTime(currentElapsedTime))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)

                Spacer()

                Text("-\(formattedTime(track.duration - currentElapsedTime))")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            startTimer(track: track)
        }
        .onChange(of: track) { newTrack in
            startTimer(track: newTrack)
            updateGlowColor(with: newTrack.artwork)
        }
        .onDisappear {
            timer?.invalidate()
            glowIntensity = 1.0 // Reset glow intensity
        }
    }

    private func albumArtView(track: NowPlayingInfo) -> some View {
        ZStack {
            // Refined glow effect only around album artwork
            Circle()
                .fill(backgroundGlowColor.opacity(0.4))
                .frame(width: 85, height: 85) // Adjusted for larger artwork
                .blur(radius: 20)
                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true))
            
            Button(action: { openAppForTrack(track) }) {
                if let nsImage = track.artwork {
                    // 🎨 Album Art
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 65, height: 65) // Updated to 65x65
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onAppear {
                            updateGlowColor(with: nsImage)
                        }
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 65, height: 65) // Updated to 65x65
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Overlay icon indicating the app
            Image(systemName: mediaMonitor.activePlayer == "Spotify" ? "spotify.logo" : "music.note")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
                .padding(5)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .offset(x: 30, y: 30) // Positioning the overlay icon
        }
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowIntensity)
    }

    private func openAppForTrack(_ track: NowPlayingInfo) {
        // Determine the active media player and open its URL scheme
        let appURLString: String
        if mediaMonitor.activePlayer == "Spotify" {
            appURLString = "spotify://"
        } else if mediaMonitor.activePlayer == "Apple Music" {
            appURLString = "music://"
        } else {
            appURLString = "music://"
        }
        if let url = URL(string: appURLString) {
            NSWorkspace.shared.open(url)
        }
    }

    private func trackInfoView(track: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MarqueeText(
                text: track.title,
                font: .system(size: 14, weight: .bold),
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
        .frame(maxWidth: 150, alignment: .leading) // Adjust as needed for your layout
    }

    private func playbackControls() -> some View {
        HStack(spacing: 16) { // Adjusted spacing for better alignment
            playbackButton(systemName: "backward.fill") {
                mediaMonitor.previousTrack()
            }
            playbackButton(systemName: mediaMonitor.isPlaying ? "pause.fill" : "play.fill") {
                mediaMonitor.togglePlayPause()
            }
            .onChange(of: mediaMonitor.isPlaying) { _ in
                withAnimation(.easeInOut(duration: 0.1)) {}
            }
            playbackButton(systemName: "forward.fill") {
                mediaMonitor.nextTrack()
            }
        }
    }

    private func playbackButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 15, weight: .bold)) // Increased button size to 20pt
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func startTimer(track: NowPlayingInfo) {
        timer?.invalidate()
        currentElapsedTime = track.elapsedTime

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if mediaMonitor.isPlaying {
                if currentElapsedTime < track.duration {
                    currentElapsedTime += 1
                } else {
                    currentElapsedTime = track.duration
                    glowIntensity = 1.0 // Reset glow intensity when track ends
                }
            }
        }
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
        let mediaMonitor = MediaPlaybackMonitor() // ✅ Create a mock instance

        VStack {
            // Idle State Preview
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor!)
                .previewLayout(.sizeThatFits)
                .padding()
                .background(Color.blue)

            // Playing State Preview
            NotchlyMediaPlayer(isExpanded: true, mediaMonitor: mediaMonitor!)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NotificationCenter.default.post(name: .mockNowPlayingTrack, object: NowPlayingInfo(
                            title: "Dibi Dibi Rek",
                            artist: "Ismaël Lô",
                            album: "Album Placeholder",
                            duration: 200,
                            elapsedTime: 10,
                            isPlaying: true,
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
