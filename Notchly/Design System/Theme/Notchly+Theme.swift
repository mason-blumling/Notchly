//
//  NotchlyTheme.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import SwiftUI

/// Centralized theme for Notchly's visual design system.
struct NotchlyTheme {

    // MARK: - Core Colors

    /// The primary background fill for notch content.
    static let background = Color.black

    /// Text used for titles, icons, and key UI elements.
    static let primaryText = Color.white

    /// Subdued text used for timestamps, subtitles, etc.
    static let secondaryText = Color.white.opacity(0.6)

    /// Highlighted text color (e.g., active items or selections).
    static let selectedHighlight = Color.white.opacity(0.8)

    // MARK: - Gradient Stops

    /// Gradient entry point (fully opaque).
    static let gradientStart = Color.black.opacity(1.0)

    /// Gradient midpoint (left side, slightly translucent).
    static let gradientMidLeft = Color.black.opacity(0.9)

    /// Gradient midpoint (right side, more translucent).
    static let gradientMidRight = Color.black.opacity(0.7)

    /// Gradient exit (fully transparent).
    static let gradientEnd = Color.clear

    // MARK: - Effects

    /// Shadow used behind the notch shape for depth.
    static let shadow = Color.black.opacity(0.5)
}
