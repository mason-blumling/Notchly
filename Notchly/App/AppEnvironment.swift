//
//  AppEnvironment.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import Foundation
import EventKit
import os.log

/// Central container for shared app-wide state and services.
/// Injected into the SwiftUI environment and accessed via `.environmentObject`.
@MainActor
final class AppEnvironment: ObservableObject {
    
    /// Global singleton for shared access across the app.
    static let shared = AppEnvironment()

    // MARK: - Shared Services

    /// Handles calendar access, event fetching, and grouping.
    let calendarManager: CalendarManager

    /// Monitors media playback and controls the media player state.
    let mediaMonitor: MediaPlaybackMonitor

    /// Tracks and triggers calendar live activity alerts based on upcoming events.
    let calendarActivityMonitor: CalendarLiveActivityMonitor
    
    /// Calendar permission status tracking
    @Published var calendarPermissionStatus: EKAuthorizationStatus = .notDetermined

    // MARK: - Initialization

    private init() {
        self.calendarManager = CalendarManager()
        self.mediaMonitor = MediaPlaybackMonitor()
        self.calendarActivityMonitor = CalendarLiveActivityMonitor(calendarManager: calendarManager)
        
        /// Check initial permission status
        self.calendarPermissionStatus = EKEventStore.authorizationStatus(for: .event)
        
        /// Set up permission observer
        setupPermissionObservers()
    }

    /// Add a method to request calendar permission
    func requestCalendarPermission(completion: @escaping (Bool) -> Void) {
        calendarManager.requestAccess(completion: completion)
    }

    func initialize() {
        /// Check permission status immediately (synchronously)
        self.checkCalendarPermissionStatus()
        
        /// Then launch an async task for the data loading part
        Task { @MainActor in
            /// If calendar is enabled and we have permission, load events
            if NotchlySettings.shared.enableCalendar && self.calendarManager.hasCalendarPermission() {
                NotchlyLogger.calendar("📅 Loading calendar data on app initialization...")
                await NotchlySettings.shared.refreshCalendarEvents()
            }
        }
    }

    func checkCalendarPermissionStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        self.calendarPermissionStatus = status
        NotchlyLogger.calendar("📅 Current calendar permission status: \(status.rawValue)")
        
        /// Broadcast the current status
        NotificationCenter.default.post(
            name: Notification.Name("NotchlyCalendarPermissionChanged"),
            object: nil,
            userInfo: ["status": status.rawValue, "granted": status == .fullAccess]
        )
        
        /// If we have permission but no data loaded, refresh the data
        if status == .fullAccess && NotchlySettings.shared.enableCalendar && calendarManager.events.isEmpty {
            Task { @MainActor in
                /// This ensures data is loaded whenever status is checked and we have permission
                await NotchlySettings.shared.refreshCalendarEvents()
            }
        }
    }
    
    private func setupPermissionObservers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NotchlyCalendarPermissionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let statusRawValue = userInfo["status"] as? Int,
                  let status = EKAuthorizationStatus(rawValue: statusRawValue) else { return }
            
            Task { @MainActor in
                /// Update the permission status
                self.calendarPermissionStatus = status
                
                /// If granted, trigger calendar data reload
                if status == .fullAccess {
                    await NotchlySettings.shared.handleCalendarPermissionGranted()
                }
                
                /// Notify settings system about permission change
                NotificationCenter.default.post(
                    name: SettingsChangeType.calendar.notificationName,
                    object: nil,
                    userInfo: ["permissionChanged": true, "permissionGranted": status == .fullAccess]
                )
            }
        }
    }
}
