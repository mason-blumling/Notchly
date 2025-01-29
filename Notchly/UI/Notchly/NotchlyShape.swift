//
//  NotchlyShape.swift
//  Notchly
//
//  Created by Mason Blumling on 1/21/25.
//

import SwiftUI

// This struct defines the notch shape with adjustable corner radii and dynamic properties.
struct NotchlyShape: Shape {
    var bottomCornerRadius: CGFloat
    var topCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        //      Top-Left Corner -->  ____________________________________ <-- Start/End Point
        //                           \                                  /
        //                            \                                /
        //    Top-Left Inner Corner -> |                              |  <- Top-Right Inner Corner
        //                             |                              |
        //                             |                              |
        //                             |                              |
        // Bottom-Left Outer Corner -> \______________________________/ <- Bottom-Right Outer Corner

        /// Define dimensions
        let width = rect.width
        let height = rect.height
        let topRadius = min(topCornerRadius, width / 2)
        let bottomRadius = min(bottomCornerRadius, width / 2)

        /// Start the shape at the top-right corner
        path.move(to: CGPoint(x: width, y: 0))
        path.addQuadCurve(to: CGPoint(x: width - topRadius, y: topRadius),
                          control: CGPoint(x: width - topRadius, y: 0))

        /// Right vertical line
        path.addLine(to: CGPoint(x: width - topRadius, y: height - bottomRadius))

        /// Bottom-Right (Outer) corner curve
        path.addQuadCurve(to: CGPoint(x: width - bottomRadius - topRadius, y: height),
                          control: CGPoint(x: width - topRadius, y: height))

        /// Bottom line
        path.addLine(to: CGPoint(x: bottomRadius + topRadius, y: height))

        /// Bottom-left (Outer) corner curve
        path.addQuadCurve(to: CGPoint(x: topRadius, y: height - bottomRadius),
                          control: CGPoint(x: topRadius, y: height))

        /// Left vertical line
        path.addLine(to: CGPoint(x: topRadius, y: topRadius))

        /// Top-left (Inner) corner curve
        path.addQuadCurve(to: CGPoint(x: 0, y: 0),
                          control: CGPoint(x: topRadius, y: 0))

        /// Top line to close the shape path
        path.closeSubpath()
        return path
    }
}
