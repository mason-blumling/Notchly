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

    @State private var appear = false

    var body: some View {
        LiveActivityView(
            leftContent: {
                calendarIcon
            },
            rightContent: {
                timeRemainingLabel
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .onAppear {
            appear = true
        }
        .onDisappear {
            appear = false
        }
    }
}

// MARK: - Components

private extension CalendarLiveActivityView {
    
    /// The icon shown on the left side (calendar symbol with background).
    var calendarIcon: some View {
        Image(systemName: "calendar")
            .resizable()
            .scaledToFit()
            .foregroundColor(.white)
            .padding(4)
            .background(Color.blue.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .matchedGeometryEffect(id: "calendarIcon", in: namespace)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            .animation(NotchlyAnimations.notchExpansion, value: appear)
    }

    /// The countdown or time-remaining text shown on the right side.
    var timeRemainingLabel: some View {
        Text(activityMonitor.timeRemainingString)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
            .matchedGeometryEffect(id: "calendarTimeText", in: namespace)
            .scaleEffect(appear ? 1 : 0.8)
            .opacity(appear ? 1 : 0)
            .animation(NotchlyAnimations.notchExpansion, value: appear)
    }
}
