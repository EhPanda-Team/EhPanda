//
//  LoggerClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct LoggerClient {
    let info: (Any, Any?) -> EffectTask<Never>
    let error: (Any, Any?) -> EffectTask<Never>
}

extension LoggerClient {
    static let live: Self = .init(
        info: { message, context in
            .fireAndForget {
                Logger.info(message, context: context)
            }
        },
        error: { message, context in
            .fireAndForget {
                Logger.error(message, context: context)
            }
        }
    )
}

// MARK: API
enum LoggerClientKey: DependencyKey {
    static let liveValue = LoggerClient.live
    static let previewValue = LoggerClient.noop
    static let testValue = LoggerClient.unimplemented
}

extension DependencyValues {
    var loggerClient: LoggerClient {
        get { self[LoggerClientKey.self] }
        set { self[LoggerClientKey.self] = newValue }
    }
}

// MARK: Test
extension LoggerClient {
    static let noop: Self = .init(
        info: { _, _ in .none },
        error: { _, _ in .none }
    )

    static let unimplemented: Self = .init(
        info: XCTestDynamicOverlay.unimplemented("\(Self.self).info"),
        error: XCTestDynamicOverlay.unimplemented("\(Self.self).error")
    )
}
