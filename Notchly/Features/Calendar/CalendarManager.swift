//
//  CalendarManager.swift
//  Notchly
//
//  Created by Mason Blumling on 1/19/25.
//

import Foundation
import EventKit

// MARK: - CalendarManager

/// Manages access to and retrieval of calendar events.
/// Handles permissions, data fetching, and reactive updates to system changes.
class CalendarManager: ObservableObject {
    private let eventStore: EKEventStore
    private var lastSystemChange: Date? = nil

    @Published var events: [EKEvent] = []

    // MARK: - Init

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        subscribeToCalendarChanges()
    }

    // MARK: - Permissions

    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            if let error = error {
                print("❌ Calendar access error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }

            guard granted else {
                print("❌ Calendar access denied by user.")
                DispatchQueue.main.async { completion(false) }
                return
            }

            DispatchQueue.main.async {
                let wasEmpty = self.events.isEmpty
                let loadedEvents = self.fetchEvents()
                self.events = loadedEvents

                if wasEmpty {
                    print("📆 Initial load: \(loadedEvents.count) events fetched.")
                } else {
                    print("📆 Refreshed after access grant: \(loadedEvents.count) events fetched.")
                }

                completion(true)
            }
        }
    }

    // MARK: - Fetching

    func fetchEvents(
        startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
        endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    ) -> [EKEvent] {
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        self.events = eventStore.events(matching: predicate)
        return self.events
    }

    /// Returns the next upcoming event today that starts within the next `thresholdMinutes`.
    func nextEventStartingSoon(thresholdMinutes: Int = 90) -> EKEvent? {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .minute, value: thresholdMinutes, to: now)!

        return events
            .filter {
                !$0.isAllDay &&
                Calendar.current.isDateInToday($0.startDate) &&
                $0.startDate > now &&
                $0.startDate <= cutoff
            }
            .sorted(by: { $0.startDate < $1.startDate })
            .first
    }

    // MARK: - Lifecycle Hooks

    func suspendUpdates() {
        print("🛑 Suspending calendar updates...")
        NotificationCenter.default.post(name: .NotchlySuspendCalendarUpdates, object: nil)
    }

    func reloadEvents() {
        print("🔁 [Wake] Reloading calendar events...")
        self.events = self.fetchEvents()
        print("📆 Reload complete: \(self.events.count) events fetched.")
        NotificationCenter.default.post(name: .NotchlyResumeCalendarUpdates, object: nil)
    }

    // MARK: - Change Monitoring

    private func subscribeToCalendarChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            if let last = self.lastSystemChange,
               Date().timeIntervalSince(last) < 2 {
                return // debounce duplicate change events
            }

            self.lastSystemChange = Date()

            let previous = self.events
            let updated = self.fetchEvents()

            guard updated != previous else { return }

            let delta = updated.count - previous.count
            if delta > 0 {
                print("📆 New event(s) detected: +\(delta) (\(updated.count) total)")
            } else if delta < 0 {
                print("📆 Event(s) removed: \(delta) (\(updated.count) total)")
            } else {
                print("📆 Event list updated (possible edits, same count: \(updated.count))")
            }

            self.events = updated
        }
    }
}

// MARK: - Notification Definitions

extension Notification.Name {
    static let NotchlySuspendCalendarUpdates = Notification.Name("NotchlySuspendCalendarUpdates")
    static let NotchlyResumeCalendarUpdates = Notification.Name("NotchlyResumeCalendarUpdates")
}
