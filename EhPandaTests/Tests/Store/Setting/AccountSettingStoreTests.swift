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
    private var environment: AccountSettingEnvironment {
        .init(
            hapticClient: .noop,
            cookiesClient: .noop,
            clipboardClient: .noop,
            uiApplicationClient: .noop
        )
    }
    private var store: TestStore<
        AccountSettingState, AccountSettingState,
        AccountSettingAction, AccountSettingAction,
        AccountSettingEnvironment
    > {
        .init(
            initialState: .init(),
            reducer: accountSettingReducer,
            environment: environment
        )
    }

    func testBinding() throws {
        let store = store

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
        store.send(.set(\.$ehCookiesState, .empty(.ehentai))) {
            $0.ehCookiesState = .empty(.ehentai)
        }
        store.send(.set(\.$exCookiesState, .empty(.exhentai))) {
            $0.exCookiesState = .empty(.exhentai)
        }
    }

    func testSetNavigation() throws {
        let store = store

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
        let store = store

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
        let store = store

        store.send(.clearSubStates) {
            $0.loginState = .init()
            $0.ehSettingState = .init()
        }
        store.receive(.login(.teardown))
        store.receive(.ehSetting(.teardown))
    }

    func testLoadCookies() throws {
        let store = store

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
        let store = store

        store.send(.copyCookies(.ehentai))
        store.receive(.setNavigation(.hud)) {
            $0.route = .hud
        }
    }

    func testLoginLoginDone() throws {
        let store = store

        store.send(.login(.loginDone(.failure(.unknown))))
        if environment.cookiesClient.didLogin {
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
