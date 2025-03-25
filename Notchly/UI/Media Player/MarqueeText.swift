//
//  MarqueeText.swift
//  Notchly
//
//  Created by Mason Blumling on 3/5/25.
//

import SwiftUI
import Foundation

/// A view that displays text as a scrolling marquee if it exceeds the container width.
/// A fade effect is applied on the right edge.
struct MarqueeText: View {
    // MARK: - Input Properties
    let text: String
    let font: Font
    let color: Color
    let fadeWidth: CGFloat
    let animationSpeed: Double
    let pauseDuration: Double

    // MARK: - Internal State
    @State private var offset: CGFloat = 0         // Horizontal offset for the text
    @State private var textWidth: CGFloat = 0        // Actual width of the text
    @State private var textOpacity: Double = 1.0     // Opacity of the text (used for fading effect)
    @State private var containerWidth: CGFloat = 0   // Width of the container view
    @State private var animate: Bool = false         // Flag to start the animation cycle

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // The text view that will scroll.
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(textOpacity)
                    // Measure the text width using a background GeometryReader.
                    .background(GeometryReader { textGeo in
                        Color.clear.preference(key: TextWidthKey.self, value: textGeo.size.width)
                    })
                    .offset(x: animate ? offset : 0)
                    // Update text and container widths when the preference changes.
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
            // Overlay a fade effect on the right side.
            .overlay(fadeEffect())
        }
        .frame(height: 20)
    }
    
    // MARK: - Fade Effect
    /// Creates a gradient overlay that fades the text on the right.
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
    
    // MARK: - Animation Setup
    /// Determines whether the text is wider than the container.
    /// If so, it starts the scrolling animation.
    private func setupAnimationIfNeeded() {
        if textWidth > containerWidth {
            if !animate {
                animate = true
                offset = 0
                startAnimationCycle()
            }
        } else {
            // If text fits, disable animation.
            animate = false
            offset = 0
        }
    }
    
    // MARK: - Animation Cycle
    /// Starts a continuous animation cycle for scrolling the text.
    private func startAnimationCycle() {
        let totalScrollDistance = textWidth - containerWidth + fadeWidth * 1.2 // Ensure full scroll visibility.
        guard totalScrollDistance > 0 else { return }
        
        // Step 1: Fade out the text at the end.
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 0.0
        }
        
        // Step 2: After fade-out, reset offset to start.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            offset = 0
        }
        
        // Step 3: Fade text back in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.5)) {
                textOpacity = 1.0
            }
        }
        
        // Step 4: Pause briefly, then scroll text.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(Animation.linear(duration: animationSpeed)) {
                offset = -totalScrollDistance
            }
        }
        
        // Step 5: After a full cycle (scroll duration + pause), restart the cycle.
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration + 1.6) {
            startAnimationCycle()
        }
    }
    
    // MARK: - Preference Key for Measuring Text Width
    private struct TextWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
