//
//  BlurAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import SwiftUI

// MARK: - Blur Modifier

/// A view modifier that applies a soft blur and fade-out effect during a transition.
/// Used to visually de-emphasize disappearing content with a smooth "blur away" animation.
private struct BlurModifier: ViewModifier {
    
    /// Indicates if the transition is in the "identity" (fully visible) or "active" (disappearing) phase.
    let isIdentity: Bool

    /// Blur radius to apply during the transition.
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: isIdentity ? intensity : 0)
            .opacity(isIdentity ? 0 : 1) // Fully fade when blurring out
    }
}

// MARK: - Blur Transition

/// A reusable transition that fades and blurs content when it appears/disappears.
/// Useful for live activity alerts and dynamic elements inside the notch.
extension AnyTransition {
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(isIdentity: true, intensity: 5),    // When disappearing
            identity: BlurModifier(isIdentity: false, intensity: 5)  // When fully visible
        )
    }
}
