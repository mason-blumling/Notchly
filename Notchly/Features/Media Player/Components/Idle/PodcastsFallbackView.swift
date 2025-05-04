//
//  PodcastsFallbackView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

/// A fallback view for Podcasts when now-playing controls are not supported.
/// It informs the user that the Podcasts app does not support now-playing functionality
/// and provides a button to close the Podcasts app.
struct PodcastsFallbackView: View {
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 10) {
            /// Podcasts icon.
            Image("podcasts-Universal")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            
            /// Headline text.
            Text("Podcasts Now Playing Not Supported")
                .font(.headline)
                .foregroundColor(.white)
            
            /// Descriptive text.
            Text("The Podcasts app doesn't currently support now playing controls.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            /// Close button.
            Button(action: {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Constants.Podcasts.bundleID).first {
                    app.terminate()
                }
            }) {
                Text("Close Podcasts")
                    .font(.body)
                    /// Adjust padding to ensure the button doesn't become too large.
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                    )
                    .foregroundColor(.white)
            }
            /// Use PlainButtonStyle to eliminate extra styling.
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            /// Background container with rounded corners and semi-transparent black fill.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
    }
}

// MARK: - Preview

struct PodcastsFallbackView_Previews: PreviewProvider {
    static var previews: some View {
        PodcastsFallbackView()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.blue)
    }
}
