//
//  UserDefaultsClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct UserDefaultsClient {
    let getString: (String) -> String?
    let setString: (String, String) -> Effect<Never, Never>
}

extension UserDefaultsClient {
    static let live: Self = .init(
        getString: { key in
            UserDefaults.standard.string(forKey: key)
        },
        setString: { value, key in
            .fireAndForget {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    )
}
