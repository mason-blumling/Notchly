//
//  NotchConfigurations.swift
//  Notchly
//
//  Created by Mason Blumling on 1/28/25.
//

import Foundation
import SwiftUI

public struct NotchlyConfiguration {
    let width: CGFloat
    let height: CGFloat
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let shadowRadius: CGFloat
}

public struct NotchPresets {
    /// Default (collapsed) size of the notch. (Measured to the same size as MBP 16' Notch)
    static let defaultNotch = NotchlyConfiguration(
        width: 199,
        height: 31.75,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )
    
    static let liveActivity = NotchlyConfiguration(
        width: 280,
        height: 31.75,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )
    
    static let small = NotchlyConfiguration(
        width: 350,
        height: 150,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    static let medium = NotchlyConfiguration(
        width: 400,
        height: 175,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )

    static let large = NotchlyConfiguration(
        width: 500,
        height: 250,
        topCornerRadius: 9,
        bottomCornerRadius: 9,
        shadowRadius: 0
    )
}

struct NotchConfigurationsPreview: View {
    let configurations: [(String, NotchlyConfiguration)] = [
        ("Default Notch", NotchPresets.defaultNotch),
        ("Live Activity", NotchPresets.liveActivity),
        ("Small", NotchPresets.small),
        ("Medium", NotchPresets.medium),
        ("Large", NotchPresets.large)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(configurations, id: \.0) { name, config in
                    VStack {
                        Text(name)
                            .font(.headline)
                            .foregroundColor(.white)

                        NotchlyShape(
                            bottomCornerRadius: config.bottomCornerRadius,
                            topCornerRadius: config.topCornerRadius
                        )
                        .fill(Color.black)
                        .frame(width: config.width, height: config.height)
                        .shadow(color: .black.opacity(0.5), radius: config.shadowRadius)
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
