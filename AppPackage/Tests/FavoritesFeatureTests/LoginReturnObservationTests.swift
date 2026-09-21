import AppModels
import ComposableArchitecture
import CookieClient
@testable import FavoritesFeature
import Foundation
import Testing

struct LoginReturnObservationTests {
    @MainActor
    @Test
    func cookieLoginTriggersReloadWithoutAViewCallback() async {
        let appStorage = UserDefaults.inMemory
        let (changes, continuation) = AsyncStream<Void>.makeStream()
        var cookies = CookieClient.testing()
        cookies.cookiesDidChange = { changes }
        let store = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = FavoritesReducer.State()
            // This test verifies event routing. The existing in-flight guard avoids a network request.
            state.rawLoadingState[-1] = .loading
            return TestStore(initialState: state, reducer: FavoritesReducer.init) {
                $0.defaultAppStorage = appStorage
                $0.cookieClient = cookies
                $0.downloadClient = .noop
            }
        }

        let observation = await store.send(.onPresented)
        await store.receive(\.observeDownloads)
        cookies.importAutomationCookies(memberID: "fixture", passHash: "fixture", igneous: nil)
        #expect(cookies.didLogin)
        continuation.yield(())
        await store.receive(\.loginSucceeded)
        await store.receive(\.fetchGalleries)
        // A later cookie refresh while still signed in must not trigger another login event.
        cookies.importAutomationCookies(memberID: "fixture", passHash: "refreshed", igneous: nil)
        #expect(cookies.didLogin)
        continuation.yield(())
        continuation.finish()
        await observation.finish()
        await store.finish()
    }
}
