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
            monthHeader()
            NotchlyDateSelector(
                selectedDate: $selectedDate,
                calendarManager: calendarManager
            )
            NotchlyEventList(
                selectedDate: selectedDate,
                calendarManager: calendarManager
            )
        }
        .frame(
            width: NotchPresets.large.width * 0.45, // ✅ Keeps it within the large notch
            height: NotchPresets.large.height - 5 // ✅ Matches notch height with slight buffer
        )
        .offset(x: NotchPresets.small.width * 0.3) // ✅ Moves it rightward to align with the small notch's rightmost point
        .padding(.leading, 5) // ✅ Optional fine-tuning
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }

    // MARK: - Month Header
    private func monthHeader() -> some View {
        HStack {
            Text(selectedDate.formatted(.dateTime.month()))
                .font(.title2).bold()
                .foregroundColor(.white)
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
