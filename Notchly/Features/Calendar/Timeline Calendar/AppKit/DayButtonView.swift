//
//  DayButtonView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import AppKit

/// Day button view - represents a single day in the date selector
class DayButtonView: NSView {
    /// MARK: - Properties
    
    let date: Date
    private var isSelected: Bool
    private var isToday: Bool
    private var hasEvent: Bool
    var buttonIndex: Int = 0

    private var weekdayLabel: NSTextField!
    private var dayLabel: NSTextField!
    private var eventDotView: NSView?
    
    /// MARK: - Initialization
    
    init(frame: NSRect, date: Date, isSelected: Bool, isToday: Bool, hasEvent: Bool) {
        self.date = date
        self.isSelected = isSelected
        self.isToday = isToday
        self.hasEvent = hasEvent
        
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
        
        /// Create weekday label with exact SwiftUI formatting
        weekdayLabel = NSTextField(labelWithString: weekdayText())
        weekdayLabel.font = NSFont.systemFont(ofSize: isSelected ? 10 : 9, weight: .semibold)
        weekdayLabel.textColor = weekdayColor()
        weekdayLabel.backgroundColor = .clear
        weekdayLabel.isBezeled = false
        weekdayLabel.isEditable = false
        weekdayLabel.alignment = .center
        weekdayLabel.lineBreakMode = .byTruncatingTail
        /// Match exact SwiftUI position
        weekdayLabel.frame = NSRect(x: 0, y: 26, width: frame.width, height: 12)
        
        /// Create day number label with exact SwiftUI styling
        dayLabel = NSTextField(labelWithString: dayNumberText())
        dayLabel.font = NSFont.systemFont(ofSize: isSelected ? 16 : 14, weight: .bold)
        dayLabel.textColor = dateColor()
        dayLabel.backgroundColor = .clear
        dayLabel.isBezeled = false
        dayLabel.isEditable = false
        dayLabel.alignment = .center
        /// Match exact SwiftUI vertical position
        dayLabel.frame = NSRect(x: 0, y: 10, width: frame.width, height: 18)
        
        /// Apply scale effect identical to SwiftUI implementation
        if isSelected {
            dayLabel.layer?.transform = CATransform3DMakeScale(1.15, 1.15, 1.0)
        }
        
        addSubview(weekdayLabel)
        addSubview(dayLabel)
        
        /// Add event dot if needed - match SwiftUI's dot position perfectly
        if hasEvent {
            addEventDot()
        }
    }
    
    private func addEventDot() {
        /// Remove existing dot if present
        eventDotView?.removeFromSuperview()
        
        /// Create dot view with exact SwiftUI positioning
        let dotView = NSView(frame: NSRect(x: frame.width/2 - 2, y: 4, width: 4, height: 4))
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = dotColor().cgColor
        dotView.layer?.cornerRadius = 2
        
        addSubview(dotView)
        eventDotView = dotView
    }
    
    /// MARK: - Public Methods
    
    func updateSelection(_ selected: Bool) {
        isSelected = selected
        
        /// Update text and colors with SwiftUI-matching appearance
        weekdayLabel.stringValue = weekdayText()
        weekdayLabel.textColor = weekdayColor()
        weekdayLabel.font = NSFont.systemFont(ofSize: isSelected ? 10 : 9, weight: .semibold)
        
        dayLabel.textColor = dateColor()
        dayLabel.font = NSFont.systemFont(ofSize: isSelected ? 16 : 14, weight: .bold)
        
        /// Animate scale change with precise SwiftUI-matching animation
        if isSelected {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                dayLabel.animator().layer?.transform = CATransform3DMakeScale(1.15, 1.15, 1.0)
            }, completionHandler: nil)
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                dayLabel.animator().layer?.transform = CATransform3DIdentity
            }, completionHandler: nil)
        }
        
        /// Update event dot with correct color based on selection state
        if hasEvent {
            eventDotView?.layer?.backgroundColor = dotColor().cgColor
        }
    }
    
    func updateEventDot(_ hasEvent: Bool) {
        self.hasEvent = hasEvent
        
        if hasEvent {
            if eventDotView == nil {
                addEventDot()
            } else {
                eventDotView?.layer?.backgroundColor = dotColor().cgColor
            }
        } else {
            eventDotView?.removeFromSuperview()
            eventDotView = nil
        }
    }
    
    /// MARK: - Helper Methods
    
    private func weekdayText() -> String {
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
    
    private func dayNumberText() -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }
    
    private func dateColor() -> NSColor {
        if isSelected { return .systemBlue }
        else if isToday { return NSColor.systemGreen.withAlphaComponent(0.8) }
        else { return .white.withAlphaComponent(0.75) }
    }
    
    private func weekdayColor() -> NSColor {
        if isSelected { return .systemBlue }
        else if isToday { return NSColor.systemGreen.withAlphaComponent(0.7) }
        else { return .gray.withAlphaComponent(0.6) }
    }
    
    private func dotColor() -> NSColor {
        if isSelected { return .systemBlue }
        else if isToday { return NSColor.systemGreen.withAlphaComponent(0.8) }
        else { return .gray.withAlphaComponent(0.6) }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        /// Only handle events on the actual day content with a small buffer zone
        let frame = self.bounds.insetBy(dx: 2, dy: 2)
        if !frame.contains(point) {
            return nil
        }
        
        return super.hitTest(point)
    }
}
