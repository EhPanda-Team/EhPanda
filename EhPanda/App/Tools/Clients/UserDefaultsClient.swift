//
//  UserDefaultsClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import Foundation
import ComposableArchitecture

struct UserDefaultsClient {
    let setValue: (Any, AppUserDefaults) -> EffectTask<Never>
}

extension UserDefaultsClient {
    static let live: Self = .init(
        setValue: { value, key in
            .fireAndForget {
                UserDefaults.standard.set(value, forKey: key.rawValue)
            }
        }
    )

    func getValue<T: Codable>(_ key: AppUserDefaults) -> T? {
        UserDefaultsUtil.value(forKey: key)
    }
}

// MARK: API
enum UserDefaultsClientKey: DependencyKey {
    static let liveValue = UserDefaultsClient.live
    static let previewValue = UserDefaultsClient.noop
    static let testValue = UserDefaultsClient.unimplemented
}

extension DependencyValues {
    var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClientKey.self] }
        set { self[UserDefaultsClientKey.self] = newValue }
    }
}

// MARK: Test
extension UserDefaultsClient {
    static let noop: Self = .init(
        setValue: { _, _ in .none }
    )

    static let unimplemented: Self = .init(
        setValue: XCTestDynamicOverlay.unimplemented("\(Self.self).setValue")
    )
}
