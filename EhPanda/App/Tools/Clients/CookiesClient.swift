//
//  CookiesClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import Foundation
import ComposableArchitecture

struct CookiesClient {
    let didLogin: () -> Bool
    let shouldFetchIgneous: () -> Bool
    let clearAll: () -> Effect<Never, Never>
    let removeYay: () -> Effect<Never, Never>
    let ignoreOffensive: () -> Effect<Never, Never>
    let setCookie: (URL, String, String) -> Effect<Never, Never>
    let getCookie: (URL, String) -> CookieValue
}

extension CookiesClient {
    static let live: Self = .init(
        didLogin: {
            CookiesUtil.didLogin
        },
        shouldFetchIgneous: {
            CookiesUtil.shouldFetchIgneous
        },
        clearAll: {
            .fireAndForget {
                CookiesUtil.clearAll()
            }
        },
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
        },
        setCookie: { url, key, value in
            .fireAndForget {
                CookiesUtil.set(for: url, key: key, value: value)
            }
        },
        getCookie: { url, key in
            CookiesUtil.get(for: url, key: key)
        }
    )
}
