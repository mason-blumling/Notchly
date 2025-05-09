//
//  IntroLogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI

/// Displays the animated N logo with transitions from white to rainbow to full 'Notchly' name.
struct IntroLogoAnimation: View {
    @Binding var state: IntroView.LogoAnimationState
    
    // MARK: - Animation State
    @State private var nProgress = 0.0           /// Trimmed stroke progress for 'N'
    @State private var showRainbow = false       /// Toggle for rainbow mode
    @State private var gradientOffset = 0.0      /// Angular gradient animation
    @State private var showFullText = false      /// Toggle for showing full 'Notchly'
    @State private var textProgress = 0.0        /// Opacity progress of text
    @State private var logoShift: CGFloat = 0    /// Horizontal shift during logo animation
    @State private var logoScale: CGFloat = 1.0  /// Scaling animation for logo
    
    // MARK: - Style
    private let style = StrokeStyle(lineWidth: 5, lineCap: .round)
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width * 0.3, 120)       /// Max logo size
            let fontSize = min(geometry.size.width * 0.12, 46)   /// Max font size
            
            ZStack {
                Group {
                    /// Base white 'N' stroke
                    NotchlyLogoShape()
                        .trim(from: 0, to: nProgress)
                        .stroke(Color.white, style: style)
                        .opacity(showRainbow ? 0 : 1)
                    
                    /// Rainbow animated stroke with blur glow layers
                    if showRainbow {
                        let base = NotchlyLogoShape()
                            .trim(from: 0, to: nProgress)
                            .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)
                        
                        base.blur(radius: 5)
                        base.blur(radius: 2)
                        base
                    }
                }
                .scaleEffect(logoScale)
                .frame(width: size, height: size)
                .offset(x: logoShift)
                
                /// "otchly" label animation after logo reveals
                if showFullText {
                    Text("otchly")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textProgress)
                        .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
                        .overlay(
                            Text("otchly")
                                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .blur(radius: 3)
                                .offset(x: 0, y: 1)
                                .mask(
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.white, .clear]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .scaleEffect(x: textProgress * 2)
                                )
                        )
                        .offset(x: size * 0.6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: state) { _, newState in
                updateAnimationForState(newState, size: size)
            }
            .onAppear {
                /// Start animation if state is .initial
                if state == .initial {
                    state = .drawingN
                }
            }
        }
    }
    
    /// Updates internal animation states when the external `state` changes
    private func updateAnimationForState(_ newState: IntroView.LogoAnimationState, size: CGFloat) {
        switch newState {
        case .initial:
            /// Reset all values
            nProgress = 0
            showRainbow = false
            showFullText = false
            textProgress = 0
            logoShift = 0
            logoScale = 1.0
            
        case .drawingN:
            /// Play the N animation sound
            AudioPlayer.shared.playSound(named: "light-brand-ident-swoop")
            
            /// Animate drawing stroke
            withAnimation(.easeInOut(duration: 3.75)) {
                nProgress = 1.0
            }
            
        case .showRainbow:
            /// Fade in rainbow stroke
            withAnimation(.easeInOut(duration: 0.85)) {
                showRainbow = true
            }
            
            /// Spin the angular gradient continuously
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
            
        case .showFullName:
            /// Animate logo shifting left
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                logoShift = -size * 0.5
                logoScale = 0.9
            }
            
            showFullText = true
            textProgress = 0
            
            /// Reveal text after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 1.2)) {
                    textProgress = 1.0
                }
            }
        }
    }
}
