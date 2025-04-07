//
//  ArtworkView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/6/25.
//

import SwiftUI
import AppKit

// MARK: - Conditional Modifier Extension
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool,
                                          transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - ArtworkView
/// Displays the album artwork for the media player.
/// - If a valid artwork is provided, it displays that image with a resizable fill mode.
/// - Otherwise, it falls back to a placeholder image ("music.note").
/// - When `isExpanded` is true and an `action` is provided, the view is wrapped in a Button to allow tap interaction.
struct ArtworkView: View {
    var artwork: NSImage?
    var isExpanded: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        Group {
            if let image = artwork, image.size != NSZeroSize {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image("music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
        .if(isExpanded && action != nil) { view in
            Button(action: { action?() }) {
                view
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ArtworkView_Previews: PreviewProvider {
    static var previews: some View {
        ArtworkView(artwork: NSImage(named: "SampleArtwork"), isExpanded: true, action: {
            print("Artwork tapped")
        })
        .frame(width: 100, height: 100)
        .previewLayout(.sizeThatFits)
    }
}
