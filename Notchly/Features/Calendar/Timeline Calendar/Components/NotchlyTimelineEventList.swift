//
//  NotchlyTimelineEventList.swift
//  Notchly
//
//  Created by Mason Blumling on 5/13/25.
//

import SwiftUI
import EventKit

/// Displays events in a timeline style with vertical connection line
struct NotchlyTimelineEventList: View {
    // MARK: - Properties
    
    let selectedDate: Date
    let cachedEvents: [EKEvent]
    let hasEvents: Bool
    let contentReady: Bool
    let calendarWidth: CGFloat
    
    @State private var pressedEventID: String? = nil
    
    /// Reusable time formatter for performance - initialized exactly as in original
    private let timeFormatter = DateFormatter()
    
    /// Timeline styling constants
    private let dotSize: CGFloat = 8
    private let lineWidth: CGFloat = 1.5
    
    // MARK: - Initialization
    
    init(selectedDate: Date, cachedEvents: [EKEvent], hasEvents: Bool, contentReady: Bool, calendarWidth: CGFloat) {
        self.selectedDate = selectedDate
        self.cachedEvents = cachedEvents
        self.hasEvents = hasEvents
        self.contentReady = contentReady
        self.calendarWidth = calendarWidth
        
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
    }
    
    // MARK: - Body
    
    var body: some View {
        /// Event content with stabilized container
        ZStack {
            /// Always include both views, just toggle opacity
            eventList
                .opacity(hasEvents && contentReady ? 1 : 0)
            
            emptyStateView
                .opacity(!hasEvents && contentReady ? 1 : 0)
                
            /// Keep the invisible placeholder for layout stability
            placeholderEventList
                .opacity(0)
        }
    }
    
    // MARK: - UI Components
    
    // Pre-rendered placeholder with same layout but invisible content
    private var placeholderEventList: some View {
        let timelineXPosition: CGFloat = calendarWidth * 0.6
        let linePosition = timelineXPosition + 7
        
        return ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: lineWidth)
                .frame(maxHeight: .infinity)
                .offset(x: linePosition)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(cachedEvents, id: \.eventIdentifier) { event in
                        placeholderEventRow(event, linePosition: timelineXPosition)
                    }
                    
                    if cachedEvents.count == 1 {
                        Spacer().frame(height: 30)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxHeight: .infinity)
    }
    
    /// Simplified placeholder with identical layout to real event row
    private func placeholderEventRow(_ event: EKEvent, linePosition: CGFloat) -> some View {
        /// Use the same title splitting logic as the real event row
        let title = event.title ?? "Untitled Event"
        
        return HStack(spacing: 0) {
            /// Match the exact structure of the real event row
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    /// Video call icon placeholder
                    Color.clear
                        .frame(width: 16, height: 16)
                    
                    /// Title placeholder with same size constraints
                    Color.clear
                        .frame(height: 18)
                        .frame(maxWidth: linePosition - 36)
                }
                
                /// Second line for longer titles
                if title.count > 25 {
                    Color.clear
                        .frame(height: 18)
                        .frame(maxWidth: linePosition - 36)
                }
            }
            .frame(width: linePosition - 20, alignment: .trailing)
            .padding(.trailing, 12)
            
            /// EVENT DOT placeholder
            Color.clear
                .frame(width: dotSize, height: dotSize)
            
            /// EVENT TIME placeholder
            Color.clear
                .frame(width: calendarWidth - linePosition - 24)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: title.count > 25 ? 50 : 38)
        .frame(width: calendarWidth - 24) // Match exact width of real event rows
    }
    
    private var eventList: some View {
        /// Maintain the same position for event layout
        let timelineXPosition: CGFloat = calendarWidth * 0.6
        
        /// Calculate the center of the dot for the timeline line
        let linePosition = timelineXPosition + 7
        
        return ZStack(alignment: .leading) {
            /// Vertical timeline line
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: lineWidth)
                .frame(maxHeight: .infinity)
                .offset(x: linePosition)
                .zIndex(1)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(cachedEvents, id: \.eventIdentifier) { event in
                        eventRow(event, linePosition: timelineXPosition)
                    }
                    
                    if cachedEvents.count == 1 {
                        Spacer().frame(height: 30)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .zIndex(2)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.gray.opacity(0.1)))
            
            Text("No events today")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .compositingGroup()
    }

    private func eventRow(_ event: EKEvent, linePosition: CGFloat) -> some View {
        let title = event.title ?? "Untitled Event"
        let hasVideoCall = checkEventHasVideoCall(event)
        let calendarColor = Color(cgColor: event.calendar.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0))
        let formattedTimeString = formatEventTime(event)
        let isPressed = pressedEventID == event.eventIdentifier
        
        return HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    /// Video call icon
                    if hasVideoCall {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    
                    /// Title with natural text wrapping
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(width: linePosition - 20, alignment: .trailing)
            .padding(.trailing, 12)
            
            /// EVENT DOT
            Circle()
                .fill(calendarColor)
                .frame(width: dotSize, height: dotSize)
            
            /// EVENT TIME
            Text(formattedTimeString)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .lineLimit(1)
                .frame(width: calendarWidth - linePosition - 24, alignment: .leading)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: title.count > 25 ? 50 : 38)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.15))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(NotchlyAnimations.fastBounce, value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            handleEventPress(event)
        }
        .drawingGroup()
    }
    
    // MARK: - Interaction Handlers
    
    private func handleEventPress(_ event: EKEvent) {
        withAnimation(.easeInOut(duration: 0.1)) {
            pressedEventID = event.eventIdentifier
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.pressedEventID = nil
            }
            self.openEventInCalendar(event: event, date: event.startDate)
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkEventHasVideoCall(_ event: EKEvent) -> Bool {
        guard let title = event.title?.lowercased() else { return false }
        return title.contains("zoom") || title.contains("meet") ||
               title.contains("teams") || title.contains("webex") ||
               title.contains("call") || title.contains("video")
    }
    
    private func formatEventTime(_ event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        
        let startTime = timeFormatter.string(from: event.startDate)
        let endTime = timeFormatter.string(from: event.endDate)
        return "\(startTime) - \(endTime)"
    }
    
    private func openEventInCalendar(event: EKEvent, date: Date) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) else {
            return
        }
        
        let formattedDate = formatDateForCalendar(date)
        
        if let url = URL(string: "ical://ekevent/\(formattedDate)/\(eventIdentifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func formatDateForCalendar(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: date)
    }
}
