//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI

struct ButtonTapEffect: ViewModifier {
    @State var isPressed = false
    let backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(pressing: { (_) in
                isPressed.toggle()
            }, perform: {})
            .background(
                RoundedRectangle(cornerRadius: .infinity)
                    .foregroundColor(isPressed ? backgroundColor.opacity(0.5) : backgroundColor)
            )
    }
}

struct CapsuleStylePadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.init(top: 5, leading: 14, bottom: 5, trailing: 14))
    }
}

extension View {
    func capsulePadding() -> some View {
        self.modifier(CapsuleStylePadding())
    }
    
    func withTapEffect(backgroundColor: Color) -> some View {
        self.modifier(ButtonTapEffect(backgroundColor: backgroundColor))
    }
}
