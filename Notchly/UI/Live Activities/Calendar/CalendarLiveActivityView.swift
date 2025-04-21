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
            }
        )
        .transition(.opacity.combined(with: .scale))
    }
}
