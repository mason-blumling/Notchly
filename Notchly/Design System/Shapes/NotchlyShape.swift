//
//  NotchlyShape.swift
//  Notchly
//
//  Created by Mason Blumling on 1/21/25.
//

import SwiftUI

/// A customizable notch shape used across the Notchly app.
///
/// Visually resembles a pill with flat sides and rounded top/bottom corners.
/// Supports smooth animation via `animatableData`.
///
/// ```
/// Top-Left Corner --->  ____________________________________ <-- Top-Right Corner
///                       \                                  /
///                        \                                /
///   Left Side ----------> |                              |  <--------- Right Side
///                         |                              |
///                         |                              |
///                         |                              |
/// Btm Left Corner ------> \______________________________/ <--------- Btm Right Corner
/// ```
struct NotchlyShape: Shape {
    var bottomCornerRadius: CGFloat
    var topCornerRadius: CGFloat

    /// Makes the shape animatable
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomCornerRadius, topCornerRadius) }
        set {
            bottomCornerRadius = newValue.first
            topCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        /// Clamp corner radii to avoid rendering bugs
        let width = rect.width
        let height = rect.height
        let topRadius = min(topCornerRadius, min(width, height) / 2)
        let bottomRadius = min(bottomCornerRadius, min(width, height) / 2)

        // MARK: – Path Drawing
        
        /// Top-right corner
        path.move(to: CGPoint(x: width, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: width - topRadius, y: topRadius),
            control: CGPoint(x: width - topRadius, y: 0)
        )

        /// Right vertical line
        path.addLine(to: CGPoint(x: width - topRadius, y: height - bottomRadius))

        /// Bottom-Right (Outer) corner curve
        path.addQuadCurve(
            to: CGPoint(x: width - topRadius - bottomRadius, y: height),
            control: CGPoint(x: width - topRadius, y: height)
        )

        /// Bottom line
        path.addLine(to: CGPoint(x: bottomRadius + topRadius, y: height))

        /// Bottom-left (Outer) corner curve
        path.addQuadCurve(
            to: CGPoint(x: topRadius, y: height - bottomRadius),
            control: CGPoint(x: topRadius, y: height)
        )

        /// Left vertical line
        path.addLine(to: CGPoint(x: topRadius, y: topRadius))

        /// Top-left (Inner) corner curve
        path.addQuadCurve(
            to: CGPoint(x: 0, y: 0),
            control: CGPoint(x: topRadius, y: 0)
        )

        /// Top line to close the shape path
        path.closeSubpath()
        return path
    }
}

// MARK: - Shape Extension

extension Shape {
    /// Adds animated corner radius transitions to any shape.
    func animatableCornerRadius(
        _ cornerRadius: CGFloat,
        animation: Animation = .easeInOut
    ) -> some View {
        self.animation(animation, value: cornerRadius)
    }
}
