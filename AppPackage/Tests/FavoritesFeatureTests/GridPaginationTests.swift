import AnalyticsClient
import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import GalleryClient
import NetworkingFeature
import Testing
import TestingSupport

@Suite(.isolatedAppStorage)
struct GridPaginationTests {
    @MainActor
    @Test
    func repeatedTrailingVisibilityDoesNotStartAnotherRequestWhileLoading() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawPageNumber[-1] = .init(nextCursor: "1-123")
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

    /// Favorites' cursor is `gid-timestamp`, from the page's own Next link. A page of galleries already listed leaves
    /// the list's last gallery where it was, so the reducer goes on from the new cursor by itself (G-11-7).
    @MainActor
    @Test
    func aPageOfRepeatsGoesOnFromTheSitesCursor() async {
        let galleries = Gallery.previews(count: 3)
        let requestedCursors = LockIsolated<[String]>([])
        var client = GalleryClient.unimplemented
        client.fetchMoreFavoritesGalleries = { _, _, cursor, _ in
            requestedCursors.withValue({ $0.append(cursor) })
            return FavoritesGalleriesResult(pageNumber: .init(), galleries: [galleries[2]])
        }
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [galleries[0], galleries[1]]
        state.rawPageNumber[-1] = .init(nextCursor: "1-100")
        state.rawLoadingState[-1] = .idle
        state.rawFooterLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init) {
            $0.galleryClient = client
        }

        await store.send(.fetchMoreGalleriesDone(index: -1, result: .success(.init(
            pageNumber: .init(nextCursor: "2-90"), galleries: [galleries[1]]
        )))) {
            $0.rawFooterLoadingState[-1] = .idle
            $0.rawPageNumber[-1] = .init(nextCursor: "2-90")
        }
        await store.receive(\.fetchMoreGalleries) {
            $0.rawFooterLoadingState[-1] = .loading
        }
        await store.receive(\.fetchMoreGalleriesDone) {
            $0.rawFooterLoadingState[-1] = .idle
            $0.rawPageNumber[-1] = .init()
            $0.rawGalleries[-1] = galleries
        }
        #expect(requestedCursors.value == ["2-90"])
    }

    @MainActor
    @Test
    func failedNextPageKeepsExistingResultsAndMarksRetryState() async {
        var state = FavoritesReducer.State()
        state.rawGalleries[-1] = [.preview]
        state.rawFooterLoadingState[-1] = .loading
        let store = TestStore(initialState: state, reducer: FavoritesReducer.init) {
            $0.analyticsClient = .noop
        }
        await store.send(.fetchMoreGalleriesDone(index: -1, result: .failure(.networkingFailed))) {
            $0.rawFooterLoadingState[-1] = .failed(.networkingFailed)
        }
        await store.finish()
        #expect(store.state.galleries == [.preview])
    }
}
