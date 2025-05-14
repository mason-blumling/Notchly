//
//  NotchlyTimelineCalendarView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI
import EventKit

/// A clean, minimalist timeline calendar view that closely matches the iOS-style design
struct NotchlyTimelineCalendarView: View {
    // MARK: - Properties
    
    @ObservedObject var calendarManager: CalendarManager
    @State private var selectedDate: Date = Date()
    
    /// Pre-cached event data to avoid computation during animations
    @State private var cachedEvents: [EKEvent] = []
    @State private var hasEvents: Bool = false
    
    /// Animation state control to prevent ellipsis flash while maintaining cohesive feel
    @State private var contentReady: Bool = false
    
    /// Layout configuration
    private let topRadius: CGFloat
    private let calendarWidth: CGFloat
    
    // MARK: - Initialization
    
    init(calendarManager: CalendarManager, topRadius: CGFloat = 12, width: CGFloat = 350) {
        self.calendarManager = calendarManager
        self.topRadius = topRadius
        self.calendarWidth = width
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            /// Date selector
            NotchlyTimelineDateSelector(
                selectedDate: $selectedDate,
                calendarManager: calendarManager,
                hasEvents: shouldShowEventDot
            )
            .frame(width: calendarWidth, alignment: .leading)
            
            /// Event list component
            NotchlyTimelineEventList(
                selectedDate: selectedDate,
                cachedEvents: cachedEvents,
                hasEvents: hasEvents,
                contentReady: contentReady,
                calendarWidth: calendarWidth
            )
            .frame(maxWidth: calendarWidth, maxHeight: .infinity)
        }
        .padding(.top, topRadius)
        .padding(.horizontal, 8)
        .frame(width: calendarWidth)
        .onAppear {
            updateCachedEvents(for: selectedDate)
            
            /// Pre-render content immediately for better stability
            contentReady = true
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                updateCachedEvents(for: newValue)
            }
        }
        .onChange(of: NotchlyViewModel.shared.state) { oldState, newState in
            /// Coordinate animation with parent container
            if oldState != .expanded && newState == .expanded {
                /// Pre-render content when expansion starts
                updateCachedEvents(for: selectedDate)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateCachedEvents(for date: Date) {
        let settings = NotchlySettings.shared
        let maxEvents = settings.maxEventsToDisplay
        
        var events = calendarManager.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
        
        if !settings.showCanceledEvents {
            events = events.filter { $0.status != .canceled }
        }
        
        events = events.sorted { $0.startDate < $1.startDate }
        
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        
        /// Force UI update on main thread
        DispatchQueue.main.async {
            self.cachedEvents = events
            self.hasEvents = !events.isEmpty
        }
    }
    
    private func shouldShowEventDot(for date: Date) -> Bool {
        let settings = NotchlySettings.shared
        return calendarManager.events.contains {
            Calendar.current.isDate($0.startDate, inSameDayAs: date) &&
            (settings.showCanceledEvents || $0.status != .canceled)
        }
    }
}
