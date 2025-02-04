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
    @State private var pressedEventID: String?
    var calendarWidth: CGFloat // ✅ Ensures events fit within CalendarA dynamically

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if eventsForSelectedDate().isEmpty {
                emptyStateView()
            } else {
                eventListView()
            }
        }
    }
}

// MARK: - UI Components
private extension NotchlyEventList {
    
    func emptyStateView() -> some View {
        Text("No Events")
            .foregroundColor(.gray)
            .font(.caption)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }

    func eventListView() -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(eventsForSelectedDate(), id: \.eventIdentifier) { event in
                        eventRow(event: event)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 0) // ✅ Adds padding to expand width
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 🔥 Extended height
            .background(Color.clear)
            .scrollBounceBehavior(.always)
            .onAppear {
                DispatchQueue.main.async {
                    if let firstEvent = eventsForSelectedDate().first {
                        scrollProxy.scrollTo(firstEvent.eventIdentifier, anchor: .top)
                    }
                }
            }
        }
    }

    func eventRow(event: EKEvent) -> some View {
        HStack {
            eventIcon(event)
            eventDetails(event)
            Spacer()
            eventTime(event)
        }
        .padding(.horizontal, 12) // ✅ Increases padding for width
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity) // ✅ Forces event width to expand
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
        .scaleEffect(pressedEventID == event.eventIdentifier ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressedEventID)
        .onTapGesture {
            pressedEventID = event.eventIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pressedEventID = nil
            }
            openEventInCalendar(event)
        }
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
                .scaleEffect(pressedEventID == event.eventIdentifier ? 0.95 : 1.0)

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

// MARK: - Event Handling
private extension NotchlyEventList {
    /// 🔹 Opens the selected event in macOS Calendar (Supports Recurring Events)
    func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode event identifier: \(String(describing: event.title))")
            return
        }
        var urlString = "ical://ekevent/\(eventIdentifier)?method=show&options=more"
        // 🔥 If it's a recurring event, append the exact start date
        if event.hasRecurrenceRules, let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = event.isAllDay ? TimeZone.current : TimeZone(secondsFromGMT: 0)
            
            let dateComponent = formatter.string(from: startDate)
            urlString.insert(contentsOf: "/\(dateComponent)", at: urlString.index(urlString.startIndex, offsetBy: 14))
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            print("❌ Failed to create URL for event: \(String(describing: event.title))")
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
