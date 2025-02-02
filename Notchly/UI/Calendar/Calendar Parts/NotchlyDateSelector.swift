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

    private let config = DateSelectorConfig()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: config.spacing) {
                generateDateViews()
            }
            .padding(.horizontal, 5)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .onChange(of: scrollPosition) { _, newValue in handleScrollUpdate(newValue) }
        .onAppear(perform: handleInitialOpen)
    }

    // MARK: - Date View Generation
    private func generateDateViews() -> some View {
        let totalSteps = (config.past + config.future) * config.steps

        return ForEach(config.offset...(totalSteps + config.offset - 1), id: \.self) { index in
            let date = dateForIndex(index)
            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
            
            Button(action: { handleDateSelection(date) }) {
                VStack(spacing: 2) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .frame(width: 18, height: 14)
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.5))

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: isSelected ? 20 : 14, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? .white : .gray.opacity(0.5))
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                        .opacity(isSelected ? 1 : 0.6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
                .padding(.vertical, isSelected ? 6 : 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Date Selection Handling
    private func handleDateSelection(_ date: Date) {
        selectedDate = date
        byClick = true
    }

    // MARK: - Scroll Behavior
    private func handleScrollUpdate(_ newValue: Int?) {
        if let newIndex = newValue, !byClick {
            selectedDate = dateForIndex(newIndex - config.offset)
        }
        byClick = false
    }

    // MARK: - Initial Load Logic
    private func handleInitialOpen() {
        if !viewOpened {
            viewOpened = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { scrollToToday() }
        }
    }

    private func scrollToToday() {
        let todayIndex = (config.past * config.steps) + config.offset
        selectedDate = Date()
        byClick = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                scrollPosition = todayIndex
            }
        }
    }

    // MARK: - Date Utilities
    private func dateForIndex(_ index: Int) -> Date {
        let startDate = Calendar.current.date(byAdding: .day, value: -config.past, to: Date()) ?? Date()
        return Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? Date()
    }
}

// MARK: - DateSelector Config
struct DateSelectorConfig {
    var past: Int = 7
    var future: Int = 8
    var steps: Int = 1
    var spacing: CGFloat = 6 // 🔥 Adjusted to fit 5 dates properly
    var offset: Int = 3
}
