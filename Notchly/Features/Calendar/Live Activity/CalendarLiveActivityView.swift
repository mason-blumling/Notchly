//
//  CalendarLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import SwiftUI

/// Displays a compact calendar live activity inside the notch.
/// Shows a calendar icon and countdown or time remaining label.
struct CalendarLiveActivityView: View {
    @ObservedObject var activityMonitor: CalendarLiveActivityMonitor
    var namespace: Namespace.ID
    
    /// Track local appearance state
    @State private var appear = false
    
    /// Reference to shared view model to monitor configuration changes
    @ObservedObject private var coordinator = NotchlyViewModel.shared

    var body: some View {
        LiveActivityView(
            leftContent: {
                calendarIcon
            },
            rightContent: {
                timeRemainingLabel
            }
        )
        .opacity(appear ? 1 : 0)
        .onAppear {
            NotchlyLogger.notice("📅 Calendar view appeared - animating in", category: .ui)
            /// Force notch into correct configuration before showing content
            DispatchQueue.main.async {
                withAnimation(NotchlyAnimations.liveActivityTransition) {
                    coordinator.configuration = .activity
                    coordinator.state = .calendarActivity
                }
                
                /// Only start content animation after configuration change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appear = true
                    }
                }
            }
        }
        /// Key improvement: Respond to isExiting flag for animated exit
        .onChange(of: activityMonitor.isExiting) { _, isExiting in
            if isExiting {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appear = false
                }
            }
        }
        .onDisappear {
            NotchlyLogger.debug("📅 Calendar view disappeared", category: .ui)
            
            /// Additional safeguard: if disappearing and still in calendar activity state, force a transition to the appropriate state
            if coordinator.state == .calendarActivity {
                DispatchQueue.main.async {
                    let shouldShowMedia = coordinator.isMediaPlaying
                    withAnimation(NotchlyAnimations.liveActivityTransition) {
                        if shouldShowMedia {
                            coordinator.configuration = .activity
                            coordinator.state = .mediaActivity
                        } else {
                            coordinator.configuration = .default
                            coordinator.state = .collapsed
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var calendarIcon: some View {
        Image(systemName: "calendar")
            .resizable()
            .scaledToFit()
            .foregroundColor(.white)
            .padding(4)
            .background(Color.blue.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            /// Consistent matchedGeometryEffect
            .matchedGeometryEffect(id: "calendarIcon", in: namespace)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            /// Use same animation for all transformations
            .animation(NotchlyAnimations.liveActivityTransition, value: appear)
    }
    
    private var timeRemainingLabel: some View {
        Text(activityMonitor.timeRemainingString)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
            /// Consistent matchedGeometryEffect
            .matchedGeometryEffect(id: "calendarTimeText", in: namespace)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            /// Use same animation for all transformations
            .animation(NotchlyAnimations.liveActivityTransition, value: appear)
    }
}
