//
//  CalendarLiveActivityMonitor.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import Foundation
import EventKit
import Combine
import SwiftUI

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
    
    // MARK: - State Protection
    private var isProcessing = false
    private var pendingEvaluation = false
    private var evaluationWorkItem: DispatchWorkItem?

    private let calendarManager: CalendarManager
    
    /// New direct access to shared view model for state coordination
    private let viewModel = NotchlyViewModel.shared

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
        
        /// Set up notifications before timer to prevent race conditions
        setupNotifications()
        
        /// Delay timer start slightly to prevent startup issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startTimer()
        }
    }

    private func setupNotifications() {
        /// Clear any existing observers first
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

        /// Respond to settings changes with debouncing
        cancellables.removeAll()
        NotificationCenter.default.publisher(for: SettingsChangeType.calendar.notificationName)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.debouncedEvaluation()
            }
            .store(in: &cancellables)
    }

    deinit {
        NotchlyLogger.debug("🧹 CalendarLiveActivityMonitor deinit", category: .calendar)
        timer?.invalidate()
        expirationTimer?.invalidate()
        evaluationWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Timer Controls

    func pauseTimers() {
        timer?.invalidate()
        timer = nil
        expirationTimer?.invalidate()
        expirationTimer = nil
        evaluationWorkItem?.cancel()
        evaluationWorkItem = nil
    }

    func resumeTimers() {
        pauseTimers()
        startTimer()
    }

    private func startTimer() {
        /// Guard against double-starting
        timer?.invalidate()
        
        /// Use a slightly longer interval to reduce CPU usage
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.debouncedEvaluation()
        }
    }

    // MARK: - Debounced Evaluation
    
    /// Debounces evaluation calls to prevent rapid consecutive evaluations
    private func debouncedEvaluation() {
        evaluationWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                /// Skip if already processing to prevent loops
                if !self.isProcessing {
                    self.evaluateLiveActivity()
                } else {
                    self.pendingEvaluation = true
                }
            }
        }
        
        evaluationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    // MARK: - Evaluation Logic

    func evaluateLiveActivity() {
        /// Prevent reentrant calls
        if isProcessing {
            pendingEvaluation = true
            return
        }
        
        isProcessing = true
        
        /// Reset exit state on new evaluation
        isExiting = false
        let settings = NotchlySettings.shared
        
        /// Exit early if calendar or alerts are disabled in settings
        guard settings.enableCalendar && settings.enableCalendarAlerts else {
            /// If we're currently showing something, reset it
            if isLiveActivityVisible || upcomingEvent != nil || !timeRemainingString.isEmpty {
                reset {
                    self.finishProcessing()
                }
            } else {
                finishProcessing()
            }
            return
        }
        
        /// Find the next event starting soon
        guard let event = calendarManager.nextEventStartingSoon(),
              event.eventIdentifier != dismissedEventID else {
            /// If we're currently showing something, reset it
            if isLiveActivityVisible || upcomingEvent != nil || !timeRemainingString.isEmpty {
                reset {
                    self.finishProcessing()
                }
            } else {
                finishProcessing()
            }
            return
        }

        let now = Date()
        let remaining = event.startDate.timeIntervalSince(now)

        if previousRemaining == nil {
            previousRemaining = remaining
        }

        if remaining < 0 {
            /// Event already started
            reset {
                self.finishProcessing()
            }
        } else if remaining < 60 && settings.alertTiming.contains(1) {
            /// 1-minute countdown phase (only if 1m alerts enabled)
            timeRemainingString = "\(Int(remaining))s"
            upcomingEvent = event

            if lastShownPhase != "countdown" {
                NotchlyLogger.notice("⏱️ Showing countdown for event: \(event.title ?? "Unknown")", category: .calendar)
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
                    /// Set calendar activity flag
                    viewModel.calendarHasLiveActivity = true
                }
            }
            finishProcessing()
        } else if remaining < 300 && settings.alertTiming.contains(5) {
            /// 5-minute alert (only if 5m alerts enabled)
            if previousRemaining! > 300 && lastShownPhase != "5m" {
                NotchlyLogger.notice("🔔 Showing 5m alert for event: \(event.title ?? "Unknown")", category: .calendar)
                timeRemainingString = "5m"
                upcomingEvent = event
                lastShownPhase = "5m"
                scheduleExpiration(for: event)
                
                /// Only update visibility if it's changing
                if !isLiveActivityVisible {
                    isLiveActivityVisible = true
                    /// Set calendar activity flag
                    viewModel.calendarHasLiveActivity = true
                }
            }
            finishProcessing()
        } else if remaining < 900 && settings.alertTiming.contains(15) {
            /// 15-minute alert (only if 15m alerts enabled)
            if previousRemaining! > 900 && lastShownPhase != "15m" {
                NotchlyLogger.notice("🔔 Showing 15m alert for event: \(event.title ?? "Unknown")", category: .calendar)
                timeRemainingString = "15m"
                upcomingEvent = event
                lastShownPhase = "15m"
                scheduleExpiration(for: event)
                
                /// Only update visibility if it's changing
                if !isLiveActivityVisible {
                    isLiveActivityVisible = true
                    /// Set calendar activity flag
                    viewModel.calendarHasLiveActivity = true
                }
            }
            finishProcessing()
        } else {
            finishProcessing()
        }

        previousRemaining = remaining
    }
    
    /// Safely finish processing and handle any pending evaluations
    private func finishProcessing() {
        isProcessing = false
        
        /// If there was a pending evaluation, process it now
        if pendingEvaluation {
            pendingEvaluation = false
            DispatchQueue.main.async {
                self.evaluateLiveActivity()
            }
        }
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

    func reset(completion: (() -> Void)? = nil) {
        /// Only proceed if we need to hide the activity or if data needs to be cleared
        guard isLiveActivityVisible || upcomingEvent != nil || !timeRemainingString.isEmpty else {
            completion?()
            return
        }
        
        NotchlyLogger.debug("🧹 Resetting calendar live activity", category: .calendar)
        
        /// Cancel any existing expiration timer
        expirationTimer?.invalidate()
        expirationTimer = nil
        
        /// First signal that we're exiting (to animate the content)
        isExiting = true
        
        /// Only proceed with visibility change if it's currently visible
        if isLiveActivityVisible {
            /// Wait for content to fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else {
                    completion?()
                    return
                }
                
                /// Reset state
                self.isExiting = false
                self.upcomingEvent = nil
                self.timeRemainingString = ""
                self.previousRemaining = nil
                self.lastShownPhase = nil
                
                /// Set calendar activity flag to false directly in view model
                self.viewModel.calendarHasLiveActivity = false
                
                /// Then signal that activity is gone
                self.isLiveActivityVisible = false
                
                /// Update the configuration based on media playing state
                let shouldShowMedia = self.viewModel.isMediaPlaying
                DispatchQueue.main.async {
                    withAnimation(NotchlyAnimations.liveActivityTransition) {
                        if shouldShowMedia {
                            self.viewModel.configuration = .activity
                            self.viewModel.state = .mediaActivity
                        } else {
                            self.viewModel.configuration = .default
                            self.viewModel.state = .collapsed
                        }
                    }
                }
                
                /// Wait for the change to propagate before completing
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    completion?()
                }
            }
        } else {
            /// Just clear data without changing visibility
            self.upcomingEvent = nil
            self.timeRemainingString = ""
            self.previousRemaining = nil
            self.lastShownPhase = nil
            self.isExiting = false
            
            /// Also update the view model state here
            self.viewModel.calendarHasLiveActivity = false
            
            /// Immediately complete since no animation is needed
            completion?()
        }
    }
}
