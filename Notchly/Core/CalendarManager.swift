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
        requestAccess { _ in
            self.fetchEvents()
        }
        subscribeToCalendarChanges() // ✅ Listen for event changes
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

    /// ✅ Listens for event changes in the system calendar
    private func subscribeToCalendarChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            print("🔄 Calendar changed, reloading events...")
            self?.fetchEvents() // ✅ Auto-refresh on changes
        }
    }
}
