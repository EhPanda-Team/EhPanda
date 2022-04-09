//
//  LoggerClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct LoggerClient {
    let info: (Any, Any?) -> Effect<Never, Never>
    let error: (Any, Any?) -> Effect<Never, Never>
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

// MARK: Test
#if DEBUG
import XCTestDynamicOverlay

extension LoggerClient {
    static let failing: Self = .init(
        info: { .failing("\(Self.self).info(\($0), \(String(describing: $1))) is unimplemented") },
        error: { .failing("\(Self.self).error(\($0), \(String(describing: $1))) is unimplemented") }
    )
}
#endif
extension LoggerClient {
    static let noop: Self = .init(
        info: { _, _ in .none },
        error: { _, _ in .none }
    )
}
