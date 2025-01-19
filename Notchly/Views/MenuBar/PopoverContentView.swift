//
//  PopoverContentView.swift
//  Notchly
//
//  Created by Mason Blumling on January 19, 2025.
//
//  This file defines the `PopoverContentView`, a SwiftUI view displayed in the popover.
//  It dynamically displays a list of calendar events.
//

import SwiftUI
import EventKit

// MARK: - PopoverContentView

/// A SwiftUI view that displays a list of calendar events in a pill-shaped popover.
struct PopoverContentView: View {
    let groupedEvents: [Date: [EKEvent]] // Accept grouped events as input

    var body: some View {
        VStack(spacing: 0) {
            if groupedEvents.isEmpty {
                Text("No upcoming events")
                    .foregroundColor(.gray)
                    .font(.system(size: 14, weight: .medium))
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(date, style: .date)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)

                                ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                                    CalendarEventCard(event: event)
                                }

                                Divider()
                                    .background(Color.white.opacity(0.2))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 400) // Limit height for the popover
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }
}

// MARK: - Previews

struct PopoverContentView_Previews: PreviewProvider {
    static var previews: some View {
        PopoverContentView(groupedEvents: [
            Calendar.current.startOfDay(for: Date()): sampleEvents
        ])
        .frame(width: 300)
        .previewLayout(.sizeThatFits)
        .background(Color.gray)
    }

    static var sampleEvents: [EKEvent] {
        let eventStore = EKEventStore()

        let event1 = EKEvent(eventStore: eventStore)
        event1.title = "Team Meeting"
        event1.startDate = Date()
        event1.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())

        let event2 = EKEvent(eventStore: eventStore)
        event2.title = "Doctor's Appointment"
        event2.startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        event2.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event2.startDate!)

        return [event1, event2]
    }
}
