//
//  NotchlyCalendarLiveActivity.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import Foundation
import EventKit

extension CalendarManager {
    /// Returns the next upcoming event today that starts within the next 90 minutes
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
            .sorted { $0.startDate < $1.startDate }
            .first
    }
}
