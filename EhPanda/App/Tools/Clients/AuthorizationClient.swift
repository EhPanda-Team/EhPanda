//
//  AuthorizationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Combine
import ComposableArchitecture

struct AuthorizationClient {
    let passcodeNotSet: () -> Bool
    let localAuth: (String) -> Effect<Bool, Never>
}

extension AuthorizationClient {
    static let live: Self = .init(
        passcodeNotSet: {
            AuthorizationUtil.passcodeNotSet
        },
        localAuth: { reason in
            Future { promise in
                AuthorizationUtil.localAuth(
                    reason: reason,
                    successAction: { promise(.success(true)) },
                    failureAction: { promise(.success(false)) },
                    passcodeNotSetAction: { promise(.success(false)) }
                )
            }
            .eraseToAnyPublisher()
            .eraseToEffect()
        }
    )
}
