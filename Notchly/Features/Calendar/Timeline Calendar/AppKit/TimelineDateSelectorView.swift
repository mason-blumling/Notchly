//
//  TimelineDateSelectorView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import AppKit
import EventKit

/// Date selector view implementation - matches SwiftUI appearance exactly
class TimelineDateSelectorView: NSView {
    /// MARK: - Properties
    
    private var selectedDate: Date
    private var calendarManager: CalendarManager
    weak var delegate: TimelineDateSelectorDelegate?
    
    /// Date selector constants (identical to SwiftUI implementation)
    private let todayPositionOffset = 3
    private let pastDays = 30
    private let futureDays = 30
    private let dayButtonWidth: CGFloat = 28
    private let dayButtonHeight: CGFloat = 44
    private let dayButtonSpacing: CGFloat = 12
    
    /// Date buttons and scroll view
    private var scrollView: NSScrollView!
    private var contentView: NSView!
    private var monthLabel: NSTextField!
    private var dayButtons: [DayButtonView] = []
    
    /// MARK: - Initialization
    
    init(frame: NSRect, selectedDate: Date, calendarManager: CalendarManager) {
        self.selectedDate = selectedDate
        self.calendarManager = calendarManager
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// MARK: - Setup
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        /// Create month label with SwiftUI-identical positioning and appearance
        monthLabel = NSTextField(labelWithString: formattedMonthName())
        monthLabel.textColor = .white
        monthLabel.font = NSFont.boldSystemFont(ofSize: 26)
        monthLabel.backgroundColor = .clear
        monthLabel.isBezeled = false
        monthLabel.isEditable = false
        monthLabel.drawsBackground = false
        
        /// Match exact position of SwiftUI version - at top with 8px x-offset and -4px y-offset
        monthLabel.frame = NSRect(x: 14, y: frame.height - 35, width: 150, height: 32)
        
        /// Add tap gesture recognizer to month label
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(monthTapped))
        monthLabel.addGestureRecognizer(tapGesture)
        monthLabel.isEnabled = true
        
        addSubview(monthLabel)
        
