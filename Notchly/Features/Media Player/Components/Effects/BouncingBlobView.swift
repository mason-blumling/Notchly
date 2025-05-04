//
//  BouncingBlobView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

/// A soft glowing blob that bounces around its container using basic physics.
/// Used to add ambient motion effects to the background.
struct BouncingGlowBlob: View {
    var size: CGFloat = 150                          /// Diameter of the blob
    var color: Color = Color.blue.opacity(0.4)       /// Glow color
    var blurRadius: CGFloat = 20                     /// Blur amount for softness

    @State private var position: CGPoint = .zero     /// Current position of the blob
    @State private var velocity: CGVector = CGVector(dx: 2, dy: 2) /// Motion vector
    @State private var timer: Timer?                 /// Timer driving the motion

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: blurRadius)
                .position(position)
                .onAppear {
                    startMotion(in: geometry.size)
                }
                .onDisappear {
                    timer?.invalidate()
                    timer = nil
                }
        }
    }

    /// Initializes the blob's position and starts the bounce animation.
    private func startMotion(in containerSize: CGSize) {
        let maxX = containerSize.width
        let maxY = containerSize.height

        /// Define safe bounds to prevent the blob from exiting the frame
        let minX = size / 2
        let maxXBound = maxX - size / 2
        let minY = size / 2
        let maxYBound = maxY - size / 2

        /// Set a random starting position within the safe bounds
        let safeX: CGFloat = minX <= maxXBound ? CGFloat.random(in: minX...maxXBound) : maxX / 2
        let safeY: CGFloat = minY <= maxYBound ? CGFloat.random(in: minY...maxYBound) : maxY / 2
        position = CGPoint(x: safeX, y: safeY)

        /// Initialize with a random velocity vector
        velocity = CGVector(
            dx: CGFloat.random(in: -2...2),
            dy: CGFloat.random(in: -2...2)
        )

        /// Start update loop
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updatePosition(in: containerSize)
        }
    }

    /// Updates the blob’s position based on velocity, bouncing off the container edges.
    private func updatePosition(in containerSize: CGSize) {
        var newX = position.x + velocity.dx
        var newY = position.y + velocity.dy

        let minX = size / 2
        let maxX = containerSize.width - size / 2
        let minY = size / 2
        let maxY = containerSize.height - size / 2

        /// Bounce off horizontal edges
        if newX < minX {
            newX = minX
            velocity.dx = -velocity.dx
        } else if newX > maxX {
            newX = maxX
            velocity.dx = -velocity.dx
        }

        /// Bounce off vertical edges
        if newY < minY {
            newY = minY
            velocity.dy = -velocity.dy
        } else if newY > maxY {
            newY = maxY
            velocity.dy = -velocity.dy
        }

        /// Apply the new position with a smooth animation
        withAnimation(.linear(duration: 0.02)) {
            position = CGPoint(x: newX, y: newY)
        }
    }
}
