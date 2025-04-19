//
//  CalendarLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/18/25.
//

import SwiftUI

struct CalendarLiveActivityView: View {
    @ObservedObject var activityMonitor: CalendarLiveActivityMonitor

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
            },
            rightContent: {
                Text(activityMonitor.timeRemainingString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Capsule())
            }
        )
        .transition(.opacity.combined(with: .scale))
    }
}
