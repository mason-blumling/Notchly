//
//  TimelineCalendarNSView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/16/25.
//

import SwiftUI
import AppKit
import EventKit

/// NSViewRepresentable wrapper for the Timeline Calendar
/// Provides smooth animations by leveraging Core Animation
struct TimelineCalendarNSView: NSViewRepresentable {
    /// MARK: - Properties
    
    @ObservedObject var calendarManager: CalendarManager
    @Binding var selectedDate: Date
    let topRadius: CGFloat
    let width: CGFloat
    let state: NotchlyViewModel.NotchState
    
    /// MARK: - NSViewRepresentable
    
    func makeNSView(context: Context) -> TimelineCalendarContainerView {
        let view = TimelineCalendarContainerView(
            calendarManager: calendarManager,
            selectedDate: selectedDate,
            topRadius: topRadius,
            width: width
        )
        view.delegate = context.coordinator
        
        /// CRITICAL FIX: Ensure we bypass mouse events except for interactive elements
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        return view
    }

    func updateNSView(_ nsView: TimelineCalendarContainerView, context: Context) {
        /// Update the container with latest data
        nsView.updateSelectedDate(selectedDate)
        nsView.updateCalendarEvents()
        
        /// IMPORTANT: Update the expanded state
        nsView.updateState(state)
        
        /// Animation code with exact NotchlyAnimations.smoothTransition timing
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            nsView.animator().alphaValue = state == .expanded ? 1.0 : 0.0
            
            if state == .expanded {
                nsView.animator().layer?.transform = CATransform3DIdentity
            } else {
                /// Match exactly the SwiftUI scale factor of 0.95
                nsView.animator().layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
            }
        })
    }
    
    /// MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, TimelineCalendarDelegate {
        var parent: TimelineCalendarNSView
        
        init(_ parent: TimelineCalendarNSView) {
            self.parent = parent
        }
        
        func didSelectDate(_ date: Date) {
            DispatchQueue.main.async {
                self.parent.selectedDate = date
            }
        }
    }
}
