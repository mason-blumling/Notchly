import SwiftUI

struct NotchShape: Shape {
    var bottomCornerRadius: CGFloat
    var topCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Define dimensions
        let width = rect.width
        let height = rect.height
        let topRadius = min(topCornerRadius, width / 2)
        let bottomRadius = min(bottomCornerRadius, width / 2)

        // Top-right corner
        path.move(to: CGPoint(x: width, y: 0))
        path.addQuadCurve(to: CGPoint(x: width - topRadius, y: topRadius), control: CGPoint(x: width - topRadius, y: 0))

        // Right vertical edge
        path.addLine(to: CGPoint(x: width - topRadius, y: height - bottomRadius))

        // Bottom-right corner
        path.addQuadCurve(to: CGPoint(x: width - bottomRadius - topRadius, y: height), control: CGPoint(x: width - topRadius, y: height))

        // Bottom horizontal edge
        path.addLine(to: CGPoint(x: bottomRadius + topRadius, y: height))

        // Bottom-left corner
        path.addQuadCurve(to: CGPoint(x: topRadius, y: height - bottomRadius), control: CGPoint(x: topRadius, y: height))

        // Left vertical edge
        path.addLine(to: CGPoint(x: topRadius, y: topRadius))

        // Top-left corner
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: topRadius, y: 0))

        // Close the path
        path.closeSubpath()
        return path
    }
}

////
////  NotchShape.swift
////  Notchly
////
////  Created by Mason Blumling on 1/21/25.
////
//
//import SwiftUI
//
///// This struct defines the notch shape with adjustable corner radii and dynamic properties.
//struct NotchShape: Shape {
//    /// Define variable notch radius' to ensure we can customize the length/width (Animation Stuff *)
//    var topCornerRadius: CGFloat
//    var bottomCornerRadius: CGFloat
//
//    
//    /// Default the initialization to ensure the shape edges/radii stay comparable (unless otherwise defined)
//    init(bottomCornerRadius: CGFloat? = nil, topCornerRadius: CGFloat? = nil) {
//        if let bottomCornerRadius = bottomCornerRadius {
//            self.bottomCornerRadius = bottomCornerRadius
//        } else {
//            self.bottomCornerRadius = 10
//        }
//        
//        if let topCornerRadius = topCornerRadius {
//            self.topCornerRadius = topCornerRadius
//        } else {
//            self.topCornerRadius = self.bottomCornerRadius
//        }
//    }
//    
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//
//        //      Top-Left Corner -->  ____________________________________ <-- Start/End Point
//        //                           \                                  /
//        //                            \                                /
//        //    Top-Left Inner Corner -> |                              |  <- Top-Right Inner Corner
//        //                             |                              |
//        //                             |                              |
//        //                             |                              |
//        // Bottom-Left Outer Corner -> \______________________________/ <- Bottom-Right Outer Corner
//        
//        
//        /// Start the shape at the top-right corner
//        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
//
//        /// Top-right corner (inner) curve
//        path.addQuadCurve(
//            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius),
//            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
//        )
//
//        /// Right vertical line
//        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius))
//
//        /// Bottom-right (outer) corner curve
//        path.addQuadCurve(
//            to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY),
//            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
//        )
//
//        /// Bottom line
//        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY))
//
//        /// Bottom-left (Outer) corner curve
//        path.addQuadCurve(
//            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius),
//            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
//        )
//
//        /// Left vertical line
//        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius))
//
//        /// Top-left (Inner) corner curve
//        path.addQuadCurve(
//            to: CGPoint(x: rect.minX, y: rect.minY),
//            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
//        )
//
//        /// Top line to close the shape path
//        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
//
//        /// Ensures the path is complete (Bug happens here with shape fill otherwise ⚠️)
//        path.closeSubpath()
//        return path
//    }
//}
//
//#Preview {
//    /// More Rigid shape design but remains clean (Similar to notch on MBP)
//    NotchShape(bottomCornerRadius: 5, topCornerRadius: 10)
//        .fill(Color.black)
//        .frame(width: 200, height: 40)
//        .padding()
//    
//    /// Simular to above, but has more smoothed rounding in each of the radii
//    NotchShape(bottomCornerRadius: 10, topCornerRadius: 10)
//        .fill(Color.black)
//        .frame(width: 200, height: 40)
//        .padding()
//    
//    /// Same rounding on the bottom as above, but an extended radii to elongate header menu bar
//    NotchShape(bottomCornerRadius: 10, topCornerRadius: 15)
//        .fill(Color.black)
//        .frame(width: 200, height: 40)
//        .padding()
//    
//    /// More *Bubbly* version of the two shapes above
//    NotchShape(bottomCornerRadius: 15, topCornerRadius: 10)
//        .fill(Color.black)
//        .frame(width: 200, height: 40)
//        .padding()
//    
//    /// Most ovular design of all (my least fav)
//    NotchShape(bottomCornerRadius: 20, topCornerRadius: 10)
//        .fill(Color.black)
//        .frame(width: 200, height: 40)
//        .padding()
//}
