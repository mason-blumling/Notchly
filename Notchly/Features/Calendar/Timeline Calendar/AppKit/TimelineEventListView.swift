//
//  TimelineEventListView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import AppKit
import EventKit

/// Event list view implementation - matches SwiftUI appearance exactly
class TimelineEventListView: NSView {
    /// MARK: - Properties
    
    private var events: [EKEvent] = []
    private var eventViews: [NSView] = []
    private var eventViewMapping: [String: NSView] = [:]
    private var timelineLayer: CAShapeLayer?
    private var scrollView: NSScrollView?
    private var emptyStateView: NSView?
    
    /// Timeline styling constants
    private let dotSize: CGFloat = 8
    private let lineWidth: CGFloat = 1.5
    
    /// MARK: - Initialization
    
    init(frame: NSRect, events: [EKEvent]) {
        super.init(frame: frame)
        self.events = events
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// MARK: - Setup
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        /// Create and add empty state view (initially hidden)
        emptyStateView = createEmptyStateView()
        emptyStateView?.isHidden = !events.isEmpty
        addSubview(emptyStateView!)
        
        /// Create a scroll view (initially hidden if no events)
        scrollView = NSScrollView(frame: bounds)
        scrollView?.hasVerticalScroller = true
        scrollView?.hasHorizontalScroller = false
        scrollView?.autohidesScrollers = true
        scrollView?.backgroundColor = .clear
        scrollView?.drawsBackground = false
        scrollView?.isHidden = events.isEmpty
        
        /// Create content view
        let contentView = NSView(frame: bounds)
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        
        scrollView?.documentView = contentView
        addSubview(scrollView!)
        
        /// Add timeline line
        addTimelineLine()
        
        /// Update scroll view contents
        updateEventsInScrollView()
    }
    
    private func addTimelineLine() {
        /// Remove existing timeline if present
        if let existingLine = timelineLayer {
            existingLine.removeFromSuperlayer()
        }
        
        /// Create new timeline line with exact SwiftUI appearance
        let line = CAShapeLayer()
        line.strokeColor = NSColor.gray.withAlphaComponent(0.3).cgColor
        line.lineWidth = lineWidth
        line.fillColor = nil
        
        /// Exact 60% position
        let path = CGMutablePath()
        let lineX = bounds.width * 0.6
        path.move(to: CGPoint(x: lineX, y: 0))
        path.addLine(to: CGPoint(x: lineX, y: bounds.height))
        line.path = path
        
        /// Only show timeline if we have events
        line.isHidden = events.isEmpty
        
        scrollView?.layer?.addSublayer(line)
        timelineLayer = line
    }
    
    /// MARK: - Public Methods
    
    func updateEvents(_ newEvents: [EKEvent]) {
        events = newEvents
        
        /// Remove existing event views
        for view in eventViews {
            view.removeFromSuperview()
        }
        eventViews.removeAll()
        eventViewMapping.removeAll()
        
        /// Update empty state visibility based on events
        emptyStateView?.isHidden = !events.isEmpty
        scrollView?.isHidden = events.isEmpty
        timelineLayer?.isHidden = events.isEmpty
        
        /// Update the scroll view contents if events exist
        if !events.isEmpty {
            updateEventsInScrollView()
        }
    }
    
    /// MARK: - Private Methods
    
    private func updateEventsInScrollView() {
        guard let scrollView = scrollView,
              let contentView = scrollView.documentView,
              !events.isEmpty else { return }
        
        /// Clear existing content
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        /// Use the same spacing as SwiftUI - 8px between events with minimal top padding
        var totalHeight: CGFloat = 4 /// Start with minimal top padding
        
        /// Calculate heights for each event
        let eventHeights: [CGFloat] = events.map { event in
            let titleLength = (event.title ?? "").count
            let height: CGFloat = titleLength > 25 ? 50 : 38
            totalHeight += height + 8 /// Add event height + 8px spacing
            return height
        }
        
        /// Set content size
        let contentHeight = max(bounds.height, totalHeight)
        contentView.frame.size.height = contentHeight
        
        /// Start positioning with proper spacing from top
        var yPosition: CGFloat = contentHeight - 4 /// Start at top minus minimal padding
        
        /// Add each event
        for (index, event) in events.enumerated() {
            let eventHeight = eventHeights[index]
            yPosition -= eventHeight /// Position from top down
            
            let eventView = createEventView(event, yOffset: yPosition, height: eventHeight)
            contentView.addSubview(eventView)
            eventViews.append(eventView)
            
            if let eventId = event.eventIdentifier {
                eventViewMapping[eventId] = eventView
            }
            
            /// 8px spacing between events
            yPosition -= 8
        }
    }
    
