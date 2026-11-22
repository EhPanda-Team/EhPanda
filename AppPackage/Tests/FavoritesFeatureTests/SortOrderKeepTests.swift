import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import NetworkingFeature
import Testing

/// A Favorites page whose order could not be read (`sortOrder == nil`) must not erase the order the
/// server last confirmed: the sort picker would lose its mark, and `selectSortOrder` would then treat
/// every choice as a change.
@Suite
struct SortOrderKeepTests {
    @MainActor
    @Test
    func firstPageWithoutAParsedOrderKeepsTheConfirmedOrder() async {
        var state = FavoritesReducer.State()
        state.sortOrder = .favoritedTime
        state.rawLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        let result = FavoritesGalleriesResult(pageNumber: PageNumber(), galleries: [.preview])
        await store.send(.fetchGalleriesDone(index: -1, keyword: "", result: .success(result))) {
            $0.rawLoadingState[-1] = .idle
            $0.rawGalleries[-1] = [.preview]
            $0.rawPageNumber[-1] = PageNumber()
        }
        #expect(store.state.sortOrder == .favoritedTime)
    }

    @MainActor
    @Test
    func firstPageWithAParsedOrderTakesIt() async {
        var state = FavoritesReducer.State()
        state.sortOrder = .favoritedTime
        state.rawLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        let result = FavoritesGalleriesResult(
            pageNumber: PageNumber(), sortOrder: .lastUpdateTime, galleries: [.preview]
        )
        await store.send(.fetchGalleriesDone(index: -1, keyword: "", result: .success(result))) {
            $0.rawLoadingState[-1] = .idle
            $0.rawGalleries[-1] = [.preview]
            $0.rawPageNumber[-1] = PageNumber()
            $0.sortOrder = .lastUpdateTime
        }
    }

    @MainActor
    @Test
    func laterPageWithoutAParsedOrderKeepsTheConfirmedOrder() async {
        var state = FavoritesReducer.State()
        state.sortOrder = .lastUpdateTime
        state.rawGalleries[-1] = [.preview]
        state.rawFooterLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        let result = FavoritesGalleriesResult(pageNumber: PageNumber(), galleries: [])
        await store.send(.fetchMoreGalleriesDone(index: -1, result: .success(result))) {
            $0.rawFooterLoadingState[-1] = .idle
            $0.rawPageNumber[-1] = PageNumber()
        }
        #expect(store.state.sortOrder == .lastUpdateTime)
    }
}
