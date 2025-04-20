//
//  NotchlyContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI

/// The visual SwiftUI container for the Notchly floating UI.
/// Displays the expanding/collapsing notch, calendar, media, and live activities.
struct NotchlyContainerView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var mediaMonitor = MediaPlaybackMonitor.shared
    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor

    @Namespace private var notchAnimation
    @State private var debounceWorkItem: DispatchWorkItem?

    init(notchly: Notchly<Content>) {
        self.notchly = notchly
        CalendarManager.shared = CalendarManager()
        _calendarManager = StateObject(wrappedValue: CalendarManager.shared!)
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: CalendarManager.shared!))
    }

    private var shouldShowCalendarLiveActivity: Bool {
        !notchly.isMouseInside &&
        !mediaMonitor.isPlaying &&
        calendarActivityMonitor.upcomingEvent != nil &&
        !calendarActivityMonitor.timeRemainingString.isEmpty
    }

    private var currentConfig: NotchlyConfiguration {
        if !notchly.isMouseInside {
            if mediaMonitor.isPlaying || calendarActivityMonitor.upcomingEvent != nil {
                return .activity
            }
        }
        return notchly.configuration
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()
                ZStack {
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

                    if shouldShowCalendarLiveActivity {
                        CalendarLiveActivityView(activityMonitor: calendarActivityMonitor)
                            .frame(width: currentConfig.width, height: currentConfig.height)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(999)
                            .animation(.easeInOut(duration: 0.3), value: calendarActivityMonitor.upcomingEvent)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Spacer().frame(width: 4)

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

                        Spacer().frame(width: 5)

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
                    .frame(width: notchly.notchWidth)
                    .padding(.horizontal, 4)
                }
                .frame(
                    width: notchly.isMouseInside ? notchly.notchWidth : currentConfig.width,
                    height: notchly.isMouseInside ? notchly.notchHeight : currentConfig.height
                )
                .clipShape(NotchlyShape(
                    bottomCornerRadius: currentConfig.bottomCornerRadius,
                    topCornerRadius: currentConfig.topCornerRadius
                ))
                .onHover { hovering in debounceHover(hovering) }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            calendarManager.requestAccess { granted in
                print("Calendar Access: \(granted)")
                print("📆 Loaded \(calendarManager.events.count) events")
                calendarActivityMonitor.evaluateLiveActivity()
            }
        }
        .onReceive(mediaMonitor.$isPlaying) { playing in
            notchly.isMediaPlaying = playing
            if !notchly.isMouseInside {
                notchly.handleHover(expand: false)
            }
        }
    }

    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem {
            guard hovering != notchly.isMouseInside else { return }
            withAnimation(notchly.animation) {
                notchly.isMouseInside = hovering
                notchly.handleHover(expand: hovering)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: debounceWorkItem!)
    }
}
