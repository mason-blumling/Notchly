//
//  NotchlyConfiguration.swift
//  Notchly
//
//  Created by Mason Blumling on 1/28/25.
//

import Foundation
import SwiftUI

/// Defines the notch size, corner radius, and shadow appearance.
public struct NotchlyConfiguration: Equatable {
    let width: CGFloat
    let height: CGFloat
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let shadowRadius: CGFloat

    /// ✅ Predefined Notch Configurations
    public static let `default` = NotchlyConfiguration(
        width: 199,
        height: 31.75,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    public static let activity = NotchlyConfiguration(
        width: 280,
        height: 35.75,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    public static let small = NotchlyConfiguration(
        width: 350,
        height: 150,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    public static let medium = NotchlyConfiguration(
        width: 400,
        height: 180,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    public static let large = NotchlyConfiguration(
        width: 750,
        height: 180,
        topCornerRadius: 20,
        bottomCornerRadius: 20,
        shadowRadius: 0
    )
}

/// Preview different Notchly configurations.
struct NotchConfigurationsPreview: View {
    let configurations: [(String, NotchlyConfiguration)] = [
        ("Default", .default),
        ("Activity", .activity),
        ("Small", .small),
        ("Medium", .medium),
        ("Large", .large)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(configurations, id: \.0) { name, config in
                    VStack {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(NotchlyTheme.primaryText)

                        NotchlyShape(
                            bottomCornerRadius: config.bottomCornerRadius,
                            topCornerRadius: config.topCornerRadius
                        )
                        .fill(NotchlyTheme.background)
                        .frame(width: config.width, height: config.height)
                        .shadow(color: NotchlyTheme.shadow, radius: config.shadowRadius)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.2)))
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all))
    }
}

#Preview {
    NotchConfigurationsPreview()
}
