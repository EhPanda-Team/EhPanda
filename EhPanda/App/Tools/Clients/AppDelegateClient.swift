//
//  AppDelegateClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct AppDelegateClient {
    let setOrientation: (UIInterfaceOrientationMask) -> Effect<Never>
    let setOrientationMask: (UIInterfaceOrientationMask) -> Effect<Never>
}

extension AppDelegateClient {
    static let live: Self = .init(
        setOrientation: { mask in
            .fireAndForget {
                DeviceUtil.keyWindow?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            }
        },
        setOrientationMask: { mask in
            .fireAndForget {
                AppDelegate.orientationMask = mask
            }
        }
    )

    func setPortraitOrientation() -> Effect<Never> {
        setOrientation(.portrait)
    }
    func setAllOrientationMask() -> Effect<Never> {
        setOrientationMask([.all])
    }
    func setPortraitOrientationMask() -> Effect<Never> {
        setOrientationMask([.portrait, .portraitUpsideDown])
    }
}

// MARK: API
enum AppDelegateClientKey: DependencyKey {
    static let liveValue = AppDelegateClient.live
    static let previewValue = AppDelegateClient.noop
    static let testValue = AppDelegateClient.unimplemented
}

extension DependencyValues {
    var appDelegateClient: AppDelegateClient {
        get { self[AppDelegateClientKey.self] }
        set { self[AppDelegateClientKey.self] = newValue }
    }
}

// MARK: Test
extension AppDelegateClient {
    static let noop: Self = .init(
        setOrientation: { _ in .none },
        setOrientationMask: { _ in .none }
    )

    static let unimplemented: Self = .init(
        setOrientation: XCTestDynamicOverlay.unimplemented("\(Self.self).setOrientation"),
        setOrientationMask: XCTestDynamicOverlay.unimplemented("\(Self.self).setOrientationMask")
    )
}
