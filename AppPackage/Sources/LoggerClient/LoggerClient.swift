import ComposableArchitecture
import AppModels

public struct LoggerClient: Sendable {
    public let info: @Sendable (Any, Any?) -> Void
    public let error: @Sendable (Any, Any?) -> Void
}

extension LoggerClient {
    public static let live: Self = .init(
        info: { message, context in
            Logger.info(message, context: context)
        },
        error: { message, context in
            Logger.error(message, context: context)
        }
    )
}

// MARK: API
public enum LoggerClientKey: DependencyKey {
    public static let liveValue = LoggerClient.live
    public static let previewValue = LoggerClient.noop
    public static let testValue = LoggerClient.unimplemented
}

extension DependencyValues {
    public var loggerClient: LoggerClient {
        get { self[LoggerClientKey.self] }
        set { self[LoggerClientKey.self] = newValue }
    }
}

// MARK: Test
extension LoggerClient {
    public static let noop: Self = .init(
        info: { _, _ in },
        error: { _, _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        info: IssueReporting.unimplemented(placeholder: placeholder()),
        error: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
