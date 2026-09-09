import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
@testable import HomeFeature
import Testing

struct LoginReturnObservationTests {
    @MainActor
    @Test
    func cookieLoginTriggersReloadWithoutAViewCallback() async {
        let appStorage = UserDefaults.inMemory
        let cookies = CookieClient.testing()
        let store = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = WatchedReducer.State()
            // This test verifies event routing. The existing in-flight guard avoids a network request.
            state.loadingState = .loading
            return TestStore(initialState: state, reducer: WatchedReducer.init) {
                $0.defaultAppStorage = appStorage
                $0.cookieClient = cookies
                $0.downloadClient = .noop
            }
        }

        let observation = await store.send(.onPresented)
        await store.receive(\.observeDownloads)
        cookies.importAutomationCookies(memberID: "fixture", passHash: "fixture", igneous: nil)
        await store.receive(\.loginSucceeded)
        await store.receive(\.fetchGalleries)
        // A later cookie refresh while still signed in must not trigger another login event.
        cookies.importAutomationCookies(memberID: "fixture", passHash: "refreshed", igneous: nil)
        await observation.cancel()
        await store.finish()
    }
}
