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
    static let hasShownIntroKey = "com.notchly.hasShownIntro"
    
    // MARK: - Intro Configuration
    
    /// Logo-specific intro configuration (more square for logo animation)
    var introLogoConfig: NotchlyConfiguration {
        NotchlyConfiguration(
            width: 320,
            height: 320,
            topCornerRadius: 15,
            bottomCornerRadius: 15,
            shadowRadius: 0
        )
    }
    
    /// Medium intro configuration (for logo + text)
    var introMediumConfig: NotchlyConfiguration {
        NotchlyConfiguration(
            width: 550,
            height: 200,
            topCornerRadius: 15,
            bottomCornerRadius: 15,
            shadowRadius: 0
        )
    }
    
    /// Wide intro configuration (for content stages)
    var introWideConfig: NotchlyConfiguration {
        NotchlyConfiguration(
            width: 800,
            height: 250,
            topCornerRadius: 15,
            bottomCornerRadius: 15,
            shadowRadius: 0
        )
    }
    
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
        
        // Update to intro logo configuration (small square)
        withAnimation(animation) {
            state = .expanded
            // Starting with a small square for the logo animation
            configuration = introLogoConfig
        }
    }
    
    /// Updates the intro configuration based on the current stage
    func updateIntroConfig(for stage: IntroView.IntroStage) {
        withAnimation(animation) {
            switch stage {
            case .logoDrawing, .logoRainbow:
                configuration = introLogoConfig
            case .fullName:
                configuration = introMediumConfig
            case .welcome, .permissions, .tips:
                configuration = introWideConfig
            case .complete:
                // Will be handled by completeIntro()
                break
            }
        }
    }
}
