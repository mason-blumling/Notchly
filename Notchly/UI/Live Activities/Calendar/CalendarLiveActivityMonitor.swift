//
//  CalendarLiveActivityMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import Foundation
import EventKit
import Combine

@MainActor
final class CalendarLiveActivityMonitor: ObservableObject {
    @Published var upcomingEvent: EKEvent?
    @Published var timeRemainingString: String = ""

    private var timer: Timer?
    private let calendarManager: CalendarManager

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task {
                await MainActor.run {
                    self.evaluateLiveActivity()
                }
            }
        }
    }

    func evaluateLiveActivity() {
        guard let next = calendarManager.nextEventStartingSoon() else {
            upcomingEvent = nil
            timeRemainingString = ""
            return
        }

        let now = Date()
        let remaining = next.startDate.timeIntervalSince(now)

        if remaining <= 60 {
            timeRemainingString = "\(Int(remaining))s"
        } else if remaining <= 300 {
            timeRemainingString = "In 5 min"
        } else if remaining <= 900 {
            timeRemainingString = "In 15 min"
        } else {
            timeRemainingString = ""
        }

        upcomingEvent = remaining <= 900 ? next : nil
    }
}
