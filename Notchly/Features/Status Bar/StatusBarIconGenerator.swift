//
//  StatusBarIconGenerator.swift
//  Notchly
//
//  Created by Mason Blumling on 5/6/25.
//

import SwiftUI

/// Generates the StatusBarIcon asset for use in the menu bar
struct StatusBarIconGenerator: View {
    var body: some View {
        ZStack {
            // Thicker-looking stroke beneath
            NotchlyLogoShape()
                .stroke(Color.primary, lineWidth: 0.5)
                .frame(width: 18, height: 18)

            // Filled logo on top
            NotchlyLogoShape()
                .fill(Color.primary)
                .frame(width: 18, height: 18)
        }
        .padding(1)
    }
}

/// Preview to visualize the icon
struct StatusBarIconGenerator_Previews: PreviewProvider {
    static var previews: some View {
        StatusBarIconGenerator()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color(.windowBackgroundColor))
            .environment(\.colorScheme, .light)
            
        StatusBarIconGenerator()
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color(.windowBackgroundColor))
            .environment(\.colorScheme, .dark)
    }
}

/// Helper to generate the icon asset
extension StatusBarIconGenerator {
    /// Helper for creating and using the StatusBarIcon
    static func createGeneratedIcon() -> NSImage? {
        let generator = StatusBarIconGenerator()
        return generator
            .asImage(size: CGSize(width: 18, height: 18))
    }
}

extension View {
    /// Converts any SwiftUI view into an `NSImage`
    func asImage(size: CGSize, scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0) -> NSImage? {
        let controller = NSHostingController(rootView: self)
        let view = controller.view
        view.frame = CGRect(origin: .zero, size: size)

        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        rep?.size = size
        view.cacheDisplay(in: view.bounds, to: rep!)

        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(rep!)
        nsImage.isTemplate = true
        return nsImage
    }
}
