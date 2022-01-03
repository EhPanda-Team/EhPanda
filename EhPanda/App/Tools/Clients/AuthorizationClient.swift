//
//  AuthorizationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct AuthorizationClient {
    let passcodeNotSet: () -> Bool
    let localAuth: (String, (() -> Void)?) -> Effect<Never, Never>
}

extension AuthorizationClient {
    static let live: Self = .init(
        passcodeNotSet: {
            AuthorizationUtil.passcodeNotSet
        },
        localAuth: { reason, successAction in
            .fireAndForget {
                AuthorizationUtil.localAuth(reason: reason, successAction: successAction)
            }
        }
    )
}
