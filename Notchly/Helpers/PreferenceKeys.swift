//
//  PreferenceKeys.swift
//  Notchly
//
//  Created by Mason Blumling on 1/19/25.
//
//  This file contains custom SwiftUI preference keys used for state management.
//  Preference keys allow child views to communicate data (like layout or size)
//  back to their parent views in a SwiftUI hierarchy.
//

import SwiftUI
import Foundation

// MARK: - MaxHeightPreferenceKey

/// A custom preference key to track the maximum height of a group of views.
/// This is useful for ensuring consistent sizing across related views, such as
/// event cards in a list.
///
/// Usage:
/// - Each child view reports its height using this key.
/// - The parent view collects all reported heights and determines the maximum.
struct MaxHeightPreferenceKey: PreferenceKey {
    // MARK: Default Value

    /// The default value when no heights are reported.
    static var defaultValue: CGFloat = 0

    // MARK: Reduce Method

    /// Combines reported values from child views to determine the maximum height.
    ///
    /// - Parameters:
    ///   - value: The current maximum height (updated as new heights are reported).
    ///   - nextValue: A closure returning the next height reported by a child view.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue()) // Update to the maximum of the current and next value
    }
}
