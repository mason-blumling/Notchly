//
//  LavaLampGlowView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

struct GlowBlob: Identifiable {
    let id = UUID()
    let size: CGFloat
    let opacity: Double
}

struct LavaLampGlowView: View {
    let blobCount: Int = 3
    var blobColor: Color

    @State private var blobs: [GlowBlob] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                blobs = []
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