    private func createEmptyStateView() -> NSView {
        /// Create view with exact SwiftUI empty state appearance
        let emptyView = NSView(frame: bounds)
        emptyView.wantsLayer = true
        emptyView.layer?.backgroundColor = NSColor.clear.cgColor
        
        /// Center position
        let verticalCenter = bounds.height / 2
        
        /// Create icon container
        let iconContainer = NSView(frame: NSRect(x: bounds.width/2 - 16, y: verticalCenter, width: 32, height: 32))
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.1).cgColor
        iconContainer.layer?.cornerRadius = 16
        
        let iconView = NSImageView(frame: NSRect(x: 7, y: 7, width: 18, height: 18))
        iconView.image = NSImage(systemSymbolName: "calendar.badge.checkmark", accessibilityDescription: "Calendar")
        iconView.contentTintColor = .systemBlue
        iconContainer.addSubview(iconView)
        
        /// Create label
        let label = NSTextField(labelWithString: "No events today")
        label.textColor = NSColor.gray.withAlphaComponent(0.9)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        
        /// Position label below icon
        label.frame = NSRect(
            x: bounds.width/2 - 80,
            y: verticalCenter - 30,
            width: 160,
            height: 20
        )
        
        emptyView.addSubview(iconContainer)
        emptyView.addSubview(label)
        
