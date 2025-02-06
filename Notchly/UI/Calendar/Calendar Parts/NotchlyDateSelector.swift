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
    @State private var byClick: Bool = false
    @State private var viewOpened: Bool = false
    @State private var monthTransition: Bool = false

    private let config = DateSelectorConfig()

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .leading) {
            monthBlock
            dateSelector
        }
        .onAppear { handleInitialOpen() }
        .onChange(of: selectedDate) { triggerHapticFeedback() } // 🔥 Haptic on scroll
    }
}

// MARK: - UI Components
private extension NotchlyDateSelector {
    
    /// 🔹 Month Block (Fully Opaque on Left, Fading Right)
    var monthBlock: some View {
        Text(selectedDate.formatted(.dateTime.month()))
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(.white)
            .padding(.leading, 6)
            .background(
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
            )
            .offset(x: 8, y: -4)
            .zIndex(2)
    }

    /// 🔹 Date Selector
    var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                generateDateViews()
            }
            .frame(height: 44)
            .padding(.horizontal, 5)
        }
        .frame(height: 44)
        .scrollTargetLayout()
        .scrollPosition(id: $scrollPosition, anchor: UnitPoint(x: 0.5, y: 0.5))
        .scrollTargetBehavior(.viewAligned) // 🔥 Auto-aligns selected date in the center
        .onChange(of: scrollPosition) {
            if let index = scrollPosition {
                let newDate = dateForIndex(index - config.offset + 1)
                if selectedDate != newDate {
                    selectedDate = newDate
                }
            }
        }
    }
    
    /// 🔹 Generates the date views
    func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps

        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 3) {
                    // 🔹 Weekday (always aligned)
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .frame(width: 18, height: 10)
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.6))

                    // 🔹 Date Number (grows when selected)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: isSelected ? 20 : 14, weight: isSelected ? .bold : .regular))
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
    
    /// 🔹 Handles Date Selection
    func handleDateSelection(_ date: Date) {
        let previousMonth = Calendar.current.component(.month, from: selectedDate)
        let newMonth = Calendar.current.component(.month, from: date)
        let targetIndex = indexForDate(date)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scrollPosition = targetIndex + 3
        }

        DispatchQueue.main.async {
            selectedDate = date
        }

        if previousMonth != newMonth {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                monthTransition.toggle()
            }
        }
        triggerHapticFeedback()
    }

    /// 🔹 Handles Initial Open
    func handleInitialOpen() {
        if !viewOpened {
            viewOpened = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollToToday()
            }
        }
    }

    /// 🔹 Centers Scroll on Today
    func scrollToToday() {
        let todayIndex = indexForDate(Date())

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scrollPosition = todayIndex + 3
            }
        }
    }
}

// MARK: - Haptic Feedback
private extension NotchlyDateSelector {
    /// 🔹 Fires haptic feedback when scrolling stops or when clicking a date
    func triggerHapticFeedback() {
        let feedback = NSHapticFeedbackManager.defaultPerformer
        feedback.perform(.alignment, performanceTime: .default) // 🔥 More distinct haptic
    }
}

// MARK: - Date Utilities
private extension NotchlyDateSelector {
    
    /// 🔹 Returns the date for a given index
    func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
    
    /// 🔹 Returns the index for a given date
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
