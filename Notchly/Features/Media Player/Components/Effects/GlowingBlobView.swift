//
//  GlowingBlobView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

// MARK: - Model

/// Represents a single glow blob with randomized size and opacity.
struct GlowBlob: Identifiable {
    let id = UUID()
    let size: CGFloat
    let opacity: Double
}

// MARK: - Glowing Blobs View

/// Creates a soothing, animated "lava lamp" glow effect using bouncing blobs.
/// Used as a background visual for the expanded media player state.
struct GlowingBlobView: View {
    let blobCount: Int = 3         /// Number of animated blobs
    var blobColor: Color           /// Base color for all blobs

    @State private var blobs: [GlowBlob] = [] /// Storage for randomized blob instances

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                /// Render each bouncing glow blob inside the container
                ForEach(blobs) { blob in
                    BouncingGlowBlob(
                        size: blob.size,
                        color: blobColor.opacity(blob.opacity),
                        blurRadius: 15
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .onAppear {
                /// Initialize blobs on first appearance
                if blobs.isEmpty {
                    blobs = (0..<blobCount).map { _ in
                        GlowBlob(
                            size: CGFloat.random(in: 10...100),
                            opacity: Double.random(in: 0.3...0.6)
                        )
                    }
                }
            }
            .onDisappear {
                /// Clear blobs to stop animation and deallocate memory
                blobs = []
            }
        }
    }
}

// MARK: - Preview

struct LavaLampGlowView_Previews: PreviewProvider {
    static var previews: some View {
        GlowingBlobView(blobColor: .red)
            .frame(width: 400, height: 400)
    }
}
