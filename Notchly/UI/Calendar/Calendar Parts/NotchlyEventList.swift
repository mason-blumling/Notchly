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
    var calendarWidth: CGFloat // ✅ Ensures events fit dynamically

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
                .padding(.horizontal, 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

// MARK: - Event Row
private extension NotchlyEventList {
    
    func eventRow(event: EKEvent) -> some View {
        let isPending = isEventPending(event)
        let isAwaitingResponses = isEventAwaitingResponses(event)
        let hasPendingStatus = isPending || isAwaitingResponses

        return HStack {
            eventIcon(event)
            eventDetails(event, isPending: isPending, isAwaitingResponses: isAwaitingResponses)
            Spacer()
            eventTime(event)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray).opacity(hasPendingStatus ? 0.25 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasPendingStatus ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: hasPendingStatus ? 1.5 : 0.5)
                    )

                if hasPendingStatus {
                    StripedBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
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

// MARK: - Event Status Detection
private extension NotchlyEventList {
    
    func isEventPending(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }

        return attendees.contains { attendee in
            attendee.isCurrentUser &&
            (attendee.participantStatus == .pending ||
             attendee.participantStatus == .unknown)
        }
    }
    
    func isEventAwaitingResponses(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }

        let isOrganizer = event.organizer?.isCurrentUser ?? false
        
        return isOrganizer && attendees.contains { attendee in
            attendee.participantStatus == .pending || attendee.participantStatus == .unknown
        }
    }
    
    func awaitingAttendees(_ event: EKEvent) -> [String] {
        guard let attendees = event.attendees else { return [] }

        return attendees.compactMap { attendee in
            let firstName = attendee.name?.components(separatedBy: " ").first ?? "Unknown"
            return (attendee.participantStatus == .pending || attendee.participantStatus == .unknown) ? firstName : nil
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

    func eventDetails(_ event: EKEvent, isPending: Bool, isAwaitingResponses: Bool) -> some View {
        let awaitingNames = awaitingAttendees(event)

        return VStack(alignment: .leading, spacing: 2) {
            Text(event.title)
                .foregroundColor(event.status == .canceled ? .gray : .white)
                .lineLimit(1)
                .strikethrough(event.status == .canceled, color: .gray)
                .scaleEffect(pressedEventID == event.eventIdentifier ? 0.95 : 1.0)

            if isPending {
                Text("Pending Your Response")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            if isAwaitingResponses, !awaitingNames.isEmpty {
                Text("Waiting on \(awaitingNames.joined(separator: ", "))")
                    .foregroundColor(.blue)
                    .font(.caption)
            }

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

// MARK: - Striped Background for Pending Events
private extension NotchlyEventList {
    struct StripedBackground: View {
        var body: some View {
            Canvas { context, size in
                let stripeWidth: CGFloat = 6
                let spacing: CGFloat = 10

                for x in stride(from: -size.height, to: size.width, by: spacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth, y: size.height))

                    context.stroke(path, with: .color(Color(.systemGray).opacity(0.25)), lineWidth: 2)
                }
            }
            .opacity(0.3)
        }
    }
}

// MARK: - Event Handling
private extension NotchlyEventList {
    
    func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode event identifier: \(String(describing: event.title))")
            return
        }
        let urlString = "ical://ekevent/\(eventIdentifier)?method=show&options=more"

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
