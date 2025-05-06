//
//  NotchlyEventConflicts.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import EventKit
import SwiftUI

// MARK: - Conflict Detection Extension

extension NotchlyEventList {
    
    // MARK: - Conflict Data Model
    
    /// Represents a time conflict between two events.
    struct ConflictInfo: Hashable {
        let event1: EKEvent
        let event2: EKEvent
        
        /// Formats the overlapping time range as a user-friendly string.
        var overlapTimeRange: String {
            let overlapStart = max(event1.startDate, event2.startDate)
            let overlapEnd = min(event1.endDate, event2.endDate)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "\(formatter.string(from: overlapStart)) - \(formatter.string(from: overlapEnd))"
        }
    }
    
    // MARK: - Conflict Identification
    
    /// Identifies conflicting events and appends conflict warnings between them.
    /// - Returns: A mixed array of `EKEvent` and `ConflictInfo` items.
    func eventsWithConflicts() -> [AnyHashable] {
        var result: [AnyHashable] = []
        let events = eventsForSelectedDate().sorted { $0.startDate < $1.startDate }
        let conflicts = detectConflictingEvents()
        
        for i in 0..<events.count {
            let event = events[i]
            result.append(event) // Always append the event itself.
            
            /// Skip conflict checks for all-day events.
            if event.isAllDay { continue }
            
            /// Ensure we are within bounds to compare with the next event.
            if i < events.count - 1 {
                let nextEvent = events[i + 1]
                
                /// Ensure the next event is not all-day before adding conflict info.
                if !nextEvent.isAllDay && conflicts.contains(event.eventIdentifier) && conflicts.contains(nextEvent.eventIdentifier) {
                    result.append(ConflictInfo(event1: event, event2: nextEvent))
                }
            }
        }
        return result
    }
    
    /// Detects overlapping events and returns a set of conflicting event identifiers.
    /// - Returns: A `Set<String>` of event identifiers that have conflicts.
    func detectConflictingEvents() -> Set<String> {
        var conflicts: Set<String> = []
        let sortedEvents = eventsForSelectedDate()
            .filter { !$0.isAllDay } /// Exclude all-day events from conflict detection.
            .sorted { $0.startDate < $1.startDate }
        
        /// Ensure at least 2 time-based events exist before checking for conflicts.
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
    
    // MARK: - UI Component
    
    /// Displays a UI warning for conflicting events.
    /// - Parameter conflict: The detected conflict info.
    /// - Returns: A `View` displaying the conflict warning.
    func conflictRow(_ conflict: ConflictInfo) -> some View {
        Text("⚠️ Conflict from \(conflict.overlapTimeRange)")
            .foregroundColor(.red)
            .background(Color.red.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 8)))
            .font(.caption).italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}
