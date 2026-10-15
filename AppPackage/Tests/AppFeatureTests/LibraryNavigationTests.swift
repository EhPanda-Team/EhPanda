@testable import AppFeature
import AppModels
import ComposableArchitecture
import CustomDump
import DownloadsFeature
import FavoritesFeature
import Testing

@Suite
struct LibraryNavigationTests {
    @MainActor
    @Test
    func selectingEachLibraryGroupUpdatesTypedSelection() async {
        let store = TestStore(initialState: LibraryFeature.State(), reducer: LibraryFeature.init)

        await store.send(.select(.favorites(-1))) {
            $0.selection = .favorites(-1)
        }
        await store.send(.select(.downloads(.all))) {
            $0.selection = .downloads(.all)
        }
        await store.send(.select(.downloads(.folder("Reading")))) {
            $0.selection = .downloads(.folder("Reading"))
        }
        await store.send(.select(nil)) {
            $0.selection = nil
        }
        await store.finish()
    }

    @MainActor
    @Test
    func selectingTheSameLibraryGroupDoesNotChangeState() async {
        let store = TestStore(
            initialState: LibraryFeature.State(selection: .downloads(.all)),
            reducer: LibraryFeature.init
        )
        await store.send(.select(.downloads(.all)))
        await store.finish()
    }

    @MainActor
    @Test
    func rootSelectionCanShowNavigationWithoutStartingChildWork() async {
        let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer.init)

        await store.send(.library(.select(nil))) {
            $0.libraryState.selection = nil
        }
        await store.finish()
        expectNoDifference(store.state.libraryState.selection, nil)
        expectNoDifference(store.state.favoritesState.rawGalleries, [:])
        expectNoDifference(store.state.downloadsState.hasLoadedInitialDownloads, false)
    }
}
