//
//  NotchlyEventList.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import SwiftUI
import EventKit

// MARK: - Event List View
struct NotchlyEventList: View {
    @State var cachedUserEmails: Set<String> = []
    var selectedDate: Date
    @ObservedObject var calendarManager: CalendarManager
    var calendarWidth: CGFloat
    @State private var pressedEventID: String?

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
        .drawingGroup() /// Offloads rendering workload to GPU
        .opacity(0.3)
    }
}

// MARK: - UI Components
private extension NotchlyEventList {
    
    /// Displays a placeholder when no events exist for the selected date.
    func emptyStateView() -> some View {
        Text("No Events")
            .foregroundColor(.gray)
            .font(.caption)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }

    /// Displays the list of events, handling conflicts visually.
    func eventListView() -> some View {
        let conflicts = detectConflictingEvents()

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(eventsWithConflicts(), id: \.self) { item in
                    if let event = item as? EKEvent {
                        eventRow(event: event, isConflicting: conflicts.contains(event.eventIdentifier))
                    } else if let conflictInfo = item as? ConflictInfo {
                        conflictRow(conflictInfo)
                    }
                }
            }
            .drawingGroup() /// Forces SwiftUI to rasterize complex views for better performance
            .padding(.vertical, 4)
            .padding(.horizontal, 0)
        }
    }
}

// MARK: - Event Row
private extension NotchlyEventList {
    
    /// Displays an individual event row.
    func eventRow(event: EKEvent, isConflicting: Bool) -> some View {
        let isPending = isEventPending(event)
        let isAwaitingResponses = isEventAwaitingResponses(event)

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
                let hasPendingStatus = isPending || isAwaitingResponses

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray).opacity(hasPendingStatus ? 0.25 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isConflicting ? Color.red.opacity(0.8) : (hasPendingStatus ? Color.yellow.opacity(0.8) : Color.clear),
                                    lineWidth: isConflicting ? 2 : (hasPendingStatus ? 1.5 : 0.5))
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
        .animation(NotchlyAnimations.fastBounce, value: pressedEventID)
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

    /// Generates the event icon (colored dot).
    func eventIcon(_ event: EKEvent) -> some View {
        Circle()
            .fill(event.calendar.cgColor.map { Color($0) } ?? .red)
            .frame(width: 10, height: 10)
    }

    /// Displays the event title, status, and other details.
    func eventDetails(_ event: EKEvent, isPending: Bool, isAwaitingResponses: Bool) -> some View {
        let settings = NotchlySettings.shared
        let awaitingNames = settings.showEventAttendees ? awaitingAttendees(event) : []
        let declinedNames = settings.showEventAttendees ? declinedAttendees(event) : []
        let maybeNames = settings.showEventAttendees ? maybeAttendees(event) : []
        let organizer = settings.showEventOrganizer ? eventOrganizer(event) : nil
        let eventLocation = settings.showEventLocation ? event.location?.trimmingCharacters(in: .whitespacesAndNewlines) : nil

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

            if isAwaitingResponses, !awaitingNames.isEmpty, settings.showEventAttendees {
                Text("Waiting on \(awaitingNames.joined(separator: ", "))")
                    .foregroundColor(.blue)
                    .font(.caption)
            }

            if !declinedNames.isEmpty && settings.showEventAttendees {
                Text("❌ Declined: \(declinedNames.joined(separator: ", "))")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if !maybeNames.isEmpty && settings.showEventAttendees {
                Text("🤔 Maybe: \(maybeNames.joined(separator: ", "))")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }

            /// 👤 Show organizer ONLY if it is NOT the user AND setting is enabled
            if let organizer, !organizer.isEmpty, settings.showEventOrganizer {
                Text("Organizer: \(organizer)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }

            /// 📍 Show location if available AND setting is enabled
            if let location = eventLocation, !location.isEmpty, settings.showEventLocation {
                Text("📍 \(location)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }

    /// Displays the event time.
    func eventTime(_ event: EKEvent) -> some View {
        Text(event.isAllDay ? "All Day" : event.startDate.formatted(date: .omitted, time: .shortened))
            .foregroundColor(.gray)
            .font(.caption)
    }
}

// MARK: - Event Filtering & Handling
extension NotchlyEventList {
    
    /// Retrieves events for the selected date.
    func eventsForSelectedDate() -> [EKEvent] {
        let settings = NotchlySettings.shared
        let maxEvents = settings.maxEventsToDisplay
        
        let events = calendarManager.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
        
        // Apply limit from settings
        if events.count > maxEvents {
            return Array(events.prefix(maxEvents))
        }
        
        return events
    }
    
    /// Opens the selected event in the macOS Calendar app.
    func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        if let url = URL(string: "ical://ekevent/\(eventIdentifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }
}
