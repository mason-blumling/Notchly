//
//  NotchlyView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/27/25.
//

import SwiftUI

/// `NotchlyView` represents the visual notch UI component inside the floating panel.
/// It dynamically expands or contracts based on hover interactions.
struct NotchlyView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var mediaMonitor = MediaPlaybackMonitor.shared
    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor
    
    init(notchly: Notchly<Content>) {
        self.notchly = notchly
        CalendarManager.shared = CalendarManager()
        _calendarManager = StateObject(wrappedValue: CalendarManager.shared!)
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: CalendarManager.shared!))
    }

    // Debounce hover state changes
    @State private var debounceWorkItem: DispatchWorkItem?
    
    // MARK: - Matched Geometry for Seamless Expansion
    @Namespace private var notchAnimation
    
    // MARK: - Live Activity Conditions

    private var shouldShowCalendarLiveActivity: Bool {
        return !notchly.isMouseInside &&
               !mediaMonitor.isPlaying &&
               calendarActivityMonitor.upcomingEvent != nil &&
               !calendarActivityMonitor.timeRemainingString.isEmpty
    }

    var body: some View {
        // Compute the configuration to use based on media playback state and hover state.
        let currentConfig: NotchlyConfiguration = {
            if !notchly.isMouseInside {
                if mediaMonitor.nowPlaying != nil && mediaMonitor.isPlaying {
                    return NotchlyConfiguration.activity
                }
                if calendarActivityMonitor.upcomingEvent != nil {
                    return NotchlyConfiguration.activity
                }
            }
            return notchly.configuration
        }()
        
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                
                ZStack {
                    // 🔥 The Notch Shape (Handles expansion) using the computed configuration.
                    NotchlyShape(
                        bottomCornerRadius: currentConfig.bottomCornerRadius,
                        topCornerRadius: currentConfig.topCornerRadius
                    )
                    .fill(NotchlyTheme.background)
                    .frame(
                        width: notchly.isMouseInside ? notchly.notchWidth : currentConfig.width,
                        height: notchly.isMouseInside ? notchly.notchHeight : currentConfig.height
                    )
                    .shadow(color: NotchlyTheme.shadow, radius: currentConfig.shadowRadius)
                    .animation(notchly.animation, value: notchly.isMouseInside)
                    .clipped()
                    
                    /// 🔔 Calendar Live Activity (Alert-style)
                    Group {
                        if shouldShowCalendarLiveActivity {
                            CalendarLiveActivityView(activityMonitor: calendarActivityMonitor)
                                .frame(width: notchly.configuration.width, height: notchly.configuration.height)
                                .transition(.scale.combined(with: .opacity))
                                .zIndex(999)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: calendarActivityMonitor.upcomingEvent)
                    
                    /// 🔹 Media Player on Left, Calendar on Right
                    HStack(alignment: .center, spacing: 6) {
                        Spacer()
                            .frame(width: 4)

                        UnifiedMediaPlayerView(
                            mediaMonitor: mediaMonitor,
                            isExpanded: notchly.isMouseInside,
                            namespace: notchAnimation
                        )
                        .frame(
                            width: notchly.isMouseInside ? notchly.notchWidth * 0.42 : currentConfig.width,
                            height: notchly.isMouseInside ? notchly.notchHeight - 5 : currentConfig.height
                        )
                        .matchedGeometryEffect(id: "mediaPlayer", in: notchAnimation)
                        .padding(.leading, 4)
                        .animation(notchly.animation, value: notchly.isMouseInside)
                        
                        Spacer()
                            .frame(width: 5)
                        
                        // The calendar module remains unchanged.
                        NotchlyCalendarView(calendarManager: calendarManager, isExpanded: notchly.isMouseInside)
                            .matchedGeometryEffect(id: "calendar", in: notchAnimation)
                            .frame(
                                width: notchly.isMouseInside ? notchly.notchWidth * 0.50 : 0,
                                height: notchly.isMouseInside ? notchly.notchHeight - 5 : 0
                            )
                            .padding(.trailing, 4)
                            .opacity(notchly.isMouseInside ? 1 : 0)
                            .clipped()
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
                            .animation(NotchlyAnimations.quickTransition, value: notchly.isMouseInside)
                    }
                    .frame(width: notchly.notchWidth, alignment: .center) // ✅ Forces full width of the Notch
                    .padding(.horizontal, 4) // ✅ Centers everything without shifting left
                }
                .frame(
                    width: notchly.isMouseInside ? notchly.notchWidth : currentConfig.width,
                    height: notchly.isMouseInside ? notchly.notchHeight : currentConfig.height
                )
                .clipShape(
                    NotchlyShape(
                        bottomCornerRadius: currentConfig.bottomCornerRadius,
                        topCornerRadius: currentConfig.topCornerRadius
                    )
                )
                .onHover { hovering in
                    debounceHover(hovering)
                }
                
                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            calendarManager.requestAccess { granted in
                print("Calendar Access: \(granted)")
                print("📆 Loaded \(calendarManager.events.count) events")

                // Kick off the calendar monitor after events load
                calendarActivityMonitor.evaluateLiveActivity()
            }
        }
        // Update the media state in the Notchly controller whenever mediaMonitor.isPlaying changes.
        .onReceive(mediaMonitor.$isPlaying) { playing in
            notchly.isMediaPlaying = playing

            if !notchly.isMouseInside {
                notchly.handleHover(expand: false) // this triggers resizeNotch internally
            }
        }
    }

    // MARK: - Debounce Hover Detection

    /// Debounces hover events to prevent rapid state changes
    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            DispatchQueue.main.async {
                guard hovering != notchly.isMouseInside else { return }
                withAnimation(notchly.animation) {
                    notchly.isMouseInside = hovering
                    notchly.handleHover(expand: hovering)
                }
            }
        }

        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}
