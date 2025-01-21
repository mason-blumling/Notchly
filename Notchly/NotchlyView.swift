import SwiftUI

struct NotchView<Content>: View where Content: View {
    @ObservedObject var notchly: Notchly<Content>

    private let defaultWidth: CGFloat = 200
    private let defaultHeight: CGFloat = 40
    private let expandedWidth: CGFloat = 500
    private let expandedHeight: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Main Notch Shape
                    NotchShape(
                        bottomCornerRadius: notchly.isMouseInside ? 10 : 10,
                        topCornerRadius: notchly.isMouseInside ? 10 : 10
                    )
                    .fill(Color.black)
                    .frame(
                        width: notchly.isMouseInside ? notchly.notchWidth : defaultWidth,
                        height: notchly.isMouseInside ? notchly.notchHeight : defaultHeight
                    )
                    .animation(notchly.animation, value: notchly.isMouseInside)
                    .shadow(color: .black.opacity(0.5), radius: notchly.isMouseInside ? 10 : 0)

                    // Hover Detection Area
                    Color.clear
                        .contentShape(Rectangle()) // Ensures hover area matches the frame
                        .frame(
                            width: notchly.isMouseInside ? notchly.notchWidth : defaultWidth,
                            height: notchly.isMouseInside ? notchly.notchHeight : defaultHeight
                        )
                        .onHover { hovering in
                            DispatchQueue.main.async {
                                notchly.isMouseInside = hovering
                                notchly.handleHover(expand: hovering)
                            }
                        }
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top) // Align everything to the top
    }
}
