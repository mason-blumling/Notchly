//
//  LavaLampGlowView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

/// Displays a layered glow effect made of animated blobs.
/// Used behind the media player in expanded state.
struct LavaLampGlowView: View {
    let blobCount: Int = 3         // Number of blobs rendered
    var blobColor: Color           // Base color for all blobs (usually album dominant color)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<blobCount, id: \.self) { _ in
                    BouncingGlowBlob(
                        size: CGFloat.random(in: 10...100),
                        color: blobColor.opacity(Double.random(in: 0.3...0.6)),
                        blurRadius: 15
                    )
                    // Each blob fills the entire glow canvas
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
    }
}

struct LavaLampGlowView_Previews: PreviewProvider {
    static var previews: some View {
        LavaLampGlowView(blobColor: .red)
            .frame(width: 400, height: 400)
    }
}
