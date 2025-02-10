//
//  FigmaView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/25/25.
//

import SwiftUI

struct GoZoneVectorRight: Shape {
        func path(in rect: CGRect) -> Path {
                var path = Path()
                let width = rect.size.width
                let height = rect.size.height
                path.move(to: CGPoint(x: 0.4857001948*width, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0.9950579839*width, y: 0))
                path.addCurve(to: CGPoint(x: width, y: 0.0157517863*height), control1: CGPoint(x: 0.9977874146*width, y: 0), control2: CGPoint(x: width, y: 0.0070523168*height))
                path.addCurve(to: CGPoint(x: 0.9950521874*width, y: 0.0315562961*height), control1: CGPoint(x: width, y: 0.0244512557*height), control2: CGPoint(x: 0.9977815554*width, y: 0.0314972916*height))
                path.addCurve(to: CGPoint(x: 0.906567772*width, y: 0.0700699212*height), control1: CGPoint(x: 0.9568583039*width, y: 0.0323819853*height), control2: CGPoint(x: 0.9269968757*width, y: 0.0430000262*height))
                path.addCurve(to: CGPoint(x: 0.8738968484*width, y: 0.2205249892*height), control1: CGPoint(x: 0.8860563472*width, y: 0.0972489065*height), control2: CGPoint(x: 0.8738968484*width, y: 0.1426755606*height))
                path.addLine(to: CGPoint(x: 0.8738968484*width, y: 0.645813687*height))
                path.addCurve(to: CGPoint(x: 0.8738395279*width, y: 0.6477768799*height), control1: CGPoint(x: 0.8738968484*width, y: 0.6464723402*height), control2: CGPoint(x: 0.8738776369*width, y: 0.6471295233*height))
                path.addCurve(to: CGPoint(x: 0.8730997283*width, y: 0.6856139946*height), control1: CGPoint(x: 0.873284246*width, y: 0.6572100805*height), control2: CGPoint(x: 0.8731632545*width, y: 0.6698087313*height))
                path.addCurve(to: CGPoint(x: 0.8730766498*width, y: 0.6919293296*height), control1: CGPoint(x: 0.8730914514*width, y: 0.6876741818*height), control2: CGPoint(x: 0.8730841484*width, y: 0.6897804522*height))
                path.addCurve(to: CGPoint(x: 0.8726142213*width, y: 0.7383464469*height), control1: CGPoint(x: 0.8730278237*width, y: 0.7059159612*height), control2: CGPoint(x: 0.8729727274*width, y: 0.7217068579*height))
                path.addCurve(to: CGPoint(x: 0.8612841878*width, y: 0.8625007967*height), control1: CGPoint(x: 0.8717878138*width, y: 0.7767034461*height), control2: CGPoint(x: 0.8693350755*width, y: 0.8209817107*height))
                path.addCurve(to: CGPoint(x: 0.8120816085*width, y: 0.9929947726*height), control1: CGPoint(x: 0.8531650912*width, y: 0.9043715818*height), control2: CGPoint(x: 0.8352871916*width, y: 0.9658348643*height))
                path.addCurve(to: CGPoint(x: 0.755896714*width, y: 0.9991569051*height), control1: CGPoint(x: 0.8026325219*width, y: 1.0005240022*height), control2: CGPoint(x: 0.7785138443*width, y: 1.0008599738*height))
                path.addLine(to: CGPoint(x: 0, y: 0.9991569051*height))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.closeSubpath()
                return path
        }
}

