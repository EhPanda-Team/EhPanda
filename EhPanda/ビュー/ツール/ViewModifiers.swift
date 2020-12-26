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
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .capsulePadding()
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .foregroundColor(configuration.isPressed ? Color.blue.opacity(0.5) : Color.blue)
            )
    }
}
