//
//  CalendarLiveActivityMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import Foundation
import EventKit
import Combine

/// Monitors upcoming calendar events and triggers live activity alerts (15m, 5m, countdown).
@MainActor
final class CalendarLiveActivityMonitor: ObservableObject {
    @Published var upcomingEvent: EKEvent?
    @Published var timeRemainingString: String = ""
    @Published var isLiveActivityVisible: Bool = false

    private var timer: Timer?
    private var expirationTimer: Timer?
    private var previousRemaining: TimeInterval?
    private var dismissedEventID: String?
    private var lastShownPhase: String?
    private var cancellables = Set<AnyCancellable>()

    private let calendarManager: CalendarManager

    // MARK: - Init & Lifecycle

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        startTimer()

        NotificationCenter.default.addObserver(
            forName: .NotchlySuspendCalendarUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pauseTimers()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NotchlyResumeCalendarUpdates,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeTimers()
            }
        }
        NotificationCenter.default.publisher(for: SettingsChangeType.calendar.notificationName)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Re-evaluate alerts based on new settings
                self.evaluateLiveActivity()
            }
            .store(in: &cancellables)
    }

    deinit {
        print("🧹 CalendarLiveActivityMonitor deinit")
        timer?.invalidate()
        expirationTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Timer Controls

    func pauseTimers() {
        timer?.invalidate()
        timer = nil

        expirationTimer?.invalidate()
        expirationTimer = nil
    }

    func resumeTimers() {
        pauseTimers()
        startTimer()
        evaluateLiveActivity()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.evaluateLiveActivity()
            }
        }
    }

    // MARK: - Evaluation Logic

   func evaluateLiveActivity() {
       let settings = NotchlySettings.shared
       
       /// Exit early if calendar or alerts are disabled in settings
       guard settings.enableCalendar && settings.enableCalendarAlerts else {
           reset()
           return
       }
       
       guard let event = calendarManager.nextEventStartingSoon(),
             event.eventIdentifier != dismissedEventID else {
           reset()
           return
       }

       let now = Date()
       let remaining = event.startDate.timeIntervalSince(now)

       if previousRemaining == nil {
           previousRemaining = remaining
       }

       if remaining < 0 {
           /// Event already started
           reset()

       } else if remaining < 60 && settings.alertTiming.contains(1) {
           /// 1-minute countdown phase (only if 1m alerts enabled)
           timeRemainingString = "\(Int(remaining))s"
           upcomingEvent = event

           if lastShownPhase != "countdown" {
               print("⏱️ Showing countdown for event: \(event.title ?? "Unknown")")
               expirationTimer?.invalidate()
               lastShownPhase = "countdown"
               isLiveActivityVisible = true

               let eventID = event.eventIdentifier
               expirationTimer = Timer.scheduledTimer(withTimeInterval: remaining + 1.0, repeats: false) { [weak self] _ in
                   Task { @MainActor in
                       self?.reset()
                       self?.dismissedEventID = eventID
                   }
               }
           }

       } else if remaining < 300 && settings.alertTiming.contains(5) {
           /// 5-minute alert (only if 5m alerts enabled)
           if previousRemaining! > 300 && lastShownPhase != "5m" {
               print("🔔 Showing 5m alert for event: \(event.title ?? "Unknown")")
               timeRemainingString = "5m"
               upcomingEvent = event
               lastShownPhase = "5m"
               scheduleExpiration(for: event)
               isLiveActivityVisible = true
           }

       } else if remaining < 900 && settings.alertTiming.contains(15) {
           /// 15-minute alert (only if 15m alerts enabled)
           if previousRemaining! > 900 && lastShownPhase != "15m" {
               print("🔔 Showing 15m alert for event: \(event.title ?? "Unknown")")
               timeRemainingString = "15m"
               upcomingEvent = event
               lastShownPhase = "15m"
               scheduleExpiration(for: event)
               isLiveActivityVisible = true
           }
       }

       previousRemaining = remaining
   }

    // MARK: - Expiration & Reset

    /// Schedules the expiration of an alert phase (15m or 5m).
    private func scheduleExpiration(for event: EKEvent) {
        let id = event.eventIdentifier
        expirationTimer?.invalidate()
        isLiveActivityVisible = false

        expirationTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.upcomingEvent = nil
                self.timeRemainingString = ""
                self.lastShownPhase = nil
                self.dismissedEventID = id
            }
        }
    }


    func reset() {
        /// Directly call reset to disable any active alerts
        Task { @MainActor in
            upcomingEvent = nil
            timeRemainingString = ""
            previousRemaining = nil
            lastShownPhase = nil
            isLiveActivityVisible = false
            expirationTimer?.invalidate()
        }
    }
}

extension CalendarLiveActivityMonitor {
    // This function checks if the alert timing is enabled in settings
    func shouldShowAlert(for minutes: Int) -> Bool {
        // Check if this alert time is enabled in settings
        return NotchlySettings.shared.alertTiming.contains(minutes)
    }
    
    // Call this from NotchlySettings to disable alerts
    func disableAllAlerts() {
        Task { @MainActor in
            reset() // Uses the existing reset method
        }
    }
}

// Then in NotchlySettings.swift, change:
@MainActor private func disableCalendarLiveActivity() {
    // Use the proper method to disable calendar alerts
    AppEnvironment.shared.calendarActivityMonitor.disableAllAlerts()
}
