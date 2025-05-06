//
//  IntroView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI
import AppKit
import EventKit

/// A complete intro experience for first-time users with smoothly coordinated animations.
struct IntroView: View {
    @ObservedObject private var coordinator = NotchlyViewModel.shared
    @State private var currentStage: IntroStage = .logoDrawing
    @State private var showContent = false
    @State private var calendarPermissionStatus: PermissionStatus = .unknown
    @State private var automationPermissionStatus: PermissionStatus = .unknown
    @State private var isCheckingCalendar = false
    @State private var isCheckingAutomation = false
    
    // Animation state - now centralized
    @State private var logoAnimationState: LogoAnimationState = .initial
    
    // Called when the intro sequence completes
    var onComplete: () -> Void
    
    // MARK: - Types
    
    // Animation state tracking
    enum LogoAnimationState: Equatable {
        case initial      // Before animation starts
        case drawingN     // Drawing the N
        case showRainbow  // Rainbow N animation
        case showFullName // Reveal text alongside logo
    }
    
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
            // IMPORTANT: The logo animation is ALWAYS present
            // but visibility is controlled by opacity based on stage
            EnhancedLogoAnimation(state: $logoAnimationState)
                .id("persistentLogoAnimation")
                .opacity(showLogoAnimation ? 1.0 : 0.0)
                .zIndex(10) // Keep logo on top during transitions
            
            // Content layers appear based on stage
            switch currentStage {
            case .logoDrawing, .logoRainbow, .fullName:
                Color.clear // Logo is shown from the persistent animation above
                
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
    
    // Computed property to show/hide logo animation
    private var showLogoAnimation: Bool {
        switch currentStage {
        case .logoDrawing, .logoRainbow, .fullName:
            return true
        default:
            return false
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

    struct EnhancedLogoAnimation: View {
        @Binding var state: LogoAnimationState
        
        // Internal animation states
        @State private var nProgress = 0.0
        @State private var showRainbow = false
        @State private var gradientOffset = 0.0
        @State private var showFullText = false
        @State private var textProgress = 0.0
        @State private var logoShift: CGFloat = 0
        @State private var logoScale: CGFloat = 1.0
        
        // Style parameters - adjusted for bigger, more visible logo
        private let style = StrokeStyle(lineWidth: 5, lineCap: .round)
        
        var body: some View {
            ZStack {
                // Logo N - made larger (120x120 instead of 80x80)
                Group {
                    // White stroke path animation for N
                    NotchlyLogoShape()
                        .trim(from: 0, to: nProgress)
                        .stroke(Color.white, style: style)
                        .opacity(showRainbow ? 0 : 1)
                    
                    // Rainbow gradient path with blur glow
                    if showRainbow {
                        let base = NotchlyLogoShape()
                            .trim(from: 0, to: nProgress)
                            .stroke(AngularGradient.notchly(offset: gradientOffset), style: style)
                        
                        base.blur(radius: 5)
                        base.blur(radius: 2)
                        base
                    }
                }
                .scaleEffect(logoScale)
                .frame(width: 120, height: 120) // Increased from 80x80
                .offset(x: logoShift)
                
                // Text component - positioned closer to the N
                if showFullText {
                    // Replace the "otchly" text with this enhanced version
                    Text("otchly")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(textProgress)
                        .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
                        .overlay(
                            Text("otchly")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .blur(radius: 3)
                                .offset(x: 0, y: 1)
                                .mask(
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.white, .clear]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .scaleEffect(x: textProgress * 2)
                                )
                        )
                        .offset(x: 70)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: state) { _, newState in
                updateAnimationForState(newState)
            }
            .onAppear {
                // Start initial animation if we're in the right state
                if state == .initial {
                    state = .drawingN
                }
            }
        }
        
        // Responds to state changes with appropriate animations - faster timing
        private func updateAnimationForState(_ newState: LogoAnimationState) {
            switch newState {
            case .initial:
                // Reset state
                nProgress = 0
                showRainbow = false
                showFullText = false
                textProgress = 0
                logoShift = 0
                logoScale = 1.0
                
            case .drawingN:
                // Draw the N with white stroke - faster animation (2.2s instead of 3.0s)
                withAnimation(.easeInOut(duration: 2.2)) {
                    nProgress = 1.0
                }
                
            case .showRainbow:
                // Crossfade to rainbow - slightly faster (0.8s instead of 1.0s)
                withAnimation(.easeInOut(duration: 0.8)) {
                    showRainbow = true
                }
                
                // Start the rainbow rotation animation
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    gradientOffset = 360
                }
                
            case .showFullName:
                // First shift the logo left - smaller shift since text is closer
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { // Faster spring
                    logoShift = -65 // Reduced shift from -90 to -65
                    logoScale = 0.9 // Less scale reduction to keep N more prominent
                }
                
                // Show text container
                showFullText = true
                textProgress = 0
                
                // Then fade in the text with slight delay - faster reveal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { // Reduced delay
                    withAnimation(.easeInOut(duration: 1.2)) { // Slightly faster text reveal
                        textProgress = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Animation Sequence
    
    private func startIntroSequence() {
        // Set initial stage and config
        currentStage = .logoDrawing
        coordinator.updateIntroConfig(for: .logoDrawing)
        logoAnimationState = .initial
        
        // Trigger drawing animation with a tiny delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
                logoAnimationState = .drawingN
            }
        }
        
        // After drawing completes, show rainbow effect - faster timing (2.5s instead of 3.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                currentStage = .logoRainbow
                coordinator.updateIntroConfig(for: .logoRainbow)
                logoAnimationState = .showRainbow
            }
            
            // After rainbow animates, prepare for full name + notch expansion - faster (1.5s instead of 2.0s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // CRITICAL: First expand the notch, then wait for animation to settle
                withAnimation(NotchlyAnimations.notchExpansion) {
                    coordinator.updateIntroConfig(for: .fullName)
                    currentStage = .fullName
                }
                
                // After notch expansion completes, reveal text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { // Slightly quicker
                    logoAnimationState = .showFullName
                }
                
                // After allowing time for animations, move to welcome - slightly faster (2.7s instead of 3.0s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                    withAnimation(NotchlyAnimations.morphAnimation) {
                        currentStage = .welcome
                        coordinator.updateIntroConfig(for: .welcome)
                    }
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
