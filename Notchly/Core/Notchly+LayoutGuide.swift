//
//  Notchly+LayoutGuide.swift
//  Notchly
//
//  Created by Mason Blumling on 5/2/25.
//

import Foundation
import SwiftUI

/// Defines logical layout regions for the Notchly UI,
/// based on current notch state and shape dimensions.
struct NotchlyLayoutGuide {
    
    // MARK: - Geometry Inputs
    
    /// Full notch bounds including rounded corners.
    let bounds: CGRect

    /// Insets applied to avoid content clipping in rounded corners.
    let safeBounds: CGRect

    /// Current notch UI state (collapsed, activity, expanded).
    let state: NotchlyViewModel.NotchState

    // MARK: - Content Sizing Helpers

    /// Safe content width (excludes rounded corner padding).
    var contentWidth: CGFloat { safeBounds.width }

    /// Safe content height (excludes rounded corner padding).
    var contentHeight: CGFloat { safeBounds.height }

    // MARK: - Layout Frames

    /// Left-side content frame (e.g. media player in expanded state).
    var leftContentFrame: CGRect {
        CGRect(
            x: safeBounds.minX,
            y: safeBounds.minY,
            width: safeBounds.width * 0.47, // Slightly under half to provide spacing
            height: safeBounds.height
        )
    }

    /// Right-side content frame (e.g. calendar in expanded state).
    var rightContentFrame: CGRect {
        CGRect(
            x: safeBounds.minX + safeBounds.width * 0.48, // Slight offset to create central spacing
            y: safeBounds.minY,
            width: safeBounds.width * 0.47,
            height: safeBounds.height
        )
    }

    /// Full content frame, typically used when only one component is shown.
    var fullContentFrame: CGRect { safeBounds }

    /// Frame for the compact media activity (e.g. collapsed state with artwork + audio bars).
    var mediaActivityFrame: CGRect {
        CGRect(
            x: safeBounds.minX + 10,
            y: safeBounds.minY,
            width: safeBounds.width - 20,
            height: safeBounds.height
        )
    }

    /// Calendar live activity alert shares the same region as media activity.
    var calendarActivityFrame: CGRect { mediaActivityFrame }
}
