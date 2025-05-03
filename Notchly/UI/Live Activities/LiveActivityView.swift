//
//  LiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

/// A reusable layout for displaying live content inside the notch shape.
/// Reads its sizing from the central NotchlyTransitionCoordinator for consistency.
struct LiveActivityView<LeftContent: View, RightContent: View>: View {
    private let leftContent: () -> LeftContent
    private let rightContent: () -> RightContent

    @ObservedObject private var coord = NotchlyTransitionCoordinator.shared

    init(
        @ViewBuilder leftContent: @escaping () -> LeftContent,
        @ViewBuilder rightContent: @escaping () -> RightContent
    ) {
        self.leftContent = leftContent
        self.rightContent = rightContent
    }

    var body: some View {
        let config = coord.configuration

        NotchlyShapeContainer(
            configuration: config,
            state: coord.state,
            animation: coord.animation
        ) { layout in
            ZStack {
                // Left slot
                HStack {
                    leftContent()
                        .frame(width: 24, height: 24)
                        .padding(.leading, 20)
                    Spacer()
                }

                // Right slot
                HStack {
                    Spacer()
                    rightContent()
                        .frame(width: 30, height: 24)
                        .padding(.trailing, 15)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
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
