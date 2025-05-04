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
    /// The text to be displayed.
    let text: String
    /// The font used for the text.
    let font: Font
    /// The color of the text.
    let color: Color
    /// The width of the fade effect on the right edge.
    let fadeWidth: CGFloat
    /// The duration of the scrolling animation.
    let animationSpeed: Double
    /// The pause duration between scrolling cycles.
    let pauseDuration: Double

    // MARK: - Internal State
    /// The current horizontal offset for scrolling.
    @State private var offset: CGFloat = 0
    /// The measured width of the text.
    @State private var textWidth: CGFloat = 0
    /// The current opacity of the text, used for the fade effect.
    @State private var textOpacity: Double = 1.0
    /// The width of the container view.
    @State private var containerWidth: CGFloat = 0
    /// A flag indicating whether the scrolling animation should run.
    @State private var animate: Bool = false

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                /// The text view that scrolls horizontally.
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(textOpacity)
                    /// Background geometry reader to measure text width.
                    .background(
                        GeometryReader { textGeo in
                            Color.clear.preference(key: TextWidthKey.self, value: textGeo.size.width)
                        }
                    )
                    .offset(x: animate ? offset : 0)
                    /// Update measured values and start the animation if needed.
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
            /// Overlay the fade gradient on the right edge.
            .overlay(fadeEffect())
        }
        .frame(height: 20)
    }
    
    // MARK: - Fade Effect
    /// Returns a gradient overlay that fades out the text on the right.
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
    
    // MARK: - Animation Setup and Cycle
    /// Checks if the text exceeds the container width and starts the scrolling animation if needed.
    private func setupAnimationIfNeeded() {
        if textWidth > containerWidth {
            if !animate {
                animate = true
                offset = 0
                startAnimationCycle()
            }
        } else {
            /// No scrolling needed if text fits.
            animate = false
            offset = 0
        }
    }
    
    /// Starts a continuous animation cycle for scrolling the text.
    private func startAnimationCycle() {
        let totalScrollDistance = textWidth - containerWidth + fadeWidth * 1.2
        guard totalScrollDistance > 0 else { return }
        
        /// 1: Fade out the text at the end.
        withAnimation(.easeOut(duration: 0.5)) {
            textOpacity = 0.0
        }
        
        /// 2: Reset offset after the fade-out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            offset = 0
        }
        
        /// 3: Fade text back in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.5)) {
                textOpacity = 1.0
            }
        }
        
        /// 4: Pause briefly, then scroll the text.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(Animation.linear(duration: animationSpeed)) {
                offset = -totalScrollDistance
            }
        }
        
        /// 5: After scrolling and pause, restart the cycle.
        DispatchQueue.main.asyncAfter(deadline: .now() + animationSpeed + pauseDuration + 1.6) {
            startAnimationCycle()
        }
    }
    
    // MARK: - Preference Key
    /// A preference key used to measure the width of the text.
    private struct TextWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
}
