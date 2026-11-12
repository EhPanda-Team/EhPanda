import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import NetworkingFeature
import Testing

@Suite
struct GridPaginationTests {
    @MainActor
    @Test
    func repeatedTrailingVisibilityDoesNotStartAnotherRequestWhileLoading() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawPageNumber[-1] = .init(lastItemTimestamp: "123", isNextButtonEnabled: true)
        state.rawFooterLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchMoreGalleries)
        await store.send(.fetchMoreGalleries)
        await store.finish()
    }

    @MainActor
    @Test
    func appendingAPageDeduplicatesAndKeepsTheQueryAndAnchor() async {
        let galleries = Gallery.previews(count: 2)
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [galleries[0]]
        state.rawLoadingState[-1] = .idle
        state.rawFooterLoadingState[-1] = .loading
        state.keyword = "library query"
        state.visibleGalleryID = galleries[0].id
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchMoreGalleriesDone(index: -1, result: .success(.init(
            pageNumber: .init(), galleries: galleries
        )))) {
            $0.rawFooterLoadingState[-1] = .idle
            $0.rawPageNumber[-1] = .init()
            $0.rawGalleries[-1] = galleries
        }
        await store.send(.fetchMoreGalleries)
        await store.finish()
        #expect(store.state.keyword == "library query")
        #expect(store.state.visibleGalleryID == galleries[0].id)
    }

    @MainActor
    @Test
    func failedNextPageKeepsExistingResultsAndMarksRetryState() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawFooterLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init)
        await store.send(.fetchMoreGalleriesDone(index: -1, result: .failure(.networkingFailed))) {
            $0.rawFooterLoadingState[-1] = .failed(.networkingFailed)
        }
        await store.finish()
        #expect(store.state.galleries == [.preview])
    }
}
