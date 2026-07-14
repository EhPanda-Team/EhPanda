import Foundation
import ComposableArchitecture
import AppTools

public struct UserDefaultsClient: Sendable {
    public let getValue: @Sendable (AppUserDefaults) -> Int?
    public let setValue: @Sendable (Any, AppUserDefaults) -> Void
}

extension UserDefaultsClient {
    public static let live: Self = .init(
        getValue: { key in
            UserDefaults.standard.value(forKey: key.rawValue) as? Int
        },
        setValue: { value, key in
            UserDefaults.standard.set(value, forKey: key.rawValue)
        }
    )
}

// MARK: API
public enum UserDefaultsClientKey: DependencyKey {
    public static let liveValue = UserDefaultsClient.live
    public static let previewValue = UserDefaultsClient.noop
    public static let testValue = UserDefaultsClient.unimplemented
}

extension DependencyValues {
    public var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClientKey.self] }
        set { self[UserDefaultsClientKey.self] = newValue }
    }
}

// MARK: Test
extension UserDefaultsClient {
    public static let noop: Self = .init(
        getValue: { _ in nil },
        setValue: { _, _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        getValue: IssueReporting.unimplemented(placeholder: placeholder()),
        setValue: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
