//
//  IntroWelcomeView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI

struct IntroWelcomeView: View {
    // MARK: - Dependencies
    let delegate: IntroViewDelegate
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                /// Top logo - with appropriate spacing
                HStack {
                    Image(systemName: "macbook")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Notchly")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .overlay(
                            AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                                .mask(
                                    Text("Notchly")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                )
                        )
                }
                .padding(.top, 18)
                
                /// Title
                Text("Welcome to Notchly")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                /// Subtitle
                Text("Your MacBook notch, reimagined")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 3)
                
                /// Description
                Text("Transform the notch into a dynamic productivity hub with seamless controls for your media and calendar.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 80)
                    .padding(.top, 12)
                
                Spacer()
                
                /// Next button
                Button(action: { delegate.advanceStage() }) {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 30)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            delegate.updateIntroConfig(for: .welcome)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
