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
    @State private var textOpacity: Double = 1.0
    @State private var containerWidth: CGFloat = 0
    @State private var animate: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(textOpacity)
                    .background(GeometryReader { textGeo in
                        Color.clear.preference(key: TextWidthKey.self, value: textGeo.size.width)
                    })
                    .offset(x: animate ? offset : 0)
                    .onPreferenceChange(TextWidthKey.self) { width in
                        textWidth = width
                        containerWidth = geo.size.width
                        setupAnimationIfNeeded()
                    }
                    .onAppear {
                        containerWidth = geo.size.width
                        setupAnimationIfNeeded()
                    }
            }
            .frame(width: containerWidth, alignment: .leading)
            .clipped()
            .overlay(fadeEffect())
        }
        .frame(height: 20)
    }

    /// **Ensures fade is ONLY on the right side**
    private func fadeEffect() -> some View {
        HStack {
            Spacer()
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fadeWidth)
        }
    }

    private func setupAnimationIfNeeded() {
        if textWidth > containerWidth {
            if !animate {
                animate = true
                offset = 0
                startAnimationCycle()
            }
        } else {
            animate = false
            offset = 0
        }
    }

    private func startAnimationCycle() {
        let totalScrollDistance = textWidth - containerWidth + fadeWidth * 1.2 // Ensures full scroll
        guard totalScrollDistance > 0 else { return } // Only animate if needed

        // Step 1: Start fading out when reaching the end
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 0.0 // ✅ Fade out
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // After fade-out completes
            offset = 0 // Step 2: Reset position while hidden
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { // Step 3: Fade in and restart scrolling
            withAnimation(.easeIn(duration: 0.5)) {
                textOpacity = 1.0 // ✅ Fade back in
            }
        }

        // Step 4: **Pause for a second before scrolling**
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { // ✅ Added delay before scrolling starts
            withAnimation(Animation.linear(duration: animationSpeed)) {
                offset = -totalScrollDistance
            }
        }

        // Step 5: Restart animation cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration + 1.6) {
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
