//
//  TimelineCalendarContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import AppKit
import EventKit
import SwiftUI

/// Container view that manages the entire calendar - matches SwiftUI layout exactly
class TimelineCalendarContainerView: NSView {
    /// MARK: - Properties
    
    private let calendarManager: CalendarManager
    private var selectedDate: Date
    private let topRadius: CGFloat
    private let width: CGFloat
    
    private var dateSelector: TimelineDateSelectorView!
    private var eventList: TimelineEventListView!
    private var cachedEvents: [EKEvent] = []
    private var isExpanded: Bool = false

    weak var delegate: TimelineCalendarDelegate?
    
    /// MARK: - Initialization
    
    init(calendarManager: CalendarManager, selectedDate: Date, topRadius: CGFloat, width: CGFloat) {
        self.calendarManager = calendarManager
        self.selectedDate = selectedDate
        self.topRadius = topRadius
        self.width = width
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 300))
        
        setupViews()
        updateCalendarEvents()
        
        /// CRITICAL FIX: Remove ALL tracking areas to prevent interfering with hover detection
        self.trackingAreas.forEach { self.removeTrackingArea($0) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// MARK: - Setup

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        /// Set date selector with exact SwiftUI positioning (8px from edges)
        dateSelector = TimelineDateSelectorView(
            frame: NSRect(x: 8, y: frame.height - 60, width: width - 16, height: 50),
            selectedDate: selectedDate,
            calendarManager: calendarManager
        )
        dateSelector.delegate = self
        addSubview(dateSelector)
        
        /// Create event list with exact SwiftUI spacing (8px from edges, 64px from top)
        eventList = TimelineEventListView(
            frame: NSRect(x: 8, y: 0, width: width - 16, height: frame.height - 64),
            events: cachedEvents
        )
        addSubview(eventList)
    }
    
    /// Update properties when state changes (expanded vs. collapsed)
    func updateState(_ state: NotchlyViewModel.NotchState) {
        isExpanded = (state == .expanded)
    }
    
    /// Only allow mouse interaction when expanded (identical to SwiftUI behavior)
    override func hitTest(_ point: NSPoint) -> NSView? {
        /// If we're not expanded, disable all hit testing
        if !isExpanded {
            return nil
        }
        
        /// Otherwise use enhanced hit testing matching SwiftUI
        let hitView = super.hitTest(point)
        
        /// If we hit the calendar background, pass through
        if hitView === self {
            return nil
        }
        
        return hitView
    }

    /// MARK: - Public Methods
    
    func updateSelectedDate(_ date: Date) {
        guard !Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }
        selectedDate = date
        dateSelector.updateSelectedDate(date)
        updateCalendarEvents()
    }
    
    func updateCalendarEvents() {
        let settings = NotchlySettings.shared
        let maxEvents = settings.maxEventsToDisplay
        
        /// Filter events using exact same logic as SwiftUI version
        var events = calendarManager.events
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
        
        if !settings.showCanceledEvents {
            events = events.filter { $0.status != .canceled }
        }
        
        /// Sort and limit exactly like SwiftUI version
        events = events.sorted { $0.startDate < $1.startDate }
        
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        
        cachedEvents = events
        eventList.updateEvents(events)
        
        /// Update date selector event dots - identical to SwiftUI behavior
        dateSelector.refreshEventDots { date in
            return self.hasEvent(on: date)
        }
    }
    
    /// Helper method to check if a date has events - identical to SwiftUI logic
    private func hasEvent(on date: Date) -> Bool {
        let settings = NotchlySettings.shared
        return calendarManager.events.contains {
            Calendar.current.isDate($0.startDate, inSameDayAs: date) &&
            (settings.showCanceledEvents || $0.status != .canceled)
        }
    }
    
    override func layout() {
        super.layout()
        
        /// Ensure exact SwiftUI spacing during resize
        dateSelector.frame = NSRect(x: 8, y: frame.height - 60, width: width - 16, height: 50)
        eventList.frame = NSRect(x: 8, y: 0, width: width - 16, height: frame.height - 64)
    }
    
    func updateVisibility(visible: Bool, animated: Bool) {
        if animated {
            /// Use Core Animation with exact SwiftUI timing values
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer?.opacity ?? (visible ? 0.0 : 1.0)
            animation.toValue = visible ? 1.0 : 0.0
            animation.duration = 0.3 /// Match NotchlyAnimations.smoothTransition
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            
            layer?.add(animation, forKey: "opacity")
        } else {
            layer?.opacity = visible ? 1.0 : 0.0
        }
    }
}

/// MARK: - DateSelector Delegate

extension TimelineCalendarContainerView: TimelineDateSelectorDelegate {
    func didSelectDate(_ date: Date) {
        selectedDate = date
        updateCalendarEvents()
        delegate?.didSelectDate(date)
    }
}
