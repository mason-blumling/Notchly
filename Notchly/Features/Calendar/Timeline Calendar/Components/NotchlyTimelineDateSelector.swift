//
//  NotchlyTimelineDateSelector.swift
//  Notchly
//
//  Created by Mason Blumling on 5/12/25.
//

import SwiftUI
import EventKit
import AppKit /// Required for NSHapticFeedbackManager

/// A horizontally scrolling date selector for the Timeline Calendar view.
/// Uses the same core functionality as NotchlyDateSelector but with the Timeline visual design.
struct NotchlyTimelineDateSelector: View {
    
    // MARK: - Properties
    
    @Binding var selectedDate: Date /// The currently selected date (bound to the parent view)
    @ObservedObject var calendarManager: CalendarManager /// Manages the user's calendar events
    @State private var scrollPosition: Int? /// Controls the scroll position in the date selector
    @State private var pendingSelection: Date? /// Used for handling smooth date selection
    @State private var isScrolling = false /// Prevents unwanted UI updates during scrolling
    @State private var monthBounce = false /// Handles the month bounce animation effect
    @State private var debounceTimer: Timer? /// Prevents excessive UI updates (debounce effect)
    @State private var visibleDates: [Date] = [] /// Array of dates to display
    
    /// Configuration for the date selector
    private let config = DateSelectorConfig()
    
    /// Event management
    private var hasEvents: (Date) -> Bool
    
    // MARK: - Initialization
    
