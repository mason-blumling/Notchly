//
//  NotchlyCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//

import SwiftUI
import EventKit
import AppKit

/// Displays the calendar module inside the Notchly UI.
/// Integrates date selection and event listing, ensuring smooth UX with animations.
struct NotchlyCalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject private var coord = NotchlyViewModel.shared
    @State private var selectedDate: Date = Date()
    @State private var weatherInfo: WeatherData?

    var body: some View {
        /// Simplified layout
        VStack(alignment: .leading, spacing: 6) {
            /// Date selector
            NotchlyDateSelector(
                selectedDate: $selectedDate,
                calendarManager: calendarManager
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            /// Event list
            NotchlyEventList(
                selectedDate: selectedDate,
                calendarManager: calendarManager,
                calendarWidth: calendarWidth
            )
            .frame(maxHeight: .infinity)
        }
        /// push content down below the notch curve plus extra margin
        .padding(.top, coord.configuration.topCornerRadius)
        .padding(.horizontal, 8)
        .opacity(coord.state == .expanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: coord.state)
    }

    /// Calculates the width of the calendar section based on the notch config.
    private var calendarWidth: CGFloat {
        coord.configuration.width * 0.45
    }
}
