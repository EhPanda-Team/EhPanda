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
    let fulfillAnotherHostField: () -> Effect<Never, Never>
    let setCookie: (URL, String, String) -> Effect<Never, Never>
    let getCookie: (URL, String) -> CookieValue
}

extension CookiesClient {
    static let live: Self = .init(
        didLogin: {
            CookiesUtil.didLogin
        },
        shouldFetchIgneous: {
            let url = Defaults.URL.exhentai
            return !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbMemberId).rawValue.isEmpty
            && !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbPassHash).rawValue.isEmpty
            && CookiesUtil.get(for: url, key: Defaults.Cookie.igneous).rawValue.isEmpty
        },
        clearAll: {
            .fireAndForget {
                CookiesUtil.clearAll()
            }
        },
        removeYay: {
            .fireAndForget {
                CookiesUtil.remove(for: Defaults.URL.exhentai, key: Defaults.Cookie.yay)
            }
        },
        ignoreOffensive: {
            .fireAndForget {
                CookiesUtil.set(for: Defaults.URL.ehentai, key: Defaults.Cookie.ignoreOffensive, value: "1")
                CookiesUtil.set(for: Defaults.URL.exhentai, key: Defaults.Cookie.ignoreOffensive, value: "1")
            }
        },
        fulfillAnotherHostField: {
            .fireAndForget {
                let ehURL = Defaults.URL.ehentai
                let exURL = Defaults.URL.exhentai
                let memberIdKey = Defaults.Cookie.ipbMemberId
                let passHashKey = Defaults.Cookie.ipbPassHash
                let ehMemberId = CookiesUtil.get(for: ehURL, key: memberIdKey).rawValue
                let ehPassHash = CookiesUtil.get(for: ehURL, key: passHashKey).rawValue
                let exMemberId = CookiesUtil.get(for: exURL, key: memberIdKey).rawValue
                let exPassHash = CookiesUtil.get(for: exURL, key: passHashKey).rawValue

                if !ehMemberId.isEmpty && !ehPassHash.isEmpty && (exMemberId.isEmpty || exPassHash.isEmpty) {
                    CookiesUtil.set(for: exURL, key: memberIdKey, value: ehMemberId)
                    CookiesUtil.set(for: exURL, key: passHashKey, value: ehPassHash)
                } else if !exMemberId.isEmpty && !exPassHash.isEmpty && (ehMemberId.isEmpty || ehPassHash.isEmpty) {
                    CookiesUtil.set(for: ehURL, key: memberIdKey, value: exMemberId)
                    CookiesUtil.set(for: ehURL, key: passHashKey, value: exPassHash)
                }
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
