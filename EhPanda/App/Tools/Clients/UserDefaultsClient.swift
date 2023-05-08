//
//  UserDefaultsClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import Foundation
import ComposableArchitecture

struct UserDefaultsClient {
    let setValue: (Any, AppUserDefaults) -> Effect<Never, Never>
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
