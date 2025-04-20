//
//  AudioBarsView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/17/25.
//

import SwiftUI

// MARK: - AudioBarsView: Animated audio bars that pulsate.
struct AudioBarsView: View {
    private let barCount = 6
    private let barWidth: CGFloat = 2
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 12
    private let spacing: CGFloat = 2
    private let updateInterval: TimeInterval = 0.15

    @State private var barHeights: [CGFloat] = Array(repeating: 6, count: 6)
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: barWidth, height: barHeights[i])
                    .animation(.linear(duration: updateInterval), value: barHeights[i])
            }
        }
        .frame(height: 24)
        .onAppear {
            animationTask = Task {
                await animateLoop()
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func animateLoop() async {
        while !Task.isCancelled {
            await MainActor.run {
                barHeights = barHeights.map { _ in
                    CGFloat.random(in: minHeight...maxHeight)
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
        }
    }
}
