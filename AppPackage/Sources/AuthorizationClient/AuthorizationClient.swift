import LocalAuthentication
import ComposableArchitecture

public struct AuthorizationClient: Sendable {
    public let passcodeNotSet: @Sendable () -> Bool
    public let localAuthroize: @Sendable (String) async -> Bool
}

extension AuthorizationClient {
    public static let live: Self = .init(
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
public enum AuthorizationClientKey: DependencyKey {
    public static let liveValue = AuthorizationClient.live
    public static let previewValue = AuthorizationClient.noop
    public static let testValue = AuthorizationClient.unimplemented
}

extension DependencyValues {
    public var authorizationClient: AuthorizationClient {
        get { self[AuthorizationClientKey.self] }
        set { self[AuthorizationClientKey.self] = newValue }
    }
}

// MARK: Test
extension AuthorizationClient {
    public static let noop: Self = .init(
        passcodeNotSet: { false },
        localAuthroize: { _ in false }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        passcodeNotSet: IssueReporting.unimplemented(placeholder: placeholder()),
        localAuthroize: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
