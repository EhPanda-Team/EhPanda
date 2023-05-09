//
//  AccountSettingStoreTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/03/06.
//

import XCTest
@testable import EhPanda
import ComposableArchitecture

class AccountSettingStoreTests: XCTestCase {
    private var noopEnvironment: AccountSettingEnvironment {
        .init(
            hapticsClient: .noop,
            cookieClient: .noop,
            clipboardClient: .noop,
            uiApplicationClient: .noop
        )
    }
    private static func getCookiesState(with value: String) -> (CookiesState, CookiesState) {
        let ehCookiesState = CookiesState(
            host: .ehentai,
            igneous: .init(key: Defaults.Cookie.igneous, value: .init(rawValue: value, localizedString: .init()), editingText: value),
            memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .init(rawValue: value, localizedString: .init()), editingText: value),
            passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .init(rawValue: value, localizedString: .init()), editingText: value)
        )
        let exCookiesState = CookiesState(
            host: .exhentai,
            igneous: .init(key: Defaults.Cookie.igneous, value: .init(rawValue: value, localizedString: .init()), editingText: value),
            memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .init(rawValue: value, localizedString: .init()), editingText: value),
            passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .init(rawValue: value, localizedString: .init()), editingText: value)
        )
        return (ehCookiesState, exCookiesState)
    }
    private static func setCookies(with state: CookiesState) {
        _ = CookieClient.live.setCookies(state: state).sink(receiveValue: { _ in })
    }
    @discardableResult private static func teardownCookies(value: String? = nil) -> String {
        let initialValue = UUID().uuidString
        let (initialEhCookiesState, initialExCookiesState) = getCookiesState(with: value ?? initialValue)
        setCookies(with: initialEhCookiesState)
        setCookies(with: initialExCookiesState)
        return value ?? initialValue
    }

    override class func tearDown() {
        super.tearDown()

        teardownCookies(value: .init())
    }

    func testCookies(with value: String) throws {
        [Defaults.Cookie.igneous, Defaults.Cookie.ipbMemberId, Defaults.Cookie.ipbPassHash]
            .flatMap({ key in [Defaults.URL.ehentai, Defaults.URL.exhentai].map({ ($0, key) }) })
            .map(CookieClient.live.getCookie)
            .forEach({ XCTAssertEqual($0, .init(rawValue: value, localizedString: .init())) })
    }

    func testBinding() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                route: .ehSetting,
                ehCookiesState: .empty(.exhentai),
                exCookiesState: .empty(.ehentai),
                loginState: .init(route: .webView(.mock)),
                ehSettingState: .init(route: .deleteProfile)
            ),
            reducer: accountSettingReducer,
            environment: AccountSettingEnvironment(
                hapticsClient: .noop,
                cookieClient: .live,
                clipboardClient: .noop,
                uiApplicationClient: .noop
            )
        )

        store.send(.set(\.$route, nil)) {
            $0.route = nil
        }
        store.receive(.clearSubStates) {
            $0.loginState = .init()
            $0.ehSettingState = .init()
        }
        store.receive(.login(.teardown))
        store.receive(.ehSetting(.teardown))
        store.send(.set(\.$route, .login)) {
            $0.route = .login
        }

        AccountSettingStoreTests.teardownCookies()

        let testValue = UUID().uuidString
        let (ehCookiesState, exCookiesState) = AccountSettingStoreTests.getCookiesState(with: testValue)
        store.send(.set(\.$ehCookiesState, ehCookiesState)) {
            $0.ehCookiesState = ehCookiesState
        }
        store.send(.set(\.$exCookiesState, exCookiesState)) {
            $0.exCookiesState = exCookiesState
        }
        try testCookies(with: testValue)
    }

    func testSetNavigation() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                route: .ehSetting,
                loginState: .init(route: .webView(.mock)),
                ehSettingState: .init(route: .deleteProfile)
            ),
            reducer: accountSettingReducer,
            environment: noopEnvironment
        )

        store.send(.setNavigation(nil)) {
            $0.route = nil
        }
        store.receive(.clearSubStates) {
            $0.loginState = .init()
            $0.ehSettingState = .init()
        }
        store.receive(.login(.teardown))
        store.receive(.ehSetting(.teardown))
        store.send(.setNavigation(.webView(.mock))) {
            $0.route = .webView(.mock)
        }
    }

    func testOnLogoutConfirmButtonTapped() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                ehCookiesState: .empty(.exhentai),
                exCookiesState: .empty(.ehentai)
            ),
            reducer: accountSettingReducer,
            environment: AccountSettingEnvironment(
                hapticsClient: .noop,
                cookieClient: .live,
                clipboardClient: .noop,
                uiApplicationClient: .noop
            )
        )

        let initialValue = AccountSettingStoreTests.teardownCookies()
        let (ehCookiesState, exCookiesState) = AccountSettingStoreTests.getCookiesState(with: initialValue)
        store.send(.onLogoutConfirmButtonTapped)
        store.receive(.loadCookies) {
            $0.ehCookiesState = ehCookiesState
            $0.exCookiesState = exCookiesState
        }
        try testCookies(with: initialValue)
    }

    func testClearSubStates() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                loginState: .init(route: .webView(.mock)),
                ehSettingState: .init(route: .deleteProfile)
            ),
            reducer: accountSettingReducer,
            environment: noopEnvironment
        )

        store.send(.clearSubStates) {
            $0.loginState = .init()
            $0.ehSettingState = .init()
        }
        store.receive(.login(.teardown))
        store.receive(.ehSetting(.teardown))
    }

    func testLoadCookies() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                ehCookiesState: .empty(.exhentai),
                exCookiesState: .empty(.ehentai)
            ),
            reducer: accountSettingReducer,
            environment: noopEnvironment
        )

        store.send(.loadCookies) {
            $0.ehCookiesState = .init(
                host: .ehentai,
                igneous: .init(key: Defaults.Cookie.igneous, value: .empty),
                memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .empty),
                passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .empty)
            )
            $0.exCookiesState = .init(
                host: .exhentai,
                igneous: .init(key: Defaults.Cookie.igneous, value: .empty),
                memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .empty),
                passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .empty)
            )
        }
    }

    func testCopyCookies() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                route: .ehSetting
            ),
            reducer: accountSettingReducer,
            environment: noopEnvironment
        )

        store.send(.copyCookies(.ehentai))
        store.receive(.setNavigation(.hud)) {
            $0.route = .hud
        }
    }

    func testLoginLoginDone() throws {
        let store = TestStore(
            initialState: AccountSettingState(
                route: .ehSetting,
                loginState: .init(route: .webView(.mock), loginState: .loading),
                ehSettingState: .init(route: .deleteProfile)
            ),
            reducer: accountSettingReducer,
            environment: noopEnvironment
        )

        store.send(.login(.loginDone(.success(nil)))) {
            $0.loginState = .init(route: nil, loginState: .idle)
        }
        if noopEnvironment.cookieClient.didLogin {
            store.receive(.setNavigation(nil)) {
                $0.route = nil
            }
            store.receive(.clearSubStates) {
                $0.loginState = .init()
                $0.ehSettingState = .init()
            }
            store.receive(.login(.teardown))
            store.receive(.ehSetting(.teardown))
        }
    }
}
