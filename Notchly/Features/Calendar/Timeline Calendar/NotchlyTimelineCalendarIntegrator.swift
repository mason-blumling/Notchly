//
//  NotchlyTimelineCalendarIntegrator.swift
//  Notchly
//
//  Created by Mason Blumling on 5/15/25.
//

import SwiftUI
import AppKit

/// Handles integrating the timeline-style calendar view into Notchly
struct NotchlyTimelineCalendarIntegrator: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject private var coord = NotchlyViewModel.shared
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        TimelineCalendarNSView(
            calendarManager: calendarManager,
            selectedDate: $selectedDate,
            topRadius: coord.configuration.topCornerRadius,
            width: coord.configuration.width * 0.45,
            state: coord.state
        )
        /// CRITICAL FIX: Only disable hit testing when the calendar is not in expanded state
        /// This ensures full interactivity when visible, but prevents hover events when collapsed
        .allowsHitTesting(coord.state == .expanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        .opacity(coord.state == .expanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: coord.state)
    }
}
