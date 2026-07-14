import Foundation
import AppModels
import ComposableArchitecture
import AppTools
#if DEBUG
import Synchronization
#endif

public struct CookieClient: Sendable {
    public let clearAll: @Sendable () -> Void
    public let getCookie: @Sendable (URL, String) -> CookieValue
    private let cookiesForURL: @Sendable (URL) -> [HTTPCookie]
    private let removeCookie: @Sendable (URL, String) -> Void
    private let checkExistence: @Sendable (URL, String) -> Bool
    private let initializeCookie: @Sendable (HTTPCookie, String) -> HTTPCookie
    private let storeCookie: @Sendable (HTTPCookie) -> Void
    private let setCookieValue: @Sendable (URL, String, String, String, TimeInterval, Bool) -> Void
}

extension CookieClient {
    public static let live: Self = live(cookieStorage: .shared)

    public static func live(cookieStorage: HTTPCookieStorage) -> Self {
        .init(
            clearAll: {
                if let historyCookies = cookieStorage.cookies {
                    historyCookies.forEach {
                        cookieStorage.deleteCookie($0)
                    }
                }
            },
            getCookie: { url, key in
                var value = CookieValue(
                    rawValue: "", localizedString: String(localized: .cookieValueNone)
                )
                guard let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty else { return value }

                cookies.forEach { cookie in
                    guard cookie.name == key && !cookie.value.isEmpty else { return }
                    if let expiresDate = cookie.expiresDate,
                       expiresDate <= .now {
                        value = CookieValue(
                            rawValue: "",
                            localizedString: String(localized: .cookieValueExpired)
                        )
                        return
                    }
                    guard cookie.value != Defaults.Cookie.mystery else {
                        value = CookieValue(
                            rawValue: cookie.value, localizedString:
                                String(localized: .cookieValueMystery)
                        )
                        return
                    }
                    value = CookieValue(rawValue: cookie.value, localizedString: "")
                }

                return value
            },
            cookiesForURL: { url in
                cookieStorage.cookies(for: url) ?? []
            },
            removeCookie: { url, key in
                if let cookies = cookieStorage.cookies(for: url) {
                    cookies.forEach { cookie in
                        guard cookie.name == key else { return }
                        cookieStorage.deleteCookie(cookie)
                    }
                }
            },
            checkExistence: { url, key in
                if let cookies = cookieStorage.cookies(for: url) {
                    var existence: HTTPCookie?
                    cookies.forEach { cookie in
                        guard cookie.name == key else { return }
                        existence = cookie
                    }
                    return existence != nil
                } else {
                    return false
                }
            },
            initializeCookie: { cookie, value in
                var properties = cookie.properties
                properties?[.value] = value
                return HTTPCookie(properties: properties ?? [:]) ?? HTTPCookie()
            },
            storeCookie: { cookie in
                cookieStorage.setCookie(cookie)
            },
            setCookieValue: { url, key, value, path, expiresTime, sessionOnly in
                let properties: [HTTPCookiePropertyKey: Any] = [
                    .path: path, .name: key, .value: value,
                    .originURL: url
                ]
                var mutableProperties = properties
                if let host = url.host {
                    mutableProperties[.domain] = host
                }
                if sessionOnly {
                    mutableProperties[.discard] = "TRUE"
                } else {
                    mutableProperties[.expires] = Date(timeIntervalSinceNow: expiresTime)
                }
                if let cookie = HTTPCookie(properties: mutableProperties) {
                    cookieStorage.setCookie(cookie)
                }
            }
        )
    }
}

// MARK: Foundation
extension CookieClient {
    public func importAutomationCookies(memberID: String, passHash: String, igneous: String?) {
        let urls = [Defaults.URL.ehentai, Defaults.URL.exhentai, Defaults.URL.sexhentai]
        let authKeys = [Defaults.Cookie.ipbMemberId, Defaults.Cookie.ipbPassHash]

        urls.forEach { url in
            authKeys.forEach { key in
                removeCookie(url, key)
            }
        }
        [Defaults.URL.exhentai, Defaults.URL.sexhentai].forEach { url in
            removeCookie(url, Defaults.Cookie.igneous)
        }

        urls.forEach { url in
            setCookie(
                for: url,
                key: Defaults.Cookie.ipbMemberId,
                value: memberID,
                sessionOnly: true
            )
            setCookie(
                for: url,
                key: Defaults.Cookie.ipbPassHash,
                value: passHash,
                sessionOnly: true
            )
        }

        if let igneous, !igneous.isEmpty {
            [Defaults.URL.exhentai, Defaults.URL.sexhentai].forEach { url in
                setCookie(
                    for: url,
                    key: Defaults.Cookie.igneous,
                    value: igneous,
                    sessionOnly: true
                )
            }
        }

        ignoreOffensive()
        fulfillAnotherHostField()
    }

