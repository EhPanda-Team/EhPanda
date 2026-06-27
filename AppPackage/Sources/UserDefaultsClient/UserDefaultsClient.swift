import Foundation
import ComposableArchitecture
import Utilities

public struct UserDefaultsClient: Sendable {
    public let setValue: @Sendable (Any, AppUserDefaults) -> Void
}

extension UserDefaultsClient {
    public static let live: Self = .init(
        setValue: { value, key in
            UserDefaults.standard.set(value, forKey: key.rawValue)
        }
    )

    public func getValue<T: Codable>(_ key: AppUserDefaults) -> T? {
        UserDefaultsUtil.value(forKey: key)
    }
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
        setValue: { _, _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        setValue: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
