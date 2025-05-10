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
    @Published var isExiting: Bool = false

    private var timer: Timer?
    private var expirationTimer: Timer?
    private var previousRemaining: TimeInterval?
    private var dismissedEventID: String?
    private var lastShownPhase: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Reset Loop Protection
    private var isResetting = false
    private var isEvaluating = false
    private var pendingReset = false

    private let calendarManager: CalendarManager

    // MARK: - Init & Lifecycle

    init(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
        
        /// Start with clean state
        self.upcomingEvent = nil
        self.timeRemainingString = ""
        self.previousRemaining = nil
        self.isLiveActivityVisible = false
        self.lastShownPhase = nil
        self.isExiting = false
        
        /// Delay timer start to prevent startup issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.startTimer()
        }

        /// Set up notifications after initialization
        setupNotifications()
    }

    private func setupNotifications() {
        /// Clear any existing observers first to prevent duplicates
        NotificationCenter.default.removeObserver(self)
        
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

        /// Respond to settings changes
        cancellables.removeAll()
        NotificationCenter.default.publisher(for: SettingsChangeType.calendar.notificationName)
            .sink { [weak self] _ in
                guard let self = self else { return }
                /// Only re-evaluate if we're not already in progress
                if !self.isEvaluating && !self.isResetting {
                    self.evaluateLiveActivity()
                }
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
    }

    private func startTimer() {
        /// Guard against double-starting
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, !self.isEvaluating, !self.isResetting else { return }
            Task { @MainActor in
                self.evaluateLiveActivity()
            }
        }
        
        /// Do an initial evaluation after a short delay to avoid startup race conditions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.evaluateLiveActivity()
        }
    }

    // MARK: - Evaluation Logic

   func evaluateLiveActivity() {
       /// Guard against reentrant calls - this prevents the reset loop
       guard !isEvaluating, !isResetting else {
           print("⚠️ Evaluation already in progress, deferring")
           pendingReset = true
           return
       }
       
       isEvaluating = true
       print("📅 Evaluating calendar live activity...")
       
       /// Reset exit state on new evaluation
       isExiting = false
       let settings = NotchlySettings.shared
       
       /// Exit early if calendar or alerts are disabled in settings
       guard settings.enableCalendar && settings.enableCalendarAlerts else {
           isEvaluating = false
           reset()
           return
       }
       
       guard let event = calendarManager.nextEventStartingSoon(),
             event.eventIdentifier != dismissedEventID else {
           isEvaluating = false
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
           isEvaluating = false
           reset()
       } else if remaining < 60 && settings.alertTiming.contains(1) {
           /// 1-minute countdown phase (only if 1m alerts enabled)
           timeRemainingString = "\(Int(remaining))s"
           upcomingEvent = event

           if lastShownPhase != "countdown" {
               print("⏱️ Showing countdown for event: \(event.title ?? "Unknown")")
               expirationTimer?.invalidate()
               lastShownPhase = "countdown"
               
               let eventID = event.eventIdentifier
               expirationTimer = Timer.scheduledTimer(withTimeInterval: remaining + 1.0, repeats: false) { [weak self] _ in
                   Task { @MainActor in
                       self?.dismissedEventID = eventID
                       self?.reset()
                   }
               }
               
               /// Only update visibility if it's changing
               if !isLiveActivityVisible {
                   isLiveActivityVisible = true
               }
           }
           isEvaluating = false
       } else if remaining < 300 && settings.alertTiming.contains(5) {
           /// 5-minute alert (only if 5m alerts enabled)
           if previousRemaining! > 300 && lastShownPhase != "5m" {
               print("🔔 Showing 5m alert for event: \(event.title ?? "Unknown")")
               timeRemainingString = "5m"
               upcomingEvent = event
               lastShownPhase = "5m"
               scheduleExpiration(for: event)
               
               /// Only update visibility if it's changing
               if !isLiveActivityVisible {
                   isLiveActivityVisible = true
               }
           }
           isEvaluating = false
       } else if remaining < 900 && settings.alertTiming.contains(15) {
           /// 15-minute alert (only if 15m alerts enabled)
           if previousRemaining! > 900 && lastShownPhase != "15m" {
               print("🔔 Showing 15m alert for event: \(event.title ?? "Unknown")")
               timeRemainingString = "15m"
               upcomingEvent = event
               lastShownPhase = "15m"
               scheduleExpiration(for: event)
               
               /// Only update visibility if it's changing
               if !isLiveActivityVisible {
                   isLiveActivityVisible = true
               }
           }
           isEvaluating = false
       } else {
           isEvaluating = false
       }

       previousRemaining = remaining
   }

    // MARK: - Expiration & Reset

    /// Schedules the expiration of an alert phase (15m or 5m).
    private func scheduleExpiration(for event: EKEvent) {
        let id = event.eventIdentifier
        expirationTimer?.invalidate()

        expirationTimer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.dismissedEventID = id
                self.reset()
            }
        }
    }

    func reset() {
        /// Guard against recursive calls
        guard !isResetting else {
            print("⚠️ Reset already in progress, ignoring redundant call")
            pendingReset = true
            return
        }
        
        /// Only proceed if we need to hide the activity or if data needs to be cleared
        guard isLiveActivityVisible || upcomingEvent != nil || !timeRemainingString.isEmpty else {
            print("ℹ️ No need to reset calendar activity - already idle")
            return
        }
        
        print("🧹 Beginning reset of calendar live activity")
        isResetting = true
        
        /// Cancel any existing expiration timer
        expirationTimer?.invalidate()
        expirationTimer = nil
        
        /// First signal that we're exiting (to animate the content)
        isExiting = true
        
        /// Only proceed with visibility change if it's currently visible
        if isLiveActivityVisible {
            /// Wait for content to fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                
                /// Reset state
                self.isExiting = false
                self.upcomingEvent = nil
                self.timeRemainingString = ""
                self.previousRemaining = nil
                self.lastShownPhase = nil
                
                /// Then signal that activity is gone
                print("🔴 Setting calendar activity visible = false")
                self.isLiveActivityVisible = false
                
                /// Reset the flag AFTER all operations are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isResetting = false
                    
                    /// Handle any pending reset that was requested while we were busy
                    if self.pendingReset {
                        self.pendingReset = false
                        self.reset()
                    }
                }
            }
        } else {
            /// Just clear data without changing visibility
            self.upcomingEvent = nil
            self.timeRemainingString = ""
            self.previousRemaining = nil
            self.lastShownPhase = nil
            self.isExiting = false
            
            /// Immediately clear the resetting flag since no animation is needed
            self.isResetting = false
            
            /// Handle any pending reset
            if self.pendingReset {
                self.pendingReset = false
                DispatchQueue.main.async {
                    self.reset()
                }
            }
        }
    }
}
