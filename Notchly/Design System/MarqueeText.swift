//
//  MarqueeText.swift
//  Notchly
//
//  Created by Mason Blumling on 3/5/25.
//

import SwiftUI
import Foundation

/// A view that displays a horizontally scrolling (marquee) text label
/// if the content width exceeds its container. Includes a right-edge fade effect.
struct MarqueeText: View {
    
    // MARK: - Input

    let text: String             // The text to display
    let font: Font               // Font to apply
    let color: Color             // Text color
    let fadeWidth: CGFloat       // Width of trailing fade-out gradient
    let animationSpeed: Double   // Scrolling animation duration
    let pauseDuration: Double    // Pause between scroll cycles

    // MARK: - State

    @State private var offset: CGFloat = 0              // Horizontal scroll offset
    @State private var textWidth: CGFloat = 0           // Measured width of rendered text
    @State private var containerWidth: CGFloat = 0      // Measured width of container
    @State private var textOpacity: Double = 1.0        // Controls fade in/out cycle
    @State private var animate: Bool = false            // Whether to animate or not

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(textOpacity)
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.preference(key: TextWidthKey.self, value: textGeo.size.width)
                        }
                    )
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
        }
        .frame(height: 20)
    }

    // MARK: - Fade Effect

    /// Creates a trailing fade overlay to visually mask the edge of scrolling text.
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

    // MARK: - Animation Control

    /// Determines whether scrolling is needed and starts the marquee cycle if so.
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

    /// Runs a full scroll → fade → reset → repeat cycle.
    private func startAnimationCycle() {
        let totalScrollDistance = textWidth - containerWidth + fadeWidth * 1.2
        guard totalScrollDistance > 0 else { return }

        /// Step 1: Fade out
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 0.0
        }

        /// Step 2: Reset offset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            offset = 0
        }

        /// Step 3: Fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.5)) {
                textOpacity = 1.0
            }
        }

        /// Step 4: Scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.linear(duration: animationSpeed)) {
                offset = -totalScrollDistance
            }
        }

        /// Step 5: Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration + 1.6) {
            startAnimationCycle()
        }
    }

    // MARK: - Preference Key

    /// Used to measure the rendered width of the text label.
    private struct TextWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
