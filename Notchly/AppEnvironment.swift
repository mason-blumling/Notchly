//
//  AppEnvironment.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

@MainActor
final class AppEnvironment: ObservableObject {
    let calendarManager: CalendarManager
    let mediaMonitor: MediaPlaybackMonitor
    let calendarActivityMonitor: CalendarLiveActivityMonitor

    init() {
        self.calendarManager = CalendarManager.shared ?? CalendarManager()
        self.mediaMonitor = MediaPlaybackMonitor.shared
        self.calendarActivityMonitor = CalendarLiveActivityMonitor(calendarManager: calendarManager)
    }
}
