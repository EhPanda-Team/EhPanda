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
            hapticClient: .noop,
            cookiesClient: .noop,
            clipboardClient: .noop,
            uiApplicationClient: .noop
        )
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
                hapticClient: .noop,
                cookiesClient: .live,
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
        let value = "test"
        let ehCookiesState = CookiesState(
            host: .ehentai,
            igneous: .init(key: Defaults.Cookie.igneous, value: .empty, editingText: value),
            memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .empty, editingText: value),
            passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .empty, editingText: value)
        )
        let exCookiesState = CookiesState(
            host: .exhentai,
            igneous: .init(key: Defaults.Cookie.igneous, value: .empty, editingText: value),
            memberID: .init(key: Defaults.Cookie.ipbMemberId, value: .empty, editingText: value),
            passHash: .init(key: Defaults.Cookie.ipbPassHash, value: .empty, editingText: value)
        )
        store.send(.set(\.$ehCookiesState, ehCookiesState)) {
            $0.ehCookiesState = ehCookiesState
        }
        store.send(.set(\.$exCookiesState, exCookiesState)) {
            $0.exCookiesState = exCookiesState
        }

        [Defaults.Cookie.igneous, Defaults.Cookie.ipbMemberId, Defaults.Cookie.ipbPassHash]
            .flatMap({ key in [Defaults.URL.ehentai, Defaults.URL.exhentai].map({ ($0, key) }) })
            .map(CookiesClient.live.getCookie)
            .forEach({ XCTAssertEqual($0, .init(rawValue: value, localizedString: .init())) })
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
            environment: noopEnvironment
        )

        store.send(.onLogoutConfirmButtonTapped)
        store.receive(.loadCookies) {
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
        if noopEnvironment.cookiesClient.didLogin {
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
