//
//  Notchly+LogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI

// MARK: - Rainbow Angular Gradient (rotates via offset)

extension ShapeStyle where Self == AngularGradient {
    /// Creates a 12-stop rainbow gradient centered at the shape’s center,
    /// rotating based on `offset` (in degrees).
    static func notchly(offset: Double) -> AngularGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 1.0 / 11.0).map {
            Gradient.Stop(
                color: Color(hue: $0, saturation: 0.6, brightness: 1.0),
                location: $0
            )
        }

        return AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .degrees(offset),
            endAngle: .degrees(offset + 360)
        )
    }
}

// MARK: - Animated Logo View

/// Animates the Notchly "N" logo:
/// 1. White stroke is drawn
/// 2. Crossfades to spinning rainbow outline
struct NotchlyLogoAnimation: View {
    @State private var progress = 0.0
    @State private var showColor = false
    @State private var gradientOffset = 0.0

    private let style = StrokeStyle(lineWidth: 6, lineCap: .round)

    var body: some View {
        ZStack {
            /// Step 1: White stroke path animation
            NotchlyLogoShape()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: style)
                .opacity(showColor ? 0 : 1)

            /// Step 2: Rainbow gradient path with blur glow
            if showColor {
                let base = NotchlyLogoShape()
                    .trim(from: 0, to: progress)
                    .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)

                base.blur(radius: 6)
                base.blur(radius: 3)
                base /// crisp outline
            }
        }
        .onAppear {
            /// Animate white stroke drawing
            withAnimation(.easeInOut(duration: 4)) {
                progress = 1
            }

            /// Crossfade to rainbow
            withAnimation(.easeInOut(duration: 1).delay(4)) {
                showColor = true
            }

            /// Spin the gradient indefinitely
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
    }
}

// MARK: - Preview

struct NotchlyLogoAnimation_Previews: PreviewProvider {
    static var previews: some View {
        let config = NotchlyConfiguration.large

        NotchlyShape(
            bottomCornerRadius: config.bottomCornerRadius,
            topCornerRadius: config.topCornerRadius
        )
        .fill(NotchlyTheme.background)
        .frame(width: config.width / 2, height: config.height + 100)
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
