//
//  PodcastsFallbackView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

struct PodcastsFallbackView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image("podcasts-Universal") // Ensure your asset catalog contains this image for podcasts.
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
            Text("Podcasts Now Playing Not Supported")
                .font(.headline)
                .foregroundColor(.white)
            Text("The Podcasts app doesn't currently support now playing controls.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Constants.Podcasts.bundleID).first {
                    app.terminate()
                }
            }) {
                Text("Close Podcasts")
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red))
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
    }
}

struct PodcastsFallbackView_Previews: PreviewProvider {
    static var previews: some View {
        PodcastsFallbackView()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.blue)
    }
}
