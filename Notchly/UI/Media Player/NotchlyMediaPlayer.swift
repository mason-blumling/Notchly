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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                albumArtView(track: track)
                trackInfoView(track: track)
                Spacer()
                playbackControls()
            }
            .padding(.horizontal, 12)

            // Interactive Progress Bar with padding
            VStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        Capsule()
                            .foregroundColor(.white.opacity(0.2))
                            .frame(height: 4)

                        // Progress bar
                        Capsule()
                            .foregroundColor(.white)
                            .frame(width: progressWidth(geometry: geometry, track: track), height: 4)

                        // Draggable indicator
                        Circle()
                            .frame(width: 10, height: 10)
                            .foregroundColor(.white)
                            .offset(x: progressWidth(geometry: geometry, track: track) - 5)
                    }
                    .contentShape(Rectangle()) // Expands clickable area
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            timer?.invalidate()
                            let percentage = max(0, min(1, value.location.x / geometry.size.width))
                            currentElapsedTime = track.duration * percentage
                        }
                        .onEnded { value in
                            let percentage = max(0, min(1, value.location.x / geometry.size.width))
                            currentElapsedTime = track.duration * percentage
                            mediaMonitor.seekTo(time: currentElapsedTime)
                            startTimer(track: track)
                        }
                    )
                }
                .frame(height: 10) // Compact height
                .padding(.horizontal, 12) // Padding on sides

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
            .padding(.bottom, 4) // Aesthetic spacing below
        }
        .onAppear {
            startTimer(track: track)
        }
        .onChange(of: track) { newTrack in
            startTimer(track: newTrack)
        }
        .onDisappear {
            timer?.invalidate()
        }
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
            .frame(height: 14)
        }
        .frame(maxWidth: 110, alignment: .leading)
    }

    private func playbackControls() -> some View {
        HStack(spacing: 12) {
            playbackButton(systemName: "backward.fill") {
                mediaMonitor.previousTrack()
            }
            playbackButton(systemName: "playpause.fill") {
                mediaMonitor.togglePlayPause()
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
                .font(.system(size: 16, weight: .bold))
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
                }
            }
        }
    }
    
    private func progressWidth(geometry: GeometryProxy, track: NowPlayingInfo) -> CGFloat {
        let percentage = track.duration > 0 ? currentElapsedTime / track.duration : 0
        return geometry.size.width * CGFloat(min(max(percentage, 0), 1))
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
