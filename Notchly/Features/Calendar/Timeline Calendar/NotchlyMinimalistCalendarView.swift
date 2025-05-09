//
//  NotchlyMinimalistCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI
import EventKit

/// A clean, minimalist timeline calendar view that closely matches the iOS-style design
/// Enhanced with feature parity from the block calendar version
struct NotchlyMinimalistCalendarView: View {
    // MARK: - Properties
    
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedDate: Date = Date()
    @State private var pressedEventID: String? = nil
    
    /// Layout configuration
    private let topRadius: CGFloat
    private let calendarWidth: CGFloat
    
    /// Timeline styling constants
    private let timelineColor = Color.gray.opacity(0.3)
    private let dotSize: CGFloat = 8
    private let timelinePadding: CGFloat = 12
    private let verticalLineOffset: CGFloat = 0.5
    
    // MARK: - Initialization
    
    /// Initializes the calendar view with the specified manager and layout parameters
    init(calendarManager: CalendarManager, topRadius: CGFloat = 12, width: CGFloat = 350) {
        self.calendarManager = calendarManager
        self.topRadius = topRadius
        self.calendarWidth = width
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            /// Using our revised date selector that positions at the same height as block calendar
            NotchlyTimelineDateSelector(
                selectedDate: $selectedDate,
                calendarManager: calendarManager,
                hasEvents: shouldShowEventDot
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            /// Timeline events view remains unchanged as you mentioned it's working perfectly
            timelineEventsView
                .frame(maxHeight: .infinity)
        }
        /// Match EXACT same padding values as the block calendar for perfect alignment
        .padding(.top, topRadius)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Timeline Events View

    /// Scrollable container for timeline events with vertical connecting line
    private var timelineEventsView: some View {
        let events = eventsForDate(selectedDate)
        
        return ScrollView {
            if events.isEmpty {
                emptyStateView
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10) /// Match block calendar padding
            } else {
                VStack(spacing: 10) {
                    ForEach(events, id: \.eventIdentifier) { event in
                        eventRow(event)
                    }
                    
                    /// Add extra spacing when only one event to extend the timeline visually
                    if events.count == 1 {
                        Spacer()
                            .frame(height: 40)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 12)
                .overlay(
                    /// Performance optimization: Simplify the vertical line rendering
                    Rectangle()
                        .fill(timelineColor)
                        .frame(width: 1)
                        /// Extend the line further when there's only one event
                        .frame(height: events.count == 1 ? 80 : nil)
                        .position(
                            x: 160 + 10 + (dotSize/2),
                            /// Adjust position based on event count
                            y: events.count == 1
                                ? 35 /// Center point when there's only one event with extension
                                : CGFloat(events.count * 28) / 2 /// Normal centering for multiple events
                        )
                )
                .frame(width: 300, alignment: .center)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Empty state view with better visual design - more compact
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            // Fun icon with subtle animation
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient(
                    colors: [.blue.opacity(0.7), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                /// More subtle breathing animation
                .modifier(BreathingAnimation(scale: 1.03))
            
            VStack(spacing: 2) {
                Text("No events today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.9))
                
                Text("Enjoy your free time")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .drawingGroup()
    }

    struct BreathingAnimation: ViewModifier {
        @State private var isBreathing = false
        var scale: CGFloat
        
        init(scale: CGFloat = 1.05) {
            self.scale = scale
        }
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isBreathing ? scale : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.8)
                        .repeatForever(autoreverses: true),
                    value: isBreathing
                )
                .onAppear {
                    isBreathing = true
                }
        }
    }
    
    /// Single event row with left title, center dot, and right time
    private func eventRow(_ event: EKEvent) -> some View {
        HStack(alignment: .center, spacing: 0) {
            /// Left side with icon and title
            HStack(alignment: .center, spacing: 4) {
                if checkEventHasVideoCall(event) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .frame(width: 16, height: 16)
                }
                
                Text(event.title ?? "Untitled Event")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 160, alignment: .trailing)
            .padding(.trailing, 10)
            
            /// Center dot
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)))
                .frame(width: dotSize, height: dotSize)
            
            /// Right side time
            Text(formatEventTime(event))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
                .padding(.leading, 10)
        }
        .frame(height: 38)
        .contentShape(Rectangle())
        .scaleEffect(pressedEventID == event.eventIdentifier ? 0.95 : 1.0)
        .animation(NotchlyAnimations.fastBounce, value: pressedEventID == event.eventIdentifier)
        .onTapGesture {
            /// Don't set the pressedEventID during the view update cycle
            DispatchQueue.main.async {
                pressedEventID = event.eventIdentifier
            }
            /// Use a delayed reset to provide visual feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                pressedEventID = nil
                openEventInCalendar(event: event, date: event.startDate)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns filtered and sorted events for the specified date
    private func eventsForDate(_ date: Date) -> [EKEvent] {
        let settings = NotchlySettings.shared
        let maxEvents = settings.maxEventsToDisplay
        
        var events = calendarManager.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
        
        /// Filter out canceled events if the setting is disabled
        if !settings.showCanceledEvents {
            events = events.filter { $0.status != .canceled }
        }
        
        /// Sort the filtered events
        events = events.sorted { $0.startDate < $1.startDate }
        
        /// Apply limit from settings
        if events.count > maxEvents {
            return Array(events.prefix(maxEvents))
        }
        
        return events
    }
    
    /// Determines if a date should show an event dot
    private func shouldShowEventDot(for date: Date) -> Bool {
        let settings = NotchlySettings.shared
        
        let dateEvents = calendarManager.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
            .filter { settings.showCanceledEvents || $0.status != .canceled }
        
        return !dateEvents.isEmpty
    }

    /// Formats event time as "startTime - endTime" or "All day"
    private func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)
            return "\(startTime) - \(endTime)"
        }
    }

    /// Optimized video call detection without excessive string operations
    private func checkEventHasVideoCall(_ event: EKEvent) -> Bool {
        let keywords = ["zoom", "meet", "teams", "webex", "call", "conference",
                        "video", "sync", "online", "virtual"]
        
        /// Check title first (most efficient)
        if let title = event.title?.lowercased() {
            for keyword in keywords where title.contains(keyword) {
                return true
            }
        }
        
        /// Check location second
        if let location = event.location?.lowercased() {
            if location.contains("http") || location.contains("://") {
                return true
            }
            
            for keyword in keywords where location.contains(keyword) {
                return true
            }
            
            let videoDomains = ["zoom.us", "meet.google", "teams.microsoft", "webex.com"]
            for domain in videoDomains where location.contains(domain) {
                return true
            }
        }
        
        /// Check notes last
        if let notes = event.notes?.lowercased() {
            if notes.contains("http://") || notes.contains("https://") {
                return true
            }
            
            for keyword in keywords where notes.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    /// Opens the selected event in the native macOS Calendar app
    func openEventInCalendar(event: EKEvent, date: Date) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) else {
            print("Error: Could not encode event identifier.")
            return
        }

        let formattedDate = date.toCalendarDateString()

        if let url = URL(string: "ical://ekevent/\(formattedDate)/\(eventIdentifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        } else {
            print("Error: Could not create URL.")
        }
    }
}

extension Date {
    fileprivate func toCalendarDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: self)
    }
}
