//
//  AppDelegate+Intro.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import Foundation
import AppKit

extension AppDelegate {
    
    /// Handles first launch logic and shows intro if needed
    func handleFirstLaunch() {
        guard viewModel.isFirstLaunch else {
            // Normal launch - ensure we're in collapsed state
            viewModel.state = .collapsed
            viewModel.isVisible = true
            return
        }
        
        // First launch - show the intro
        showIntroSequence()
    }
    
    /// Initiates the intro sequence
    private func showIntroSequence() {
        Task { @MainActor in
            // Start in collapsed state
            viewModel.state = .collapsed
            viewModel.isVisible = true
            
            // Wait a moment for the window to appear
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Expand to intro configuration
            viewModel.showIntro()
        }
    }
}
