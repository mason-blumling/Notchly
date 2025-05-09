//
//  CalendarManager.swift
//  Notchly
//
//  Created by Mason Blumling on 1/19/25.
//

import Foundation
import EventKit
import os.log

// MARK: - CalendarManager

/// Manages access to and retrieval of calendar events.
/// Handles permissions, data fetching, and reactive updates to system changes.
class CalendarManager: ObservableObject {
    private let eventStore: EKEventStore
    private var lastSystemChange: Date? = nil
    private var lastFetchTime: Date? = nil
    private var lastBroadcastedPermission: EKAuthorizationStatus?

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

        guard status != lastBroadcastedPermission else {
            return
        }
        
        lastBroadcastedPermission = status
        NotchlyLogger.info("📅 Current calendar permission status: \(status == .fullAccess ? "'Full-Access'" : "Not-Granted")", category: .calendar)

        NotificationCenter.default.post(
            name: Notification.Name("NotchlyCalendarPermissionChanged"),
            object: nil,
            userInfo: ["status": status.rawValue, "granted": status == .fullAccess]
        )
    }

    /// Enhanced version of requestAccess that provides better permission handling
    func requestAccess(completion: @escaping (Bool) -> Void) {
        NotchlyLogger.info("📅 Checking calendar permission status...", category: .calendar)
        let currentStatus = EKEventStore.authorizationStatus(for: .event)

        switch currentStatus {
        case .fullAccess:
            NotchlyLogger.notice("✅ Calendar access already granted", category: .calendar)
            self.refreshCalendarData()
            DispatchQueue.main.async {
                self.checkAndBroadcastPermissionStatus()
                completion(true)
            }

        case .notDetermined:
            NotchlyLogger.info("📝 Requesting calendar access...", category: .calendar)
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }

                if let error = error {
                    NotchlyLogger.error("❌ Calendar access error: \(error.localizedDescription)", category: .calendar)
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                    return
                }
                
                if granted {
                    NotchlyLogger.notice("✅ Calendar access granted", category: .calendar)
                    self.refreshCalendarData()
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(true)
                    }
                } else {
                    NotchlyLogger.error("❌ Calendar access denied by user", category: .calendar)
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                }
            }
            
        case .authorized, .restricted, .denied, .writeOnly:
            NotchlyLogger.info("⚠️ Calendar has partial access: \(currentStatus.rawValue)", category: .calendar)

            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }

                if granted {
                    NotchlyLogger.notice("✅ Calendar access upgraded to full access", category: .calendar)
                    self.refreshCalendarData()
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(true)
                    }
                } else {
                    NotchlyLogger.error("❌ Unable to upgrade calendar access: \(error?.localizedDescription ?? "No reason given")", category: .calendar)
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                }
            }

        @unknown default:
            NotchlyLogger.error("⚠️ Unknown calendar permission state: \(currentStatus.rawValue)", category: .calendar)
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                guard let self = self else { return }

                if granted {
                    NotchlyLogger.notice("✅ Calendar access granted from unknown state", category: .calendar)
                    self.refreshCalendarData()
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(true)
                    }
                } else {
                    NotchlyLogger.error("❌ Unable to get calendar access: \(error?.localizedDescription ?? "No reason provided")", category: .calendar)
                    DispatchQueue.main.async {
                        self.checkAndBroadcastPermissionStatus()
                        completion(false)
                    }
                }
            }
        }
    }

    /// Refreshes calendar data after permissions are granted
    private func refreshCalendarData() {
        NotchlyLogger.notice("📅 Refreshing calendar data after permission granted...", category: .calendar)
        let startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        let loadedEvents = self.fetchEvents(startDate: startDate, endDate: endDate)

        DispatchQueue.main.async {
            self.events = loadedEvents
            NotchlyLogger.notice("📆 Fetched \(loadedEvents.count) events after permission confirmed", category: .calendar)

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

    func fetchEvents(startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
                     endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!) -> [EKEvent] {
        let now = Date()
        
        /// Suppress logs if called again within 0.5 seconds
        let shouldLog = {
            if let last = self.lastFetchTime, now.timeIntervalSince(last) < 0.5 {
                return false
            }
            self.lastFetchTime = now
            return true
        }()

        if shouldLog {
            NotchlyLogger.debug("🔍 Fetching events from \(startDate) to \(endDate)", category: .calendar)
            NotchlyLogger.debug("🔍 Authorization status: \(EKEventStore.authorizationStatus(for: .event) == .fullAccess ? "'Full-Access'" : "Not-Granted")", category: .calendar)
        }

        let calendars = eventStore.calendars(for: .event)
        if shouldLog {
            NotchlyLogger.debug("🔍 Found \(calendars.count) User Calendars", category: .calendar)
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let fetchedEvents = eventStore.events(matching: predicate)

        if shouldLog {
            NotchlyLogger.debug("🔍 Fetched \(fetchedEvents.count) Events", category: .calendar)

            if fetchedEvents.isEmpty {
                for calendar in calendars {
                    NotchlyLogger.debug("  - Calendar: \(calendar.title) (source: \(calendar.source.title))", category: .calendar)
                }
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

        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        var fetchedEvents: [EKEvent] = []

        let allCalendars = await getAllCalendars()
        let selectedCalendars = allCalendars.filter { selectedIDs.contains($0.calendarIdentifier) }

        if !selectedCalendars.isEmpty {
            fetchedEvents = fetchEventsForCalendars(selectedCalendars, startDate: startDate, endDate: endDate)
        }

        self.events = fetchedEvents
    }
    
    /// Helper method to fetch events for specific calendars without requiring direct eventStore access
    private func fetchEventsForCalendars(_ calendars: [EKCalendar], startDate: Date, endDate: Date) -> [EKEvent] {
        return fetchEvents(startDate: startDate, endDate: endDate).filter {
            guard let calendar = $0.calendar else { return false }
            return calendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier })
        }
    }

    @MainActor
    func clearEvents() {
        self.events = []
    }

    // MARK: - Enhanced Calendar Wake Handling

    @MainActor
    func suspendUpdates() {
        NotchlyLogger.info("🛑 Suspending calendar updates...", category: .calendar)
        
        /// Cancel any lingering operations
        lastSystemChange = nil
        lastFetchTime = nil
        
        /// Post notification to inform listeners
        NotificationCenter.default.post(name: .NotchlySuspendCalendarUpdates, object: nil)
    }

    @MainActor
    func reloadEvents() {
        NotchlyLogger.notice("🔁 [Wake] Reloading calendar events...", category: .calendar)
        
        /// Check permission status first
        let hasPermission = self.hasCalendarPermission()
        guard hasPermission else {
            NotchlyLogger.notice("📅 Skipping calendar reload - no permission", category: .calendar)
            return
        }
        
        /// Implement retry mechanism for stability
        Task {
            /// Try up to 3 times with increasing delays
            var attempts = 0
            var success = false
            
            while attempts < 3 && !success {
                do {
                    attempts += 1
                    
                    /// Add exponential backoff delay between attempts
                    if attempts > 1 {
                        try await Task.sleep(nanoseconds: UInt64(0.5 * Double(attempts) * 1_000_000_000))
                    }
                    
                    /// Fetch events with normal date range
                    let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                    let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                    let fetchedEvents = self.fetchEvents(startDate: startDate, endDate: endDate)
                    
                    /// Update the events property
                    self.events = fetchedEvents
                    
                    NotchlyLogger.notice("📆 Reload complete: \(fetchedEvents.count) events fetched.", category: .calendar)
                    success = true
                    
                    /// Notify listeners that calendar updates are resumed
                    NotificationCenter.default.post(name: .NotchlyResumeCalendarUpdates, object: nil)
                } catch {
                    NotchlyLogger.error("❌ Calendar reload attempt \(attempts) failed: \(error.localizedDescription)", category: .calendar)
                }
            }
            
            if !success {
                NotchlyLogger.error("❌ All calendar reload attempts failed", category: .calendar)
                /// Post notification anyway to prevent UI from waiting indefinitely
                NotificationCenter.default.post(name: .NotchlyResumeCalendarUpdates, object: nil)
            }
        }
    }

    // MARK: - Change Monitoring
    
    private func subscribeToCalendarChanges() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            NotchlyLogger.debug("📱 Received calendar change notification", category: .calendar)

            if let last = self.lastSystemChange, Date().timeIntervalSince(last) < 2 {
                NotchlyLogger.debug("⏱️ Debouncing duplicate notification", category: .calendar)
                return
            }
            
            self.lastSystemChange = Date()
            NotchlyLogger.debug("🔄 Reloading events after system change...", category: .calendar)

            let previous = self.events
            let updated = self.fetchEvents()

            guard updated != previous else {
                NotchlyLogger.debug("📆 No changes detected in event list", category: .calendar)
                return
            }

            let delta = updated.count - previous.count
            if delta > 0 {
                NotchlyLogger.notice("📆 New event(s) detected: +\(delta) (\(updated.count) total)", category: .calendar)
            } else if delta < 0 {
                NotchlyLogger.notice("📆 Event(s) removed: \(delta) (\(updated.count) total)", category: .calendar)
            } else {
                NotchlyLogger.notice("📆 Event list updated (possible edits, same count: \(updated.count))", category: .calendar)
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
