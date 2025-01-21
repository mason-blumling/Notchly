//
//  NotchlyApp.swift
//

import SwiftUI
import Combine

@main
struct NotchlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // No settings UI for now
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchly: Notchly<ContentView>!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Notchly with a test content view
        notchly = Notchly {
            ContentView()
        }

        // Show the notch on the primary screen
        if let screen = NSScreen.main {
            notchly.initializeWindow(screen: screen) // Explicitly initialize
            notchly.isVisible = true // Make sure it's visible by default
        }
    }
}

struct ContentView: View {
    @State private var isHovered = false

    var body: some View {
        VStack {
            Text(isHovered ? "Hovering!" : "Not Hovering")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(isHovered ? Color.green : Color.red)
                .cornerRadius(10)
        }
        .frame(width: 200, height: 40)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
