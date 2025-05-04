//
//  NotchlyViewModel+Configuration.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import Foundation

extension NotchlyViewModel {
    
    /// Updates configuration observation to support intro state
    func setupIntroStateObservation() {
        // This replaces the existing setupStateObservation method
        $state
            .combineLatest($ignoreHoverOnboarding)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, isOnboarding in
                guard let self = self else { return }
                
                let newConfig: NotchlyConfiguration
                
                // Special case: if we're in expanded state during onboarding, use intro config
                if state == .expanded && isOnboarding {
                    newConfig = .intro
                } else {
                    // Normal state mapping
                    switch state {
                    case .expanded:
                        newConfig = .large
                    case .mediaActivity, .calendarActivity:
                        newConfig = .activity
                    case .collapsed:
                        newConfig = .default
                    }
                }
                
                withAnimation(self.animation) {
                    self.configuration = newConfig
                }
            }
            .store(in: &subscriptions)
    }
}
