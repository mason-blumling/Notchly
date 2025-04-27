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
    @ObservedObject private var coord = NotchlyTransitionCoordinator.shared
    @State private var selectedDate: Date = Date()
    @State private var weatherInfo: WeatherData?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date selector
            NotchlyDateSelector(
                selectedDate: $selectedDate,
                calendarManager: calendarManager
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            // Event list
            NotchlyEventList(
                selectedDate: selectedDate,
                calendarManager: calendarManager,
                calendarWidth: calendarWidth
            )
            .frame(maxHeight: .infinity)
        }
        // **SIZE** driven by the central configuration
        .frame(
            width: calendarWidth,
            height: contentHeight
        )
        // push content down below the notch curve plus extra margin
        .padding(.top, safeTopInset)
        .background(NotchlyTheme.background)
        .opacity(coord.state == .expanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: coord.state)
        // **NO** .clipped() here — container’s clipShape will handle overflow
    }

    /// Calculates the width of the calendar section based on the notch config.
    private var calendarWidth: CGFloat {
        coord.configuration.width * 0.45
    }

    /// Additional vertical offset to avoid the notch curve.
    private var safeTopInset: CGFloat {
        coord.configuration.topCornerRadius + 15
    }

    /// Height for the content region excluding the top inset.
    private var contentHeight: CGFloat {
        coord.configuration.height - safeTopInset
    }
}
