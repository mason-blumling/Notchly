//
//  RenderSafeView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import SwiftUI

/// A view wrapper that stabilizes rendering for GPU-heavy effects like blur + mask.
struct RenderSafeView<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        content()
            .compositingGroup() // Creates a layer
            .drawingGroup(opaque: false, colorMode: .linear)
    }
}
