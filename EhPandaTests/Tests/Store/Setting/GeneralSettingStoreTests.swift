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

    func testClearSubStates() throws {
        let store = TestStore(
            initialState: GeneralSettingState(
                logsState: .init(route: .log(
                    .init(fileName: .init(), contents: .init())
                ))
            ),
            reducer: generalSettingReducer,
            environment: noopEnvironment
        )

        store.send(.clearSubStates) {
            $0.logsState = .init()
        }
        store.receive(.logs(.teardown))
    }

    func testClearWebImageCache() throws {
        let store = TestStore(
            initialState: GeneralSettingState(),
            reducer: generalSettingReducer,
            environment: GeneralSettingEnvironment(
                fileClient: .noop,
                loggerClient: .noop,
                libraryClient: .live,
                databaseClient: .live,
                uiApplicationClient: .noop,
                authorizationClient: .noop
            )
        )
        store.send(.clearWebImageCache)
        XCTWaiter.wait(timeout: 1)
        store.receive(.calculateWebImageDiskCache)
        store.receive(.calculateWebImageDiskCacheDone(0)) {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = .useAll
            $0.diskImageCacheSize = formatter.string(fromByteCount: 0)
        }
    }
}
