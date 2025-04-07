//
//  MediaControlsView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI

/// Displays media playback controls (previous, play/pause, next).
/// Accepts action closures for all buttons and reflects current play state.
struct MediaControlsView: View {
    var isPlaying: Bool
    var onPrevious: () -> Void
    var onPlayPause: () -> Void
    var onNext: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            controlButton(systemName: "backward.fill", action: onPrevious)
            controlButton(systemName: isPlaying ? "pause.fill" : "play.fill", action: onPlayPause)
            controlButton(systemName: "forward.fill", action: onNext)
        }
        .font(.system(size: 20, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(.white.opacity(0.8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct MediaControlsView_Previews: PreviewProvider {
    static var previews: some View {
        MediaControlsView(
            isPlaying: true,
            onPrevious: {},
            onPlayPause: {},
            onNext: {}
        )
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
