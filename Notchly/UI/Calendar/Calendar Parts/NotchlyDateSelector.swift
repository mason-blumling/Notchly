//
//  NotchlyDateSelector.swift
//  Notchly
//
//  Created by Mason Blumling on 2/2/25.
//

import SwiftUI
import EventKit

/// A horizontally scrolling date selector for Notchly.
/// - Displays a range of past and future dates.
/// - Highlights the selected date.
/// - Automatically centers "Today" on first open.
/// - Prevents overscrolling to avoid empty gaps.
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
    }
}

// MARK: - UI Components
private extension NotchlyDateSelector {
    
    // 🔹 Month Block (Fully Opaque on Left, Fading Right)
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

    // 🔹 Date Selector
    var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                generateDateViews()
            }
            .frame(height: 44)
            .padding(.horizontal, 5)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .onChange(of: scrollPosition) { _, newValue in handleScrollUpdate(newValue) }
        .zIndex(1)
    }
    
    func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps

        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)

            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 3) { // 🔥 Keeps weekday aligned, date number shifts
                    // 🔹 Weekday (NEVER moves, always stays aligned)
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .frame(width: 18, height: 10)
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.6))

                    // 🔹 Date Number (ONLY this moves down slightly & enlarges)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: isSelected ? 20 : 14, weight: isSelected ? .bold : .regular))
                        .foregroundColor(.white)
                        .scaleEffect(isSelected ? 1.25 : 1.0) // 🔥 Smooth increase
                        .offset(y: isSelected ? 3 : 0) // 🔥 Slight shift down (not too much)
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
    
    // 🔹 Handles Date Selection
    func handleDateSelection(_ date: Date) {
        let previousMonth = Calendar.current.component(.month, from: selectedDate)
        let newMonth = Calendar.current.component(.month, from: date)

        selectedDate = date
        byClick = true

        if previousMonth != newMonth {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                monthTransition.toggle()
            }
        }
    }

    // 🔹 Handles Scroll Updates
    func handleScrollUpdate(_ newValue: Int?) {
        if let newIndex = newValue, !byClick {
            selectedDate = dateForIndex(newIndex - config.offset)
        }
        byClick = false
    }

    // 🔹 Handles Initial Open
    func handleInitialOpen() {
        if !viewOpened {
            viewOpened = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { scrollToToday() }
        }
    }

    // 🔹 Centers Scroll on Today
    func scrollToToday() {
        let todayIndex = (config.past * config.steps) + config.offset
        selectedDate = Date()
        byClick = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                scrollPosition = todayIndex
            }
        }
    }
}

// MARK: - Date Utilities
private extension NotchlyDateSelector {
    
    func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
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
