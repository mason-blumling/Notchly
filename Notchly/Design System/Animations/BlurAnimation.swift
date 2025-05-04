//
//  BlurAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import SwiftUI

// MARK: - Blur Modifier

/// `BlurModifier` applies a dynamic blur effect during transitions.
/// It adjusts the blur radius and opacity based on the transition state.
private struct BlurModifier: ViewModifier {
    
    /// Determines if the transition is in the active (blurring) or identity (normal) state.
    let isIdentity: Bool
    
    /// The intensity of the blur effect.
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: isIdentity ? intensity : 0) /// Apply blur only when active
            .opacity(isIdentity ? 0 : 1) /// Fade in/out based on transition state
    }
}

// MARK: - Blur Transition Extension

/// Custom transition that applies a blur effect when appearing or disappearing.
extension AnyTransition {
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(isIdentity: true, intensity: 5),    /// Apply blur when transitioning
            identity: BlurModifier(isIdentity: false, intensity: 5)  /// Remove blur when fully visible
        )
    }
}