        /// Ensure proper resizing
        emptyView.autoresizingMask = [.width, .height]
        iconContainer.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        label.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        
        return emptyView
    }
    
    // Rest of the implementation stays the same...
    // [The createEventView, handleEventTap, checkEventHasVideoCall, openEventInCalendar remain unchanged]
    
    override func layout() {
        super.layout()
        
        /// Update empty state view's frame
        emptyStateView?.frame = bounds
        
        /// Update scroll view frame
        scrollView?.frame = bounds
        
        /// Update timeline line position
        if let line = timelineLayer {
            let path = CGMutablePath()
            let lineX = bounds.width * 0.6
            path.move(to: CGPoint(x: lineX, y: 0))
            path.addLine(to: CGPoint(x: lineX, y: bounds.height))
            line.path = path
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        /// If showing empty state, disable all hit testing except for the view itself
        if !(emptyStateView?.isHidden ?? true) {
            return nil
        }
        
        /// Otherwise, use the existing hit testing logic
        let hitView = super.hitTest(point)
        
        if hitView === self {
            return nil
        }
        
        if let scrollView = hitView as? NSScrollView {
            if let scroller = scrollView.verticalScroller,
               scroller.frame.contains(scrollView.convert(point, from: self)) {
                return scroller
            }
            return nil
        }
        
        if hitView is NSClipView {
            return nil
        }
        
        for view in eventViews {
            if hitView === view || hitView?.isDescendant(of: view) == true {
                if view.frame.contains(convert(point, to: view.superview)) {
                    return hitView
                }
            }
        }
        
        return nil
    }
    
    private func createEventView(_ event: EKEvent, yOffset: CGFloat, height: CGFloat) -> NSView {
        /// Create event view with identical proportions to SwiftUI version
        let eventView = NSView(frame: NSRect(x: 0, y: yOffset, width: bounds.width, height: height))
        eventView.wantsLayer = true
        eventView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        eventView.layer?.cornerRadius = 8
        
        let title = event.title ?? "Untitled Event"
        
        /// Exact 60% position matching SwiftUI version
        let lineX = bounds.width * 0.6
        
        /// Use identical video call detection as SwiftUI
        let hasVideoCall = checkEventHasVideoCall(event)
        
        /// Position title with identical layout to SwiftUI
        let titleField = NSTextField(labelWithString: title)
        titleField.textColor = .white
        titleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleField.alignment = .right
        titleField.lineBreakMode = .byWordWrapping
        titleField.usesSingleLineMode = false
        titleField.cell?.wraps = true
        titleField.maximumNumberOfLines = 2
        titleField.backgroundColor = .clear
        titleField.isBezeled = false
        titleField.isEditable = false
        
        /// Use exact vertical centering to match SwiftUI layout
        let titleHeight = height - 16
        titleField.frame = NSRect(x: 12, y: (height - titleHeight) / 2, width: lineX - 30, height: titleHeight)
        
        /// Format time with identical formatter to SwiftUI
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        
        let timeString = event.isAllDay ? "All day" :
        "\(timeFormatter.string(from: event.startDate)) - \(timeFormatter.string(from: event.endDate))"
        
        /// Position time label with exact SwiftUI positioning
        let timeField = NSTextField(labelWithString: timeString)
        timeField.textColor = .lightGray
        timeField.font = NSFont.systemFont(ofSize: 12)
        timeField.backgroundColor = .clear
        timeField.isBezeled = false
        timeField.isEditable = false
        timeField.frame = NSRect(x: lineX + 12, y: height/2 - 8, width: bounds.width - lineX - 24, height: 16)
        
        /// Create event dot on timeline with identical size/position to SwiftUI (8px)
        let dotView = NSView(frame: NSRect(x: lineX - 4, y: height/2 - 4, width: 8, height: 8))
        dotView.wantsLayer = true
        let calendarColor = event.calendar.cgColor ?? CGColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        dotView.layer?.backgroundColor = calendarColor
        dotView.layer?.cornerRadius = 4
        
        /// Add video call icon with identical positioning to SwiftUI
        if hasVideoCall {
            let videoIcon = NSImageView(frame: NSRect(x: lineX - 30, y: height/2 - 5, width: 11, height: 11))
            videoIcon.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Video call")
            videoIcon.contentTintColor = .systemBlue
            eventView.addSubview(videoIcon)
        }
        
        eventView.addSubview(titleField)
        eventView.addSubview(timeField)
        eventView.addSubview(dotView)
        
        /// Add tap handling with animation identical to SwiftUI
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(handleEventTap(_:)))
        eventView.addGestureRecognizer(tapGesture)
        
        return eventView
    }
    
    @objc private func handleEventTap(_ gesture: NSClickGestureRecognizer) {
        guard let eventView = gesture.view else { return }
        
        /// Find which event this view belongs to
        for (eventId, view) in eventViewMapping {
            if view == eventView, let event = events.first(where: { $0.eventIdentifier == eventId }) {
                /// Animate tap effect with exact SwiftUI timings
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.1
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    eventView.animator().layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
                }, completionHandler: {
                    /// Animate back to normal with same timing as SwiftUI
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.1
                        context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                        eventView.animator().layer?.transform = CATransform3DIdentity
                    }, completionHandler: nil)
                    
                    /// Open event in calendar exactly like SwiftUI
                    self.openEventInCalendar(event: event)
                })
                break
            }
        }
    }
    
    private func openEventInCalendar(event: EKEvent) {
        guard let eventIdentifier = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed) else {
            return
        }
        
        /// Format date exactly like SwiftUI version for URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let formattedDate = dateFormatter.string(from: event.startDate)
        
        if let url = URL(string: "ical://ekevent/\(formattedDate)/\(eventIdentifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkEventHasVideoCall(_ event: EKEvent) -> Bool {
        guard let title = event.title?.lowercased() else { return false }
        return title.contains("zoom") || title.contains("meet") ||
        title.contains("teams") || title.contains("webex") ||
        title.contains("call") || title.contains("video")
    }
}
