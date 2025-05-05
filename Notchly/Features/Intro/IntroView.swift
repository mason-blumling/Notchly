//
//  IntroView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI
import AppKit
import EventKit

/// A complete intro experience for first-time users.
/// Displays the animated logo, welcome text, permissions, and usage instructions.
struct IntroView: View {
    @ObservedObject private var coordinator = NotchlyViewModel.shared
    @State private var currentStage: IntroStage = .logoDrawing
    @State private var notchSize: NotchSize = .small
    @State private var showContent = false
    @State private var calendarPermissionStatus: PermissionStatus = .unknown
    @State private var automationPermissionStatus: PermissionStatus = .unknown
    @State private var isCheckingCalendar = false
    @State private var isCheckingAutomation = false
    
    // Called when the intro sequence completes
    var onComplete: () -> Void
    
    // MARK: - Types
    
    private enum IntroStage: Int, CaseIterable {
        case logoDrawing = 0    // Initial N logo animation
        case logoRainbow        // N transitions to rainbow
        case fullName           // "otchly" appears next to the N
        case welcome            // Welcome message
        case permissions        // Permission requests
        case tips               // Usage tips
        case complete           // Ready to exit
    }
    
    private enum NotchSize {
        case small      // Initial small square for N drawing
        case medium     // Medium size for logo+name
        case large      // Full width for content stages
        
        var config: NotchlyConfiguration {
            switch self {
            case .small:
                return NotchlyConfiguration(
                    width: 300,
                    height: 300,
                    topCornerRadius: 15,
                    bottomCornerRadius: 15,
                    shadowRadius: 0
                )
            case .medium:
                return NotchlyConfiguration(
                    width: 500,
                    height: 250,
                    topCornerRadius: 15,
                    bottomCornerRadius: 15,
                    shadowRadius: 0
                )
            case .large:
                return NotchlyConfiguration(
                    width: 800,
                    height: 225,
                    topCornerRadius: 15,
                    bottomCornerRadius: 15,
                    shadowRadius: 0
                )
            }
        }
    }
    
    private enum PermissionStatus {
        case unknown
        case checking
        case granted
        case denied
    }
    
    // MARK: - Body
    
    var body: some View {
        createNotchView()
            .onAppear {
                startIntroSequence()
                checkPermissions()
            }
    }
    
    @ViewBuilder
    private func createNotchView() -> some View {
        NotchlyShapeView(
            configuration: notchSize.config,
            state: coordinator.state,
            animation: coordinator.animation
        ) { layout in
            ZStack {
                switch currentStage {
                case .logoDrawing, .logoRainbow:
                    logoStageView(layout: layout)
                case .fullName:
                    fullNameStageView(layout: layout)
                case .welcome:
                    welcomeStageView(layout: layout)
                case .permissions:
                    permissionsStageView(layout: layout)
                case .tips:
                    tipsStageView(layout: layout)
                case .complete:
                    EmptyView()
                }
            }
            .frame(width: layout.contentWidth, height: layout.contentHeight)
        }
    }
    
    // MARK: - Permission Checking
    
    private func checkPermissions() {
        // Check calendar permission
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        calendarPermissionStatus = calendarStatus == .fullAccess ? .granted : .unknown
        
        // For automation, we'll leave it as unknown since we can't check without triggering
        automationPermissionStatus = .unknown
    }
    
    // MARK: - Logo Stage
    
