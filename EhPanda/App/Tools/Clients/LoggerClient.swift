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
