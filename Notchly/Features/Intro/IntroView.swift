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
    @State private var showContent = false
    @State private var calendarPermissionStatus: PermissionStatus = .unknown
    @State private var automationPermissionStatus: PermissionStatus = .unknown
    @State private var isCheckingCalendar = false
    @State private var isCheckingAutomation = false
    
    // Called when the intro sequence completes
    var onComplete: () -> Void
    
    // MARK: - Types
    
    // Make this enum public so it can be accessed by NotchlyViewModel
    public enum IntroStage: Int, CaseIterable {
        case logoDrawing = 0    // Initial N logo animation
        case logoRainbow        // N transitions to rainbow
        case fullName           // "otchly" appears next to the N
        case welcome            // Welcome message
        case permissions        // Permission requests
        case tips               // Usage tips
        case complete           // Ready to exit
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
        ZStack {
            switch currentStage {
            case .logoDrawing, .logoRainbow:
                logoStageView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .fullName:
                fullNameStageView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .welcome:
                welcomeStageView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .permissions:
                permissionsStageView()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            case .tips:
                tipsStageView()
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            case .complete:
                EmptyView()
            }
        }
        .padding(.top, NotchlyViewModel.shared.hasNotch ? 30 : 0)
        .animation(NotchlyAnimations.morphAnimation, value: currentStage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private func logoStageView() -> some View {
        EnhancedNotchlyLogoAnimation(
            startAnimation: true,
            coordinateWithNotch: true
        )
        .id("logoAnimation")
        .scaleEffect(showContent ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            coordinator.updateIntroConfig(for: .logoDrawing)
            
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            
            // Set up timers for advancing through logo stages
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    currentStage = .logoRainbow
                    coordinator.updateIntroConfig(for: .logoRainbow)
                }
                
                // After rainbow effect, animate to full name with medium notch
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Create a smoother, coordinated transition for expansion + text reveal
                    withAnimation(NotchlyAnimations.notchExpansion) {
                        // First expand the notch shape
                        coordinator.updateIntroConfig(for: .fullName)
                        currentStage = .fullName
                    }
                }
            }
        }
    }

    
    // MARK: - Full Name Stage
    
    private func fullNameStageView() -> some View {
        EnhancedNotchlyLogoAnimation(
            startAnimation: false,
            coordinateWithNotch: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Time the text reveal with the notch expansion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Send the notification to trigger text reveal
                NotificationCenter.default.post(
                    name: Notification.Name("NotchlyRevealText"),
                    object: nil
                )
            }
            
            // After showing full name, begin transition to welcome
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // Start transitioning to welcome with a smooth animation
                withAnimation(NotchlyAnimations.morphAnimation) {
                    currentStage = .welcome
                    coordinator.updateIntroConfig(for: .welcome)
                }
            }
        }
    }

    // MARK: - Welcome Stage
    
    private func welcomeStageView() -> some View {
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
        .opacity(1) // Ensure it's visible immediately
        .onAppear {
            coordinator.updateIntroConfig(for: .welcome)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Permissions Stage
    
    private func permissionsStageView() -> some View {
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
        .onAppear {
            coordinator.updateIntroConfig(for: .permissions)
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
    
    private func tipsStageView() -> some View {
        VStack(spacing: 8) {
            if NotchlyViewModel.shared.hasNotch {
                Spacer()
                    .frame(height: 15) // Reduced from 20 to 15
            }
            
            Text("Quick Tips")
                .font(.system(size: 22, weight: .bold, design: .rounded)) // Reduced from 24 to 22
                .foregroundColor(.white)
                .overlay(
                    AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                        .mask(
                            Text("Quick Tips")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                        )
                )
                .padding(.bottom, 2) // Reduced from 5 to 2
            
            HStack(spacing: 15) { // Reduced from 20 to 15
                // Tip cards in a row - using more compact cards
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
            .padding(.vertical, 5) // Reduced from 10/15 to 5
            
            Button(action: { completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)) // Reduced from 16 to 15
                    .foregroundColor(.black)
                    .padding(.vertical, 8) // Reduced from 10 to 8
                    .padding(.horizontal, 40)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 5)
            .padding(.bottom, NotchlyViewModel.shared.hasNotch ? 5 : 3) // Further reduced padding
        }
        .onAppear {
            coordinator.updateIntroConfig(for: .tips)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // More compact tip card
    private func tipCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22)) // Reduced from 26/30 to 22
                .foregroundColor(.white)
                .frame(width: 42, height: 42) // Reduced from 50/60 to 42
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
            
            // Title
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded)) // Reduced from 14 to 13
                .foregroundColor(.white)
            
            // Description - shorter height
            Text(description)
                .font(.system(size: 11, weight: .medium))                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 35) // Reduced from 40/50 to 35
                .lineLimit(3)
        }
        .frame(width: 200) // Reduced from 220 to 200
        .padding(.vertical, 10) // Reduced from 12/15 to 10
        .padding(.horizontal, 8) // Reduced from 10 to 8
        .background(Color.white.opacity(0.1))
        .cornerRadius(10) // Reduced from 12 to 10
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
        
        // First check if permission is already granted with a non-blocking script
        let checkScript = NSAppleScript(source: """
            try
                tell application "System Events"
                    return true -- Permission already granted
                end tell
            on error
                return false -- Permission needed
            end try
        """)
        
        var checkError: NSDictionary?
        let result = checkScript?.executeAndReturnError(&checkError)
        
        if result != nil, let boolValue = result?.booleanValue, boolValue == true {
            // Permission already granted
            DispatchQueue.main.async {
                isCheckingAutomation = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    automationPermissionStatus = .granted
                }
                
                if allPermissionsGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        advanceStage()
                    }
                }
            }
            return
        }
        
        // If we reach here, we need to request permission
        // Use a light-weight approach that won't freeze the UI
        DispatchQueue.global(qos: .userInitiated).async {
            let requestScript = NSAppleScript(source: """
                tell application "System Events"
                    -- Simple command that triggers permission dialog
                    set frontApp to name of first process
                end tell
            """)
            
            requestScript?.executeAndReturnError(nil)
            
            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                let verifyScript = NSAppleScript(source: """
                    try
                        tell application "System Events"
                            return true
                        end tell
                    on error
                        return false
                    end try
                """)
                
                var verifyError: NSDictionary?
                let verifyResult = verifyScript?.executeAndReturnError(&verifyError)
                let granted = verifyResult != nil && verifyResult?.booleanValue == true
                
                isCheckingAutomation = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    automationPermissionStatus = granted ? .granted : .denied
                }
                
                if allPermissionsGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        advanceStage()
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
        coordinator.updateIntroConfig(for: .logoDrawing)
        
        // Set up timers for advancing through logo stages
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                currentStage = .logoRainbow
                coordinator.updateIntroConfig(for: .logoRainbow)
            }
            
            // After rainbow effect, prepare for full name transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Create a smoother, coordinated transition for expansion + text reveal
                withAnimation(NotchlyAnimations.notchExpansion) {
                    // First expand the notch shape and change stage
                    coordinator.updateIntroConfig(for: .fullName)
                    currentStage = .fullName
                }
            }
        }
    }

    private func advanceStage() {
        // Find the next stage in the sequence
        if let currentIndex = IntroStage.allCases.firstIndex(of: currentStage),
           currentIndex < IntroStage.allCases.count - 1 {
            let nextStage = IntroStage.allCases[currentIndex + 1]
            
            withAnimation(.easeInOut(duration: 0.6)) {
                currentStage = nextStage
                coordinator.updateIntroConfig(for: nextStage)
            }
        } else {
            completeIntro()
        }
    }
    
    func completeIntro() {
        withAnimation(.easeOut(duration: 0.3)) {
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
