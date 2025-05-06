//
//  EnhancedNotchlyLogoAnimation.swift
//  Notchly
//
//  Created by Mason Blumling on 5/5/25.
//

import SwiftUI
import Combine

/// An enhanced version of the NotchlyLogoAnimation with proper persistence
struct EnhancedNotchlyLogoAnimation: View {
    // Animation state variables
    @State private var nProgress = 0.0
    @State private var showRainbow = false
    @State private var gradientOffset = 0.0
    @State private var showFullText = false
    @State private var textProgress = 0.0
    @State private var logoShift: CGFloat = 0
    @State private var logoScale: CGFloat = 1.0
    @State private var notificationSubscription: AnyCancellable?
    
    // State persistence - critical!
    @State private var isAnimationComplete = false
    
    // Control parameters
    var startAnimation: Bool = true
    var coordinateWithNotch: Bool = false
    
    // Visual style
    private let style = StrokeStyle(lineWidth: 4, lineCap: .round)
    
    var body: some View {
        ZStack {
            // Logo N with persistent state
            Group {
                // White stroke path animation for N
                NotchlyLogoShape()
                    .trim(from: 0, to: nProgress)
                    .stroke(Color.white, style: style)
                    .opacity(showRainbow ? 0 : 1)
                
                // Rainbow gradient path with blur glow
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
            .frame(width: 80, height: 80)
            .offset(x: logoShift)
            
            // Text component
            if showFullText {
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
                    .offset(x: 90)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Important: Only start initial animation once
            if startAnimation && !isAnimationComplete {
                startAnimationSequence()
                isAnimationComplete = true
            }
            
            if coordinateWithNotch {
                // Set up notification observer for text reveal
                notificationSubscription = NotificationCenter.default
                    .publisher(for: Notification.Name("NotchlyRevealText"))
                    .receive(on: RunLoop.main)
                    .sink { _ in
                        revealText()
                    }
            }
        }
        .onDisappear {
            notificationSubscription?.cancel()
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimationSequence() {
        // Step 1: Draw the N with white stroke
        withAnimation(.easeInOut(duration: 3.0)) {
            nProgress = 1.0
        }
        
        // Step 2: Crossfade to rainbow
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 1.0)) {
                showRainbow = true
            }
            
            // Start the rainbow rotation animation
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                gradientOffset = 360
            }
        }
        
        // Skip auto-text reveal if coordinating with notch
        if !coordinateWithNotch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                revealText()
            }
        }
    }
    
    func revealText() {
        // Make text container visible but initially transparent
        showFullText = true
        textProgress = 0
        
        // First shift the logo left
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoShift = -90
            logoScale = 0.85
        }
        
        // Then fade in the text with slight delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 1.5)) {
                textProgress = 1.0
            }
        }
    }
}