    private func setCookie(
        for url: URL, key: String, value: String, path: String = "/",
        expiresTime: TimeInterval = .oneYear,
        sessionOnly: Bool = false
    ) {
        setCookieValue(url, key, value, path, expiresTime, sessionOnly)
    }
    public func editCookie(for url: URL, key: String, value: String) {
        var newCookie: HTTPCookie?
        cookiesForURL(url).forEach { cookie in
            guard cookie.name == key else { return }
            newCookie = initializeCookie(cookie, value)
            removeCookie(url, key)
        }
        guard let cookie = newCookie else { return }
        storeCookie(cookie)
    }
    public func setOrEditCookie(for url: URL, key: String, value: String) {
        if checkExistence(url, key) {
            editCookie(for: url, key: key, value: value)
        } else {
            setCookie(for: url, key: key, value: value)
        }
    }
    public func cookies(for url: URL) -> [HTTPCookie] {
        cookiesForURL(url)
    }
}

// MARK: Accessor
extension CookieClient {
    public var didLogin: Bool {
        let ehHasAuth = !getCookie(Defaults.URL.ehentai, Defaults.Cookie.ipbMemberId).rawValue.isEmpty
            && !getCookie(Defaults.URL.ehentai, Defaults.Cookie.ipbPassHash).rawValue.isEmpty
        let exIgneous = getCookie(Defaults.URL.exhentai, Defaults.Cookie.igneous).rawValue
        let exHasAuth = !getCookie(Defaults.URL.exhentai, Defaults.Cookie.ipbMemberId).rawValue.isEmpty
            && !getCookie(Defaults.URL.exhentai, Defaults.Cookie.ipbPassHash).rawValue.isEmpty
            && !exIgneous.isEmpty
            && exIgneous != Defaults.Cookie.mystery
        return ehHasAuth || exHasAuth
    }
    public func apiuid(host: GalleryHost) -> String {
        getCookie(host.url, Defaults.Cookie.ipbMemberId).rawValue
    }
    public var isSameAccount: Bool {
        let ehUID = getCookie(Defaults.URL.ehentai, Defaults.Cookie.ipbMemberId).rawValue
        let exUID = getCookie(Defaults.URL.exhentai, Defaults.Cookie.ipbMemberId).rawValue
        if !ehUID.isEmpty && !exUID.isEmpty { return ehUID == exUID } else { return false }
    }
    public var shouldFetchIgneous: Bool {
        let url = Defaults.URL.exhentai
        return !getCookie(url, Defaults.Cookie.ipbMemberId).rawValue.isEmpty
            && !getCookie(url, Defaults.Cookie.ipbPassHash).rawValue.isEmpty
            && getCookie(url, Defaults.Cookie.igneous).rawValue.isEmpty
    }
    public func removeYay() {
        removeCookie(Defaults.URL.exhentai, Defaults.Cookie.yay)
        removeCookie(Defaults.URL.sexhentai, Defaults.Cookie.yay)
    }
    public func syncExCookies() {
        let cookies = [
            Defaults.Cookie.ipbMemberId,
            Defaults.Cookie.ipbPassHash,
            Defaults.Cookie.igneous
        ]
        for cookie in cookies {
            setOrEditCookie(
                for: Defaults.URL.sexhentai,
                key: cookie,
                value: getCookie(Defaults.URL.exhentai, cookie).rawValue
            )
        }
    }
    public func ignoreOffensive() {
        setOrEditCookie(for: Defaults.URL.ehentai, key: Defaults.Cookie.ignoreOffensive, value: "1")
        setOrEditCookie(for: Defaults.URL.exhentai, key: Defaults.Cookie.ignoreOffensive, value: "1")
    }
    public func fulfillAnotherHostField() {
        let ehURL = Defaults.URL.ehentai
        let exURL = Defaults.URL.exhentai
        let memberIdKey = Defaults.Cookie.ipbMemberId
        let passHashKey = Defaults.Cookie.ipbPassHash
        let ehMemberId = getCookie(ehURL, memberIdKey).rawValue
        let ehPassHash = getCookie(ehURL, passHashKey).rawValue
        let exMemberId = getCookie(exURL, memberIdKey).rawValue
        let exPassHash = getCookie(exURL, passHashKey).rawValue

        if !ehMemberId.isEmpty && !ehPassHash.isEmpty && (exMemberId.isEmpty || exPassHash.isEmpty) {
            setOrEditCookie(for: exURL, key: memberIdKey, value: ehMemberId)
            setOrEditCookie(for: exURL, key: passHashKey, value: ehPassHash)
        } else if !exMemberId.isEmpty && !exPassHash.isEmpty && (ehMemberId.isEmpty || ehPassHash.isEmpty) {
            setOrEditCookie(for: ehURL, key: memberIdKey, value: exMemberId)
            setOrEditCookie(for: ehURL, key: passHashKey, value: exPassHash)
        }
    }
    public func loadCookiesState(host: GalleryHost) -> CookiesState {
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
    public func getCookiesDescription(host: GalleryHost) -> String {
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

// MARK: SetCookies
extension CookieClient {
    public func setCookies(state: CookiesState, trimsSpaces: Bool = true) {
        for subState in state.allCases {
            for cookie in state.host.cookieURLs {
                setOrEditCookie(
                    for: cookie,
                    key: subState.key,
                    value: trimsSpaces
                        ? subState.editingText .trimmingCharacters(in: .whitespaces) : subState.editingText
                )
            }
        }

    }
    public func setCredentials(response: HTTPURLResponse) {
        guard let setString = response.allHeaderFields["Set-Cookie"] as? String else { return }
        setString.components(separatedBy: ", ")
            .flatMap { $0.components(separatedBy: "; ") }.forEach { value in
                [Defaults.URL.ehentai, Defaults.URL.exhentai].forEach { url in
                    [
                        Defaults.Cookie.ipbMemberId,
                        Defaults.Cookie.ipbPassHash,
                        Defaults.Cookie.igneous
                    ].forEach { key in
                        guard !(url == Defaults.URL.ehentai && key == Defaults.Cookie.igneous),
                              let range = value.range(of: "\(key)=") else { return }
                        setCookie(for: url, key: key, value: String(value[range.upperBound...]))
                    }
                }
            }
    }
    public func setSkipServer(response: HTTPURLResponse, host: GalleryHost) {
        guard let setString = response.allHeaderFields["Set-Cookie"] as? String else { return }
        setString.components(separatedBy: ", ")
            .flatMap { $0.components(separatedBy: "; ") }
            .forEach { value in
                let key = Defaults.Cookie.skipServer
                if let range = value.range(of: "\(key)=") {
                    setCookie(
                        for: host.url, key: key,
                        value: String(value[range.upperBound...]), path: "/s/"
                    )
                }
            }
    }
}

// MARK: API
public enum CookieClientKey: DependencyKey {
    public static let liveValue = CookieClient.live
    public static let previewValue = CookieClient.noop
    public static let testValue = CookieClient.unimplemented
}

extension DependencyValues {
    public var cookieClient: CookieClient {
        get { self[CookieClientKey.self] }
        set { self[CookieClientKey.self] = newValue }
    }
}

// MARK: Test
extension CookieClient {
    public static let noop: Self = .init(
        clearAll: {},
        getCookie: { _, _ in .empty },
        cookiesForURL: { _ in [] },
        removeCookie: { _, _ in },
        checkExistence: { _, _ in false },
        initializeCookie: { _, _ in .init() },
        storeCookie: { _ in },
        setCookieValue: { _, _, _, _, _, _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        clearAll: IssueReporting.unimplemented(placeholder: placeholder()),
        getCookie: IssueReporting.unimplemented(placeholder: placeholder()),
        cookiesForURL: IssueReporting.unimplemented(placeholder: placeholder()),
        removeCookie: IssueReporting.unimplemented(placeholder: placeholder()),
        checkExistence: IssueReporting.unimplemented(placeholder: placeholder()),
        initializeCookie: IssueReporting.unimplemented(placeholder: placeholder()),
        storeCookie: IssueReporting.unimplemented(placeholder: placeholder()),
        setCookieValue: IssueReporting.unimplemented(placeholder: placeholder())
    )
}

#if DEBUG
private struct CookieClientTestingCookie: Sendable {
    public var domain: String
    public var path: String
    public var name: String
    public var value: String
    public var expiresDate: Date?
    public var isSessionOnly: Bool

    public func matches(url: URL, key: String? = nil) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        // Host-exact: the store only ever holds concrete-host cookies (never a wildcard `.domain`
        // one), so a subdomain query such as `s.exhentai.org` must NOT match an `exhentai.org`
        // cookie. A suffix match let a `syncExCookies` write to one host collaterally delete a
        // sibling host's login cookies (via `editCookie`'s remove-all-matching), nondeterministically.
        let normalizedDomain = domain.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let domainMatches = host == normalizedDomain
        let keyMatches = key.map { name == $0 } ?? true
        return domainMatches && keyMatches
    }

    public func httpCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: path,
            .name: name,
            .value: value
        ]
        if isSessionOnly {
            properties[.discard] = "TRUE"
        } else if let expiresDate {
            properties[.expires] = expiresDate
        }
        return HTTPCookie(properties: properties)
    }
}

private final class CookieClientTestingStore: Sendable {
    private let cookies: Mutex<[String: CookieClientTestingCookie]>

