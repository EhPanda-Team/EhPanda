//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI

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
}

struct CapsuleButtonStyle: ButtonStyle {
    let color: Color
    let cornerRadius: CGFloat
    
    init(_ color: Color = .blue, _ cornerRadius: CGFloat = 30) {
        self.color = color
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .foregroundColor(configuration.isPressed ? color.opacity(0.5) : color)
            )
    }
}
