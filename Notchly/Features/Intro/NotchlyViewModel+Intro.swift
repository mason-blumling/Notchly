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
        return NotchlyConfiguration(
            width: 320,
            height: hasNotch ? 350 : 320,
            topCornerRadius: 15,
            bottomCornerRadius: 15,
            shadowRadius: 0
        )
    }
    
    /// Medium intro configuration (for logo + text)
    var introMediumConfig: NotchlyConfiguration {
        return NotchlyConfiguration(
            width: 550,
            height: hasNotch ? 230 : 200,
            topCornerRadius: 15,
            bottomCornerRadius: 15,
            shadowRadius: 0
        )
    }
    
    /// Wide intro configuration (for content stages)
    var introWideConfig: NotchlyConfiguration {
        return NotchlyConfiguration(
            width: 800,
            height: hasNotch ? 280 : 250,
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
        
        /// When ending the intro sequence, set the isInIntroSequence flag to false
        isInIntroSequence = false
        
        /// First ensure we set the configuration to the default/collapsed size
        /// IMPORTANT: This should happen BEFORE changing the state
        withAnimation(animation) {
            /// Set configuration first, then state
            configuration = .default
            state = .collapsed
            ignoreHoverOnboarding = false  /// Re-enable hover interaction
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let window = self?.windowController?.window,
                  let screen = self?.currentScreen else { return }
            
            /// Get current window frame
            var frame = window.frame
            
            /// Calculate the center position of the screen
            let centerX = screen.frame.midX
            
            /// Position the window to be perfectly centered
            frame.origin.x = centerX - (frame.width / 2)
            
            /// Apply the centering
            window.setFrame(frame, display: true, animate: true)
        }
    }
    
    /// Shows the intro experience
    func showIntro() {
        /// 1. Set flag that we're in intro sequence - this prevents automatic config changes
        /// 2. Set ignore hover flag
        isInIntroSequence = true
        ignoreHoverOnboarding = true
        
        /// 3. Start with collapsed
        state = .collapsed
        configuration = .default
        
        /// 4. Small delay then animate to logo config
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            
            withAnimation(self.animation) {
                self.configuration = self.introLogoConfig
                self.state = .expanded
            }
        }
    }

    /// Updates the intro configuration based on the current stage
    func updateIntroConfig(for stage: IntroView.IntroStage) {
        if stage == .complete {
            /// End of intro sequence, so restore normal behavior
            isInIntroSequence = false
        }
        
        withAnimation(animation) {
            switch stage {
            case .logoDrawing, .logoRainbow, .fullName:
                configuration = introMediumConfig
            case .welcome, .permissions, .tips:
                configuration = introWideConfig
            case .complete:
                break
            }
        }
    }
}
