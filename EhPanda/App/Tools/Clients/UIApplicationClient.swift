//
//  UIApplicationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import ComposableArchitecture

struct UIApplicationClient {
    let openURL: (URL) -> Effect<Never, Never>
    let hideKeyboard: () -> Effect<Never, Never>
}

extension UIApplicationClient {
    static let live: Self = .init(
        openURL: { url in
            .fireAndForget {
                UIApplication.shared.open(url, options: [:])
            }
        },
        hideKeyboard: {
            .fireAndForget {
                UIApplication.shared.endEditing()
            }
        }
    )
    func openSettings() -> Effect<Never, Never> {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return openURL(url)
        }
        return .none
    }
}
