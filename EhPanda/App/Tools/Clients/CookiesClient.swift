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
    let clearAll: () -> Effect<Never, Never>
    let setCookie: (URL, String, String) -> Effect<Never, Never>
    let getCookie: (URL, String) -> CookieValue
    let removeCookie: (URL, String) -> Effect<Never, Never>
}

extension CookiesClient {
    static let live: Self = .init(
        didLogin: {
            CookiesUtil.didLogin
        },
        clearAll: {
            .fireAndForget {
                CookiesUtil.clearAll()
            }
        },
        setCookie: { url, key, value in
            .fireAndForget {
                CookiesUtil.set(for: url, key: key, value: value)
            }
        },
        getCookie: { url, key in
            CookiesUtil.get(for: url, key: key)
        },
        removeCookie: { url, key in
            .fireAndForget {
                CookiesUtil.remove(for: url, key: key)
            }
        }
    )

    var apiuid: String {
        getCookie(Defaults.URL.host, Defaults.Cookie.ipbMemberId).rawValue
    }
    var shouldFetchIgneous: Bool {
        let url = Defaults.URL.exhentai
        return !getCookie(url, Defaults.Cookie.ipbMemberId).rawValue.isEmpty
        && !getCookie(url, Defaults.Cookie.ipbPassHash).rawValue.isEmpty
        && getCookie(url, Defaults.Cookie.igneous).rawValue.isEmpty
    }
    func removeYay() -> Effect<Never, Never> {
        removeCookie(Defaults.URL.exhentai, Defaults.Cookie.yay)
    }
    func ignoreOffensive() -> Effect<Never, Never> {
        .merge(
            setCookie(Defaults.URL.ehentai, Defaults.Cookie.ignoreOffensive, "1"),
            setCookie(Defaults.URL.exhentai, Defaults.Cookie.ignoreOffensive, "1")
        )
    }
    func fulfillAnotherHostField() -> Effect<Never, Never> {
        let ehURL = Defaults.URL.ehentai
        let exURL = Defaults.URL.exhentai
        let memberIdKey = Defaults.Cookie.ipbMemberId
        let passHashKey = Defaults.Cookie.ipbPassHash
        let ehMemberId = CookiesUtil.get(for: ehURL, key: memberIdKey).rawValue
        let ehPassHash = CookiesUtil.get(for: ehURL, key: passHashKey).rawValue
        let exMemberId = CookiesUtil.get(for: exURL, key: memberIdKey).rawValue
        let exPassHash = CookiesUtil.get(for: exURL, key: passHashKey).rawValue

        if !ehMemberId.isEmpty && !ehPassHash.isEmpty && (exMemberId.isEmpty || exPassHash.isEmpty) {
            return .merge(
                setCookie(exURL, memberIdKey, ehMemberId),
                setCookie(exURL, passHashKey, ehPassHash)
            )
        } else if !exMemberId.isEmpty && !exPassHash.isEmpty && (ehMemberId.isEmpty || ehPassHash.isEmpty) {
            return .merge(
                setCookie(ehURL, memberIdKey, exMemberId),
                setCookie(ehURL, passHashKey, exPassHash)
            )
        } else {
            return .none
        }
    }
}
