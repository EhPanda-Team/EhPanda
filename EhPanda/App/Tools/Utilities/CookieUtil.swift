//
//  CookieUtil.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/02.
//

import Foundation

// MARK: Cookie
struct CookieUtil {
    static var didLogin: Bool {
        CookieUtil.verify(for: Defaults.URL.ehentai, isEx: false)
        || CookieUtil.verify(for: Defaults.URL.exhentai, isEx: true)
    }

    static func verify(for url: URL, isEx: Bool) -> Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url), !cookies.isEmpty else { return false }

        var igneous, memberID, passHash: String?
        cookies.forEach { cookie in
            guard let expiresDate = cookie.expiresDate, expiresDate > .now, !cookie.value.isEmpty else { return }
            if cookie.name == Defaults.Cookie.igneous && cookie.value != Defaults.Cookie.mystery {
                igneous = cookie.value
            }
            if cookie.name == Defaults.Cookie.ipbMemberId {
                memberID = cookie.value
            }
            if cookie.name == Defaults.Cookie.ipbPassHash {
                passHash = cookie.value
            }
        }

        return (!isEx || igneous != nil) && memberID != nil && passHash != nil
    }
}
