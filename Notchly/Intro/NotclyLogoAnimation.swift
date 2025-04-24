//
//  NotchlyLogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 4/23/25.
//

import SwiftUI

// MARK: – rainbow gradient that can be “rotated” via its start/end angles
extension ShapeStyle where Self == AngularGradient {
    static func notchly(offset: Double) -> AngularGradient {
        // 12-stop rainbow
        let stops = stride(from: 0.0, through: 1.0, by: 1.0/11.0).map {
            Gradient.Stop(
                color: Color(hue: $0, saturation: 0.6, brightness: 1.0),
                location: $0
            )
        }
        return AngularGradient(
            gradient:   Gradient(stops: stops),
            center:     .center,
            startAngle: .degrees(offset),
            endAngle:   .degrees(offset + 360)
        )
    }
}

// MARK: – glowing “trim‐and‐glow” wrapper
struct GlowingSnake<Content: Shape, Fill: ShapeStyle>: View, Animatable {
    var progress: Double
    var fill: Fill
    var lineWidth: CGFloat = 6
    var blurRadius: CGFloat = 4
    @ViewBuilder var shape: Content

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        shape
            .trim(from: 0, to: progress)
            .glow(fill: fill, lineWidth: lineWidth, blurRadius: blurRadius)
    }
}

// MARK: – glow modifier (blur behind, crisp stroke on top)
extension View where Self: Shape {
    func glow(fill: some ShapeStyle,
              lineWidth: Double,
              blurRadius: Double = 6,
              lineCap: CGLineCap = .round) -> some View {
        ZStack {
            // heavy blur
            self.stroke(style: .init(lineWidth: lineWidth, lineCap: lineCap))
                .fill(fill)
                .blur(radius: blurRadius)
            // lighter blur
            self.stroke(style: .init(lineWidth: lineWidth, lineCap: lineCap))
                .fill(fill)
                .blur(radius: blurRadius/2)
            // crisp outline
            self.stroke(style: .init(lineWidth: lineWidth, lineCap: lineCap))
                .fill(fill)
        }
    }
}

// MARK: – main view
struct NotchlyLogoAnimation: View {
    @State private var drawProgress   = 0.0   // white-line draw
    @State private var showColor      = false // cross-fade flag
    @State private var gradientOffset = 0.0   // rainbow rotation

    var body: some View {
        ZStack {
            // 1️⃣ white outline
            NotchlyLogoShape()
                .trim(from: 0, to: drawProgress)
                .stroke(Color.white,
                        style: .init(lineWidth: 6, lineCap: .round))
                .opacity(showColor ? 0 : 1)

            // 2️⃣ rainbow glow that “moves” via changing the gradient’s start angle
            GlowingSnake(progress: drawProgress,
                         fill: AngularGradient.notchly(offset: gradientOffset),
                         lineWidth: 6,
                         blurRadius: 6) {
                NotchlyLogoShape()
            }
            .opacity(showColor ? 1 : 0)
        }
        .onAppear {
            // a) draw white over 4s
            withAnimation(.easeInOut(duration: 4)) {
                drawProgress = 1
            }
            // b) cross-fade to rainbow over 1s, starting at t=4
            withAnimation(.easeInOut(duration: 1).delay(4)) {
                showColor = true
            }
            // c) spin the rainbow forever (8s per lap), starting immediately
            withAnimation(.linear(duration: 8)
                            .repeatForever(autoreverses: false)) {
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
            topCornerRadius:    config.topCornerRadius
        )
        .fill(NotchlyTheme.background)
        .frame(width:  config.width/2,
               height: config.height + 100)
        .shadow(color: NotchlyTheme.shadow,
                radius: config.shadowRadius)
        .overlay(
            NotchlyLogoAnimation()
                .frame(width:  config.width,
                       height: config.height)
                .aspectRatio(
                    CGSize(
                        width: 722.28 - 276.27,
                        height: 780.95 - 244.01
                    ),
                    contentMode: .fit
                )
        )
    }
}
