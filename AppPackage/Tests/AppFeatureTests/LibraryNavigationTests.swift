@testable import AppFeature
import AppModels
import ComposableArchitecture
import CookieClient
import CustomDump
import DetailFeature
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
    @MainActor
    @Test
    func changingLibraryGroupsRetainsPathsAndQueriesButUpdatesCanonicalFilters() async {
        var initialState = AppReducer.State()
        initialState.favoritesState.path.append(.gallery(.detail(.init(gallery: .preview))))
        initialState.downloadsState.path.append(.gallery(.detail(.init(gallery: .preview))))
        initialState.favoritesState.keyword = "favorite query"
        initialState.downloadsState.keyword = "download query"
        initialState.favoritesState.visibleGalleryID = "favorite anchor"
        initialState.downloadsState.visibleGalleryID = "download anchor"
        let store = TestStore(initialState: initialState, reducer: AppReducer.init) {
            $0.cookieClient = .noop
        }
        await store.send(.library(.select(.favorites(3)))) {
            $0.libraryState.selection = .favorites(3)
        }
        await store.receive(\.favorites.setFavoritesIndex, 3) {
            $0.favoritesState.favoritesIndex = 3
        }
        await store.send(.library(.select(.downloads(.folder("Reading"))))) {
            $0.libraryState.selection = .downloads(.folder("Reading"))
        }
        await store.receive(\.downloads.binding) {
            $0.downloadsState.folderFilter = .folder("Reading")
        }
        await store.receive(\.library.syncFromSources)
        await store.finish()
        expectNoDifference(store.state.favoritesState.path, initialState.favoritesState.path)
        expectNoDifference(store.state.downloadsState.path, initialState.downloadsState.path)
        expectNoDifference(store.state.favoritesState.keyword, "favorite query")
        expectNoDifference(store.state.downloadsState.keyword, "download query")
        expectNoDifference(store.state.favoritesState.visibleGalleryID, "favorite anchor")
        expectNoDifference(store.state.downloadsState.visibleGalleryID, "download anchor")
    }

}
