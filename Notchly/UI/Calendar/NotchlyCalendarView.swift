//
//  NotchlyCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//

import SwiftUI
import EventKit

/// A calendar view that displays the current week, highlights today, and shows events for the selected day.
/// It also integrates a weather widget for a full view of daily plans.
struct NotchlyCalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedDate: Date = Date() // Default to today
    @State private var weatherInfo: WeatherData? = nil // Holds weather data

    private let weekdays: [String] = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month Header
            Text(selectedDate.formatted(.dateTime.month()))
                .font(.title3)
                .bold()
                .foregroundColor(.white)

            // Weekday Headers & Dates
            HStack(spacing: 12) {
                let startOfWeek = Calendar.current.startOfWeek(for: Date()) ?? Date()
                ForEach(0..<7, id: \.self) { index in
                    let day = Calendar.current.date(byAdding: .day, value: index, to: startOfWeek) ?? Date()
                    VStack {
                        Text(weekdays[index])
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(day.formatted(.dateTime.day()))
                            .font(.headline)
                            .foregroundColor(isSelected(day) ? .black : .white)
                            .padding(8)
                            .background(isSelected(day) ? Color.white : Color.clear)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedDate = day
                                fetchWeather(for: day) // Fetch weather for selected date
                            }
                            .scaleEffect(isSelected(day) ? 1.1 : 1.0) // Interactive hover effect
                            .animation(.easeInOut(duration: 0.2), value: selectedDate)
                    }
                }
            }

            // Weather Widget
            if let weather = weatherInfo {
                HStack {
                    Image(systemName: weather.icon)
                        .foregroundColor(.yellow)
                        .font(.title2)

                    Text("\(weather.temperature)° \(weather.condition)")
                        .foregroundColor(.white)
                        .font(.subheadline)

                    Spacer()
                }
                .padding(.vertical, 5)
            }

            // Events for Selected Day
            VStack(alignment: .leading, spacing: 5) {
                if eventsForSelectedDate().isEmpty {
                    Text("No Events")
                        .foregroundColor(.gray)
                        .font(.caption)
                        .italic()
                } else {
                    ForEach(eventsForSelectedDate(), id: \.eventIdentifier) { event in
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)

                            Text(event.title)
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .onAppear {
            fetchWeather(for: selectedDate)
        }
    }

    // MARK: - Helper Methods

    /// Checks if a given date is the currently selected date.
    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: date)
    }

    /// Fetches events for the selected date.
    private func eventsForSelectedDate() -> [EKEvent] {
        return calendarManager.events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }
    }

    /// Fetches weather data for the selected date.
    private func fetchWeather(for date: Date) {
        WeatherService.shared.getWeather(for: date) { weather in
            DispatchQueue.main.async {
                self.weatherInfo = weather
            }
        }
    }
}

// MARK: - Calendar Extension
extension Calendar {
    /// Returns the start of the week for a given date.
    func startOfWeek(for date: Date) -> Date? {
        self.dateInterval(of: .weekOfYear, for: date)?.start
    }
}

// MARK: - Weather Model
struct WeatherData {
    let temperature: Int
    let condition: String
    let icon: String
}

// MARK: - Weather Service
class WeatherService {
    static let shared = WeatherService()

    func getWeather(for date: Date, completion: @escaping (WeatherData?) -> Void) {
        // Mocked Weather Data (Replace with real API call if needed)
        let sampleWeather = WeatherData(temperature: 72, condition: "Sunny", icon: "sun.max.fill")
        completion(sampleWeather)
    }
}

// MARK: - Preview
#Preview {
    NotchlyCalendarView(calendarManager: CalendarManager())
        .background(Color.gray.edgesIgnoringSafeArea(.all))
}
