//
//  LoggerClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct LoggerClient {
    let info: (Any, Any?) -> Void
    let error: (Any, Any?) -> Void
}

extension LoggerClient {
    static let live: Self = .init(
        info: { message, context in
            Logger.info(message, context: context)
        },
        error: { message, context in
            Logger.error(message, context: context)
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
        info: { _, _ in },
        error: { _, _ in }
    )

    static let unimplemented: Self = .init(
        info: XCTestDynamicOverlay.unimplemented("\(Self.self).info"),
        error: XCTestDynamicOverlay.unimplemented("\(Self.self).error")
    )
}
