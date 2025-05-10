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

    /// Checks if we have proper calendar permissions
    func hasCalendarPermission() -> Bool {
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }
    
    @MainActor
    func checkAndBroadcastPermissionStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("📅 Current calendar permission status: \(status.rawValue)")
        
        /// Broadcast the current status
        NotificationCenter.default.post(
            name: Notification.Name("NotchlyCalendarPermissionChanged"),
            object: nil,
            userInfo: ["status": status.rawValue, "granted": status == .fullAccess]
        )
    }

    /// Enhanced version of requestAccess that provides better permission handling
    func requestAccess(completion: @escaping (Bool) -> Void) {
        print("📅 Checking calendar permission status...")
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        
        switch currentStatus {
        case .fullAccess:
            /// Already have full access - no need to request again
            print("✅ Calendar access already granted")
            self.refreshCalendarData()
            DispatchQueue.main.async {
                self.checkAndBroadcastPermissionStatus() // Add this broadcast
                completion(true)
            }
            
        case .notDetermined:
            /// Need to request access
            print("📝 Requesting calendar access...")
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Calendar access error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                    return
                }
                
                if granted {
                    print("✅ Calendar access granted")
                    self.refreshCalendarData()
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(true)
                    }
                } else {
                    print("❌ Calendar access denied by user")
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                }
            }
            
        case .authorized, .restricted, .denied, .writeOnly:
            /// Legacy or partial access states
            print("⚠️ Calendar has partial access: \(currentStatus.rawValue)")
            
            /// Try to request full access
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }
                
                if granted {
                    print("✅ Calendar access upgraded to full access")
                    self.refreshCalendarData()
                    DispatchQueue.main.async { completion(true) }
                } else {
                    print("❌ Unable to upgrade calendar access: \(error?.localizedDescription ?? "No reason given")")
                    DispatchQueue.main.async { completion(false) }
                }
            }
            
        @unknown default:
            /// Handle future states
            print("⚠️ Unknown calendar permission state: \(currentStatus.rawValue)")
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }
                
                if granted {
                    print("✅ Calendar access granted from unknown state")
                    self.refreshCalendarData()
                    DispatchQueue.main.async { completion(true) }
                } else {
                    print("❌ Unable to get calendar access: \(error?.localizedDescription ?? "No reason provided")")
                    DispatchQueue.main.async { completion(false) }
                }
            }
        }
    }
    
    /// Refreshes calendar data after permissions are granted
    private func refreshCalendarData() {
        print("📅 Refreshing calendar data after permission granted...")
        let startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let loadedEvents = self.fetchEvents(startDate: startDate, endDate: endDate)
        
        /// Update the events collection
        DispatchQueue.main.async {
            self.events = loadedEvents
            print("📆 Fetched \(loadedEvents.count) events after permission confirmed")
            
            /// Notify others that calendar data has been refreshed
            NotificationCenter.default.post(
                name: SettingsChangeType.calendar.notificationName,
                object: nil
            )
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
    
    func reloadSelectedCalendars(_ selectedIDs: Set<String>) async {
        /// Only load selected calendars rather than all
        guard !selectedIDs.isEmpty else {
            self.events = []
            return
        }
        
        /// Create a method to get filtered events that avoids direct access to private properties
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        /// Use the existing fetchEvents method which has access to the eventStore
        var fetchedEvents: [EKEvent] = []
        
        /// Get all available calendars
        let allCalendars = await getAllCalendars()
        
        /// Filter for just the selected ones
        let selectedCalendars = allCalendars.filter { calendar in
            selectedIDs.contains(calendar.calendarIdentifier)
        }
        
        /// Only fetch if we have calendars selected
        if !selectedCalendars.isEmpty {
            /// Use a custom implementation that doesn't need direct eventStore access
            fetchedEvents = fetchEventsForCalendars(selectedCalendars, startDate: startDate, endDate: endDate)
        }
        
        self.events = fetchedEvents
    }
    
    /// Helper method to fetch events for specific calendars without requiring direct eventStore access
    private func fetchEventsForCalendars(_ calendars: [EKCalendar], startDate: Date, endDate: Date) -> [EKEvent] {
        /// This method is implemented in the CalendarManager class and has access to the eventStore
        return fetchEvents(startDate: startDate, endDate: endDate)
            .filter { event in
                /// Only include events from the selected calendars
                guard let eventCalendar = event.calendar else { return false }
                return calendars.contains(where: { $0.calendarIdentifier == eventCalendar.calendarIdentifier })
            }
    }
    
    /// Clear all events
    @MainActor
    func clearEvents() {
        self.events = []
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
                return
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
            
            /// Important: Update on main thread
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
