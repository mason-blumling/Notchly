//
//  NotchlyViewModel+Intro.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import Foundation
import SwiftUI

extension NotchlyViewModel {
    
    /// UserDefaults key for tracking if intro has been shown
    private static let hasShownIntroKey = "com.notchly.hasShownIntro"
    
    // MARK: - Intro State
    
    /// Checks if this is the first launch (intro not shown yet)
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: NotchlyViewModel.hasShownIntroKey)
    }
    
    /// Marks the intro as completed
    func completeIntro() {
        UserDefaults.standard.set(true, forKey: NotchlyViewModel.hasShownIntroKey)
        
        // Transition to normal collapsed state
        withAnimation(animation) {
            state = .collapsed
            ignoreHoverOnboarding = false  // Re-enable hover interaction
        }
    }
    
    /// Shows the intro experience
    func showIntro() {
        // Temporarily ignore hover during intro
        ignoreHoverOnboarding = true
        
        // Update to intro configuration
        withAnimation(animation) {
            state = .expanded  // Use expanded state but with intro config
        }
    }
}

// MARK: - State Extensions

extension NotchlyViewModel.NotchState {
    /// Check if this is an intro state
    var isIntro: Bool {
        // We'll treat .expanded as intro when ignoreHoverOnboarding is true
        return self == .expanded
    }
}
