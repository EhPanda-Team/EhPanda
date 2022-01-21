//
//  UserDefaultsClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct UserDefaultsClient {
    let setValue: (Any, AppUserDefaults) -> Effect<Never, Never>
}

extension UserDefaultsClient {
    static let live: Self = .init(
        setValue: { value, key in
            .fireAndForget {
                UserDefaultsUtil.set(value: value, forKey: key)
            }
        }
    )

    func getValue<T: Codable>(_ key: AppUserDefaults) -> T? {
        UserDefaultsUtil.value(forKey: key)
    }
}
