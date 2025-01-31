//
//  NotchlyCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/29/25.
//

import SwiftUI
import EventKit
import AppKit

struct Config {
    var past: Int = 3
    var future: Int = 7
    var steps: Int = 1
    var spacing: CGFloat = 8
    var offset: Int = 3
}

struct NotchlyCalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedDate: Date = Date()
    @State private var weatherInfo: WeatherData? = nil
    @State private var pressedEvents: Set<String> = []
    @State private var scrollPosition: Int?
    @State private var byClick: Bool = false
    private let config = Config()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(.dateTime.month()))
                .font(.title3)
                .bold()
                .foregroundColor(.white)

            // Horizontal Scrolling Dates
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: config.spacing) {
                    let totalSteps = config.steps * (config.past + config.future)
                    let spacerNum = config.offset
                    ForEach(0..<totalSteps + 2 * spacerNum + 1, id: \.self) { index in
                        if index < spacerNum || index > totalSteps + spacerNum - 1 {
                            Spacer().frame(width: 32, height: 32).id(index)
                        } else {
                            let offset = -config.offset - config.past
                            let date = dateForIndex(index, offset: offset)
                            let isSelected = isDateSelected(index, offset: offset)
                            dateButton(date: date, isSelected: isSelected, offset: offset) {
                                selectedDate = date
                                byClick = true
                                withAnimation {
                                    scrollPosition = indexForDate(date, offset: offset) - config.offset
                                }
                                fetchWeather(for: date)
                            }
                        }
                    }
                }
                .frame(height: 75)
                .padding(.vertical, 5)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrollPosition, anchor: .leading)
            .onChange(of: scrollPosition) { _, newValue in
                if !byClick {
                    handleScrollChange(newValue: newValue)
                } else {
                    byClick = false
                }
            }
            .onAppear {
                scrollToToday()
                fetchWeather(for: selectedDate)
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
                        eventRow(event: event)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    // MARK: - Event Row
    private func eventRow(event: EKEvent) -> some View {
        let isCancelled = event.status == .canceled

        return HStack {
            Circle()
                .fill(isCancelled ? Color.gray.opacity(0.5) : (event.startDate < Date() ? Color.gray : Color.red))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading) {
                Text(event.title)
                    .foregroundColor(isCancelled ? .gray : (event.startDate < Date() ? .gray : .white))
                    .lineLimit(1)
                    .strikethrough(isCancelled, color: .gray)

                if let attendees = event.attendees, !attendees.isEmpty {
                    HStack {
                        Text("\(attendees.count) attendees")
                            .foregroundColor(.gray)
                            .font(.caption)

                        if let currentUser = attendees.first(where: { $0.isCurrentUser }) {
                            switch currentUser.participantStatus {
                            case .pending:
                                Text("(Pending)").foregroundColor(.yellow).font(.caption)
                            case .accepted:
                                Text("(Accepted)").foregroundColor(.green).font(.caption)
                            case .declined:
                                Text("(Declined)").foregroundColor(.red).font(.caption)
                            case .tentative:
                                Text("(Tentative)").foregroundColor(.orange).font(.caption)
                            default:
                                EmptyView()
                            }
                        }
                    }
                }

                if isCancelled {
                    Text("(Cancelled)")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }

            Spacer()

            if let currentUser = event.attendees?.first(where: { $0.isCurrentUser }),
               currentUser.participantStatus == .pending && !isCancelled {
                Button("✔") { }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(.green)
                Button("✖") { }
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(.red)
            }

            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isCancelled { // Prevents opening cancelled events
                openEventInCalendar(event)
            }
        }
    }

    // MARK: - Open Event in Calendar
    private func openEventInCalendar(_ event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("❌ Failed to encode event identifier: \(String(describing: event.title))")
            return
        }

        var urlString = "ical://ekevent/\(eventIdentifier)?method=show&options=more"

        // If it's a recurring event, append the exact start date
        if event.hasRecurrenceRules, let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = event.isAllDay ? TimeZone.current : TimeZone(secondsFromGMT: 0)
            
            let dateComponent = formatter.string(from: startDate)
            urlString.insert(contentsOf: "/\(dateComponent)", at: urlString.index(urlString.startIndex, offsetBy: 14))
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            print("❌ Failed to create URL for event: \(String(describing: event.title))")
        }
    }

    // MARK: - Helper Methods
    private func isDateSelected(_ index: Int, offset: Int) -> Bool {
        Calendar.current.isDate(dateForIndex(index, offset: offset), inSameDayAs: selectedDate)
    }

    private func eventsForSelectedDate() -> [EKEvent] {
        return calendarManager.events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate)
        }
    }

    private func fetchWeather(for date: Date) {
        WeatherService.shared.getWeather(for: date) { weather in
            DispatchQueue.main.async {
                self.weatherInfo = weather
            }
        }
    }

    private func handleScrollChange(newValue: Int?) {
        let offset = -config.offset - config.past
        guard let newIndex = newValue else { return }
        selectedDate = dateForIndex(newIndex + config.offset, offset: offset)
    }

    private func scrollToToday() {
        let today = Date()
        let todayIndex = indexForDate(today, offset: -config.offset - config.past)
        byClick = true
        scrollPosition = todayIndex - config.offset
        selectedDate = today
    }

    private func dateForIndex(_ index: Int, offset: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }

    private func indexForDate(_ date: Date, offset: Int) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0
    }

    private func dateToString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func dateButton(date: Date, isSelected: Bool, offset: Int, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            VStack(spacing: 4) {
                Text(dateToString(for: date))
                    .font(.caption2)
                    .foregroundColor(isSelected ? .red : .gray)

                ZStack {
                    Circle()
                        .fill(isSelected ? .red : .clear)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().stroke(Color.red, lineWidth: isSelected ? 2 : 0)
                        )

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : .gray)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .id(indexForDate(date, offset: offset))
        }
        .buttonStyle(PlainButtonStyle())
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
        let sampleWeather = WeatherData(temperature: 72, condition: "Sunny", icon: "sun.max.fill")
        completion(sampleWeather)
    }
}
