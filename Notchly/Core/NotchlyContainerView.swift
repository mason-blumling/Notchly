//
//  NotchlyContainerView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/19/25.
//

import SwiftUI
import Combine

/// The visual SwiftUI container for the Notchly floating UI.
/// Displays the expanding/collapsing notch, calendar, media, and live activities.
struct NotchlyContainerView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>
    @EnvironmentObject var appEnvironment: AppEnvironment

    @Namespace private var notchAnimation

    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showMediaAfterCalendar: Bool = false
    @State private var forceCollapseForCalendar = false

    @StateObject private var calendarActivityMonitor: CalendarLiveActivityMonitor

    private var mediaMonitor: MediaPlaybackMonitor { appEnvironment.mediaMonitor }
    private var calendarManager: CalendarManager { appEnvironment.calendarManager }

    init(notchly: Notchly<Content>) {
        self.notchly = notchly
        let manager = AppEnvironment.shared.calendarManager
        _calendarActivityMonitor = StateObject(wrappedValue: CalendarLiveActivityMonitor(calendarManager: manager))
    }

    private var shouldShowCalendarLiveActivity: Bool {
        !notchly.isMouseInside &&
        calendarActivityMonitor.upcomingEvent != nil &&
        !calendarActivityMonitor.timeRemainingString.isEmpty
    }

    private var currentConfig: NotchlyConfiguration {
        if forceCollapseForCalendar {
            return .default
        }

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
                    .animation(notchly.animation, value: notchly.isMouseInside || forceCollapseForCalendar)

                    Group {
                        if shouldShowCalendarLiveActivity {
                            CalendarLiveActivityView(activityMonitor: calendarActivityMonitor, namespace: notchAnimation)
                                .matchedGeometryEffect(id: "calendarLiveActivity", in: notchAnimation)
                                .transition(.opacity.combined(with: .scale))
                                .zIndex(999)
                        }
                    }
                    .frame(width: currentConfig.width, height: currentConfig.height)
                    .animation(NotchlyAnimations.notchExpansion, value: shouldShowCalendarLiveActivity)

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
                        .opacity(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0 : 1)
                        .scaleEffect(shouldShowCalendarLiveActivity && !showMediaAfterCalendar ? 0.95 : 1)
                        .animation(notchly.animation, value: shouldShowCalendarLiveActivity)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

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
                if granted {
                    calendarActivityMonitor.evaluateLiveActivity()
                }
            }

            calendarActivityMonitor.$isLiveActivityVisible
                .removeDuplicates()
                .sink { isActive in
                    notchly.calendarHasLiveActivity = isActive
                    forceCollapseForCalendar = true
                    notchly.handleHover(expand: false)

                    DispatchQueue.main.asyncAfter(deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()) {
                        forceCollapseForCalendar = false

                        if isActive {
                            withAnimation(NotchlyAnimations.quickTransition) {
                                showMediaAfterCalendar = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + NotchlyAnimations.Durations.quick) {
                                notchly.handleHover(expand: true)
                            }
                        } else {
                            withAnimation(NotchlyAnimations.quickTransition) {
                                showMediaAfterCalendar = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + NotchlyAnimations.delayAfterLiveActivityTransition()) {
                                if mediaMonitor.isPlaying {
                                    withAnimation(NotchlyAnimations.smoothTransition) {
                                        showMediaAfterCalendar = true
                                    }
                                    notchly.handleHover(expand: true)
                                }
                            }
                        }
                    }
                }
                .store(in: &cancellables)
            appEnvironment.mediaMonitor.setExpanded(notchly.isMouseInside)
        }
        .onReceive(mediaMonitor.$isPlaying) { playing in
            notchly.isMediaPlaying = playing
            if !notchly.isMouseInside {
                notchly.handleHover(expand: false)
            }
        }
        .onChange(of: notchly.isMouseInside) { _, inside in
            appEnvironment.mediaMonitor.setExpanded(inside)
            print("Inside Hover, increasing polling")
        }
    }

    private func debounceHover(_ hovering: Bool) {
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem {
            guard hovering != notchly.isMouseInside else { return }
            withAnimation(NotchlyAnimations.notchExpansion) {
                notchly.isMouseInside = hovering
                notchly.handleHover(expand: hovering)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: debounceWorkItem!)
    }
}
