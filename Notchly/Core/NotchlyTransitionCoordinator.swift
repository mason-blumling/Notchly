//
//  NotchlyTransitionCoordinator.swift
//  Notchly
//
//  Created by Mason Blumling on 4/24/25.
//

import SwiftUI

/// Central manager for handling notch shape transitions and content layout.
/// Moves all resizing and animation logic into one place for scalability.
@MainActor
final class NotchlyTransitionCoordinator: ObservableObject {
    /// Shared instance for global access.
    static let shared = NotchlyTransitionCoordinator()

    /// Published configuration to drive shape size and content clipping.
    @Published private(set) var configuration: NotchlyConfiguration = .default
    
    /// The animation that all transitions should use.
    var animation: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    private init() {}
    
    /// Transition to a new notch configuration with unified animation.
    func transition(to newConfig: NotchlyConfiguration) {
        withAnimation(animation) {
            configuration = newConfig
        }
    }

    /// Determine the target configuration based on state flags.
    func targetConfiguration(expanded: Bool, mediaActive: Bool, calendarActive: Bool) -> NotchlyConfiguration {
        if expanded {
            return .large
        }
        if calendarActive || mediaActive {
            return .activity
        }
        return .default
    }

    /// Convenience method to update based on all state inputs.
    func update(expanded: Bool, mediaActive: Bool, calendarActive: Bool) {
        let newConfig = targetConfiguration(expanded: expanded, mediaActive: mediaActive, calendarActive: calendarActive)
        transition(to: newConfig)
    }
}
