//
//  BouncingBlobView.swift
//  Notchly
//
//  Created by Mason Blumling on 3/30/25.
//

import SwiftUI

struct BouncingGlowBlob: View {
    // Customize the blob’s appearance.
    var size: CGFloat = 150
    var color: Color = Color.blue.opacity(0.4)
    var blurRadius: CGFloat = 20

    // State variables to hold position and velocity.
    @State private var position: CGPoint = .zero
    @State private var velocity: CGVector = CGVector(dx: 2, dy: 2)
    
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .blur(radius: blurRadius)
                .position(position)
                .onAppear {
                    // Get container dimensions.
                    let maxX = geometry.size.width
                    let maxY = geometry.size.height
                    // Define safe bounds for x and y.
                    let minX = size / 2
                    let maxXBound = maxX - size / 2
                    let minY = size / 2
                    let maxYBound = maxY - size / 2
                    
                    // If the container is too small, default to the center.
                    let safeX: CGFloat = minX <= maxXBound ? CGFloat.random(in: minX...maxXBound) : maxX / 2
                    let safeY: CGFloat = minY <= maxYBound ? CGFloat.random(in: minY...maxYBound) : maxY / 2
                    
                    position = CGPoint(x: safeX, y: safeY)
                    
                    // Set a random initial velocity.
                    velocity = CGVector(
                        dx: CGFloat.random(in: -2...2),
                        dy: CGFloat.random(in: -2...2)
                    )
                    
                    // Start a timer to update the position.
                    Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                        // Calculate new position.
                        var newX = position.x + velocity.dx
                        var newY = position.y + velocity.dy
                        
                        // Bounce off the horizontal edges.
                        if newX < size / 2 {
                            newX = size / 2
                            velocity.dx = -velocity.dx
                        } else if newX > maxX - size / 2 {
                            newX = maxX - size / 2
                            velocity.dx = -velocity.dx
                        }
                        
                        // Bounce off the vertical edges.
                        if newY < size / 2 {
                            newY = size / 2
                            velocity.dy = -velocity.dy
                        } else if newY > maxY - size / 2 {
                            newY = maxY - size / 2
                            velocity.dy = -velocity.dy
                        }
                        
                        // Update the position with a linear animation.
                        withAnimation(.linear(duration: 0.02)) {
                            position = CGPoint(x: newX, y: newY)
                        }
                    }
                }
        }
    }
}

struct BouncingGlowBlob_Previews: PreviewProvider {
    static var previews: some View {
        BouncingGlowBlob()
            .frame(width: 300, height: 300)
    }
}
