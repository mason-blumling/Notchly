//
//  NotchlyEventList.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import SwiftUI
import EventKit

struct NotchlyEventList: View {
    @State private var cachedUserEmails: Set<String> = []
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

    func conflictRow(_ conflict: ConflictInfo) -> some View {
        Text("⚠️ Conflict from \(conflict.overlapTimeRange)")
            .foregroundColor(.red)
            .background(Color.red.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 8)))
            .font(.caption).italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}

// MARK: - Event Row
private extension NotchlyEventList {
    
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

// MARK: - Event Status Detection
private extension NotchlyEventList {
    
    func isEventPending(_ event: EKEvent) -> Bool {
        guard let attendees = event.attendees else { return false }
        return attendees.contains { attendee in
            attendee.isCurrentUser &&
            (attendee.participantStatus == .pending || attendee.participantStatus == .unknown)
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

// MARK: - Conflict Handling
private extension NotchlyEventList {
    func eventsWithConflicts() -> [AnyHashable] {
        var result: [AnyHashable] = []
        let events = eventsForSelectedDate().sorted { $0.startDate < $1.startDate }
        let conflicts = detectConflictingEvents()

        for i in 0..<events.count {
            let event = events[i]
            result.append(event)

            // ✅ Skip all-day events from conflict checking
            if event.isAllDay { continue }

            // ✅ Ensure we are not out-of-bounds
            if i < events.count - 1 {
                let nextEvent = events[i + 1]

                // ✅ Ensure the next event is not all-day before adding conflict info
                if !nextEvent.isAllDay && conflicts.contains(event.eventIdentifier) && conflicts.contains(nextEvent.eventIdentifier) {
                    result.append(ConflictInfo(event1: event, event2: nextEvent))
                }
            }
        }
        return result
    }

    func detectConflictingEvents() -> Set<String> {
        var conflicts: Set<String> = []
        let sortedEvents = eventsForSelectedDate()
            .filter { !$0.isAllDay } // ✅ Exclude all-day events from conflict checks but not from display
            .sorted { $0.startDate < $1.startDate }

        // ✅ Prevent crash: Ensure at least 2 time-based events exist
        guard sortedEvents.count > 1 else { return conflicts }

        for i in 0..<sortedEvents.count - 1 {
            let currentEvent = sortedEvents[i]
            let nextEvent = sortedEvents[i + 1]

            if currentEvent.endDate > nextEvent.startDate {
                conflicts.insert(currentEvent.eventIdentifier)
                conflicts.insert(nextEvent.eventIdentifier)
            }
        }
        return conflicts
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
        let declinedNames = declinedAttendees(event)
        let maybeNames = maybeAttendees(event)
        let organizer = eventOrganizer(event) // ✅ Use our function
        let eventLocation = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)

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

            if !declinedNames.isEmpty {
                Text("❌ Declined: \(declinedNames.joined(separator: ", "))")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if !maybeNames.isEmpty {
                Text("🤔 Maybe: \(maybeNames.joined(separator: ", "))")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }

            // 👤 **Show organizer ONLY if it is NOT the user**
            if let organizer, !organizer.isEmpty {
                Text("Organizer: \(organizer)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }

            // 📍 Show location if available
            if let location = eventLocation, !location.isEmpty {
                Text("📍 \(location)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }

    func eventTime(_ event: EKEvent) -> some View {
        Text(event.isAllDay ? "All Day" : event.startDate.formatted(date: .omitted, time: .shortened))
            .foregroundColor(.gray)
            .font(.caption)
    }
}

// MARK: - Cached User Emails (Fix 1)
private extension NotchlyEventList {
    func fetchAndCacheUserEmails() {
        DispatchQueue.global(qos: .background).async {
            let emails = fetchCurrentUserEmails()
            DispatchQueue.main.async {
                self.cachedUserEmails = emails
            }
        }
    }
}

// MARK: - Event Attendee Handling
private extension NotchlyEventList {
    
    /// Fetches declined attendees, excluding the current user.
    func declinedAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .declined && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    /// Fetches attendees who responded "Maybe," excluding the current user.
    func maybeAttendees(_ event: EKEvent) -> [String] {
        return event.attendees?
            .filter { $0.participantStatus == .tentative && !cachedUserEmails.contains($0.name ?? "") }
            .compactMap { $0.name }
            ?? []
    }

    /// Determines the event organizer and ensures it's not the current user.
    func eventOrganizer(_ event: EKEvent) -> String? {
        if event.organizer?.isCurrentUser == true {
            print("🔹 Skipping organizer because it's the current user: \(event.organizer?.name ?? "Unknown")")
            return nil
        }

        if let organizerName = event.organizer?.name {
            if cachedUserEmails.contains(organizerName.lowercased()) {
                print("🔹 Skipping organizer \(organizerName) because it's my own email")
                return nil
            }
            return organizerName
        }

        return nil
    }

    /// Fetches all possible email addresses associated with the current user.
    func fetchCurrentUserEmails() -> Set<String> {
        let eventStore = EKEventStore()
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source?.title,
           defaultSource.contains("@") {
            return [defaultSource.lowercased()]
        }
        return []
    }
}

// MARK: - Lifecycle (Fix 1 - Call `fetchAndCacheUserEmails()`)
private extension NotchlyEventList {
    func onAppear() {
        fetchAndCacheUserEmails()
    }
}

// MARK: - Supporting Structs
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
            .drawingGroup() /// Offloads rendering workload to GPU
            .opacity(0.3)
        }
    }
    
    struct ConflictInfo: Hashable {
        let event1: EKEvent
        let event2: EKEvent

        var overlapTimeRange: String {
            let overlapStart = max(event1.startDate, event2.startDate)
            let overlapEnd = min(event1.endDate, event2.endDate)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: overlapStart)) - \(formatter.string(from: overlapEnd))"
        }
    }
}

// MARK: - Event Filtering
private extension NotchlyEventList {
    func eventsForSelectedDate() -> [EKEvent] {
        calendarManager.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
    }
}

// MARK: - Event Handling
private extension NotchlyEventList {
    
    func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        if let url = URL(string: "ical://ekevent/\(eventIdentifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }
}