    private func logoStageView(layout: NotchlyLayoutGuide) -> some View {
        EnhancedNotchlyLogoAnimation()
            .frame(
                width: layout.contentWidth * 0.7,
                height: layout.contentHeight * 0.7
            )
            .scaleEffect(showContent ? 1 : 0.5)
            .opacity(showContent ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
                
                // Set up timers for advancing through logo stages
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        currentStage = .logoRainbow
                    }
                    
                    // After rainbow effect, transition to full name with medium notch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(NotchlyAnimations.morphAnimation) {
                            notchSize = .medium
                            currentStage = .fullName
                        }
                    }
                }
            }
    }
    
    // MARK: - Full Name Stage
    
    private func fullNameStageView(layout: NotchlyLayoutGuide) -> some View {
        EnhancedNotchlyLogoAnimation()
            .frame(
                width: layout.contentWidth * 0.7,
                height: layout.contentHeight * 0.7
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // After showing full name, transition to welcome with large notch
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(NotchlyAnimations.morphAnimation) {
                        notchSize = .large
                        currentStage = .welcome
                    }
                }
            }
    }
    
    // MARK: - Welcome Stage
    
    private func welcomeStageView(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "macbook")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Notchly")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .overlay(
                        AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                            .mask(
                                Text("Notchly")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                            )
                    )
            }
            .padding(.bottom, 5)
            
            Text("Welcome to Notchly")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Your MacBook notch, reimagined")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Transform the notch into a dynamic productivity hub with seamless controls for your media and calendar.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 80)
                .padding(.vertical, 10)
            
            Button(action: { advanceStage() }) {
                Text("Next")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 30)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Permissions Stage
    
    private func permissionsStageView(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Before we get started")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Notchly needs some permissions to work its magic")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                permissionRow(
                    icon: "calendar",
                    title: "Calendar Access",
                    description: "See your upcoming events",
                    status: calendarPermissionStatus,
                    isChecking: isCheckingCalendar,
                    action: requestCalendarPermission
                )
                
                permissionRow(
                    icon: "music.note",
                    title: "Media Control",
                    description: "Control Apple Music & Spotify",
                    status: automationPermissionStatus,
                    isChecking: isCheckingAutomation,
                    action: requestAutomationPermission
                )
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                if canSkipPermissions {
                    Button(action: { advanceStage() }) {
                        Text("Skip for Now")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: handleContinueAction) {
                    Text(continueButtonText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                        .background(continueButtonColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isCheckingPermissions)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        status: PermissionStatus,
        isChecking: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(status == .granted ? .green : .white)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if isChecking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if status == .granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            } else {
                Button(action: action) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Tips Stage
    
    private func tipsStageView(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 10) {
            Text("Quick Tips")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .overlay(
                    AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                        .mask(
                            Text("Quick Tips")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        )
                )
                .padding(.bottom, 5)
            
            HStack(spacing: 20) {
                // Tip cards in a row
                tipCard(
                    icon: "hand.point.up.fill",
                    title: "Hover to Expand",
                    description: "Simply move your cursor over the notch to expand Notchly"
                )
                
                tipCard(
                    icon: "music.note",
                    title: "Media Controls",
                    description: "Play, pause, skip tracks and adjust volume right from your notch"
                )
                
                tipCard(
                    icon: "calendar",
                    title: "Calendar Alerts",
                    description: "Get timely notifications about upcoming events"
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
            
            Button(action: { completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 40)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 5)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func tipCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .center, spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
            
            // Title
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Description
            Text(description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 50)
        }
        .frame(width: 220)
        .padding(.vertical, 15)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Permission Helpers
    
    private var allPermissionsGranted: Bool {
        calendarPermissionStatus == .granted && automationPermissionStatus == .granted
    }
    
    private var canSkipPermissions: Bool {
        calendarPermissionStatus == .granted
    }
    
    private var isCheckingPermissions: Bool {
        isCheckingCalendar || isCheckingAutomation
    }
    
    private var continueButtonText: String {
        if isCheckingPermissions {
            return "Checking..."
        } else if allPermissionsGranted {
            return "Continue"
        } else {
            return "Open Settings"
        }
    }
    
    private var continueButtonColor: Color {
        if allPermissionsGranted {
            return Color.green
        } else {
            return Color.white
        }
    }
    
    private func handleContinueAction() {
        if allPermissionsGranted {
            advanceStage()
        } else {
            openSystemPreferences()
        }
    }
    
    // MARK: - Permission Requests
    
    private func requestCalendarPermission() {
        isCheckingCalendar = true
        
        AppEnvironment.shared.calendarManager.requestAccess { granted in
            DispatchQueue.main.async {
                isCheckingCalendar = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    calendarPermissionStatus = granted ? .granted : .denied
                }
                
                if allPermissionsGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        advanceStage()
                    }
                }
            }
        }
    }
    
    private func requestAutomationPermission() {
        isCheckingAutomation = true
        
        // For automation permissions, we'll use a different approach
        // We'll try to access a simple AppleScript that should work if we have permission
        let testScript = NSAppleScript(source: """
            tell application "System Events"
                -- Just check if we can access System Events
                return exists
            end tell
        """)
        
        DispatchQueue.global().async {
            var errorInfo: NSDictionary?
            testScript?.executeAndReturnError(&errorInfo)
            
            DispatchQueue.main.async {
                isCheckingAutomation = false
                
                if errorInfo == nil {
                    // Permission already granted
                    withAnimation(.easeInOut(duration: 0.3)) {
                        automationPermissionStatus = .granted
                    }
                } else {
                    // Need to request permission - this will trigger the system dialog
                    let requestScript = NSAppleScript(source: """
                        tell application "System Events"
                            -- This will trigger the permission dialog
                            set runningApps to name of processes
                        end tell
                    """)
                    
                    var requestError: NSDictionary?
                    requestScript?.executeAndReturnError(&requestError)
                    
                    // After the dialog, check the status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        let checkScript = NSAppleScript(source: """
                            tell application "System Events"
                                return exists
                            end tell
                        """)
                        
                        var checkError: NSDictionary?
                        checkScript?.executeAndReturnError(&checkError)
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            automationPermissionStatus = checkError == nil ? .granted : .denied
                        }
                        
                        if allPermissionsGranted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                advanceStage()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Sequence Control
    
    private func startIntroSequence() {
        currentStage = .logoDrawing
        notchSize = .small
    }
    
    private func advanceStage() {
        // Find the next stage in the sequence
        if let currentIndex = IntroStage.allCases.firstIndex(of: currentStage),
           currentIndex < IntroStage.allCases.count - 1 {
            let nextStage = IntroStage.allCases[currentIndex + 1]
            
            withAnimation(.easeInOut(duration: 0.6)) {
                currentStage = nextStage
            }
        } else {
            completeIntro()
        }
    }
    
    private func completeIntro() {
        withAnimation(.easeIn(duration: 0.3)) {
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}

// MARK: - Preview

struct IntroView_Previews: PreviewProvider {
    static var previews: some View {
        IntroView(onComplete: {})
            .frame(width: 800, height: 300)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
