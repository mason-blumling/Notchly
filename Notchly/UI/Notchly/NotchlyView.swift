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
    @StateObject private var calendarManager = CalendarManager() // 🔥 Persist CalendarManager

    // Debounce hover state changes
    @State private var debounceWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                // 🔥 The entire Notch is now responsible for hover detection & animations
                ZStack {
                    NotchlyShape(
                        bottomCornerRadius: notchly.configuration.bottomCornerRadius,
                        topCornerRadius: notchly.configuration.topCornerRadius
                    )
                    .fill(Color.black)
                    .frame(
                        width: notchly.isMouseInside ? notchly.notchWidth : NotchPresets.defaultNotch.width,
                        height: notchly.isMouseInside ? notchly.notchHeight : NotchPresets.defaultNotch.height
                    )
                    .animation(notchly.animation, value: notchly.isMouseInside
                    )
                    .clipped() // 🔥 Prevents any unwanted content bleed

                    // 🔥 Directly embed content inside the expanding notch
                    NotchlyCalendarView(calendarManager: calendarManager)
                        .frame(width: notchly.notchWidth - 30, height: notchly.notchHeight - 30)
                        .opacity(notchly.isMouseInside ? 1 : 0) // 🔥 Fade out at the right moment
                        .transition(.opacity.combined(with: .scale(scale: 0.9))) // 🔥 Fade *before* shrink
                        .animation(notchly.animation, value: notchly.isMouseInside)
                        .clipped() // 🔥 Ensures smooth expansion/shrink without overflow
                }
                .onHover { hovering in
                    debounceHover(hovering)
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            calendarManager.requestAccess { granted in
                print("Calendar Access: \(granted)")
            }
        }
    }

    // MARK: - Debounce Hover Detection

    /// Debounces hover events to prevent rapid state changes
    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                guard hovering != notchly.isMouseInside else { return }
                withAnimation(notchly.animation) {
                    notchly.isMouseInside = hovering
                    notchly.handleHover(expand: hovering)
                }
            }
        }
        
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
