//
//  NotchlyTimelineCalendarIntegrator.swift
//  Notchly
//
//  Created by Mason Blumling on 5/11/25.
//

import SwiftUI
import EventKit

/// Handles integrating the timeline-style calendar view into Notchly
/// Maintains identical animation behavior and state handling to the block calendar
struct NotchlyTimelineCalendarIntegrator: View {
    // MARK: - Properties
    
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject private var coord = NotchlyViewModel.shared
    @State private var selectedDate: Date = Date()
    
    // MARK: - Body
    
    var body: some View {
        /// Direct measurement to ensure proper sizing
        GeometryReader { geometry in
            NotchlyMinimalistCalendarView(
                calendarManager: calendarManager,
                topRadius: coord.configuration.topCornerRadius,
                width: geometry.size.width - 16 /// Account for horizontal padding
            )
        }
        /// Important: Match padding exactly with block calendar
        .padding(.horizontal, 8)
        
        /// Use the same transition as the block calendar
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
        .animation(NotchlyAnimations.smoothTransition, value: coord.state)
        .opacity(coord.state == .expanded ? 1 : 0)
        
        /// Listen for calendar setting changes
        .onReceive(NotificationCenter.default.publisher(for: SettingsChangeType.calendar.notificationName)) { _ in
            /// Force a refresh when calendar settings change
            NotchlyLogger.calendar("Calendar settings changed - refreshing view")
        }
    }
}
