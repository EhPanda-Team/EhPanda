import AnalyticsClient
@testable import AppFeature
import ComposableArchitecture
import DeviceClient
@testable import DownloadsFeature
import HapticsClient
import Testing

// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. It is applied
// per member rather than to the suite so the type's `DownloadFeatureTestCase` conformance
// stays nonisolated — a main-actor conformance cannot be used from the `@Sendable`
// dependency closures these stores install.
struct DownloadsReducerReadingDismissTests {
    @MainActor
    @Test
    func readingDismissClearsDestination() async {
        var initialState = DownloadsReducer.State()
        initialState.destination = .reading(.init(gallery: .preview, contentSource: .remote))

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.deviceClient = .noop
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.destination(.presented(.reading(.onPerformDismiss))))
        await store.receive(\.destination.dismiss)

        #expect(store.state.destination == nil)
    }
}
