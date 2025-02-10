//
//  NotchlyDateSelector.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//
//  This component provides a horizontally scrolling date selector for Notchly.
//  - Displays past and future dates.
//  - Highlights the currently selected date.
//  - Centers "Today" on first open.
//  - Includes haptic feedback for selection.
//

import SwiftUI
import EventKit
import AppKit // ✅ Required for NSHapticFeedbackManager

/// A horizontally scrolling date selector for the Notchly UI.
/// Allows users to pick a date with smooth animations and haptic feedback.
struct NotchlyDateSelector: View {
    
    // MARK: - Properties
    
    @Binding var selectedDate: Date /// The currently selected date (bound to the parent view).
    @ObservedObject var calendarManager: CalendarManager /// Manages the user's calendar events.
    @State private var scrollPosition: Int? /// Controls the scroll position in the date selector.
    @State private var pendingSelection: Date? /// Used for handling smooth date selection.
    @State private var isScrolling = false /// Prevents unwanted UI updates during scrolling.
    @State private var monthBounce = false /// Handles the month bounce animation effect.
    @State private var debounceTimer: Timer? /// Prevents excessive UI updates (debounce effect).
    private let config = DateSelectorConfig() /// Configuration for past/future date limits and spacing.

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .leading) {
            monthBlock
            dateSelector
        }
        .onAppear { handleInitialOpen() }
    }
}

// MARK: - UI Components

private extension NotchlyDateSelector {
    
    /// Displays the current month name with a subtle gradient.
    var monthBlock: some View {
        Text(selectedDate.formatted(.dateTime.month()))
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(monthBounce ? Color.white.opacity(0.6) : .white)
            .padding(.leading, 6)
            .background(monthGradient)
            .offset(x: 8, y: -4)
            .scaleEffect(monthBounce ? 1.15 : 1.0)
            .animation(NotchlyAnimations.fastBounce, value: monthBounce)
            .zIndex(2)
            .onTapGesture {
                monthBounce = true
                scrollToToday()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { monthBounce = false }
            }
    }
    
    /// Creates a smooth gradient behind the month label.
    var monthGradient: some View {
        ZStack {
            NotchlyTheme.gradientStart
                .frame(width: 150, height: 45)
                .offset(x: -50)
                .allowsHitTesting(false)
            LinearGradient(
                gradient: Gradient(colors: [
                    NotchlyTheme.gradientStart,
                    NotchlyTheme.gradientMidLeft,
                    NotchlyTheme.gradientMidRight,
                    NotchlyTheme.gradientEnd
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 90, height: 45)
            .offset(x: 18)
            .allowsHitTesting(false)
        }
    }
    
    /// The horizontally scrolling date selector.
    var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { generateDateViews() }
                .frame(height: 44)
                .padding(.horizontal, 5)
        }
        .frame(height: 44)
        .scrollTargetLayout()
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .onChange(of: scrollPosition) { _, newValue in
            if let index = newValue {
                let newDate = dateForIndex(index - config.offset + 1)
                if selectedDate != newDate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selectedDate = newDate
                        triggerHapticFeedback()
                    }
                }
            }
        }
    }
    
    /// Generates individual date buttons.
    func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps
        
        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: pendingSelection ?? selectedDate)
            
            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 3) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .frame(width: 18, height: 10)
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.6))
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: isSelected ? 20 : 14, weight: .bold))
                        .foregroundColor(NotchlyTheme.primaryText)
                        .scaleEffect(isSelected ? 1.25 : 1.0)
                        .offset(y: isSelected ? 3 : 0)
                        .animation(NotchlyAnimations.fastBounce, value: isSelected)
                }
                .padding(.vertical, isSelected ? 6 : 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Behavior Logic

private extension NotchlyDateSelector {
    
    func handleDateSelection(_ date: Date) {
        let targetIndex = indexForDate(date)
        isScrolling = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetIndex + 3
        }

        triggerHapticFeedback()

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) {
            _ in selectedDate = date
        }
    }

    /// Handles updates when scrolling occurs.
    func handleScrollUpdate(_ newValue: Int?) {
        guard let newIndex = newValue else { return }

        let newDate = dateForIndex(newIndex - config.offset)

        if !Calendar.current.isDate(selectedDate, inSameDayAs: newDate) {
            DispatchQueue.main.async {
                selectedDate = newDate
                scrollPosition = newIndex
            }
        }
    }

    /// Scrolls the selector back to today's date.
    func scrollToToday() {
        let todayIndex = indexForDate(Date())
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = todayIndex + 3
        }

        triggerHapticFeedback()
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) {
            _ in selectedDate = Date()
        }
    }

    /// Ensures that the view scrolls to "Today" on first open.
    func handleInitialOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToToday()
        }
    }
}

// MARK: - Haptic Feedback

private extension NotchlyDateSelector {
    /// Provides haptic feedback when a new date is selected.
    func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .now)
    }
}

// MARK: - Date Utilities

private extension NotchlyDateSelector {
    
    /// Converts an index to a corresponding date.
    func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
    
    /// Finds the index position of a given date.
    func indexForDate(_ date: Date) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0 + config.offset
    }
}

// MARK: - DateSelector Config

/// Defines the configuration for the date selector.
struct DateSelectorConfig {
    var past = 30
    var future = 30
    var steps = 1
    var spacing: CGFloat = 6
    var offset = 3
}
