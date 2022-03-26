//
//  AppearanceSettingStoreTests.swift
//  EhPandaTests
//
//  Created by 荒木辰造 on R 4/03/26.
//

import XCTest
@testable import EhPanda
import ComposableArchitecture

class AppearanceSettingStoreTests: XCTestCase {
    private var noopEnvironment: AppearanceSettingEnvironment {
        .init()
    }

    func testBinding() throws {
        let store = TestStore(
            initialState: AppearanceSettingState(
                route: .appIcon
            ),
            reducer: appearanceSettingReducer,
            environment: noopEnvironment
        )
        store.send(.set(\.$route, nil)) {
            $0.route = nil
        }
    }

    func testSetNavigation() throws {
        let store = TestStore(
            initialState: AppearanceSettingState(
                route: .appIcon
            ),
            reducer: appearanceSettingReducer,
            environment: noopEnvironment
        )
        store.send(.setNavigation(nil)) {
            $0.route = nil
        }
    }
}
