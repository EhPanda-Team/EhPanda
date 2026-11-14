import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import HapticsClient
import NetworkingFeature
import Testing

/// The favorite slot and the user's own rating, kept on the gallery the Detail screen shows: what the header's
/// heart and the stars colour from. A gesture's success updates them at once; the page that is fetched
/// afterwards confirms them.
@Suite
struct DetailFavoriteStateTests {
    @MainActor
    private func makeStore(
        favoriteTagIndex: Int? = nil, favoriteTagName: String? = nil
    ) -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                // No URL: the detail refetch every successful gesture triggers has nothing to request.
                coverURL: nil, galleryURL: nil,
                favoriteTagIndex: favoriteTagIndex, favoriteTagName: favoriteTagName
            )
        )
        state.galleryDetail = .preview
        let store = TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.appLaunchAutomationClient = .none
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    @MainActor
    @Test
    func favoritingRecordsTheSlotOnTheGalleryAndTheDetail() async {
        let store = makeStore()
        await store.send(.favorGalleryDone(.success(()), favIndex: 3))
        #expect(store.state.gallery.favoriteTagIndex == 3)
        #expect(store.state.gallery.favoriteTagName == "Favorites 3")
        #expect(store.state.gallery.isFavorite)
        #expect(store.state.galleryDetail?.favoriteTagIndex == 3)
        #expect(store.state.galleryDetail?.favoriteTagName == "Favorites 3")
    }

    @MainActor
    @Test
    func aFailedFavoriteChangesNothing() async {
        let store = makeStore(favoriteTagIndex: 1, favoriteTagName: "Favorites 1")
        await store.send(.favorGalleryDone(.failure(.networkingFailed), favIndex: 3))
        #expect(store.state.gallery.favoriteTagIndex == 1)
        #expect(store.state.gallery.favoriteTagName == "Favorites 1")
    }

    @MainActor
    @Test
    func unfavoritingClearsTheSlot() async {
        let store = makeStore(favoriteTagIndex: 4, favoriteTagName: "Favorites 4")
        await store.send(.unfavorGalleryDone(.success(())))
        #expect(store.state.gallery.favoriteTagIndex == nil)
        #expect(store.state.gallery.favoriteTagName == nil)
        #expect(store.state.gallery.isFavorite == false)
        #expect(store.state.galleryDetail?.favoriteTagIndex == nil)
        #expect(store.state.galleryDetail?.favoriteTagName == nil)
    }

    @MainActor
    @Test
    func aFailedUnfavoriteKeepsTheSlot() async {
        let store = makeStore(favoriteTagIndex: 4, favoriteTagName: "Favorites 4")
        await store.send(.unfavorGalleryDone(.failure(.networkingFailed)))
        #expect(store.state.gallery.favoriteTagIndex == 4)
    }

    @MainActor
    @Test
    func ratingMarksTheGalleryRatedOnSuccessOnly() async {
        let store = makeStore()
        await store.send(.rateGalleryDone(.failure(.networkingFailed)))
        #expect(store.state.gallery.hasRated == false)
        await store.send(.rateGalleryDone(.success(())))
        #expect(store.state.gallery.hasRated)
    }

    private func response(for detail: GalleryDetail) -> GalleryDetailResponse {
        GalleryDetailResponse(galleryDetail: detail, galleryState: GalleryState(gid: "42"), apiKey: "")
    }

    @MainActor
    @Test
    func aFetchedFavoriteDetailGivesTheGalleryItsSlotAndItsRating() async {
        let store = makeStore()
        var detail = GalleryDetail.preview
        detail.favoriteTagIndex = 6
        detail.favoriteTagName = "Favorites 6"
        detail.userRating = 3.5
        detail.userRatingTint = .green
        await store.send(.fetchGalleryDetailDone(.success(response(for: detail))))
        await store.skipReceivedActions(strict: false)
        #expect(store.state.gallery.favoriteTagIndex == 6)
        #expect(store.state.gallery.favoriteTagName == "Favorites 6")
        #expect(store.state.gallery.hasRated)
        #expect(store.state.gallery.userRatingTint == .green)
    }

    @MainActor
    @Test
    func aFetchedDetailThatNoLongerSaysFavoriteClearsAStaleSlot() async {
        let store = makeStore(favoriteTagIndex: 2, favoriteTagName: "Favorites 2")
        var detail = GalleryDetail.preview
        detail.isFavorited = false
        detail.favoriteTagIndex = nil
        detail.favoriteTagName = nil
        detail.userRating = 0
        detail.userRatingTint = nil
        await store.send(.fetchGalleryDetailDone(.success(response(for: detail))))
        await store.skipReceivedActions(strict: false)
        #expect(store.state.gallery.favoriteTagIndex == nil)
        #expect(store.state.gallery.favoriteTagName == nil)
        #expect(store.state.gallery.hasRated == false)
        #expect(store.state.gallery.userRatingTint == nil)
    }
}
