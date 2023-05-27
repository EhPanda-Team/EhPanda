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
    let localAuthroize: (String) -> EffectTask<Bool>
}

extension AuthorizationClient {
    static let live: Self = .init(
        passcodeNotSet: {
            var error: NSError?
            return !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        },
        localAuthroize: { reason in
            Future { promise in
                let context = LAContext()
                var error: NSError?

                if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { isSuccess, _ in
                        promise(.success(isSuccess))
                    }
                } else {
                    promise(.success(false))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
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
        localAuthroize: { _ in .none }
    )

    static let unimplemented: Self = .init(
        passcodeNotSet: XCTestDynamicOverlay.unimplemented("\(Self.self).passcodeNotSet"),
        localAuthroize: XCTestDynamicOverlay.unimplemented("\(Self.self).localAuthroize")
    )
}
