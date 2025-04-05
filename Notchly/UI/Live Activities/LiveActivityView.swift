//
//  LiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

// MARK: - LiveActivityView: Base view with left and right slot content.
struct LiveActivityView<LeftContent: View, RightContent: View>: View {
    let configuration: NotchlyConfiguration
    let leftContent: () -> LeftContent
    let rightContent: () -> RightContent

    init(configuration: NotchlyConfiguration = .activity,
         @ViewBuilder leftContent: @escaping () -> LeftContent,
         @ViewBuilder rightContent: @escaping () -> RightContent) {
        self.configuration = configuration
        self.leftContent = leftContent
        self.rightContent = rightContent
    }

    var body: some View {
        NotchlyShape(
            bottomCornerRadius: configuration.bottomCornerRadius,
            topCornerRadius: configuration.topCornerRadius
        )
        .fill(NotchlyTheme.background)
        .frame(width: configuration.width, height: configuration.height)
        .shadow(color: NotchlyTheme.shadow, radius: configuration.shadowRadius)
        .overlay(
            HStack {
                leftContent()
                    .frame(width: 24, height: 24) // constrained album art
                Spacer()
                rightContent()
                    .frame(width: 30, height: 24) // constrained audio bars view
            }
            .padding(.horizontal, 14) // increased from 10 to 16
        )
    }
}

struct LiveActivityView_Previews: PreviewProvider {
    static var previews: some View {
        LiveActivityView(
            leftContent: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.red.opacity(0.5))
                    .overlay(Text("L").font(.caption))
            },
            rightContent: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.blue.opacity(0.5))
                    .overlay(Text("R").font(.caption))
            }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
