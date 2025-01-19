//
//  ContentView.swift
//  Notchly
//
//  Created by Mason Blumling on 12/10/24.
//

import SwiftUI
import EventKit

// MARK: - ContentView

struct ContentView: View {

    // MARK: - Properties

    /// An instance of `CalendarManager` to manage events.
    private let calendarManager = CalendarManager()

    /// Grouped calendar events by date (Accounts for several events on a single date)
    @State private var groupedEvents: [Date: [EKEvent]] = [:]

    /// Tracks the maximum height of the event cards for uniform sizing.
    @State private var maxHeight: CGFloat = 0

    // MARK: - Body

    var body: some View {
        VStack {
            Text("Upcoming Events")
                .font(.headline)
                .padding()

            if groupedEvents.isEmpty {
                Text("No upcoming events")
                    .foregroundColor(.gray)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(groupedEvents.keys.sorted(), id: \.self) { date in
                            Section(header: Text(date, style: .date).bold()) {
                                ForEach(groupedEvents[date] ?? [], id: \.eventIdentifier) { event in
                                    CalendarEventCard(event: event)
                                        .background(
                                            GeometryReader { geometry in
                                                Color.clear
                                                    .preference(key: MaxHeightPreferenceKey.self, value: geometry.size.height)
                                            }
                                        )
                                        .frame(height: maxHeight)
                                }
                            }
                        }
                    }
                    .padding()
                    .onPreferenceChange(MaxHeightPreferenceKey.self) { maxHeight = $0 }
                }
                .frame(height: 200)
            }

            Spacer()
        }
        .padding()
        .frame(width: 350, height: 300)
        .onAppear(perform: loadEvents)
    }

    // MARK: - Methods

    /// Requests access to the calendar and fetches events.
    private func loadEvents() {
        calendarManager.requestAccess { granted in
            guard granted else { return }
            let now = Date()
            guard let oneWeekLater = Calendar.current.date(byAdding: .day, value: 7, to: now) else { return }
            let events = calendarManager.fetchEvents(startDate: now, endDate: oneWeekLater)
            groupedEvents = calendarManager.groupEventsByDate(events)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
