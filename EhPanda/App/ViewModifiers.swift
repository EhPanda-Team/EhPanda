//
//  ViewModifiers.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/06.
//

import SwiftUI
import Kingfisher

extension View {
    func modify<T, U>(
        if condition: Bool,
        then modifierT: T,
        else modifierU: U
    ) -> some View where
        T: ViewModifier,
        U: ViewModifier
    {
        Group {
            if condition {
                modifier(modifierT)
            } else {
                modifier(modifierU)
            }
        }
    }
}

extension KFImage {
    func defaultModifier(withRoundedCorners: Bool = true) -> KFImage {
        self
            .setProcessor(RoundCornerImageProcessor(cornerRadius: 5))
            .fade(duration: 0.25)
            .loadImmediately()
            .resizable()
    }
}
