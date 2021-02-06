//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI

struct StackNavStyle: ViewModifier {
    func body(content: Content) -> some View { content.navigationViewStyle(StackNavigationViewStyle()) }
}

struct DefaultNavStyle: ViewModifier {
    func body(content: Content) -> some View { content.navigationViewStyle(DefaultNavigationViewStyle()) }
}

extension View {
    public func modify<T, U>(if condition: Bool, then modifierT: T, else modifierU: U) -> some View where T: ViewModifier, U: ViewModifier {
        Group {
            if condition {
                modifier(modifierT)
            } else {
                modifier(modifierU)
            }
        }
    }
}
