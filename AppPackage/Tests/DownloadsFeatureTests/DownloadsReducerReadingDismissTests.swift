import ComposableArchitecture
import Testing
import HapticsClient
import DeviceClient
@testable import DownloadsFeature
@testable import AppFeature

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
