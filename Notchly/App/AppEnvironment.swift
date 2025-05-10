//
//  AppEnvironment.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import Foundation
import EventKit

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
    
    /// Add a method to request calendar permission
    func requestCalendarPermission(completion: @escaping (Bool) -> Void) {
        calendarManager.requestAccess(completion: completion)
    }
    
    /// Add a method to check current permission status
    func checkCalendarPermissionStatus() {
        calendarManager.checkAndBroadcastPermissionStatus()
    }
}
