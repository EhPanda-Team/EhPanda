//
//  CookiesClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct CookiesClient {
    let removeYay: () -> Effect<Never, Never>
    let ignoreOffensive: () -> Effect<Never, Never>
}

extension CookiesClient {
    static let live: Self = .init(
        removeYay: {
            .fireAndForget {
                CookiesUtil.removeYay()
            }
        },
        ignoreOffensive: {
            .fireAndForget {
                CookiesUtil.set(for: Defaults.URL.ehentai, key: "nw", value: "1")
                CookiesUtil.set(for: Defaults.URL.exhentai, key: "nw", value: "1")
            }
        }
    )
}
