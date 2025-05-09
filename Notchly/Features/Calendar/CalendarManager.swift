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
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            guard let self = self else { return }
            
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
                print("✅ Calendar access granted, fetching events...")
                /// Force fetch events with maximum date range to ensure we get something
                let startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
                let endDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
                let loadedEvents = self.fetchEvents(startDate: startDate, endDate: endDate)
                
                /// Important: set published property to trigger UI updates
                self.events = loadedEvents
                
                print("📆 Fetched \(loadedEvents.count) events after permission granted")
                completion(true)
            }
        }
    }
    
    // MARK: - Fetching

    @MainActor
    func getAllCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }

    func fetchEvents(
        startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
        endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    ) -> [EKEvent] {
        print("🔍 Fetching events from \(startDate) to \(endDate)")
        print("🔍 Authorization status: \(EKEventStore.authorizationStatus(for: .event).rawValue)")
        
        let calendars = eventStore.calendars(for: .event)
        print("🔍 Found \(calendars.count) calendars")
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let fetchedEvents = eventStore.events(matching: predicate)
        print("🔍 Fetched \(fetchedEvents.count) events")
        
        if fetchedEvents.isEmpty {
            /// Debug: Display some calendar information to diagnose
            for calendar in calendars {
                print("  - Calendar: \(calendar.title) (source: \(calendar.source.title))")
            }
        } else {
            /// Sample a few events to verify data
            let sampleCount = min(fetchedEvents.count, 3)
            print("🔍 Sample events:")
            for i in 0..<sampleCount {
                let event = fetchedEvents[i]
                print("  - \(event.title ?? "Untitled") on \(String(describing: event.startDate))")
            }
        }
        
        self.events = fetchedEvents
        return fetchedEvents
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
            
            print("📱 Received calendar change notification")
            
            if let last = self.lastSystemChange,
               Date().timeIntervalSince(last) < 2 {
                print("⏱️ Debouncing duplicate notification")
                return // debounce duplicate change events
            }
            
            self.lastSystemChange = Date()
            print("🔄 Reloading events after system change...")
            
            let previous = self.events
            let updated = self.fetchEvents()
            
            guard updated != previous else {
                print("📆 No changes detected in event list")
                return
            }
            
            let delta = updated.count - previous.count
            if delta > 0 {
                print("📆 New event(s) detected: +\(delta) (\(updated.count) total)")
            } else if delta < 0 {
                print("📆 Event(s) removed: \(delta) (\(updated.count) total)")
            } else {
                print("📆 Event list updated (possible edits, same count: \(updated.count))")
            }
            
            // Important: Update on main thread
            DispatchQueue.main.async {
                self.events = updated
            }
        }
    }
}

// MARK: - Notification Definitions

extension Notification.Name {
    static let NotchlySuspendCalendarUpdates = Notification.Name("NotchlySuspendCalendarUpdates")
    static let NotchlyResumeCalendarUpdates = Notification.Name("NotchlyResumeCalendarUpdates")
}
