//
//  OnboardingContentView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/24/25.
//

import SwiftUI

/// Wraps the notch shape and clamps the logo animation inside it, driven by the shared transition coordinator.
struct OnboardingContentView: View {
    /// Called when the user taps "Let’s Go"
    var onComplete: () -> Void

    // Central transition coordinator for notch sizing
    @ObservedObject private var coord = NotchlyTransitionCoordinator.shared

    var body: some View {
        let config = coord.configuration

        ZStack {
            // Background shape
            NotchlyShape(
                bottomCornerRadius: config.bottomCornerRadius,
                topCornerRadius:    config.topCornerRadius
            )
            .fill(NotchlyTheme.background)
            .frame(width: config.width, height: config.height)
            .shadow(color: NotchlyTheme.shadow, radius: config.shadowRadius)

            // Content clipped to the notch
            VStack(spacing: 6) {
                NotchlyLogoAnimation()
                    .frame(
                        width: config.width * 0.8,
                        height: config.height * 0.5
                    )
                    .clipShape(
                        NotchlyShape(
                            bottomCornerRadius: config.bottomCornerRadius,
                            topCornerRadius:    config.topCornerRadius
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
            .frame(
                width: config.width * 0.9,
                height: config.height * 0.9
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipShape(
                NotchlyShape(
                    bottomCornerRadius: config.bottomCornerRadius,
                    topCornerRadius:    config.topCornerRadius
                )
            )
        }
    }
}

// MARK: - Preview

struct OnboardingContentView_Previews: PreviewProvider {
    static var previews: some View {
        let config = NotchlyConfiguration.large

        OnboardingContentView(onComplete: {})
            .frame(width: config.width, height: config.height)
            .background(Color.black)
            .onAppear {
                // Ensure the coordinator uses the large config for preview
                NotchlyTransitionCoordinator.shared.transition(to: config)
            }
            .previewLayout(.sizeThatFits)
    }
}
