//
//  IntroView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/4/25.
//

import SwiftUI
import AppKit
import EventKit
import AVFoundation

/// A complete intro experience for first-time users with smoothly coordinated animations.
struct IntroView: View {
    // MARK: - State & Environment

    @ObservedObject private var coordinator = NotchlyViewModel.shared
    @State private var currentStage: IntroStage = .logoDrawing
    @State private var showContent = false
    @State internal var calendarPermissionStatus: PermissionStatus = .unknown
    @State internal var automationPermissionStatus: PermissionStatus = .unknown
    @State internal var isCheckingCalendar = false
    @State internal var isCheckingAutomation = false
    @State private var playSound = false
    @State private var logoAnimationState: LogoAnimationState = .initial

    /// Completion handler triggered when the intro finishes
    var onComplete: () -> Void

    // MARK: - Types

    /// Enum tracking internal logo animation state
    enum LogoAnimationState: Equatable {
        case initial      /// Before animation starts
        case drawingN     /// Drawing the "N"
        case showRainbow  /// Morph to rainbow coloring
        case showFullName /// Reveal "otchly" text
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
                /// Main logo animation (always mounted)
                IntroLogoAnimation(state: $logoAnimationState)
                    .id("persistentLogoAnimation")
                    .opacity(showLogoAnimation ? 1.0 : 0.0)
                    .zIndex(10)
                    .onChange(of: logoAnimationState) { _, newState in
                        triggerStateHaptics(for: newState)
                    }

                /// Screen-specific overlay content
                switch currentStage {
                case .logoDrawing, .logoRainbow, .fullName:
                    Color.clear
                case .welcome:
                    IntroWelcomeView(delegate: self)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .permissions:
                    IntroPermissionsView(delegate: self)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                case .tips:
                    IntroTipsView(delegate: self)
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
    func triggerHapticFeedback() {
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

    // MARK: - Animation Sequence
    
    private func startIntroSequence() {
        /// Set initial stage and config
        currentStage = .logoDrawing
        coordinator.updateIntroConfig(for: .logoDrawing)
        logoAnimationState = .initial
        
        /// Trigger drawing animation with a tiny delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
                logoAnimationState = .drawingN
            }
        }
        
        /// After drawing completes, show rainbow effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut) {
                currentStage = .logoRainbow
                coordinator.updateIntroConfig(for: .logoRainbow)
                logoAnimationState = .showRainbow
            }
            
            /// After rainbow animates, prepare for full name + notch expansion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                /// CRITICAL: First expand the notch, then wait for animation to settle
                withAnimation(NotchlyAnimations.notchExpansion) {
                    coordinator.updateIntroConfig(for: .fullName)
                    currentStage = .fullName
                }
                
                /// After notch expansion completes, reveal text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    logoAnimationState = .showFullName
                }
                
                /// After allowing time for animations, move to welcome
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
    
    // MARK: - Sequence Control
    
    func advanceStage() {
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

// MARK: - IntroViewDelegate Implementation
extension IntroView: IntroViewDelegate {
    func updateIntroConfig(for stage: IntroStage) {
        coordinator.updateIntroConfig(for: stage)
    }
}

// MARK: - IntroPermissionsDelegate Implementation
extension IntroView: IntroPermissionsDelegate {
    func requestCalendarPermission() {
        isCheckingCalendar = true
        
        AppEnvironment.shared.calendarManager.requestAccess { granted in
            DispatchQueue.main.async {
                self.isCheckingCalendar = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.calendarPermissionStatus = granted ? .granted : .denied
                }
                
                /// No auto-advancement - user must click continue
            }
        }
    }
    
    func requestAutomationPermission() {
        isCheckingAutomation = true
        
        /// First check if permission is already granted
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
                self.isCheckingAutomation = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.automationPermissionStatus = .granted
                }
            }
            return
        }
        
        /// If we reach here, we need to request permission
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
                
                self.isCheckingAutomation = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.automationPermissionStatus = granted ? .granted : .denied
                }
            }
        }
    }
    
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}
