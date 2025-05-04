//
//  NotchlyTheme.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import SwiftUI

/// Centralized theme for Notchly's colors
struct NotchlyTheme {
    static let background = Color.black
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let selectedHighlight = Color.white.opacity(0.8)
    static let gradientStart = Color.black.opacity(1.0)
    static let gradientMidLeft = Color.black.opacity(0.9)
    static let gradientMidRight = Color.black.opacity(0.7)
    static let gradientEnd = Color.clear
    static let shadow = Color.black.opacity(0.5)
}
