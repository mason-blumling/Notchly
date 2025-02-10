//
//  NotchlyCalendarUtilities.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//

import Foundation
import SwiftUI
import EventKit

// MARK: - Shared Utilities
struct NotchlyCalendarUtilities {

    /// Formats a date to display as a weekday letter (e.g., "M", "T", "W")
    static func formattedWeekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    /// Formats a date to show only the numerical day (e.g., "12" for January 12)
    static func formattedDay(from date: Date) -> String {
        return "\(Calendar.current.component(.day, from: date))"
    }

    /// Returns whether two dates are the same calendar day
    static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    /// Fetches the index for a given date based on past/future offset
    static func indexForDate(_ date: Date, config: DateSelectorConfig) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.offset - config.past, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0
    }
}
