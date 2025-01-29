//
//  TestContentView.swift
//  Notchly
//
//  Created by Mason Blumling on 1/21/25.
//

import SwiftUI

//struct Test1ContentView: View {
//    @State private var isHovering: Bool = false
//    @State private var bottomCornerRadius: CGFloat = 10
//    @State private var isExpanded: Bool = false
//
//    var body: some View {
//        NotchlyShape(bottomCornerRadius: bottomCornerRadius)
//            .fill(isExpanded ? Color.green.opacity(0.8) : isHovering ? Color.blue.opacity(0.8) : Color.gray.opacity(0.6))
//            .frame(width: isExpanded ? 400 : isHovering ? 300 : 200, height: 40)
//            .shadow(color: .black.opacity(0.2), radius: isExpanded ? 15 : isHovering ? 10 : 5)
//            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isExpanded)
//            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isHovering)
//            .onHover { hovering in
//                isHovering = hovering
//                bottomCornerRadius = hovering ? 20 : 10
//            }
//            .onTapGesture {
//                isExpanded.toggle() // Toggles between expanded and collapsed states
//            }
//            .padding(50)
//    }
//}
//
//#Preview {
//    Test1ContentView()
//}