        /// Create scroll view with positioning matching SwiftUI
        scrollView = NSScrollView(frame: NSRect(x: 75, y: 0, width: frame.width - 75, height: 44))
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        /// Content view for day buttons (match SwiftUI dimensions)
        let totalDays = pastDays + futureDays + 1
        let contentWidth = CGFloat(totalDays) * (dayButtonWidth + dayButtonSpacing)
        contentView = NSView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 44))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        
        scrollView.documentView = contentView
        addSubview(scrollView)
        
        /// Create day buttons
        createDayButtons()
        
        /// Position at today initially - exactly like SwiftUI implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollToToday(animated: false)
        }
    }
    
    private func createDayButtons() {
        /// Clear existing buttons
        for button in dayButtons {
            button.removeFromSuperview()
        }
        dayButtons.removeAll()
        
        /// Create buttons for each day - match SwiftUI implementation exactly
        let totalDays = pastDays + futureDays + 1
        let today = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        
        for i in 0..<totalDays {
            let dayOffset = i - pastDays
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(date)
            
            /// Match exact SwiftUI button spacing with 5px initial padding
            let x = CGFloat(i) * (dayButtonWidth + dayButtonSpacing) + 5
            
            let button = DayButtonView(
                frame: NSRect(x: x, y: 0, width: dayButtonWidth, height: dayButtonHeight),
                date: date,
                isSelected: isSelected,
                isToday: isToday,
                hasEvent: false
            )
            button.buttonIndex = i
            
            let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(dayButtonTapped(_:)))
            button.addGestureRecognizer(tapGesture)
            
            contentView.addSubview(button)
            dayButtons.append(button)
        }
    }
    
    /// MARK: - Public Methods
    
    func updateSelectedDate(_ date: Date) {
        let previousDate = selectedDate
        selectedDate = date
        
        /// Update button states
        for button in dayButtons {
            let isSelected = Calendar.current.isDate(button.date, inSameDayAs: date)
            button.updateSelection(isSelected)
        }
        
        /// Update month label if month changed
        if !Calendar.current.isDate(previousDate, equalTo: date, toGranularity: .month) {
            monthLabel.stringValue = formattedMonthName()
        }
        
        /// Scroll to make selected date visible with animation matching SwiftUI
        scrollToDate(date, animated: true)
    }
    
    func refreshEventDots(_ hasEventCallback: @escaping (Date) -> Bool) {
        for button in dayButtons {
            button.updateEventDot(hasEventCallback(button.date))
        }
    }
    
    /// MARK: - Actions
    
    @objc private func dayButtonTapped(_ gesture: NSClickGestureRecognizer) {
        guard let button = gesture.view as? DayButtonView else { return }
        
        /// Provide haptic feedback just like SwiftUI version
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        
        /// Update selection
        selectedDate = button.date
        
        /// Update all buttons
        for otherButton in dayButtons {
            let isSelected = Calendar.current.isDate(otherButton.date, inSameDayAs: selectedDate)
            otherButton.updateSelection(isSelected)
        }
        
        /// Update month label
        monthLabel.stringValue = formattedMonthName()
        
        /// Notify delegate
        delegate?.didSelectDate(selectedDate)
    }
    
    @objc private func monthTapped() {
        /// Animate month label - identical to SwiftUI bounce effect
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.15
        animation.duration = 0.15
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.autoreverses = true
        monthLabel.layer?.add(animation, forKey: "bounce")
        
        /// Go to today
        goToToday()
    }
    
    /// MARK: - Helper Methods
    
    private func formattedMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }
    
    private func goToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        
        /// Update selected date
        selectedDate = today
        
        /// Update button states
        for button in dayButtons {
            let isSelected = Calendar.current.isDate(button.date, inSameDayAs: today)
            button.updateSelection(isSelected)
        }
        
        /// Update month label
        monthLabel.stringValue = formattedMonthName()
        
        /// Scroll to today with animation matching SwiftUI
        scrollToToday(animated: true)
        
        /// Notify delegate
        delegate?.didSelectDate(today)
        
        /// Haptic feedback (identical to SwiftUI)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    
    private func scrollToToday(animated: Bool) {
        /// Find index of today
        let todayIndex = dayButtons.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) ?? pastDays
        
        /// Calculate scroll position to center today exactly like SwiftUI
        let targetButton = dayButtons[todayIndex]
        let buttonCenterX = targetButton.frame.midX
        let visibleWidth = scrollView.frame.width
        let targetX = max(0, buttonCenterX - (visibleWidth / 2))
        
        /// Scroll to position with animation matching SwiftUI exactly
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
            }, completionHandler: nil)
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: targetX, y: 0))
        }
    }
    
    private func scrollToDate(_ date: Date, animated: Bool) {
        /// Find button for date
        guard let index = dayButtons.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else { return }
        
        /// Calculate scroll position matching SwiftUI behavior
        let targetButton = dayButtons[index]
        let buttonCenterX = targetButton.frame.midX
        let visibleWidth = scrollView.frame.width
        let targetX = max(0, buttonCenterX - (visibleWidth / 2))
        
        /// Scroll to position with animation matching SwiftUI
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
            }, completionHandler: nil)
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: targetX, y: 0))
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        
        /// Match SwiftUI hit testing behavior
        if hitView === self {
            return nil
        }
        
        /// For month label, ensure hit detection matches SwiftUI's behavior
        if let textField = hitView as? NSTextField, textField === monthLabel {
            /// Calculate text bounds for accurate hit testing like SwiftUI
            let textRect = textField.attributedStringValue.boundingRect(
                with: textField.bounds.size,
                options: .usesLineFragmentOrigin
            )
            
            let localPoint = convert(point, to: textField)
            /// Slightly larger hitbox for better UX (matches SwiftUI)
            let expandedRect = NSRect(
                x: textRect.origin.x - 5,
                y: textRect.origin.y - 5,
                width: textRect.width + 10,
                height: textRect.height + 10
            )
            
            if !expandedRect.contains(localPoint) {
                return nil
            }
        }
        
        /// For scroll views, only handle scroller interaction like SwiftUI
        if let scrollView = hitView as? NSScrollView {
            let scrollerFrame = scrollView.verticalScroller?.frame ?? .zero
            if !scrollerFrame.contains(convert(point, to: scrollView)) {
                return nil
            }
        }
        
        return hitView
    }
}
