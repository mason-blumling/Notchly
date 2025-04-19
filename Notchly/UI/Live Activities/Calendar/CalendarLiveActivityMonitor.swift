//
//  CalendarLiveActivityMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import Foundation
import EventKit
import Combine

final class CalendarLiveActivityMonitor: ObservableObject {
    @Published var upcomingEvent: EKEvent?
    @Published var timeRemainingString: String = ""

    private var timer: Timer?
    private var expirationTimer: Timer?
    private var previousRemaining: TimeInterval?
    private var dismissedEventID: String?
    private var lastShownPhase: String?
    private let calendarManager: CalendarManager

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.evaluateLiveActivity() }
        }
    }

    func evaluateLiveActivity() {
        guard let event = calendarManager.nextEventStartingSoon(),
              event.eventIdentifier != dismissedEventID else {
            reset()
            return
        }

        let now = Date()
        let remaining = event.startDate.timeIntervalSince(now)

        // Skip countdown if we already showed the alert and it's expired
        if previousRemaining == nil {
            previousRemaining = remaining
        }

        if remaining < 0 {
            reset()
        } else if remaining < 60 {
            // ✅ Always show live countdown
            timeRemainingString = "\(Int(remaining))s"
            upcomingEvent = event
            expirationTimer?.invalidate()
            lastShownPhase = "countdown"
        } else if remaining < 300 {
            if previousRemaining! > 300 && lastShownPhase != "5m" {
                timeRemainingString = "5m"
                upcomingEvent = event
                lastShownPhase = "5m"
                scheduleExpiration(for: event)
            }
        } else if remaining < 900 {
            if previousRemaining! > 900 && lastShownPhase != "15m" {
                timeRemainingString = "15m"
                upcomingEvent = event
                lastShownPhase = "15m"
                scheduleExpiration(for: event)
            }
        }

        previousRemaining = remaining
    }

    private func scheduleExpiration(for event: EKEvent) {
        let id = event.eventIdentifier
        expirationTimer?.invalidate()
        expirationTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { _ in
            Task { @MainActor in
                self.upcomingEvent = nil
                self.timeRemainingString = ""
                self.lastShownPhase = nil
                self.dismissedEventID = id
            }
        }
    }

    private func reset() {
        upcomingEvent = nil
        timeRemainingString = ""
        previousRemaining = nil
        lastShownPhase = nil
        expirationTimer?.invalidate()
    }
}
