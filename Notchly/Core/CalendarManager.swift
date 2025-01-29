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
    
    // MARK: - Properties
    
    private let eventStore: EKEventStore // Interface to the user's calendar data
    @Published var events: [EKEvent] = [] // List of fetched calendar events

    // MARK: - Initialization
    
    /// Initializes the CalendarManager with a given EKEventStore.
    /// - Parameter eventStore: The EKEventStore instance to manage calendar data.
    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - Permissions
    
    /// Requests access to the user's calendar.
    /// If access is granted, it fetches upcoming events and updates the `events` array.
    /// - Parameter completion: A closure that provides the access status and an optional error.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { granted, error in
            if let error = error {
                print("Error requesting calendar access: \(error.localizedDescription)")
                completion(false)
                return
            }

            if granted {
                print("Calendar access granted: \(granted)")
                DispatchQueue.main.async {
                    // Fetch and update events
                    self.events = self.fetchEvents()
                    print("Events fetched: \(self.events)")
                    completion(true)
                }
            } else {
                print("Access to calendar denied")
                completion(false)
            }
        }
    }

    // MARK: - Event Fetching

    /// Fetches upcoming events from the user's calendar.
    /// - Parameters:
    ///   - startDate: The start date for the time range.
    ///   - endDate: The end date for the time range.
    func fetchEvents(startDate: Date = Date(), endDate: Date = Calendar.current.date(byAdding: .weekOfYear,
                                                                                     value: 1,
                                                                                     to: Date())!) -> [EKEvent] {
        // Retrieve all calendars visible to the user
        let calendars = eventStore.calendars(for: .event)

        // Create a predicate to fetch events within the specified time range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)

        // Filter and store events occurring in the future
        self.events = eventStore.events(matching: predicate).filter { $0.startDate >= Date() }
        return self.events
    }
    
    /// Groups events by their start date.
    /// - Parameter events: The array of events to group.
    /// - Returns: A dictionary of events grouped by their start date.
    func groupEventsByDate(_ events: [EKEvent]) -> [Date: [EKEvent]] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.startDate) }
    }
}
