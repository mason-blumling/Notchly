//
//  NotchlyView+IntroIntegration.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI

extension NotchlyView {
    
    /// Modified content builder that checks for intro state
    @ViewBuilder
    func mainContent(in layout: NotchlyLayoutGuide) -> some View {
        ZStack(alignment: .top) {
            if shouldShowIntro {
                // Show intro content instead of normal content
                introContent()
            } else {
                // Normal content logic
                if shouldShowCalendarLiveActivity {
                    CalendarLiveActivityView(
                        activityMonitor: calendarActivityMonitor,
                        namespace: notchAnimation
                    )
                    .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(999)
                }
                
                if coordinator.state == .expanded {
                    expandedContent(in: layout)
                } else {
                    collapsedContent(in: layout)
                }
            }
        }
    }
    
    // Extracted methods for readability
    
    private func expandedContent(in layout: NotchlyLayoutGuide) -> some View {
        HStack(alignment: .top, spacing: 0) {
            UnifiedMediaPlayerView(
                mediaMonitor: mediaMonitor,
                isExpanded: true,
                namespace: notchAnimation
            )
            .frame(
                width: layout.leftContentFrame.width,
                height: layout.leftContentFrame.height
            )

            NotchlyCalendarView(calendarManager: calendarManager)
                .frame(
                    width: layout.rightContentFrame.width,
                    height: layout.rightContentFrame.height
                )
        }
        .frame(width: layout.bounds.width)
        .opacity(expandedContentOpacity)
    }
    
    private func collapsedContent(in layout: NotchlyLayoutGuide) -> some View {
        UnifiedMediaPlayerView(
            mediaMonitor: mediaMonitor,
            isExpanded: false,
            namespace: notchAnimation
        )
        .frame(
            width: layout.bounds.width,
            height: layout.bounds.height,
            alignment: .leading
        )
        .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : activityContentOpacity)
    }
}
