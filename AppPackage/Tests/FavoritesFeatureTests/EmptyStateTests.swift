import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import NetworkingFeature
import Testing

/// Favorites with nothing saved shows its own empty state instead of the shared not-found error, in every
/// category; a keyword search or a date-seek with no hits is "no results" and keeps the not-found error
/// (owner msg 2896).
@Suite
struct EmptyStateTests {
    private static let keyword = "artist:nobody"

    private static func emptyFavorites() -> Result<FavoritesGalleriesResult, AppError> {
        .success(FavoritesGalleriesResult(pageNumber: PageNumber(), galleries: []))
    }

    @MainActor
    @Test(arguments: [-1, 0, 9])
    func emptyLoadOfACategoryIsTheEmptyStateNotAnError(index: Int) async {
        var state = FavoritesReducer.State()
        state.favoritesIndex = index
        state.rawLoadingState[index] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchGalleriesDone(index: index, keyword: "", result: Self.emptyFavorites())) {
            $0.rawLoadingState[index] = .idle
            $0.rawGalleries[index] = []
            $0.rawPageNumber[index] = PageNumber()
            $0.emptyFavoritesIndices = [index]
        }
        await store.finish()
        #expect(store.state.isEmpty)
        #expect(store.state.loadingState == .idle)
    }

    @MainActor
    @Test
    func refreshThatComesBackEmptyDropsTheStaleGalleries() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawPageNumber[-1] = PageNumber()
        state.rawLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchGalleriesDone(index: -1, keyword: "", result: Self.emptyFavorites())) {
            $0.rawLoadingState[-1] = .idle
            $0.rawGalleries[-1] = []
            $0.emptyFavoritesIndices = [-1]
        }
        await store.finish()
        #expect(store.state.isEmpty)
    }

    @MainActor
    @Test
    func emptyKeywordSearchStaysNotFound() async {
        var state = FavoritesReducer.State()
        state.keyword = Self.keyword
        state.rawGalleries[-1] = [.preview]
        state.rawLoadingState[-1] = .loading
        state.emptyFavoritesIndices = [-1]
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchGalleriesDone(index: -1, keyword: Self.keyword, result: Self.emptyFavorites())) {
            $0.rawLoadingState[-1] = .failed(.notFound)
            $0.emptyFavoritesIndices = []
        }
        await store.finish()
        #expect(!store.state.isEmpty)
    }

    @MainActor
    @Test
    func emptyDateSeekStaysNotFound() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.performDateSeekDone(
            index: -1, result: .success(GalleriesResult(pageNumber: PageNumber(), galleries: []))
        )) {
            $0.rawLoadingState[-1] = .failed(.notFound)
        }
        await store.finish()
        #expect(!store.state.isEmpty)
    }

    @MainActor
    @Test
    func failedReloadOfAnEmptyCategoryShowsTheErrorInstead() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = []
        state.rawLoadingState[-1] = .loading
        state.emptyFavoritesIndices = [-1]
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchGalleriesDone(index: -1, keyword: "", result: .failure(.networkingFailed))) {
            $0.rawLoadingState[-1] = .failed(.networkingFailed)
            $0.emptyFavoritesIndices = []
        }
        await store.finish()
        #expect(!store.state.isEmpty)
    }

    @MainActor
    @Test
    func emptyStateBelongsToItsOwnCategory() {
        var state = FavoritesReducer.State()
        state.emptyFavoritesIndices = [3]
        state.rawLoadingState[3] = .idle
        state.favoritesIndex = -1
        #expect(!state.isEmpty)
        state.favoritesIndex = 3
        #expect(state.isEmpty)
        state.rawLoadingState[3] = .loading
        #expect(!state.isEmpty)
    }
}