struct GoZoneVectorLeft: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        
        path.move(to: CGPoint(x: 0.5142998052 * width, y: 0)) // Start at the top middle
        path.addLine(to: CGPoint(x: width, y: 0)) // Line to the top-right corner
        path.move(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: 0.0049420161 * width, y: 0)) // Move back to the left
        path.addCurve(to: CGPoint(x: 0, y: 0.0157517863 * height), control1: CGPoint(x: 0.0022125854 * width, y: 0), control2: CGPoint(x: 0, y: 0.0070523168 * height))
        path.addCurve(to: CGPoint(x: 0.0049478126 * width, y: 0.0315562961 * height), control1: CGPoint(x: 0, y: 0.0244512557 * height), control2: CGPoint(x: 0.0022184446 * width, y: 0.0314972916 * height))
        path.addCurve(to: CGPoint(x: 0.093432228 * width, y: 0.0700699212 * height), control1: CGPoint(x: 0.0431416961 * width, y: 0.0323819853 * height), control2: CGPoint(x: 0.0730031243 * width, y: 0.0430000262 * height))
        path.addCurve(to: CGPoint(x: 0.1261031516 * width, y: 0.2205249892 * height), control1: CGPoint(x: 0.1139436528 * width, y: 0.0972489065 * height), control2: CGPoint(x: 0.1261031516 * width, y: 0.1426755606 * height))
        path.addLine(to: CGPoint(x: 0.1261031516 * width, y: 0.645813687 * height))
        path.addCurve(to: CGPoint(x: 0.1261604721 * width, y: 0.6477768799 * height), control1: CGPoint(x: 0.1261031516 * width, y: 0.6464723402 * height), control2: CGPoint(x: 0.1261223631 * width, y: 0.6471295233 * height))
        path.addCurve(to: CGPoint(x: 0.1269002717 * width, y: 0.6856139946 * height), control1: CGPoint(x: 0.126715754 * width, y: 0.6572100805 * height), control2: CGPoint(x: 0.1268367455 * width, y: 0.6698087313 * height))
        path.addCurve(to: CGPoint(x: 0.1269233502 * width, y: 0.6919293296 * height), control1: CGPoint(x: 0.1269085486 * width, y: 0.6876741818 * height), control2: CGPoint(x: 0.1269158516 * width, y: 0.6897804522 * height))
        path.addCurve(to: CGPoint(x: 0.1273857787 * width, y: 0.7383464469 * height), control1: CGPoint(x: 0.1269721763 * width, y: 0.7059159612 * height), control2: CGPoint(x: 0.1270272726 * width, y: 0.7217068579 * height))
        path.addCurve(to: CGPoint(x: 0.1387158122 * width, y: 0.8625007967 * height), control1: CGPoint(x: 0.1282121862 * width, y: 0.7767034461 * height), control2: CGPoint(x: 0.1306649245 * width, y: 0.8209817107 * height))
        path.addCurve(to: CGPoint(x: 0.1879183915 * width, y: 0.9929947726 * height), control1: CGPoint(x: 0.1468349088 * width, y: 0.9043715818 * height), control2: CGPoint(x: 0.1647128084 * width, y: 0.9658348643 * height))
        path.addCurve(to: CGPoint(x: 0.244103286 * width, y: 0.9991569051 * height), control1: CGPoint(x: 0.1973674781 * width, y: 1.0005240022 * height), control2: CGPoint(x: 0.2214861557 * width, y: 1.0008599738 * height))
        path.addLine(to: CGPoint(x: width, y: 0.9991569051 * height))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }
}

struct GoZoneVector: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Right half of the notch
        let rightPath = GoZoneVectorRight().path(in: rect)
        path.addPath(rightPath)
        
        // Left half of the notch (mirrored horizontally)
        let leftTransform = CGAffineTransform(scaleX: -1, y: 1)
            .concatenating(CGAffineTransform(translationX: rect.width, y: 0))
        let leftPath = GoZoneVectorRight().path(in: rect).applying(leftTransform)
        path.addPath(leftPath)
        
        return path
    }
}

struct GoZoneVector_Preview: View {
    var body: some View {
        GoZoneVector()
            .fill(.white)
            .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .top, endPoint: .bottom))
            .frame(width: 500, height: 100)
            .background(NotchlyTheme.background)
            .padding()
            .padding()
            .padding()
            .padding()
    }
}

#Preview {
    GoZoneVector_Preview()
}
