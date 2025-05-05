//
//  EnhancedNotchlyLogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 5/5/25.
//

import SwiftUI

/// An enhanced version of the NotchlyLogoAnimation that draws an "N"
/// and then reveals the rest of the "otchly" text with smooth animations
struct EnhancedNotchlyLogoAnimation: View {
    // Animation state variables
    @State private var nProgress = 0.0                 // Progress of N drawing (0-1)
    @State private var showRainbow = false             // Controls rainbow effect
    @State private var gradientOffset = 0.0            // For rotating gradient effect
    @State private var showFullText = false            // Controls "otchly" text visibility
    @State private var textProgress = 0.0              // Text reveal animation (0-1)
    @State private var logoShift: CGFloat = 0          // Controls horizontal shift of the N
    @State private var logoScale: CGFloat = 0.75       // Controls scaling of the N - REDUCED SIZE
    
    // Visual style - THINNER LINE for better proportion
    private let style = StrokeStyle(lineWidth: 4, lineCap: .round)
    
    // Animation timing
    private let nDrawDuration: Double = 3.0
    private let rainbowFadeDuration: Double = 1.0
    private let fullTextDelay: Double = 4.5
    private let textRevealDuration: Double = 1.5
    private let logoShiftDelay: Double = 6.0
    private let logoShiftDuration: Double = 0.8
    
    // Control flag to determine if animations should start
    var startAnimation: Bool = true
    
    var body: some View {
        ZStack {
            // MARK: - N Logo
            
            Group {
                // Step 1: White stroke path animation for N
                NotchlyLogoShape()
                    .trim(from: 0, to: nProgress)
                    .stroke(Color.white, style: style)
                    .opacity(showRainbow ? 0 : 1)
                
                // Step 2: Rainbow gradient path with blur glow
                if showRainbow {
                    let base = NotchlyLogoShape()
                        .trim(from: 0, to: nProgress)
                        .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)
                    
                    // Add blur for glow effect
                    base.blur(radius: 5)
                    base.blur(radius: 2)
                    base // Crisp outline on top
                }
            }
            .scaleEffect(logoScale)  // Start with a smaller scale
            .offset(x: logoShift)
            
            // MARK: - "otchly" Text
            
            if showFullText {
                HStack(spacing: 0) {
                    // Empty space where the N would be - INCREASED SPACING
                    Spacer()
                        .frame(width: 85) // Wider gap between N and "otchly"
                    
                    // The "otchly" text - ADJUSTED FONT SIZE
                    Text("otchly")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textProgress)
                        .mask(
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.white, .clear]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .scaleEffect(x: textProgress * 2)
                        )
                }
                .padding(.leading, 40) // INCREASED PADDING
            }
        }
        .onAppear {
            // Only start animations when instructed (and only in the logoStageView)
            if startAnimation {
                startAnimationSequence()
            }
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimationSequence() {
        // Step 1: Draw the N with white stroke
        withAnimation(.easeInOut(duration: nDrawDuration)) {
            nProgress = 1.0
        }
        
        // Step 2: Crossfade to rainbow
        DispatchQueue.main.asyncAfter(deadline: .now() + nDrawDuration) {
            withAnimation(.easeInOut(duration: rainbowFadeDuration)) {
                showRainbow = true
            }
            
            // Start the rainbow rotation animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
        
        // Step 3: Show the "otchly" text with reveal animation
        DispatchQueue.main.asyncAfter(deadline: .now() + fullTextDelay) {
            showFullText = true
            withAnimation(.easeInOut(duration: textRevealDuration)) {
                textProgress = 1.0
            }
        }
        
        // Step 4: Shift the N logo to the left and scale it down slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + logoShiftDelay) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoShift = -110 // INCREASED SHIFT
                logoScale = 0.65 // FURTHER REDUCE SCALE DURING SHIFT
            }
        }
    }
}
