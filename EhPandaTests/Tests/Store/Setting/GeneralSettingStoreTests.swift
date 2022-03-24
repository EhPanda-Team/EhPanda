//
//  GeneralSettingStoreTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/03/24.
//

import XCTest
@testable import EhPanda
import ComposableArchitecture

class GeneralSettingStoreTests: XCTestCase {
    private var noopEnvironment: GeneralSettingEnvironment {
        .init(
            fileClient: .noop,
            loggerClient: .noop,
            libraryClient: .noop,
            databaseClient: .noop,
            uiApplicationClient: .noop,
            authorizationClient: .noop
        )
    }
    func testBinding() throws {
        let store = TestStore(
            initialState: GeneralSettingState(
                route: .clearCache,
                loadingState: .idle,
                diskImageCacheSize: .init(),
                passcodeNotSet: false,
                logsState: .init(route: .log(
                    .init(fileName: .init(), contents: .init())
                ))
            ),
            reducer: generalSettingReducer,
            environment: noopEnvironment
        )

        store.send(.set(\.$route, nil)) {
            $0.route = nil
        }
        store.receive(.clearSubStates) {
            $0.logsState = .init()
        }
        store.receive(.logs(.teardown))
        store.send(.set(\.$route, .logs)) {
            $0.route = .logs
        }
    }

    func testSetNavigation() throws {
        let store = TestStore(
            initialState: GeneralSettingState(
                route: .clearCache,
                loadingState: .idle,
                diskImageCacheSize: .init(),
                passcodeNotSet: false,
                logsState: .init(route: .log(
                    .init(fileName: .init(), contents: .init())
                ))
            ),
            reducer: generalSettingReducer,
            environment: noopEnvironment
        )

        store.send(.setNavigation(nil)) {
            $0.route = nil
        }
        store.receive(.clearSubStates) {
            $0.logsState = .init()
        }
        store.receive(.logs(.teardown))
        store.send(.set(\.$route, .logs)) {
            $0.route = .logs
        }
    }
}
