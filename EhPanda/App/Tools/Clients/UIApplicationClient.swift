//
//  UIApplicationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import ComposableArchitecture

struct UIApplicationClient {
    let hideKeyboard: () -> Effect<Never, Never>
}

extension UIApplicationClient {
    static let live: Self = .init(
        hideKeyboard: {
            .fireAndForget {
                UIApplication.shared.endEditing()
            }
        }
    )
}
