//
//  IntroPermissionsView.swift
//  Notchly
//
//  Created by Mason Blumling on 5/10/25.
//

import SwiftUI
import EventKit
import AppKit

struct IntroPermissionsView: View {
    // MARK: - Dependencies
    let delegate: IntroPermissionsDelegate
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            permissionsContent(geometry: geometry)
        }
    }
    
    // MARK: - Content
    
    private func permissionsContent(geometry: GeometryProxy) -> some View {
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
                    status: delegate.calendarPermissionStatus,
                    isChecking: delegate.isCheckingCalendar,
                    action: {
                        delegate.requestCalendarPermission()
                    }
                )
                
                permissionRow(
                    geometry: geometry,
                    icon: "music.note",
                    title: "Media Control",
                    description: "Control Apple Music & Spotify Media",
                    status: delegate.automationPermissionStatus,
                    isChecking: delegate.isCheckingAutomation,
                    action: {
                        delegate.requestAutomationPermission()
                    }
                )
            }
            .padding(.horizontal, geometry.size.width * 0.05)
            
            Spacer()
                
            HStack(spacing: geometry.size.width * 0.02) {
                if canSkipPermissions {
                    Button(action: { delegate.advanceStage() }) {
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
                .buttonStyle(IntroHoverButtonStyle(
                    foregroundColor: .black,
                    backgroundColor: continueButtonColor,
                    hoverColor: continueButtonColor.opacity(0.9)
                ))
                .disabled(isCheckingPermissions)
            }
            .padding(.bottom, geometry.size.height * 0.06)
        }
        .onAppear {
            delegate.updateIntroConfig(for: .permissions)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Permission Helpers
    
    private var allPermissionsGranted: Bool {
        delegate.calendarPermissionStatus == .granted && delegate.automationPermissionStatus == .granted
    }
    
    private var canSkipPermissions: Bool {
        delegate.calendarPermissionStatus == .granted
    }
    
    private var isCheckingPermissions: Bool {
        delegate.isCheckingCalendar || delegate.isCheckingAutomation
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
            delegate.advanceStage()
        } else {
            delegate.openSystemPreferences()
        }
    }
    
    // MARK: - UI Components
    
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
}
