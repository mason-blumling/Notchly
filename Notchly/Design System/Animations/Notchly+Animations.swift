//
//  NotchlyAnimations.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import SwiftUI

/// A central collection of reusable animation curves, durations, and delay helpers used throughout Notchly.
struct NotchlyAnimations {
    
    // MARK: - Animation Presets

    static let bounce = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let fastBounce = Animation.spring(response: 0.2, dampingFraction: 0.6)
    static let smoothTransition = Animation.easeInOut(duration: 0.3)
    static let quickTransition = Animation.easeInOut(duration: 0.15)
    static let notchExpansion = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let fadeIn = Animation.easeInOut(duration: 0.3)
    static let opacityTransition = Animation.linear(duration: 0.2)
    static let liveActivityTransition = Animation.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.2)
    static let morphAnimation = Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.5)

    // MARK: - Timing Constants

    struct Durations {
        static let bounce = 0.3
        static let fastBounce = 0.2
        static let smooth = 0.3
        static let quick = 0.15
        static let notchExpand = 0.4
        static let fadeIn = 0.3
        static let opacity = 0.2
        static let liveActivityTransition = 0.35
        static let morph = 0.3
    }

    // MARK: - Delay Helpers

    /// Returns a delay following the end of a live activity animation.
    static func delayAfterLiveActivityTransition(_ extra: Double = 0) -> Double {
        Durations.liveActivityTransition + extra
    }

    /// Returns a delay following a notch expansion morph.
    static func delayAfterNotchExpand(_ extra: Double = 0) -> Double {
        Durations.notchExpand + extra
    }

    /// Returns the delay needed before fading in content after an expansion.
    static func delayForContentFadeIn(afterNotchExpand: Bool = true) -> Double {
        (afterNotchExpand ? Durations.notchExpand : 0) + Durations.fadeIn
    }

    /// Looks up an animation based on a semantic key.
    static func animation(for identifier: String) -> Animation {
        switch identifier {
        case "fade": return fadeIn
        case "quick": return quickTransition
        case "bounce": return bounce
        case "morph": return morphAnimation
        default: return smoothTransition
        }
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    /// A morphing transition that scales slightly in/out with a soft opacity fade.
    static var morphingTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.85, anchor: .center)
                .combined(with: .opacity),
            removal: .scale(scale: 1.15, anchor: .center)
                .combined(with: .opacity)
        )
    }
}
