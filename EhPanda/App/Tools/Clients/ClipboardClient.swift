//
//  ClipboardClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import ComposableArchitecture

struct ClipboardClient {
    let save: (String) -> Effect<Never, Never>
}

extension ClipboardClient {
    static let live: Self = .init(
        save: { value in
            .fireAndForget {
                ClipboardUtil.save(value: value)
            }
        }
    )
}
