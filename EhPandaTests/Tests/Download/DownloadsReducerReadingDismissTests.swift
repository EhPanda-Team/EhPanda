//
//  DownloadsReducerReadingDismissTests.swift
//  EhPandaTests
//

import ComposableArchitecture
import Testing
@testable import EhPanda

struct DownloadsReducerReadingDismissTests {
    @MainActor
    @Test
    func readingDismissClearsRoute() async {
        let gid = "135790"
        var initialState = DownloadsReducer.State()
        initialState.route = .reading(gid)

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.reading(.onPerformDismiss))
        await store.receive(\.setNavigation)

        #expect(store.state.route == nil)
    }
}
