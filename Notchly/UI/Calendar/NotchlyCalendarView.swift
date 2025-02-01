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
    @State private var pressedEventID: String? = nil
    @State private var scrollPosition: Int?
    @State private var byClick: Bool = false
    private let config = Config()
    @State private var lastCloseTime: Date?

    var body: some View {
        HStack(spacing: 0) {
            Spacer() // Pushes everything to the right

            VStack(alignment: .leading, spacing: 6) {
                monthHeader() // 🔥 Extracted into a method
                calendarRow() // 🔥 Extracted condensed calendar
                eventsSection() // 🔥 Extracted event display
            }
            .frame(width: 180) // 🔥 Shrink width for balance
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    // MARK: - Month Header
    private func monthHeader() -> some View {
        HStack {
            Text(selectedDate.formatted(.dateTime.month()))
                .font(.title2).bold()
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.bottom, 2) // 🔥 Slight padding below the header
    }

    // MARK: - Condensed Calendar Row
    private func calendarRow() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                let totalSteps = config.steps * (config.past + config.future)
                let spacerNum = config.offset

                ForEach(0..<totalSteps + 2 * spacerNum + 1, id: \.self) { index in
                    let offset = -config.offset - config.past
                    let date = dateForIndex(index, offset: offset)
                    let isSelected = isDateSelected(index, offset: offset)

                    dateButton(date: date, isSelected: isSelected)
                }
            }
            .padding(.horizontal, 5)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center) // 🔥 Ensures smooth scrolling
        .onChange(of: scrollPosition) { _, newValue in
            if !byClick {
                handleScrollChange(newValue: newValue)
            } else {
                byClick = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                scrollToToday() // ✅ Ensure today is centered
            }
            fetchWeather(for: selectedDate)
        }
    }

    // MARK: - Date Button
    private func dateButton(date: Date, isSelected: Bool) -> some View {
        Button(action: {
            withAnimation {
                selectedDate = date
            }
        }) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.narrow))) // 🔥 Day letters
                    .font(.caption2)
                    .frame(width: 18, height: 14)
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))

                Text("\(Calendar.current.component(.day, from: date))") // 🔥 Day number
                    .font(.subheadline)
                    .bold()
                    .monospacedDigit()
                    .frame(minWidth: 22, maxWidth: 24)
                    .foregroundColor(isSelected ? .white : .gray.opacity(0.5))
            }
            .padding(8) // 🔥 Makes the entire highlight a bigger hitbox
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle()) // 🔥 Prevents button styling from messing with layout
        .contentShape(Rectangle()) // 🔥 Expands the tappable area to the whole highlight
    }

    // MARK: - Events Section
    private func eventsSection() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if eventsForSelectedDate().isEmpty {
                Text("No Events")
                    .foregroundColor(.gray)
                    .font(.caption)
                    .italic()
            } else {
                ForEach(eventsForSelectedDate().prefix(3), id: \.eventIdentifier) { event in
                    eventRow(event: event)
                }

                if eventsForSelectedDate().count > 3 {
                    Text("More events...")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .italic()
                }
            }
        }
    }

    // MARK: - Calendar Date Scroll View
    private func calendarDateScrollView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) { // 🔥 Adjust spacing for better alignment
                let totalSteps = config.steps * (config.past + config.future)
                let spacerNum = config.offset
                ForEach(0..<totalSteps + 2 * spacerNum + 1, id: \.self) { index in
                    if index < spacerNum || index > totalSteps + spacerNum - 1 {
                        Spacer().frame(width: 28, height: 28).id(index) // 🔥 Maintain spacing
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
            .padding(.horizontal, 5) // 🔥 Gives space for smooth scrolling
        }
        .scrollPosition(id: $scrollPosition, anchor: .center) // 🔥 Keeps it scrollable
        .onChange(of: scrollPosition) { _, newValue in
            if !byClick {
                handleScrollChange(newValue: newValue)
            } else {
                byClick = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // 🔥 Ensure proper scrolling
                scrollToToday()
            }
            fetchWeather(for: selectedDate)
        }
    }

    // MARK: - Weather Widget
    private func weatherWidget() -> some View {
        Group {
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
        }
    }

    // MARK: - Events List View
    private func eventsListView() -> some View {
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


    // MARK: - Event Row
    private func eventRow(event: EKEvent) -> some View {
        let isCancelled = event.status == .canceled
        let isPressed = pressedEventID == event.eventIdentifier

        return HStack {
            Circle()
                .fill(isCancelled ? Color.gray.opacity(0.5) : (event.startDate < Date() ? Color.gray : Color.red))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading) {
                Text(event.title)
                    .foregroundColor(isCancelled ? .gray : (event.startDate < Date() ? .gray : .white))
                    .lineLimit(1)
                    .strikethrough(isCancelled, color: .gray)
                    .scaleEffect(isPressed ? 0.9 : 1.0) // Press effect

                if let attendees = event.attendees, !attendees.isEmpty {
                    attendeesInfo(attendees: attendees)
                }

                if isCancelled {
                    Text("(Cancelled)")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }

            Spacer()
            eventTimeText(event)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            pressedEventID = event.eventIdentifier
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pressedEventID = nil
            }
            if !isCancelled {
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

    private func attendeesInfo(attendees: [EKParticipant]) -> some View {
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

    private func eventTimeText(_ event: EKEvent) -> some View {
        Text(event.startDate.formatted(date: .omitted, time: .shortened))
            .foregroundColor(.gray)
            .font(.caption)
    }

    // MARK: - Helper Methods
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
        let offset = -config.offset - config.past - 1 
        let todayIndex = indexForDate(today, offset: offset)

        selectedDate = today
        byClick = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // Give UI time to render
            withAnimation {
                scrollPosition = todayIndex // ✅ Centers today in the scroll view
            }
        }
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

    private func isDateSelected(_ index: Int, offset: Int) -> Bool {
        Calendar.current.isDate(dateForIndex(index, offset: offset), inSameDayAs: selectedDate)
    }
}

// MARK: - Weather Model & Service
struct WeatherData {
    let temperature: Int
    let condition: String
    let icon: String
}

class WeatherService {
    static let shared = WeatherService()
    func getWeather(for date: Date, completion: @escaping (WeatherData?) -> Void) {
        let sampleWeather = WeatherData(temperature: 72, condition: "Sunny", icon: "sun.max.fill")
        completion(sampleWeather)
    }
}
