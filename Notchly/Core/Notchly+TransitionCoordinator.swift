//
//  Notchly+TransitionCoordinator.swift
//  Notchly
//
//  Created by Mason Blumling on 4/24/25.
//

import SwiftUI
import Combine

/// Central manager for handling notch UI transitions.
/// Manages the current notch state and drives the associated layout configuration.
/// All morphing, expansion, and live activity transitions pass through this coordinator.
@MainActor
final class NotchlyTransitionCoordinator: ObservableObject {
    
    /// Shared singleton for global access.
    static let shared = NotchlyTransitionCoordinator()

    /// Enum representing all visual states of the notch.
    enum NotchState {
        case collapsed         // Default idle state
        case expanded          // Fully expanded, showing main content
        case mediaActivity     // Compact media activity (artwork + bars)
        case calendarActivity  // Compact calendar alert
    }

    /// Current visual state of the notch.
    @Published var state: NotchState = .collapsed

    /// Published shape configuration (width, corner radius, etc.) based on current state.
    @Published private(set) var configuration: NotchlyConfiguration = .default

    /// Internal set of Combine subscriptions.
    private var subscriptions = Set<AnyCancellable>()

    /// Unified animation used for notch transitions.
    var animation: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.4))
        } else {
            return .timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    // MARK: - Init

    private init() {
        /// Sync configuration any timethe state changes
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

    // MARK: - State Updater

    /// Updates the notch state based on hover, media, and calendar input.
    /// Priority: calendar > expanded > media > collapsed
    func update(expanded: Bool, mediaActive: Bool, calendarActive: Bool) {
        let newState: NotchState

        if calendarActive {
            newState = .calendarActivity
        } else if expanded {
            newState = .expanded
        } else if mediaActive {
            newState = .mediaActivity
        } else {
            newState = .collapsed
        }

        withAnimation(animation) {
            state = newState
        }
    }
}
