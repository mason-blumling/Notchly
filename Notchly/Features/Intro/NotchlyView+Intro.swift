//
//  NotchlyView+Intro.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI

extension NotchlyView {
    
    /// Determines if the intro should be shown instead of normal content
    private var shouldShowIntro: Bool {
        coordinator.state == .expanded && coordinator.ignoreHoverOnboarding
    }
    
    /// Creates the intro view that replaces normal content during onboarding
    @ViewBuilder
    func introContent() -> some View {
        IntroView {
            // Called when intro completes
            coordinator.completeIntro()
        }
    }
}
