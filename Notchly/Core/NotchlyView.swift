//
//  NotchlyView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import SwiftUI

/// `NotchlyView` represents the visual notch UI component inside the floating panel.
/// It dynamically expands or contracts based on hover interactions.
struct NotchlyView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var mediaMonitor = MediaPlaybackMonitor.shared

    // Debounce hover state changes
    @State private var debounceWorkItem: DispatchWorkItem?
    
    // MARK: - Matched Geometry for Seamless Expansion
    @Namespace private var notchAnimation

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
                    .fill(NotchlyTheme.background)
                    .frame(
                        width: notchly.isMouseInside ? notchly.notchWidth : NotchlyConfiguration.default.width,
                        height: notchly.isMouseInside ? notchly.notchHeight : NotchlyConfiguration.default.height
                    )
                    .animation(notchly.animation, value: notchly.isMouseInside)
                    .clipped()

                    /// 🔹 Media Player on Left, Calendar on Right
                    HStack(alignment: .center, spacing: 6) { // ✅ Set fixed spacing
                        Spacer()
                            .frame(width: 4)
                        
                        NotchlyMediaPlayer(isExpanded: notchly.isMouseInside, mediaMonitor: mediaMonitor)
                            .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                            .frame(
                                width: notchly.isMouseInside ? notchly.notchWidth * 0.42 : 0,
                                height: notchly.isMouseInside ? notchly.notchHeight - 5 : 0
                            )
                            .padding(.leading, 4) // 🔥 Adds balance by pushing it slightly right
                            .opacity(notchly.isMouseInside ? 1 : 0)
                            .clipped()
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                            .animation(NotchlyAnimations.quickTransition, value: notchly.isMouseInside)

                        Spacer()
                            .frame(width: 5)
                        
                        // ✅ Remove separate Spacer() and use padding instead
                        NotchlyCalendarView(calendarManager: calendarManager,
                                            isExpanded: notchly.isMouseInside)
                            .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                            .frame(
                                width: notchly.isMouseInside ? notchly.notchWidth * 0.50 : 0,
                                height: notchly.isMouseInside ? notchly.notchHeight - 5 : 0
                            )
                            .padding(.trailing, 4) // 🔥 Adds balance by pulling it slightly left
                            .opacity(notchly.isMouseInside ? 1 : 0)
                            .clipped()
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                            .animation(NotchlyAnimations.quickTransition, value: notchly.isMouseInside)
                    }
                    .frame(width: notchly.notchWidth, alignment: .center) // ✅ Forces full width of the Notch
                    .padding(.horizontal, 4) // ✅ Centers everything without shifting left
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
