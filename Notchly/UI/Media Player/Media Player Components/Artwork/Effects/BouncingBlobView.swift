//
//  BouncingBlobView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

struct BouncingGlowBlob: View {
    var size: CGFloat = 150
    var color: Color = Color.blue.opacity(0.4)
    var blurRadius: CGFloat = 20

    @State private var position: CGPoint = .zero
    @State private var velocity: CGVector = CGVector(dx: 2, dy: 2)
    @State private var timer: Timer?

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

    private func startMotion(in containerSize: CGSize) {
        let maxX = containerSize.width
        let maxY = containerSize.height

        let minX = size / 2
        let maxXBound = maxX - size / 2
        let minY = size / 2
        let maxYBound = maxY - size / 2

        let safeX: CGFloat = minX <= maxXBound ? CGFloat.random(in: minX...maxXBound) : maxX / 2
        let safeY: CGFloat = minY <= maxYBound ? CGFloat.random(in: minY...maxYBound) : maxY / 2

        position = CGPoint(x: safeX, y: safeY)
        velocity = CGVector(
            dx: CGFloat.random(in: -2...2),
            dy: CGFloat.random(in: -2...2)
        )

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            updatePosition(in: containerSize)
        }
    }

    private func updatePosition(in containerSize: CGSize) {
        var newX = position.x + velocity.dx
        var newY = position.y + velocity.dy

        let minX = size / 2
        let maxX = containerSize.width - size / 2
        let minY = size / 2
        let maxY = containerSize.height - size / 2

        if newX < minX {
            newX = minX
            velocity.dx = -velocity.dx
        } else if newX > maxX {
            newX = maxX
            velocity.dx = -velocity.dx
        }

        if newY < minY {
            newY = minY
            velocity.dy = -velocity.dy
        } else if newY > maxY {
            newY = maxY
            velocity.dy = -velocity.dy
        }

        withAnimation(.linear(duration: 0.02)) {
            position = CGPoint(x: newX, y: newY)
        }
    }
}
