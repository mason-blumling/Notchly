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

    /// Use @State with initial random values for immediate visibility
    @State private var barHeights: [CGFloat] = (0..<6).map { _ in
        CGFloat.random(in: 3...12)
    }
    
    /// Track view lifecycle
    @State private var isVisible = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: barWidth, height: barHeights[i])
                    .animation(.linear(duration: updateInterval), value: barHeights[i])
            }
        }
        .frame(height: 24)
        .onAppear {
            isVisible = true
            startAnimation()
        }
        .onDisappear {
            isVisible = false
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func startAnimation() {
        /// Cancel any existing task first
        animationTask?.cancel()
        
        /// Create a new animation task
        animationTask = Task { @MainActor in
            /// Ensure we start with visible bars
            updateBarHeights()
            
            /// Continue animation while the view is visible
            while !Task.isCancelled && isVisible {
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
                if isVisible {
                    updateBarHeights()
                }
            }
        }
    }
    
    private func updateBarHeights() {
        barHeights = barHeights.map { _ in
            CGFloat.random(in: minHeight...maxHeight)
        }
    }
}
