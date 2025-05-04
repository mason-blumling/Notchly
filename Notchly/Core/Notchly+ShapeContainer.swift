//
//  Notchly+ShapeContainer.swift
//  Notchly
//
//  Created by Mason Blumling on 5/2/25.
//

import Foundation
import SwiftUI

/// A layout container that wraps dynamic Notchly shapes and applies content using a shared layout guide.
/// Automatically clips content to the notch shape and animates size/shape changes.
struct NotchlyShapeContainer<Content: View>: View {
    let configuration: NotchlyConfiguration
    let state: NotchlyTransitionCoordinator.NotchState
    let animation: Animation
    let content: (NotchlyLayoutGuide) -> Content
    var namespace: Namespace.ID?

    var body: some View {
        /// Create shared layout metrics for sizing child content
        let layoutGuide = createLayoutGuide()

        ZStack(alignment: .top) {
            /// 🟦 Background shape behind the content
            NotchlyShape(
                bottomCornerRadius: configuration.bottomCornerRadius,
                topCornerRadius: configuration.topCornerRadius
            )
            .fill(NotchlyTheme.background)
            .frame(
                width: configuration.width,
                height: configuration.height
            )
            .shadow(
                color: NotchlyTheme.shadow,
                radius: configuration.shadowRadius
            )
            .animation(animation, value: configuration)

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
    }

    // MARK: - Layout Calculation

    /// Produces a layout guide that defines safe and usable regions inside the notch shape.
    private func createLayoutGuide() -> NotchlyLayoutGuide {
        /// Slightly shrink content area to avoid overlapping rounded corners
        let insetTop = configuration.topCornerRadius * 0.65
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
            state: state
        )
    }
}
