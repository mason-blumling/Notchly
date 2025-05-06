//
//  AppEnvironment.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import Foundation

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

    // MARK: - Initialization

    private init() {
        self.calendarManager = CalendarManager()
        self.mediaMonitor = MediaPlaybackMonitor()
        self.calendarActivityMonitor = CalendarLiveActivityMonitor(calendarManager: calendarManager)
    }
}
