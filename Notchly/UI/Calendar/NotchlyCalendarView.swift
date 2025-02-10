//
//  NotchlyCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//

import SwiftUI
import EventKit
import AppKit

struct NotchlyCalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedDate: Date = Date()
    @State private var weatherInfo: WeatherData? // ✅ Stores fetched weather
    var notchWidth: CGFloat
    var isExpanded: Bool // ✅ Receive the notch expansion state


    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // ✅ Month & Date Selector Stay Fixed
            VStack(spacing: 2) {
                Spacer(minLength: 2)
                NotchlyDateSelector(selectedDate: $selectedDate,
                                    calendarManager: calendarManager)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 🔥 Locks left-alignment

            // 🔹 Event List (or "No Events" placeholder)
            NotchlyEventList(selectedDate: selectedDate,
                             calendarManager: calendarManager,
                             calendarWidth: NotchlyConfiguration.large.width * 0.45)
                .frame(maxHeight: .infinity) // 🔥 Expands dynamically but never shifts things
        }
        .frame(
            width: NotchlyConfiguration.large.width * 0.45, // ✅ Keeps it within the large notch
            height: NotchlyConfiguration.large.height - 25 // ✅ Matches notch height with slight buffer
        )
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(NotchlyAnimations.smoothTransition, value: isExpanded)
    }

    // MARK: - Month Header
    private func monthHeader() -> some View {
        HStack {
            Text(selectedDate.formatted(.dateTime.month()))
                .font(.title2).bold()
                .foregroundColor(NotchlyTheme.primaryText)
            Spacer()
        }
    }

    // MARK: - Fetch Weather
    private func fetchWeather(for date: Date) {
        WeatherService.shared.getWeather(for: date) { weather in
            DispatchQueue.main.async { self.weatherInfo = weather }
        }
    }
}
