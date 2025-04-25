//
//  OnboardingContentView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/24/25.
//

import SwiftUI

/// Wraps the notch shape and clamps the logo animation inside it.
struct OnboardingContentView<Content: View>: View {
    @ObservedObject var notchly: Notchly<Content>
    /// Called when the user taps "Let’s Go"
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background shape
            NotchlyShape(
                bottomCornerRadius: notchly.configuration.bottomCornerRadius,
                topCornerRadius:    notchly.configuration.topCornerRadius
            )
            .fill(NotchlyTheme.background)
            .frame(width: notchly.notchWidth, height: notchly.notchHeight)
            .shadow(color: NotchlyTheme.shadow, radius: notchly.configuration.shadowRadius)

            // Content clipped to the notch
            VStack(spacing: 6) {
                NotchlyLogoAnimation()
                    .frame(width: notchly.notchWidth * 0.8,
                           height: notchly.notchHeight * 0.5)
                    .clipShape(
                        NotchlyShape(
                            bottomCornerRadius: notchly.configuration.bottomCornerRadius,
                            topCornerRadius:    notchly.configuration.topCornerRadius
                        )
                    )

                Text("Welcome to Notchly")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Button(action: onComplete) {
                    Text("Let’s Go")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(width: notchly.notchWidth * 0.9,
                   height: notchly.notchHeight * 0.9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipShape(
                NotchlyShape(
                    bottomCornerRadius: notchly.configuration.bottomCornerRadius,
                    topCornerRadius:    notchly.configuration.topCornerRadius
                )
            )
        }
    }
}

// MARK: - Preview

struct OnboardingContentView_Previews: PreviewProvider {
    static var previews: some View {
        let config = NotchlyConfiguration.large
        
        // 1) Create a Notchly<EmptyView> so OnboardingContentView’s generic constraint is satisfied
        let sampleNotchly = Notchly<EmptyView> { EmptyView() }
        // 2) Match the “half-width by extra-height” dimensions you use in NotchlyLogoAnimation_Previews
        sampleNotchly.notchWidth  = config.width / 2
        sampleNotchly.notchHeight = config.height + 100
        sampleNotchly.configuration = config

        // 3) Render the OnboardingContentView inside a matching notch frame
        return OnboardingContentView(notchly: sampleNotchly, onComplete: { })
            .frame(width: sampleNotchly.notchWidth,
                   height: sampleNotchly.notchHeight)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
