//
//  NotchlyLiveActivityView.swift
//  Notchly
//
//  Created by Mason Blumling on 4/4/25.
//

import SwiftUI

/// A reusable container for rendering live activity content inside the notch shape.
/// Places content in left/right slots using a flexible layout driven by Notchly's transition state.
struct LiveActivityView<LeftContent: View, RightContent: View>: View {
    
    private let leftContent: () -> LeftContent
    private let rightContent: () -> RightContent

    @ObservedObject private var coord = NotchlyViewModel.shared

    // MARK: - Init

    init(
        @ViewBuilder leftContent: @escaping () -> LeftContent,
        @ViewBuilder rightContent: @escaping () -> RightContent
    ) {
        self.leftContent = leftContent
        self.rightContent = rightContent
    }

    // MARK: - View

    var body: some View {
        let config = coord.configuration

        NotchlyShapeView(
            configuration: config,
            state: coord.state,
            animation: coord.animation
        ) { layout in
            ZStack {
                /// Left-aligned slot (typically an icon or logo)
                HStack {
                    leftContent()
                        .frame(width: 24, height: 24)
                        .padding(.leading, 15)
                    Spacer()
                }

                /// Right-aligned slot (typically text or animation)
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

// MARK: - Preview

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
