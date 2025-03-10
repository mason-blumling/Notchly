//
//  MarqueeText.swift
//  Notchly
//
//  Created by Mason Blumling on 3/5/25.
//

import SwiftUI
import Foundation

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let fadeWidth: CGFloat
    let animationSpeed: Double
    let pauseDuration: Double

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var animate: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(GeometryReader {
                        Color.clear.preference(key: TextWidthKey.self, value: $0.size.width)
                    })
                    .offset(x: animate ? offset : 0)
                    .opacity(animate ? opacity : 1)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.black)
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black, Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: fadeWidth)
                        }
                    )
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .onPreferenceChange(TextWidthKey.self) { width in
                if width != textWidth {
                    textWidth = width
                    containerWidth = geo.size.width
                    setupAnimationIfNeeded()
                }
            }
            .onAppear {
                containerWidth = geo.size.width
                setupAnimationIfNeeded()
            }
        }
        .frame(height: 20)
    }

    private func setupAnimationIfNeeded() {
        if textWidth > containerWidth {
            if !animate {
                animate = true
                startAnimationCycle()
            }
        } else {
            animate = false
            offset = 0
            opacity = 1
        }
    }

    private func startAnimationCycle() {
        let totalScrollDistance = textWidth - containerWidth

        withAnimation(.easeIn(duration: 0.8)) {
            opacity = 1
        }

        withAnimation(Animation.linear(duration: animationSpeed).delay(0.8)) {
            offset = -totalScrollDistance
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration) {
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration + 1.0) {
            offset = fadeWidth
            startAnimationCycle()
        }
    }

    private struct TextWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
