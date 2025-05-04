//
//  IntroView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI

/// A complete intro experience for first-time users.
/// Displays the animated logo, welcome text, and usage instructions.
struct IntroView: View {
    @ObservedObject private var coordinator = NotchlyViewModel.shared
    @State private var currentStage: IntroStage = .logo
    @State private var showContent = false
    
    /// Called when the intro sequence completes
    var onComplete: () -> Void
    
    // MARK: - Intro Stages
    
    private enum IntroStage {
        case logo           // Logo animation playing
        case welcome        // Welcome message
        case tips           // Usage tips
        case complete       // Ready to exit
    }
    
    var body: some View {
        NotchlyShapeView(
            configuration: coordinator.configuration,
            state: coordinator.state,
            animation: coordinator.animation
        ) { layout in
            ZStack {
                switch currentStage {
                case .logo:
                    logoStage(layout: layout)
                case .welcome:
                    welcomeStage(layout: layout)
                case .tips:
                    tipsStage(layout: layout)
                case .complete:
                    EmptyView()
                }
            }
            .frame(width: layout.contentWidth, height: layout.contentHeight)
        }
        .onAppear {
            startIntroSequence()
        }
    }
    
    // MARK: - Stage Views
    
    private func logoStage(layout: NotchlyLayoutGuide) -> some View {
        NotchlyLogoAnimation()
            .frame(
                width: layout.contentWidth * 0.7,
                height: layout.contentHeight * 0.5
            )
            .scaleEffect(showContent ? 1 : 0.5)
            .opacity(showContent ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
            }
    }
    
    private func welcomeStage(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 20) {
            Text("Welcome to Notchly")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Your MacBook notch, reimagined")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: { advanceStage() }) {
                Text("Next")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func tipsStage(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                tipRow(icon: "hand.point.up", text: "Hover over the notch to expand")
                tipRow(icon: "music.note", text: "Control your media playback")
                tipRow(icon: "calendar", text: "View upcoming events and alerts")
            }
            
            Button(action: { completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    // MARK: - Sequence Control
    
    private func startIntroSequence() {
        // Start with logo stage
        currentStage = .logo
        
        // After logo animation plays (about 5 seconds), advance to welcome
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            advanceStage()
        }
    }
    
    private func advanceStage() {
        withAnimation(.easeInOut(duration: 0.6)) {
            switch currentStage {
            case .logo:
                currentStage = .welcome
            case .welcome:
                currentStage = .tips
            case .tips:
                currentStage = .complete
            case .complete:
                completeIntro()
            }
        }
    }
    
    private func completeIntro() {
        // Animate out the intro content
        withAnimation(.easeIn(duration: 0.3)) {
            showContent = false
        }
        
        // Collapse the notch and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}

// MARK: - Preview

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView(onComplete: {})
            .frame(width: 800, height: 300)
            .background(Color.white)
            .previewLayout(.sizeThatFits)
    }
}
