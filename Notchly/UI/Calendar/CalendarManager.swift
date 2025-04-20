//
//  CalendarManager.swift
//  Notchly
//
//  Created by Mason Blumling on 1/19/25.
//
//  This class is responsible for managing calendar events.
//  It handles requesting user permissions, fetching events, and providing them to the UI.
//

import Foundation
import EventKit

// MARK: - CalendarManager

/// Manages access to and retrieval of calendar events.
/// This class handles permissions, data fetching, and exposing events to the UI.
class CalendarManager: ObservableObject {
    private let eventStore: EKEventStore
    @Published var events: [EKEvent] = []
    
    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        subscribeToCalendarChanges() // ✅ Safe
        requestAccess { granted in
            print("📆 Calendar permission granted: \(granted)")
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            if let error = error {
                print("Error requesting calendar access: \(error.localizedDescription)")
                completion(false)
                return
            }
            if granted {
                DispatchQueue.main.async {
                    self.events = self.fetchEvents()
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }

    func fetchEvents(startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
                     endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!) -> [EKEvent] {
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        self.events = eventStore.events(matching: predicate)
        return self.events
    }
    
    // MARK: - Sleep/Wake Integration

    /// Suspends all monitoring (e.g., before sleep)
    func suspendUpdates() {
        print("🛑 Suspending calendar updates...")
        NotificationCenter.default.post(name: .NotchlySuspendCalendarUpdates, object: nil)
    }

    /// Reloads all calendar data and resumes monitoring (e.g., after wake)
    func reloadEvents() {
        print("🔄 Reloading calendar events after wake...")
        self.events = self.fetchEvents()
        NotificationCenter.default.post(name: .NotchlyResumeCalendarUpdates, object: nil)
    }

    /// ✅ Listens for event changes in the system calendar
    private func subscribeToCalendarChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Calendar changed, reloading events...")
            self?.events = self?.fetchEvents() ?? []
        }
    }
}

extension Notification.Name {
    static let NotchlySuspendCalendarUpdates = Notification.Name("NotchlySuspendCalendarUpdates")
    static let NotchlyResumeCalendarUpdates = Notification.Name("NotchlyResumeCalendarUpdates")
}
