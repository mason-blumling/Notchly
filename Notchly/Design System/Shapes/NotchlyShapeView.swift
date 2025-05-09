//
//  NotchlyShapeView.swift
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
    
    /// Does the active display have a notch
    let hasNotch: Bool

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
            width: safeBounds.width * 0.47,
            height: safeBounds.height
        )
    }

    /// Right-side content frame (e.g. calendar in expanded state).
    var rightContentFrame: CGRect {
        CGRect(
            x: safeBounds.minX + safeBounds.width * 0.48,
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

/// A layout container that wraps dynamic Notchly shapes and applies content using a shared layout guide.
/// Automatically clips content to the notch shape and animates size/shape changes.
struct NotchlyShapeView<Content: View>: View {
    let configuration: NotchlyConfiguration
    let state: NotchlyViewModel.NotchState
    let animation: Animation
    let content: (NotchlyLayoutGuide) -> Content
    var namespace: Namespace.ID?
    
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        /// Create shared layout metrics for sizing child content
        let layoutGuide = createLayoutGuide()

        ZStack(alignment: .top) {
            /// 🟦 Background shape behind the content
            NotchlyShape(
                bottomCornerRadius: configuration.bottomCornerRadius,
                topCornerRadius: configuration.topCornerRadius
            )
            .fill(NotchlyTheme.background.opacity(backgroundOpacity))
            .frame(
                width: configuration.width,
                height: configuration.height
            )
            .shadow(
                color: NotchlyTheme.shadow,
                radius: configuration.shadowRadius
            )
            .animation(animation, value: configuration.width)
            .animation(animation, value: configuration.height)
            .animation(animation, value: configuration.topCornerRadius)
            .animation(animation, value: configuration.bottomCornerRadius)

            /// 🟨 Foreground content sized and aligned using layout guide
            content(layoutGuide)
                .frame(
                    width: configuration.width,
                    height: configuration.height
                )
        }
        .frame(
            width: configuration.width,
            height: configuration.height
        )
        .clipShape(
            NotchlyShape(
                bottomCornerRadius: configuration.bottomCornerRadius,
                topCornerRadius: configuration.topCornerRadius
            )
        )
        .animation(animation, value: configuration.width)
        .animation(animation, value: configuration.height)
        .onAppear {
            /// Initialize opacity from settings
            backgroundOpacity = NotchlySettings.shared.backgroundOpacity
        }
        .onReceive(NotificationCenter.default.publisher(for: .NotchlyBackgroundOpacityChanged)) { notification in
            if let opacity = notification.userInfo?["opacity"] as? Double {
                /// Update the background opacity
                withAnimation(.easeInOut(duration: 0.2)) {
                    /// Apply to background shape
                    self.backgroundOpacity = opacity
                }
            }
        }
    }

    // MARK: - Layout Calculation

    /// Produces a layout guide that defines safe and usable regions inside the notch shape.
    private func createLayoutGuide() -> NotchlyLayoutGuide {
        // Detect if we have a notch
        let hasNotch = NotchlyViewModel.shared.hasNotch
        
        /// Only apply the notch padding for specific states
        let shouldApplyNotchPadding = hasNotch &&
            (state != .expanded || NotchlyViewModel.shared.isInIntroSequence)
        
        /// Adjust top inset based on notch presence and context
        let insetTop = configuration.topCornerRadius * 0.65 +
            (shouldApplyNotchPadding ? 30 : 0) /// Only add extra padding when needed
        let insetSide = configuration.bottomCornerRadius * 0.4

        return NotchlyLayoutGuide(
            bounds: CGRect(origin: .zero, size: CGSize(
                width: configuration.width,
                height: configuration.height
            )),
            safeBounds: CGRect(
                x: insetSide,
                y: insetTop,
                width: configuration.width - (insetSide * 2),
                height: configuration.height - insetTop - insetSide
            ),
            state: state,
            hasNotch: hasNotch
        )
    }
}
