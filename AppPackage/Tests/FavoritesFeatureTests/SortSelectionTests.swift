import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import Foundation
import Testing

struct SortSelectionTests {
    @MainActor
    @Test
    func selectingWhileLoadingAndFailedResponsePreserveConfirmedOrder() async {
        let appStorage = UserDefaults.inMemory
        let store = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = FavoritesReducer.State()
            state.sortOrder = .lastUpdateTime
            state.rawLoadingState[-1] = .loading
            return TestStore(
                initialState: state,
                reducer: FavoritesReducer.init,
                withDependencies: {
                    $0.defaultAppStorage = appStorage
                    $0.cookieClient = .noop
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
        }

        // A second selection cannot optimistically replace the server-confirmed order.
        await store.send(.selectSortOrder(.favoritedTime))
        await store.receive(\.fetchGalleries)
        await store.send(.fetchGalleriesDone(index: -1, result: .failure(.unknown))) {
            $0.rawLoadingState[-1] = .failed(.unknown)
        }
        #expect(store.state.sortOrder == .lastUpdateTime)

        // Reopening a native picker with the old value must not retry a failed request.
        await store.send(.selectSortOrder(.lastUpdateTime))
        await store.send(.selectSortOrder(nil))
    }
}
