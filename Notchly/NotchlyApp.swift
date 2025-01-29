//
//  NotchlyApp.swift
//

import SwiftUI
import Combine

// MARK: - Application Entry Point

@main
struct NotchlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // 🔥 Delegate to manage app lifecycle

    var body: some Scene {
        // 🔥 Settings scene is currently empty
        Settings {
            EmptyView() // Placeholder for future settings UI
        }
    }
}

// MARK: - App Delegate

/// Handles the initialization and configuration of the Notchly app.
class AppDelegate: NSObject, NSApplicationDelegate {
    // Instance of the main Notchly controller
    private var notchly: Notchly<ContentView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Notchly with a sample content view
        notchly = Notchly {
            ContentView() // Use ContentView as the default notch content
        }

        // Show the Notchly window on the primary screen
        if let screen = NSScreen.main {
            notchly.initializeWindow(screen: screen) // Explicitly initialize the notch window
            notchly.isVisible = true // Ensure it's visible by default
        }
    }
}

// MARK: - Sample Content View

/// A placeholder content view for testing the hover state.
struct ContentView: View {
    var body: some View {
        VStack {
            // Dynamic label that changes based on hover state
            Text("HOWDYYYYYYYY")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
        }
        .frame(width: 200, height: 40) // Fixed frame size
        .background(Color.black.opacity(0.8)) // Background for the content
        .cornerRadius(20)
    }
}

// MARK: - Preview

#Preview {
    ContentView() // Preview the sample ContentView
}
