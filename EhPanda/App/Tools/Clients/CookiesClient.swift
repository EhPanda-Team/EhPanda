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
    let isSameAccount: () -> Bool
    let clearAll: () -> Effect<Never, Never>
    let setCookies: (HTTPURLResponse) -> Effect<Never, Never>
    let setCookie: (URL, String, String) -> Effect<Never, Never>
    let getCookie: (URL, String) -> CookieValue
    let removeCookie: (URL, String) -> Effect<Never, Never>
}

extension CookiesClient {
    static let live: Self = .init(
        didLogin: {
            CookiesUtil.didLogin
        },
        isSameAccount: {
            CookiesUtil.isSameAccount
        },
        clearAll: {
            .fireAndForget {
                CookiesUtil.clearAll()
            }
        },
        setCookies: { response in
            .fireAndForget {
                CookiesUtil.setCookies(for: response)
            }
        },
        setCookie: { url, key, value in
            .fireAndForget {
                if CookiesUtil.checkExistence(for: url, key: key) {
                    CookiesUtil.edit(for: url, key: key, value: value)
                } else {
                    CookiesUtil.set(for: url, key: key, value: value)
                }
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
        let ehMemberId = getCookie(ehURL, memberIdKey).rawValue
        let ehPassHash = getCookie(ehURL, passHashKey).rawValue
        let exMemberId = getCookie(exURL, memberIdKey).rawValue
        let exPassHash = getCookie(exURL, passHashKey).rawValue

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
    func loadCookiesState(host: GalleryHost) -> CookiesState {
        let igneousKey = Defaults.Cookie.igneous
        let memberIDKey = Defaults.Cookie.ipbMemberId
        let passHashKey = Defaults.Cookie.ipbPassHash
        let igneous = getCookie(host.url, igneousKey)
        let memberID = getCookie(host.url, memberIDKey)
        let passHash = getCookie(host.url, passHashKey)
        return .init(
            host: host,
            igneous: .init(key: igneousKey, value: igneous, editingText: igneous.rawValue),
            memberID: .init(key: memberIDKey, value: memberID, editingText: memberID.rawValue),
            passHash: .init(key: passHashKey, value: passHash, editingText: passHash.rawValue)
        )
    }
    func setCookies(state: CookiesState) -> Effect<Never, Never> {
        let effects: [Effect<Never, Never>] = state.allCases.map { subState in
            setCookie(state.host.url, subState.key, subState.editingText)
        }
        return effects.isEmpty ? .none : .merge(effects)
    }
    func getCookiesDescription(host: GalleryHost) -> String {
        var dictionary = [String: String]()
        [Defaults.Cookie.igneous, Defaults.Cookie.ipbMemberId, Defaults.Cookie.ipbPassHash].forEach { key in
            let cookieValue = getCookie(host.url, key)
            if !cookieValue.rawValue.isEmpty {
                dictionary[key] = cookieValue.rawValue
            }
        }
        return dictionary.description
    }
}
