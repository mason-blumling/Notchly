//
//  MediaPlayerIdleView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

// MARK: - MediaPlayerIdleView
/// A view shown when no media is currently playing.
/// Encourages users to launch a supported app like Music, Spotify, or Podcasts.
struct MediaPlayerIdleView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("No media app is running...")
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
}

// MARK: - AppIconButton
/// A tappable icon that launches a media app using a custom URL scheme.
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

    /// Opens the associated app using its URL scheme.
    private func openApp(_ url: String) {
        if let appURL = URL(string: url) {
            NSWorkspace.shared.open(appURL)
        }
    }
}

// MARK: - Preview

struct MediaPlayerIdleView_Previews: PreviewProvider {
    static var previews: some View {
        MediaPlayerIdleView()
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
