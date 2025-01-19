//
//  CalendarEventCard.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `CalendarEventCard` SwiftUI view, which represents a single calendar event.
//  The card displays the event's title, date, and time in a clean, structured format.
//

import SwiftUI
import EventKit // Provides access to EKEvent for calendar data
import Foundation

// MARK: - CalendarEventCard

/// A custom view for each event in the calendar.
struct CalendarEventCard: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(event.calendar?.cgColor ?? .clear)) // Handle `nil` calendar
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "No Title") // Fallback for `nil` title
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                if let startDate = event.startDate { // Handle `nil` startDate
                    Text(startDate, style: .time)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                } else {
                    Text("No Start Time")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Previews

/// A preview of the `CalendarEventCard` for SwiftUI canvas testing.
struct CalendarEventCard_Previews: PreviewProvider {
    static var previews: some View {
        CalendarEventCard(event: sampleEvent) // Provide a sample event for previews
            .previewLayout(.sizeThatFits) // Adapt the layout size to fit the content
    }

    // MARK: Sample Event
    /// A sample event for previewing purposes.
    static var sampleEvent: EKEvent {
        let eventStore = EKEventStore()
        let sampleEvent = EKEvent(eventStore: eventStore)
        sampleEvent.title = "Team Meeting"
        sampleEvent.startDate = Date()
        sampleEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        return sampleEvent
    }
}
