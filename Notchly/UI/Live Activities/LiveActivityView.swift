//
//  LiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

/// LiveActivityView: Base view with left and right slot content.
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
        .fill(.clear)
        .frame(width: configuration.width, height: configuration.height)
        .shadow(color: NotchlyTheme.shadow, radius: configuration.shadowRadius)
        .overlay(
            ZStack {
                HStack {
                    leftContent()
                        .frame(width: 24, height: 24)
                        .padding(.leading, 20)
                    Spacer()
                }
                HStack {
                    Spacer()
                    rightContent()
                        .frame(width: 30, height: 24)
                        .padding(.trailing, 12)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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
