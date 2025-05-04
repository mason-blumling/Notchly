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
    @ObservedObject private var coord = NotchlyViewModel.shared

    var body: some View {
        NotchlyShapeView(
            configuration: coord.configuration,
            state: coord.state,
            animation: coord.animation
        ) { layout in
            VStack(spacing: 6) {
                NotchlyLogoAnimation()
                    .frame(
                        width: layout.contentWidth * 0.8,
                        height: layout.contentHeight * 0.5
                    )

                Text("Welcome to Notchly")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Button(action: onComplete) {
                    Text("Let's Go")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(
                width: layout.contentWidth * 0.9,
                height: layout.contentHeight * 0.9
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                /// switch into expanded so config = .large
                NotchlyViewModel.shared.state = .expanded
            }
            .previewLayout(.sizeThatFits)
    }
}
