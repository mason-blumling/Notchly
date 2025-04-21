//
//  Notchly+Environment.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let calendarManager: CalendarManager
    let mediaMonitor: MediaPlaybackMonitor
    let calendarActivityMonitor: CalendarLiveActivityMonitor

    private init() {
        self.calendarManager = CalendarManager()
        self.mediaMonitor = MediaPlaybackMonitor()
        self.calendarActivityMonitor = CalendarLiveActivityMonitor(calendarManager: calendarManager)
    }
}
