//
//  NotchView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import SwiftUI

/// `NotchView` represents the visual notch UI component inside the floating panel.
/// It dynamically expands or contracts based on hover interactions.
struct NotchView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>

    // MARK: - Default & Expanded Dimensions

    /// Default (collapsed) size of the notch. (Measured to the same size as MBP 16' Notch)
    /// Width: 199, Height: 31.75
    private let defaultWidth: CGFloat = 199
    private let defaultHeight: CGFloat = 31.75
    
    /// Expanded size of the notch when hovered.
    private let expandedWidth: CGFloat = 500
    private let expandedHeight: CGFloat = 250

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                // ZStack to layer the Notch shape and hover detection area
                ZStack {
                    notchShape() // Main Notch UI
                    notchly.content() // 🔥 Add the content inside the notch
                        .frame(width: notchly.notchWidth - 20, height: notchly.notchHeight - 20) // Prevents clipping
                        .opacity(notchly.isMouseInside ? 1 : 0) // Optional: fades in
                        .animation(notchly.animation, value: notchly.isMouseInside)
                    hoverDetectionArea() // Invisible area for mouse tracking
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top) // 🔥 Ensures the Notch stays pinned at the top
    }

    // MARK: - Notch UI

    /// Creates the notch shape with dynamic expansion on hover.
    private func notchShape() -> some View {
        NotchlyShape(
            bottomCornerRadius: notchly.configuration.bottomCornerRadius,
            topCornerRadius: notchly.configuration.topCornerRadius
        )
        .fill(Color.black)
        .frame(
            width: notchly.isMouseInside ? notchly.notchWidth : NotchPresets.defaultNotch.width,
            height: notchly.isMouseInside ? notchly.notchHeight : NotchPresets.defaultNotch.height
        )
        .animation(notchly.animation, value: notchly.isMouseInside)
        .shadow(color: .black.opacity(0.5), radius: notchly.isMouseInside ? 10 : 0)
    }

    // MARK: - Hover Detection

    /// Creates an invisible area matching the notch size to detect hover interactions.
    private func hoverDetectionArea() -> some View {
        Color.clear
            .contentShape(Rectangle()) // Ensures the hover area matches the frame
            .frame(
                width: notchly.isMouseInside ? notchly.notchWidth : NotchPresets.defaultNotch.width,
                height: notchly.isMouseInside ? notchly.notchHeight : NotchPresets.defaultNotch.height
            )
            .onHover { hovering in
                DispatchQueue.main.async {
                    notchly.isMouseInside = hovering
                    notchly.handleHover(expand: hovering)
                }
            }
    }
}
