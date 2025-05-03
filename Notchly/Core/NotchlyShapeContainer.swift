//
//  NotchlyShapeContainer.swift
//  Notchly
//
//  Created by Mason Blumling on 5/2/25.
//

import Foundation
import SwiftUI

struct NotchlyShapeContainer<Content: View>: View {
    let configuration: NotchlyConfiguration
    let state: NotchlyTransitionCoordinator.NotchState
    let animation: Animation
    let content: (NotchlyLayoutGuide) -> Content
    var namespace: Namespace.ID?
    
    var body: some View {
        // Calculate layout guide
        let layoutGuide = createLayoutGuide()
        
        // Container with shape and content
        ZStack(alignment: .top) {
            // Background shape
            NotchlyShape(
                bottomCornerRadius: configuration.bottomCornerRadius,
                topCornerRadius: configuration.topCornerRadius
            )
            .fill(NotchlyTheme.background)
            .frame(
                width: configuration.width,
                height: configuration.height
            )
            .shadow(color: NotchlyTheme.shadow, radius: configuration.shadowRadius)
            .animation(animation, value: configuration)
            
            // Content positioned with layout guide
            content(layoutGuide)
                .frame(
                    width: configuration.width,
                    height: configuration.height
                )
        }
        .frame(
            width: configuration.width,
            height: configuration.height
        )
        .clipShape(
            NotchlyShape(
                bottomCornerRadius: configuration.bottomCornerRadius,
                topCornerRadius: configuration.topCornerRadius
            )
        )
    }
    
    // Create layout guide from current configuration with more precise values
    private func createLayoutGuide() -> NotchlyLayoutGuide {
        let insetTop = configuration.topCornerRadius * 0.65 // Reduce top inset
        let insetSide = configuration.bottomCornerRadius * 0.4 // Reduce side inset
        
        return NotchlyLayoutGuide(
            bounds: CGRect(origin: .zero, size: CGSize(
                width: configuration.width,
                height: configuration.height
            )),
            safeBounds: CGRect(
                x: insetSide,
                y: insetTop,
                width: configuration.width - (insetSide * 2),
                height: configuration.height - insetTop - insetSide
            ),
            state: state
        )
    }
}
