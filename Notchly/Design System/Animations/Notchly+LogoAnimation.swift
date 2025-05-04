//
//  Notchly+LogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//
import SwiftUI

// MARK: – Rainbow Gradient that Rotates via its Start/End angles

extension ShapeStyle where Self == AngularGradient {
    static func notchly(offset: Double) -> AngularGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 1.0/11.0).map {
            Gradient.Stop(color: Color(hue: $0, saturation: 0.6, brightness: 1.0), location: $0)
        }
        return AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .degrees(offset),
            endAngle: .degrees(offset + 360)
        )
    }
}

struct NotchlyLogoAnimation: View {
    @State private var progress = 0.0
    @State private var showColor = false
    @State private var gradientOffset = 0.0

    private let style = StrokeStyle(lineWidth: 6, lineCap: .round)

    var body: some View {
        ZStack {
            /// White outline drawing
            NotchlyLogoShape()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: style)
                .opacity(showColor ? 0 : 1)

            /// Rainbow glow with spinning gradient
            if showColor {
                let base = NotchlyLogoShape()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)
                /// blur layers
                base.blur(radius: 6)
                base.blur(radius: 3)
                /// crisp outline
                base
            }
        }
        .onAppear {
            /// 1) draw white path
            withAnimation(.easeInOut(duration: 4)) {
                progress = 1
            }
            /// 2) crossfade to rainbow
            withAnimation(.easeInOut(duration: 1).delay(4)) {
                showColor = true
            }
            /// 3) spin gradient (only updates start/end angles)
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
    }
}

// MARK: – preview
struct NotchlyLogoAnimation_Previews: PreviewProvider {
    static var previews: some View {
        let config = NotchlyConfiguration.large
        NotchlyShape(
            bottomCornerRadius: config.bottomCornerRadius,
            topCornerRadius: config.topCornerRadius
        )
        .fill(NotchlyTheme.background)
        .frame(width: config.width/2, height: config.height + 100)
        .shadow(color: NotchlyTheme.shadow, radius: config.shadowRadius)
        .overlay(
            NotchlyLogoAnimation()
                .frame(width: config.width, height: config.height)
                .aspectRatio(
                    CGSize(width: 722.28 - 276.27, height: 780.95 - 244.01),
                    contentMode: .fit
                )
        )
    }
}
