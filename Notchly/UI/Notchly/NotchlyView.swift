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

                ZStack {
                    // 🔥 The Notch Shape (Handles expansion)
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
                    .clipped()

                    // 🔹 Positioning the Calendar Inside Notch
                    HStack(spacing: 0) {
                        Spacer(minLength: NotchPresets.small.width + 10) // ✅ Ensures space after small notch

                        NotchlyCalendarView(calendarManager: calendarManager, notchWidth: notchly.notchWidth, isExpanded: notchly.isMouseInside)
//                            .frame(
//                                width: notchly.notchWidth * 0.5, // ✅ Ensures it stays inside the notch
//                                height: notchly.notchHeight - 30)
                            .frame(width: NotchPresets.large.width * 0.48,
                                   height: notchly.notchHeight) // ✅ Matches notch height
                            .opacity(notchly.isMouseInside ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: notchly.isMouseInside) // ✅ More natural fade-in
                            .clipped()

                        Spacer() // ✅ Ensures right alignment doesn't overflow
                    }
                    .frame(width: notchly.notchWidth, alignment: .trailing)
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