    public init(cookies: [String: CookieClientTestingCookie]) {
        self.cookies = Mutex(cookies)
    }

    public func value(for url: URL, key: String) -> String {
        cookie(for: url, key: key)?.value ?? ""
    }

    public func setValue(
        _ value: String,
        for url: URL,
        key: String,
        path: String = "/",
        expiresTime: TimeInterval = .oneYear,
        sessionOnly: Bool = false
    ) {
        guard let domain = url.host else { return }
        let cookie = CookieClientTestingCookie(
            domain: domain,
            path: path,
            name: key,
            value: value,
            expiresDate: sessionOnly ? nil : Date(timeIntervalSinceNow: expiresTime),
            isSessionOnly: sessionOnly
        )
        cookies.withLock { $0[storageKey(domain: domain, key: key)] = cookie }
    }

    public func removeValue(for url: URL, key: String) {
        cookies.withLock { storage in
            storage = storage.filter { !$0.value.matches(url: url, key: key) }
        }
    }

    public func containsValue(for url: URL, key: String) -> Bool {
        cookie(for: url, key: key) != nil
    }

    public func cookies(for url: URL) -> [HTTPCookie] {
        cookies.withLock { storage in
            storage.values
                .filter { $0.matches(url: url) }
                .compactMap { $0.httpCookie() }
        }
    }

