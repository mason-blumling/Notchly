//
//  IntroTipsView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI

struct IntroTipsView: View {
    // MARK: - Dependencies
    let delegate: IntroViewDelegate
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            tipsContent(geometry: geometry)
        }
    }
    
    // MARK: - Content
    
    private func tipsContent(geometry: GeometryProxy) -> some View {
        let titleSize = min(geometry.size.width * 0.035, 22)
        let buttonTextSize = min(geometry.size.width * 0.025, 15)
        
        return VStack(spacing: geometry.size.height * 0.015) {
            Text("Quick Tips")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .overlay(
                    AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                        .mask(
                            Text("Quick Tips")
                                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        )
                )
                .padding(.top, geometry.size.height * 0.06)
            
            Spacer()
                .frame(height: geometry.size.height * 0.02)
                
            /// Center the cards with proper spacing
            HStack(spacing: min(geometry.size.width * 0.015, 10)) {
                Spacer()
                
                tipCard(
                    icon: "hand.point.up.fill",
                    title: "Hover to Expand",
                    description: "Move your cursor over the notch"
                )
                
                tipCard(
                    icon: "music.note",
                    title: "Media Controls",
                    description: "Control playback from your notch"
                )
                
                tipCard(
                    icon: "calendar",
                    title: "Calendar Alerts",
                    description: "Get alerts for upcoming events"
                )
                
                Spacer()
            }
            .padding(.horizontal, geometry.size.width * 0.02)
            
            Spacer()
                
            Button(action: { delegate.completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: buttonTextSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 30)
            }
            .buttonStyle(IntroHoverButtonStyle(
                foregroundColor: .black,
                backgroundColor: .white,
                hoverColor: Color.white.opacity(0.9)
            ))
            .padding(.bottom, geometry.size.height * 0.06)
        }
        .onAppear {
            delegate.updateIntroConfig(for: .tips)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - UI Components
    
    private func tipCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
            
            /// Title
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            /// Description
            Text(enhancedDescription(for: title))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 45)
                .lineLimit(4)
        }
        .frame(width: 200)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Helpers
    
    /// Helper function to provide enhanced descriptions
    private func enhancedDescription(for title: String) -> String {
        switch title {
        case "Hover to Expand":
            return "Glide your cursor over the notch to reveal Notchly."
        case "Media Controls":
            return "Play, pause, and skip right from your notch."
        case "Calendar Alerts":
            return "See upcoming events with real-time Live-Activities."
        default:
            return ""
        }
    }
}
