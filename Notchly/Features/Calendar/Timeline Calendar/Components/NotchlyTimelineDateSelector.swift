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
/// Uses the exact same core logic as NotchlyDateSelector but with the Timeline visual design.
struct NotchlyTimelineDateSelector: View {
    
    // MARK: - Properties
    
    @Binding var selectedDate: Date
    @ObservedObject var calendarManager: CalendarManager
    @State private var scrollPosition: Int? /// Controls the scroll position in the date selector
    @State private var pendingSelection: Date? /// Used for handling smooth date selection
    @State private var isScrolling = false /// Prevents unwanted UI updates during scrolling
    @State private var monthBounce = false /// Handles the month bounce animation effect
    @State private var debounceTimer: Timer? /// Prevents excessive UI updates (debounce effect)
    @State private var isInitialized = false /// Track if we've done initial positioning
    
    /// Constants for consistent positioning
    private let todayPositionOffset = 3 /// The fixed offset where today should appear
    
    private let config = DateSelectorConfig()
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
            /// Month display - using exact same positioning as block calendar
            monthBlock
                .zIndex(2)
            
            /// Date selector - using exact same parameters as block calendar
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) { generateDateViews(proxy: proxy) }
                        .frame(height: 44)
                        .padding(.horizontal, 5)
                }
                .padding(.leading, 75) /// Exactly matching block calendar padding
                .frame(height: 44)
                .scrollTargetLayout()
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .scrollTargetBehavior(.viewAligned)
                .onChange(of: scrollPosition) { _, newValue in
                    if let index = newValue, !isScrolling {
                        let newDate = dateForIndex(index - config.offset + 1)
                        if selectedDate != newDate {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                selectedDate = newDate
                                triggerHapticFeedback()
                            }
                        }
                    }
                }
                .onAppear {
                    /// Direct positioning without animation on first appearance
                    if !isInitialized {
                        directlyPositionDate(proxy)
                        isInitialized = true
                    }
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    /// Month display with the same position, animation, and tap gesture as block calendar
    private var monthBlock: some View {
        Text(formattedMonthName)
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(monthBounce ? Color.white.opacity(0.6) : .white)
            .padding(.leading, 6)
            .offset(x: 8, y: -4) /// Exact same offset as block calendar
            .scaleEffect(monthBounce ? 1.15 : 1.0)
            .animation(NotchlyAnimations.fastBounce, value: monthBounce)
            .onTapGesture {
                monthBounce = true
                goToToday()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    monthBounce = false
                }
            }
    }
    
    /// Date buttons with timeline visual styling but same logic as block calendar
    private func generateDateViews(proxy: ScrollViewProxy) -> some View {
        let totalSteps = (config.past + config.future) * config.steps
        
        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: pendingSelection ?? selectedDate)
            let isToday = Calendar.current.isDateInToday(date)
            let dayNumber = Calendar.current.component(.day, from: date)
            
            Button(action: { handleDateSelection(date, proxy: proxy) }) {
                VStack(spacing: 1) {
                    /// Weekday letter with timeline styling
                    Text(weekdayText(for: date, isSelected: isSelected))
                        .font(.system(size: isSelected ? 10 : 9, weight: .semibold))
                        .foregroundColor(weekdayColor(for: date, isSelected: isSelected, isToday: isToday))
                        .frame(width: 28, alignment: .center)
                    
                    /// Day number with timeline styling
                    Text("\(dayNumber)")
                        .font(.system(size: isSelected ? 16 : 14, weight: .bold))
                        .foregroundColor(dateColor(for: date, isSelected: isSelected, isToday: isToday))
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(NotchlyAnimations.fastBounce, value: isSelected)
                        .frame(height: 18)
                    
                    /// Event indicator dot
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
                .padding(.vertical, isSelected ? 6 : 4)
                .frame(width: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Positioning Methods
    
    /// Directly positions at initial position - sets the reference position for all selections
    private func directlyPositionDate(_ proxy: ScrollViewProxy) {
        /// Calculate the target index - always use todayPositionOffset to ensure consistent positioning
        let todayIndex = indexForDate(Date())
        let index = todayIndex + todayPositionOffset
        
        /// Use a small delay to ensure the view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            /// Set position without animation
            withAnimation(.none) {
                self.scrollPosition = index
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }
    
    /// Calculates the correct scroll position for any date - keeps it in the same visual position
    private func calculateScrollPositionForDate(_ date: Date) -> Int {
        let dateIndex = indexForDate(date)
        let todayIndex = indexForDate(Calendar.current.startOfDay(for: Date()))
        let offset = dateIndex - todayIndex
        
        /// Base position (where today appears) + the offset to the target date
        return (todayIndex + todayPositionOffset) + offset
    }
    
    /// Go to today and ensure it appears in the correct position
    private func goToToday() {
        isScrolling = true
        let today = Calendar.current.startOfDay(for: Date())
        let todayIndex = indexForDate(today)
        let targetPosition = todayIndex + todayPositionOffset
        
        /// Scroll to the correct position
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetPosition
        }
        
        /// Update the date
        DispatchQueue.main.async {
            self.selectedDate = today
            
            /// Reset scrolling state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isScrolling = false
            }
        }
        
        triggerHapticFeedback()
    }
    
    /// Handle date selection - ensure selected date appears in consistent position
    private func handleDateSelection(_ date: Date, proxy: ScrollViewProxy) {
        /// Skip if already on this date
        if Calendar.current.isDate(selectedDate, inSameDayAs: date) {
            return
        }
        
        isScrolling = true
        pendingSelection = date
        
        /// Calculate position to maintain consistent visual position
        let targetPosition = calculateScrollPositionForDate(date)
        
        /// Animate scroll to the consistent position
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetPosition
            proxy.scrollTo(targetPosition, anchor: .center)
        }
        
        /// Provide haptic feedback
        triggerHapticFeedback()
        
        /// Update the date after animation completes
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            DispatchQueue.main.async {
                self.selectedDate = date
                self.pendingSelection = nil
                
                /// Reset scrolling state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isScrolling = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Converts a date to a 3-letter or 1-letter weekday depending on selection
    private func weekdayText(for date: Date, isSelected: Bool) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        
        if isSelected {
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
    
    /// Get formatted month name
    private var formattedMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }
    
    /// Date visualization colors from timeline style
    private func dateColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .blue }
        else if isToday { return .green.opacity(0.8) }
        else { return .white.opacity(0.75) }
    }
    
    private func weekdayColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .blue }
        else if isToday { return .green.opacity(0.7) }
        else { return .gray.opacity(0.6) }
    }
    
    private func dotColor(for date: Date, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .blue }
        else if isToday { return .green.opacity(0.8) }
        else { return .gray.opacity(0.6) }
    }
    
    /// Provides haptic feedback when a new date is selected
    private func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .now)
    }
    
    // MARK: - Date Utilities
    
    /// Converts an index to a corresponding date
    private func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
    
    /// Finds the index position of a given date
    private func indexForDate(_ date: Date) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0 + config.offset
    }
}
