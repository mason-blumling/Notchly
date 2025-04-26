//
//  NotchlyTransitionCoordinator.swift
//  Notchly
//
//  Created by Mason Blumling on 4/24/25.
//

import SwiftUI
import Combine

/// Central manager for handling notch shape transitions and content layout.
/// Moves all resizing and animation logic into one place for scalability.
@MainActor
final class NotchlyTransitionCoordinator: ObservableObject {
    /// Shared instance for global access.
    static let shared = NotchlyTransitionCoordinator()

    /// Possible states for the notch
    enum NotchState {
        /// Fully collapsed (default)
        case collapsed
        /// Expanded by hover or onboarding
        case expanded
        /// Showing media activity slot
        case mediaActivity
        /// Showing calendar live activity slot
        case calendarActivity
    }

    /// Current high-level notch state.
    @Published var state: NotchState = .collapsed
    /// Published shape configuration driven by the current state.
    @Published private(set) var configuration: NotchlyConfiguration = .default

    /// Subscriptions for Combine pipelines.
    private var subscriptions = Set<AnyCancellable>()

    /// The unified animation used for shape morphs.
    var animation: Animation {
        if #available(macOS 14.0, *) {
            return Animation.spring(.bouncy(duration: 0.4))
        } else {
            return Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    private init() {
        // Map state changes to configuration presets
        $state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self = self else { return }
                let newConfig: NotchlyConfiguration
                switch newState {
                case .expanded:
                    newConfig = .large
                case .mediaActivity, .calendarActivity:
                    newConfig = .activity
                case .collapsed:
                    newConfig = .default
                }
                withAnimation(self.animation) {
                    self.configuration = newConfig
                }
            }
            .store(in: &subscriptions)
    }

    /// Convenience method to update based on all state inputs.
    func update(expanded: Bool, mediaActive: Bool, calendarActive: Bool) {
        let newState: NotchState
        if expanded {
            newState = .expanded
        } else if calendarActive {
            newState = .calendarActivity
        } else if mediaActive {
            newState = .mediaActivity
        } else {
            newState = .collapsed
        }
        state = newState
    }
}
