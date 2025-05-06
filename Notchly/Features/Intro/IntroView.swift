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
    // MARK: - State & Environment

    @ObservedObject private var coordinator = NotchlyViewModel.shared
    @State private var currentStage: IntroStage = .logoDrawing
    @State private var showContent = false
    @State private var calendarPermissionStatus: PermissionStatus = .unknown
    @State private var automationPermissionStatus: PermissionStatus = .unknown
    @State private var isCheckingCalendar = false
    @State private var isCheckingAutomation = false
    @State private var playSound = false
    @State private var logoAnimationState: LogoAnimationState = .initial

    /// Completion handler triggered when the intro finishes
    var onComplete: () -> Void

    // MARK: - Types

    /// Enum tracking internal logo animation state
    enum LogoAnimationState: Equatable {
        case initial      // Before animation starts
        case drawingN     // Drawing the "N"
        case showRainbow  // Morph to rainbow coloring
        case showFullName // Reveal "otchly" text
    }

    /// Enum controlling stages of the onboarding experience
    public enum IntroStage: Int, CaseIterable {
        case logoDrawing = 0
        case logoRainbow
        case fullName
        case welcome
        case permissions
        case tips
        case complete
    }

    /// Enum tracking permission status for calendar/automation
    private enum PermissionStatus {
        case unknown
        case checking
        case granted
        case denied
    }

    // MARK: - Main View

    var body: some View {
        createNotchView()
            .onAppear {
                startIntroSequence()
                checkPermissions()
            }
    }

    /// Primary notch animation container view
    @ViewBuilder
    private func createNotchView() -> some View {
        GeometryReader { geometry in
            ZStack {
                // Main logo animation (always mounted)
                EnhancedLogoAnimation(state: $logoAnimationState)
                    .id("persistentLogoAnimation")
                    .opacity(showLogoAnimation ? 1.0 : 0.0)
                    .zIndex(10)
                    .onChange(of: logoAnimationState) { _, newState in
                        triggerStateHaptics(for: newState)
                    }

                // Screen-specific overlay content
                switch currentStage {
                case .logoDrawing, .logoRainbow, .fullName:
                    Color.clear
                case .welcome:
                    welcomeStageView()
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .permissions:
                    permissionsStageView(geometry: geometry)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                case .tips:
                    tipsStageView(geometry: geometry)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                case .complete:
                    EmptyView()
                }
            }
            .padding(.top, NotchlyViewModel.shared.hasNotch ? min(15, geometry.size.height * 0.05) : 0)
            .animation(NotchlyAnimations.morphAnimation, value: currentStage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Whether to show the logo animation overlay
    private var showLogoAnimation: Bool {
        switch currentStage {
        case .logoDrawing, .logoRainbow, .fullName:
            return true
        default:
            return false
        }
    }

    // MARK: - Haptics

    /// Triggers macOS haptic feedback (if available)
    private func triggerHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .default
        )
    }

    /// Applies haptic feedback on animation state transitions
    private func triggerStateHaptics(for state: LogoAnimationState) {
        switch state {
        case .drawingN, .showRainbow, .showFullName:
            triggerHapticFeedback()
        default:
            break
        }
    }

    // MARK: - Permissions

    /// Initial permission status checks
    private func checkPermissions() {
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        calendarPermissionStatus = calendarStatus == .fullAccess ? .granted : .unknown
        automationPermissionStatus = .unknown // Cannot check without prompting
    }

    // MARK: - Enhanced Components

    /// A capsule-shaped hoverable button with spring animation.
    struct HoverButtonStyle: ButtonStyle {
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

    /// Displays the animated N logo with transitions from white to rainbow to full 'Notchly' name.
    struct EnhancedLogoAnimation: View {
        @Binding var state: LogoAnimationState

        // MARK: - Animation State
        @State private var nProgress = 0.0           // Trimmed stroke progress for 'N'
        @State private var showRainbow = false       // Toggle for rainbow mode
        @State private var gradientOffset = 0.0      // Angular gradient animation
        @State private var showFullText = false      // Toggle for showing full 'Notchly'
        @State private var textProgress = 0.0        // Opacity progress of text
        @State private var logoShift: CGFloat = 0    // Horizontal shift during logo animation
        @State private var logoScale: CGFloat = 1.0  // Scaling animation for logo

        // MARK: - Style
        private let style = StrokeStyle(lineWidth: 5, lineCap: .round)

        var body: some View {
            GeometryReader { geometry in
                let size = min(geometry.size.width * 0.3, 120)       /// Max logo size
                let fontSize = min(geometry.size.width * 0.12, 46)   /// Max font size

                ZStack {
                    Group {
                        /// Base white 'N' stroke
                        NotchlyLogoShape()
                            .trim(from: 0, to: nProgress)
                            .stroke(Color.white, style: style)
                            .opacity(showRainbow ? 0 : 1)

                        /// Rainbow animated stroke with blur glow layers
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
                    .frame(width: size, height: size)
                    .offset(x: logoShift)

                    /// "otchly" label animation after logo reveals
                    if showFullText {
                        Text("otchly")
                            .font(.system(size: fontSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(textProgress)
                            .shadow(color: .white.opacity(0.5), radius: 2, x: 0, y: 0)
                            .overlay(
                                Text("otchly")
                                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
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
                            .offset(x: size * 0.6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: state) { _, newState in
                    updateAnimationForState(newState, size: size)
                }
                .onAppear {
                    /// Start animation if state is .initial
                    if state == .initial {
                        state = .drawingN
                    }
                }
            }
        }

        /// Updates internal animation states when the external `state` changes
        private func updateAnimationForState(_ newState: LogoAnimationState, size: CGFloat) {
            switch newState {
            case .initial:
                /// Reset all values
                nProgress = 0
                showRainbow = false
                showFullText = false
                textProgress = 0
                logoShift = 0
                logoScale = 1.0

            case .drawingN:
                /// Animate drawing stroke
                withAnimation(.easeInOut(duration: 2.2)) {
                    nProgress = 1.0
                }

            case .showRainbow:
                /// Fade in rainbow stroke
                withAnimation(.easeInOut(duration: 0.8)) {
                    showRainbow = true
                }

                /// Spin the angular gradient continuously
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    gradientOffset = 360
                }

            case .showFullName:
                /// Animate logo shifting left
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    logoShift = -size * 0.5
                    logoScale = 0.9
                }

                showFullText = true
                textProgress = 0

                /// Reveal text after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 1.2)) {
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
        
        // After drawing completes, show rainbow effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                currentStage = .logoRainbow
                coordinator.updateIntroConfig(for: .logoRainbow)
                logoAnimationState = .showRainbow
            }
            
            // After rainbow animates, prepare for full name + notch expansion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // CRITICAL: First expand the notch, then wait for animation to settle
                withAnimation(NotchlyAnimations.notchExpansion) {
                    coordinator.updateIntroConfig(for: .fullName)
                    currentStage = .fullName
                }
                
                // After notch expansion completes, reveal text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    logoAnimationState = .showFullName
                }
                
                // After allowing time for animations, move to welcome
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.3)) {
                        currentStage = .welcome
                        coordinator.updateIntroConfig(for: .welcome)
                        triggerHapticFeedback()
                    }
                }
            }
        }
    }
    
    // MARK: - Welcome Stage

    private func welcomeStageView() -> some View {
        GeometryReader { geometry in
            VStack {
                /// Top logo - with appropriate spacing
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
                .padding(.top, 18)
                
                /// Title
                Text("Welcome to Notchly")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                /// Subtitle
                Text("Your MacBook notch, reimagined")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 3)
                
                /// Description
                Text("Transform the notch into a dynamic productivity hub with seamless controls for your media and calendar.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
                    .padding(.top, 12)
                
                Spacer()
                
                /// Next button
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
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            coordinator.updateIntroConfig(for: .welcome)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Permissions Stage
    
    private func permissionsStageView(geometry: GeometryProxy) -> some View {
        let titleSize = min(geometry.size.width * 0.035, 20)
        let subtitleSize = min(geometry.size.width * 0.022, 14)
        let buttonTextSize = min(geometry.size.width * 0.022, 14)
        
        return VStack(spacing: geometry.size.height * 0.02) {
            /// Title section aligned with other screens
            Text("Before we get started")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, geometry.size.height * 0.06)
            
            Text("Notchly needs some permissions to work its magic")
                .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Spacer()
                .frame(height: geometry.size.height * 0.02)
                
            VStack(spacing: geometry.size.height * 0.02) {
                permissionRow(
                    geometry: geometry,
                    icon: "calendar",
                    title: "Calendar Access",
                    description: "See your upcoming & past events",
                    status: calendarPermissionStatus,
                    isChecking: isCheckingCalendar,
                    action: requestCalendarPermission
                )
                
                permissionRow(
                    geometry: geometry,
                    icon: "music.note",
                    title: "Media Control",
                    description: "Control Apple Music & Spotify Media",
                    status: automationPermissionStatus,
                    isChecking: isCheckingAutomation,
                    action: requestAutomationPermission
                )
            }
            .padding(.horizontal, geometry.size.width * 0.05)
            
            Spacer()
                
            HStack(spacing: geometry.size.width * 0.02) {
                if canSkipPermissions {
                    Button(action: { advanceStage() }) {
                        Text("Skip for Now")
                            .font(.system(size: buttonTextSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Capsule())
                }
                
                Button(action: handleContinueAction) {
                    Text(continueButtonText)
                        .font(.system(size: buttonTextSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(HoverButtonStyle(
                    foregroundColor: .black,
                    backgroundColor: continueButtonColor,
                    hoverColor: continueButtonColor.opacity(0.9)
                ))
                .disabled(isCheckingPermissions)
            }
            .padding(.bottom, geometry.size.height * 0.06)
        }
        .onAppear {
            coordinator.updateIntroConfig(for: .permissions)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func permissionRow(
        geometry: GeometryProxy,
        icon: String,
        title: String,
        description: String,
        status: PermissionStatus,
        isChecking: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let iconSize = min(geometry.size.width * 0.03, 20)
        let titleSize = min(geometry.size.width * 0.02, 13)
        let descSize = min(geometry.size.width * 0.018, 11)
        let buttonSize = min(geometry.size.width * 0.018, 11)
        
        return HStack(spacing: geometry.size.width * 0.02) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(status == .granted ? .green : .white)
                .frame(width: iconSize * 1.4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: descSize, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            if isChecking {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else if status == .granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.green)
            } else {
                Button(action: action) {
                    Text("Grant")
                        .font(.system(size: buttonSize, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Rectangle())
                .scaleEffect(isCheckingPermissions ? 0.95 : 1.0)
            }
        }
        .padding(.vertical, geometry.size.height * 0.02)
        .padding(.horizontal, geometry.size.width * 0.02)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Tips Stage
    
    private func tipsStageView(geometry: GeometryProxy) -> some View {
        let titleSize = min(geometry.size.width * 0.035, 22)
        let buttonTextSize = min(geometry.size.width * 0.025, 15)
        
        return VStack(spacing: geometry.size.height * 0.015) {
            Text("Quick Tips")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .overlay(
                    AngularGradient.notchly(offset: Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 360))
                        .mask(
                            Text("Quick Tips")
                                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        )
                )
                .padding(.top, geometry.size.height * 0.06)
            
            Spacer()
                .frame(height: geometry.size.height * 0.02)
                
            HStack(spacing: min(geometry.size.width * 0.015, 10)) {
                tipCard(
                    icon: "hand.point.up.fill",
                    title: "Hover to Expand",
                    description: "Move your cursor over the notch"
                )
                
                tipCard(
                    icon: "music.note",
                    title: "Media Controls",
                    description: "Control playback from your notch"
                )
                
                tipCard(
                    icon: "calendar",
                    title: "Calendar Alerts",
                    description: "Get alerts for upcoming events"
                )
            }
            .padding(.horizontal, geometry.size.width * 0.02)
            
            Spacer()
                
            Button(action: { completeIntro() }) {
                Text("Get Started")
                    .font(.system(size: buttonTextSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 30)
            }
            .buttonStyle(HoverButtonStyle(
                foregroundColor: .black,
                backgroundColor: .white,
                hoverColor: Color.white.opacity(0.9)
            ))
            .padding(.bottom, geometry.size.height * 0.06)
        }
        .onAppear {
            coordinator.updateIntroConfig(for: .tips)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func tipCard(icon: String, title: String, description: String) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
            
            /// Title
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            /// Description
            Text(enhancedDescription(for: title))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(height: 45)
                .lineLimit(4)
        }
        .frame(width: 200)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    /// Helper function to provide enhanced descriptions
    private func enhancedDescription(for title: String) -> String {
        switch title {
        case "Hover to Expand":
            return "Glide your cursor over the notch to reveal Notchly."
        case "Media Controls":
            return "Play, pause, and skip right from your notch."
        case "Calendar Alerts":
            return "See upcoming events with real-time Live-Activities."
        default:
            return ""
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
        
        /// First check if permission is already granted with a non-blocking script
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
            /// Permission already granted
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
        
        /// If we reach here, we need to request permission
        /// Use a light-weight approach that won't freeze the UI
        DispatchQueue.global(qos: .userInitiated).async {
            let requestScript = NSAppleScript(source: """
                tell application "System Events"
                    -- Simple command that triggers permission dialog
                    set frontApp to name of first process
                end tell
            """)
            
            requestScript?.executeAndReturnError(nil)
            
            /// Check again after a short delay
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
        /// Find the next stage in the sequence
        if let currentIndex = IntroStage.allCases.firstIndex(of: currentStage),
           currentIndex < IntroStage.allCases.count - 1 {
            let nextStage = IntroStage.allCases[currentIndex + 1]
            
            /// Use spring animation for better bounce
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.3)) {
                currentStage = nextStage
                coordinator.updateIntroConfig(for: nextStage)
                triggerHapticFeedback()
            }
        } else {
            completeIntro()
        }
    }
    
    func completeIntro() {
        triggerHapticFeedback()
        
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}
