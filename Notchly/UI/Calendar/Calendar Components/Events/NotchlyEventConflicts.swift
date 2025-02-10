//
//  NotchlyEventConflicts.swift
//  Notchly
//
//  Created by Mason Blumling on 2/9/25.
//

import EventKit
import SwiftUI

extension NotchlyEventList {
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
    
    func conflictRow(_ conflict: ConflictInfo) -> some View {
        Text("⚠️ Conflict from \(conflict.overlapTimeRange)")
            .foregroundColor(.red)
            .background(Color.red.opacity(0.1).clipShape(RoundedRectangle(cornerRadius: 8)))
            .font(.caption).italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}