    init(selectedDate: Binding<Date>, calendarManager: CalendarManager, hasEvents: @escaping (Date) -> Bool = { _ in false }) {
        self._selectedDate = selectedDate
        self.calendarManager = calendarManager
        self.hasEvents = hasEvents
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .leading) {
            /// Date selector - positioned like block calendar with offset for month
            dateSelector
                .zIndex(1)
            
            /// Month text with gradient background - positioned like block calendar
            monthBlock
                .zIndex(2)
        }
        .onAppear {
            /// Generate dates and scroll to today on first appearance
            generateVisibleDates()
            handleInitialOpen()
        }
    }
    
    // MARK: - UI Components
    
    private var monthBlock: some View {
        Text(selectedMonthName)
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(monthBounce ? Color.white.opacity(0.6) : .white)
            .padding(.leading, 6)
            .offset(x: -20, y: -4) /// Shifted left by 28 points to not overlap with dates
            .scaleEffect(monthBounce ? 1.15 : 1.0)
            .animation(NotchlyAnimations.fastBounce, value: monthBounce)
            .onTapGesture {
                monthBounce = true
                scrollToToday()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { monthBounce = false }
            }
    }
    
    /// The horizontally scrolling date selector - positioned like block calendar
    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { generateDateViews() }
                .frame(height: 44)
                .padding(.horizontal, 5)
        }
        .padding(.leading, 37)
        .frame(height: 44)
        .scrollTargetLayout()
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .onChange(of: scrollPosition) { _, newValue in
            if let index = newValue {
                let newDate = dateForIndex(index - config.offset + 1)
                if !Calendar.current.isDate(selectedDate, inSameDayAs: newDate) {
                    /// Small delay to prevent updating during view rendering
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selectedDate = newDate
                        triggerHapticFeedback()
                    }
                }
            }
        }
    }
    
    // MARK: - Date Generation
    
    /// Generates individual date buttons with timeline styling
    private func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps
        
        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: pendingSelection ?? selectedDate)
            let isToday = Calendar.current.isDateInToday(date)
            let dayNumber = Calendar.current.component(.day, from: date)
            
            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 1) {
                    /// Weekday text - using timeline style (with consistent weight)
                    Text(weekdayText(for: date, isSelected: isSelected))
                        .font(.system(size: isSelected ? 10 : 9, weight: .semibold))
                        .foregroundColor(weekdayColor(for: date, isSelected: isSelected, isToday: isToday))
                        .frame(width: 28, alignment: .center)
                    
                    /// Day number (with consistent weight)
                    Text("\(dayNumber)")
                        .font(.system(size: isSelected ? 16 : 14, weight: .bold))
                        .foregroundColor(dateColor(for: date, isSelected: isSelected, isToday: isToday))
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(NotchlyAnimations.fastBounce, value: isSelected)
                        .frame(height: 18)
                    
                    /// Event indicator dot from timeline
                    if hasEvents(date) {
                        Circle()
                            .fill(dotColor(for: date, isSelected: isSelected, isToday: isToday))
                            .frame(width: 4, height: 4)
                            .padding(.bottom, 2)
                    } else {
                        Spacer()
                            .frame(height: 6)
                    }
                }
                .padding(.vertical, isSelected ? 6 : 4) /// Match the block calendar padding
                .frame(width: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Behavior Logic (same as block calendar)
    
    private func handleDateSelection(_ date: Date) {
        /// Only proceed if we're not already selecting this date
        if Calendar.current.isDate(selectedDate, inSameDayAs: date) {
            return
        }
        
        let targetIndex = indexForDate(date)
        
        /// Safely set scrolling state outside of view update cycle
        DispatchQueue.main.async {
            self.isScrolling = true
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetIndex + 3
        }

        triggerHapticFeedback()

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            /// Use main thread for UI updates
            DispatchQueue.main.async {
                self.selectedDate = date
                self.isScrolling = false
            }
        }
    }

    /// Scrolls the selector back to today's date (same as block calendar)
    private func scrollToToday() {
        let todayIndex = indexForDate(Date())
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = todayIndex + 3
        }

        triggerHapticFeedback()
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            /// Safely update selection on main thread
            DispatchQueue.main.async {
                self.selectedDate = Date()
            }
        }
    }

    /// Ensures that the view scrolls to "Today" on first open (same as block calendar)
    private func handleInitialOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollToToday()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate dates array on component load (from timeline view)
    private func generateVisibleDates() {
        if !visibleDates.isEmpty {
            return
        }
        
        let calendar = Calendar.current
        let today = Date()
        let past = config.past
        let future = config.future
        
        let startDate = calendar.date(byAdding: .day, value: -past, to: today) ?? today
        
        var dates: [Date] = []
        for dayOffset in 0..<(past + future + 1) {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) {
                dates.append(date)
            }
        }
        
        visibleDates = dates
    }
    
    /// Get month name from selected date (from timeline view)
    private var selectedMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }
    
    /// Determine weekday text based on selection state (from timeline view)
    private func weekdayText(for date: Date, isSelected: Bool) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        
        if isSelected {
            /// Selected date shows 3-letter abbreviation
            switch weekday {
            case 1: return "SUN"
            case 2: return "MON"
            case 3: return "TUE"
            case 4: return "WED"
            case 5: return "THU"
            case 6: return "FRI"
            case 7: return "SAT"
            default: return ""
            }
        } else {
            /// Non-selected dates show single letter
            switch weekday {
            case 1: return "S"
            case 2: return "M"
            case 3: return "T"
            case 4: return "W"
            case 5: return "T"
            case 6: return "F"
            case 7: return "S"
            default: return ""
            }
        }
    }
    
    /// Date text color (from timeline view)
    private func dateColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .green.opacity(0.8)
        } else {
            return .white.opacity(0.75)
        }
    }

    /// Weekday letter color (from timeline view)
    private func weekdayColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .green.opacity(0.7)
        } else {
            return .gray.opacity(0.6)
        }
    }
    
    /// Event indicator dot color (from timeline view)
    private func dotColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .blue
        } else if isToday {
            return .green.opacity(0.8)
        } else {
            return .gray.opacity(0.6)
        }
    }
    
    /// Provides haptic feedback when a new date is selected.
    private func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .now)
    }
    
    /// Converts an index to a corresponding date (same as block calendar)
    private func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
    
    /// Finds the index position of a given date (same as block calendar)
    private func indexForDate(_ date: Date) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0 + config.offset
    }
}