    public func store(_ cookie: HTTPCookie) {
        let testingCookie = CookieClientTestingCookie(
            domain: cookie.domain,
            path: cookie.path,
            name: cookie.name,
            value: cookie.value,
            expiresDate: cookie.expiresDate,
            isSessionOnly: cookie.isSessionOnly
        )
        cookies.withLock {
            $0[storageKey(domain: cookie.domain, key: cookie.name)] = testingCookie
        }
    }

    public func removeAll() {
        cookies.withLock { $0.removeAll() }
    }

    private func cookie(for url: URL, key: String) -> CookieClientTestingCookie? {
        cookies.withLock { storage in
            storage.values.first { $0.matches(url: url, key: key) }
        }
    }

    private func storageKey(domain: String, key: String) -> String {
        "\(domain.lowercased())|\(key)"
    }
}

extension CookieClient {
    public static func testing(
        memberID: String = "",
        passHash: String = "",
        igneous: String? = nil
    ) -> Self {
        let store = CookieClientTestingStore(cookies: [:])
        for url in [Defaults.URL.ehentai, Defaults.URL.exhentai, Defaults.URL.sexhentai] {
            if !memberID.isEmpty {
                store.setValue(memberID, for: url, key: Defaults.Cookie.ipbMemberId)
            }
            if !passHash.isEmpty {
                store.setValue(passHash, for: url, key: Defaults.Cookie.ipbPassHash)
            }
        }
        if let igneous, !igneous.isEmpty {
            for url in [Defaults.URL.exhentai, Defaults.URL.sexhentai] {
                store.setValue(igneous, for: url, key: Defaults.Cookie.igneous)
            }
        }

        return .init(
            clearAll: {
                store.removeAll()
            },
            getCookie: { url, key in
                .init(rawValue: store.value(for: url, key: key), localizedString: "")
            },
            cookiesForURL: { url in
                store.cookies(for: url)
            },
            removeCookie: { url, key in
                store.removeValue(for: url, key: key)
            },
            checkExistence: { url, key in
                store.containsValue(for: url, key: key)
            },
            initializeCookie: { cookie, value in
                var properties = cookie.properties
                properties?[.value] = value
                return HTTPCookie(properties: properties ?? [:]) ?? HTTPCookie()
            },
            storeCookie: { cookie in
                store.store(cookie)
            },
            setCookieValue: { url, key, value, path, expiresTime, sessionOnly in
                store.setValue(
                    value,
                    for: url,
                    key: key,
                    path: path,
                    expiresTime: expiresTime,
                    sessionOnly: sessionOnly
                )
            }
        )
    }
}
#endif
