//
//  NotchlyAnimations.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import SwiftUI

/// A collection of reusable animations for Notchly.
struct NotchlyAnimations {
    
    /// Standard bounce animation for UI interactions.
    static let bounce = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Faster bounce animation for quick interactions.
    static let fastBounce = Animation.spring(response: 0.2, dampingFraction: 0.6)

    /// Smooth ease-in-out transition animation.
    static let smoothTransition = Animation.easeInOut(duration: 0.3)

    /// Slightly faster ease-in-out transition.
    static let quickTransition = Animation.easeInOut(duration: 0.15)

    /// Expansion animation for the notch when hovered.
    static let notchExpansion = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Fade-in animation for UI elements appearing.
    static let fadeIn = Animation.easeInOut(duration: 0.3)

    /// Opacity animation for fading in/out UI elements.
    static let opacityTransition = Animation.linear(duration: 0.2)
}
