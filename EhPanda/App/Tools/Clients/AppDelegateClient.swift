//
//  AppDelegateClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct AppDelegateClient {
    let setOrientationMask: (UIInterfaceOrientationMask) -> Effect<Never, Never>
}

extension AppDelegateClient {
    static let live: Self = .init(
        setOrientationMask: { mask in
            .fireAndForget {
                AppDelegate.orientationMask = mask
            }
        }
    )

    func setPortraitOrientationMask() -> Effect<Never, Never> {
        setOrientationMask([.portrait, .portraitUpsideDown])
    }
}
