//
//  CalendarLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import SwiftUI

struct CalendarLiveActivityView: View {
    @ObservedObject var activityMonitor: CalendarLiveActivityMonitor
    var namespace: Namespace.ID
    @State private var appear = false

    var body: some View {
        LiveActivityView(
            leftContent: {
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
            },
            rightContent: {
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
