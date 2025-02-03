//
//  NotchlyEventList.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import SwiftUI
import EventKit

struct NotchlyEventList: View {
    var selectedDate: Date
    @ObservedObject var calendarManager: CalendarManager
    var calendarWidth: CGFloat // ✅ Ensures events fit within CalendarA dynamically


    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if eventsForSelectedDate().isEmpty {
                emptyStateView()
            } else {
                eventListView()
            }
        }
        .frame(width: calendarWidth, alignment: .trailing) // ✅ Matches the date selector width
    }
}

// MARK: - UI Components
private extension NotchlyEventList {
    
    func emptyStateView() -> some View {
        VStack {
            Spacer()
            Text("No Events")
                .foregroundColor(.gray)
                .font(.caption)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
            Spacer()
        }
        .frame(maxHeight: .infinity) // 🔥 Matches event list dynamically
    }

    func eventListView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(eventsForSelectedDate(), id: \.eventIdentifier) { event in
                    eventRow(event: event)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: calendarWidth, alignment: .trailing) // ✅ Prevents right overflow
        .padding(.leading, 5) // ✅ Nudges it slightly right to align exactly
        .scrollBounceBehavior(.always)
    }

    func eventRow(event: EKEvent) -> some View {
        HStack(alignment: .center, spacing: 6) {
            eventIcon(event)
            eventDetails(event)
            Spacer()
            eventTime(event)
        }
        .padding(.horizontal, 6) // ✅ Matches "No Events" padding
        .padding(.vertical, 4)
        .frame(width: calendarWidth * 0.9, alignment: .leading) // ✅ Ensures events fit perfectly
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray).opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

// MARK: - Event UI Elements
private extension NotchlyEventList {
    
    func eventIcon(_ event: EKEvent) -> some View {
        Circle()
            .fill(event.calendar.cgColor.map { Color($0) } ?? .red)
            .frame(width: 10, height: 10)
    }

    func eventDetails(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .foregroundColor(event.status == .canceled ? .gray : .white)
                .lineLimit(1)
                .strikethrough(event.status == .canceled, color: .gray)

            if let attendees = event.attendees, !attendees.isEmpty {
                Text("\(attendees.count) attendees")
                    .foregroundColor(.gray)
                    .font(.caption)
            }

            if event.status == .canceled {
                Text("(Cancelled)")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }

    func eventTime(_ event: EKEvent) -> some View {
        Text(event.isAllDay ? "All Day" : event.startDate.formatted(date: .omitted, time: .shortened))
            .foregroundColor(.gray)
            .font(.caption)
    }
}

// MARK: - Open Event in Calendar
private extension NotchlyEventList {
    func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        var urlString = "ical://ekevent/\(eventIdentifier)?method=show&options=more"

        if event.hasRecurrenceRules, let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = event.isAllDay ? TimeZone.current : TimeZone(secondsFromGMT: 0)
            let dateComponent = formatter.string(from: startDate)
            urlString.insert(contentsOf: "/\(dateComponent)", at: urlString.index(urlString.startIndex, offsetBy: 14))
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Event Filtering
private extension NotchlyEventList {
    func eventsForSelectedDate() -> [EKEvent] {
        calendarManager.events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }
    }
}
