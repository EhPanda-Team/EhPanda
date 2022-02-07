//
//  AppDelegateClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct AppDelegateClient {
    let setOrientation: (UIInterfaceOrientation) -> Effect<Never, Never>
    let setOrientationMask: (UIInterfaceOrientationMask) -> Effect<Never, Never>
}

extension AppDelegateClient {
    static let live: Self = .init(
        setOrientation: { orientation in
            .fireAndForget {
                UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }
        },
        setOrientationMask: { mask in
            .fireAndForget {
                AppDelegate.orientationMask = mask
            }
        }
    )

    func setPortraitOrientation() -> Effect<Never, Never> {
        setOrientation(.portrait)
    }
    func setAllOrientationMask() -> Effect<Never, Never> {
        setOrientationMask([.all])
    }
    func setPortraitOrientationMask() -> Effect<Never, Never> {
        setOrientationMask([.portrait, .portraitUpsideDown])
    }
}
