//
//  NotchlyCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//
//  This view displays a compact calendar within the Notchly UI.
//  It includes a date selector, an event list, and adapts dynamically
//  to the notch expansion state.
//

import SwiftUI
import EventKit
import AppKit

/// Displays the calendar module inside the Notchly UI.
/// Integrates date selection and event listing, ensuring smooth UX with animations.
struct NotchlyCalendarView: View {
    
    // MARK: - Properties

    @ObservedObject var calendarManager: CalendarManager /// Handles fetching and managing calendar events.
    @State private var selectedDate: Date = Date() /// The currently selected date.
    @State private var weatherInfo: WeatherData? /// Stores fetched weather data for the selected date (future implementation).
    var isExpanded: Bool /// Indicates whether the notch is expanded, controlling visibility.

    // Shared transition coordinator for dynamic sizing
    @ObservedObject private var coord = NotchlyTransitionCoordinator.shared

    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            // MARK: - Date Selector (Fixed)
            VStack(spacing: 2) {
                Spacer(minLength: 2)
                NotchlyDateSelector(selectedDate: $selectedDate,
                                    calendarManager: calendarManager)
            }
            .frame(maxWidth: .infinity, alignment: .leading) /// Locks left alignment

            // MARK: - Event List
            NotchlyEventList(
                selectedDate: selectedDate,
                calendarManager: calendarManager,
                calendarWidth: calendarWidth
            )
            .frame(maxHeight: .infinity) /// Expands dynamically but stays within bounds
        }
        .frame(
            width: calendarWidth,
            height: isExpanded
                ? coord.configuration.height - 25  /// match container inset
                : 0 /// ✅ Prevents incorrect expansion
        )
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: isExpanded)
    }
    
    // MARK: - Computed Properties
    
    /// Dynamically calculates the width of the calendar section.
    private var calendarWidth: CGFloat {
        coord.configuration.width * 0.45
    }
}
