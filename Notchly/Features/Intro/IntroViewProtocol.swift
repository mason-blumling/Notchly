//
//  IntroViewProtocol.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI
import EventKit

/// Shared permission status enum
enum PermissionStatus {
    case unknown
    case checking
    case granted
    case denied
}

/// Button style shared across intro components
struct IntroHoverButtonStyle: ButtonStyle {
    var foregroundColor: Color
    var backgroundColor: Color
    var hoverColor: Color

    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .background(isHovering ? hoverColor : backgroundColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
    }
}

/// Delegate protocol for communication with parent view
protocol IntroViewDelegate {
    func advanceStage()
    func completeIntro()
    func triggerHapticFeedback()
    func updateIntroConfig(for stage: IntroView.IntroStage)
}

/// Extended delegate for permissions view
protocol IntroPermissionsDelegate: IntroViewDelegate {
    func requestCalendarPermission()
    func requestAutomationPermission()
    func openSystemPreferences()
    var calendarPermissionStatus: PermissionStatus { get }
    var automationPermissionStatus: PermissionStatus { get }
    var isCheckingCalendar: Bool { get }
    var isCheckingAutomation: Bool { get }
}
