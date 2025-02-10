//
//  NotchlyDateSelector.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import SwiftUI
import EventKit
import AppKit // ✅ Required for NSHapticFeedbackManager

/// A horizontally scrolling date selector for Notchly.
/// - Displays a range of past and future dates.
/// - Highlights the selected date.
/// - Automatically centers "Today" on first open.
/// - Prevents overscrolling to avoid empty gaps.
/// - Provides haptic feedback on date selection.
struct NotchlyDateSelector: View {
    
    // MARK: - Properties
    @Binding var selectedDate: Date
    @ObservedObject var calendarManager: CalendarManager
    @State private var scrollPosition: Int?
    @State private var pendingSelection: Date?
    @State private var isScrolling = false
    @State private var debounceTimer: Timer?

    private let config = DateSelectorConfig()

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
    
    var monthBlock: some View {
        Text(selectedDate.formatted(.dateTime.month()))
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(.white)
            .padding(.leading, 6)
            .background(monthGradient)
            .offset(x: 8, y: -4)
            .zIndex(2)
            .onTapGesture { scrollToToday() } // ✅ Click month to return to today
    }
    
    var monthGradient: some View {
        ZStack {
            Color.black.opacity(1.0)
                .frame(width: 150, height: 45)
                .offset(x: -50)
                .allowsHitTesting(false)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(1.0),
                    Color.black.opacity(0.9),
                    Color.black.opacity(0.7),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 90, height: 45)
            .offset(x: 18)
            .allowsHitTesting(false)
        }
    }
    
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
        .onChange(of: scrollPosition) {
            if let index = scrollPosition {
                let newDate = dateForIndex(index - config.offset + 1)

                // ✅ Prevent shifting left by ensuring `scrollPosition` doesn't change unexpectedly
                if selectedDate != newDate {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        selectedDate = newDate
                    }
                }
            }
        }
    }
    
    func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps
        
        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: pendingSelection ?? selectedDate)
            
            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 3) {
                    // 🔹 Weekday (always aligned)
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .frame(width: 18, height: 10)
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.6))
                    
                    // 🔹 Date Number (🔥 Now **always bold** to prevent flickering)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: isSelected ? 20 : 14, weight: .bold)) // ✅ Always bold
                        .foregroundColor(.white)
                        .scaleEffect(isSelected ? 1.25 : 1.0)
                        .offset(y: isSelected ? 3 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
    
    /// Handles Date Selection via Click
    func handleDateSelection(_ date: Date) {
        let targetIndex = indexForDate(date)
        isScrolling = true

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetIndex + 3
        }

        // ✅ Debounce: Wait before setting `selectedDate` to avoid flickering
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            selectedDate = date
            pendingSelection = nil
            isScrolling = false
        }

        pendingSelection = date
        triggerHapticFeedback()
    }

    /// Handles Date Selection via Scroll
    func handleScrollUpdate(_ newValue: Int?) {
        guard let newIndex = newValue else { return }

        let newDate = dateForIndex(newIndex - config.offset)

        // ✅ Prevents the leftward shift by locking the scroll position
        if !Calendar.current.isDate(selectedDate, inSameDayAs: newDate) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                selectedDate = newDate
                scrollPosition = newIndex // 🔥 Locks it properly
            }
        }
    }

    /// Centers Scroll on Today
    func scrollToToday() {
        let todayIndex = indexForDate(Date())

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = todayIndex + 3
        }

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            selectedDate = Date()
        }
    }

    func handleInitialOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToToday()
        }
    }
}

// MARK: - Haptic Feedback
private extension NotchlyDateSelector {
    func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .default)
    }
}

// MARK: - Date Utilities
private extension NotchlyDateSelector {
    
    func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
    
    func indexForDate(_ date: Date) -> Int {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0 + config.offset
    }
}

// MARK: - DateSelector Config
struct DateSelectorConfig {
    var past: Int = 30
    var future: Int = 30
    var steps: Int = 1
    var spacing: CGFloat = 6
    var offset: Int = 3
}
