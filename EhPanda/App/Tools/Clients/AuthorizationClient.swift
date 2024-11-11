//
//  AuthorizationClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Combine
import LocalAuthentication
import ComposableArchitecture

struct AuthorizationClient {
    let passcodeNotSet: () -> Bool
    let localAuthroize: (String) async -> Bool
}

extension AuthorizationClient {
    static let live: Self = .init(
        passcodeNotSet: {
            var error: NSError?
            return !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        },
        localAuthroize: { reason in
            await withCheckedContinuation { continuation in
                let context = LAContext()
                var error: NSError?

                if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { isSuccess, _ in
                        continuation.resume(returning: isSuccess)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    )
}

// MARK: API
enum AuthorizationClientKey: DependencyKey {
    static let liveValue = AuthorizationClient.live
    static let previewValue = AuthorizationClient.noop
    static let testValue = AuthorizationClient.unimplemented
}

extension DependencyValues {
    var authorizationClient: AuthorizationClient {
        get { self[AuthorizationClientKey.self] }
        set { self[AuthorizationClientKey.self] = newValue }
    }
}

// MARK: Test
extension AuthorizationClient {
    static let noop: Self = .init(
        passcodeNotSet: { false },
        localAuthroize: { _ in false }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        passcodeNotSet: IssueReporting.unimplemented(placeholder: placeholder()),
        localAuthroize: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
