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
    @State private var currentStage: IntroStage = .logo
    @State private var showContent = false
    @State private var calendarPermissionStatus: PermissionStatus = .unknown
    @State private var automationPermissionStatus: PermissionStatus = .unknown
    @State private var isCheckingCalendar = false
    @State private var isCheckingAutomation = false
    
    /// Called when the intro sequence completes
    var onComplete: () -> Void
    
    // MARK: - Types
    
    private enum IntroStage {
        case logo           // Logo animation playing
        case welcome        // Welcome message
        case permissions    // Permission requests
        case tips           // Usage tips
        case complete       // Ready to exit
    }
    
    private enum PermissionStatus {
        case unknown
        case checking
        case granted
        case denied
    }
    
    var body: some View {
        NotchlyShapeView(
            configuration: coordinator.configuration,
            state: coordinator.state,
            animation: coordinator.animation
        ) { layout in
            ZStack {
                switch currentStage {
                case .logo:
                    logoStage(layout: layout)
                case .welcome:
                    welcomeStage(layout: layout)
                case .permissions:
                    permissionsStage(layout: layout)
                case .tips:
                    tipsStage(layout: layout)
                case .complete:
                    EmptyView()
                }
            }
            .frame(width: layout.contentWidth, height: layout.contentHeight)
        }
        .onAppear {
            startIntroSequence()
            checkPermissions()
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
    
    // MARK: - Stage Views
    
    private func logoStage(layout: NotchlyLayoutGuide) -> some View {
        NotchlyLogoAnimation()
            .frame(
                width: layout.contentWidth * 0.6,
                height: layout.contentHeight * 0.5
            )
            .scaleEffect(showContent ? 1 : 0.5)
            .opacity(showContent ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    showContent = true
                }
            }
    }
    
    private func welcomeStage(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 16) {
            Text("Welcome to Notchly")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Your MacBook notch, reimagined")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: { advanceStage() }) {
                Text("Next")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func permissionsStage(layout: NotchlyLayoutGuide) -> some View {
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
            
            VStack(spacing: 10) {
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
    
    private func tipsStage(layout: NotchlyLayoutGuide) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: "hand.point.up", text: "Hover over the notch to expand")
                tipRow(icon: "music.note", text: "Control your media playback")
                tipRow(icon: "calendar", text: "View upcoming events and alerts")
            }
            
            Button(action: { completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 22)
            
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
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
        currentStage = .logo
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            advanceStage()
        }
    }
    
    private func advanceStage() {
        withAnimation(.easeInOut(duration: 0.6)) {
            switch currentStage {
            case .logo:
                currentStage = .welcome
            case .welcome:
                currentStage = .permissions
            case .permissions:
                currentStage = .tips
            case .tips:
                currentStage = .complete
            case .complete:
                completeIntro()
            }
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
