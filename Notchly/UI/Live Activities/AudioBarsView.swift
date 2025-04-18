//
//  AudioBarsView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/17/25.
//

import SwiftUI

// MARK: - AudioBarsView: Animated audio bars that pulsate.
struct AudioBarsView: View {
    @State private var barHeights: [CGFloat] = [6, 8, 7, 9, 8, 7]
    private let barCount = 6
    private let minBarHeight: CGFloat = 3
    private let maxBarHeight: CGFloat = 12
    private let barWidth: CGFloat = 2
    private let animationDuration: Double = 0.25

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .frame(height: 24)
        .onAppear {
            startAnimating()
        }
    }

    private func startAnimating() {
        Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: true) { _ in
            withAnimation(.easeInOut(duration: animationDuration)) {
                barHeights = (0..<barCount).map { _ in
                    CGFloat.random(in: minBarHeight...maxBarHeight)
                }
            }
        }
    }
}
