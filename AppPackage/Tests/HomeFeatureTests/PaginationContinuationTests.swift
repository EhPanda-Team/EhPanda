import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
import GalleryClient
import HapticsClient
@testable import HomeFeature
import NetworkingFeature
import Testing

/// A list fetches its next page when its last gallery scrolls into view, so a page that adds no new gallery leaves
/// nothing new to scroll to and the list would stop there (G-11-7). These cases pin the reducers going on by
/// themselves from the site's own cursor, and stopping when the cursor does not move.
///
/// The rule lives in the reducers, which both layouts share: the row list and the grid only report that the last
/// gallery became visible. `GalleryLayoutUITests` drives the same repeated page through both layouts.
@Suite
struct PaginationContinuationTests {
    private static let listed = Gallery.previews(count: 2)
    private static let new = Gallery.previews(count: 1)

    @MainActor
    @Test
    func aFrontPageOfRepeatsGoesOnFromTheSitesCursor() async {
        let requestedCursors = LockIsolated<[String]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = FrontPageReducer.State()
            state.galleries = Self.listed
            state.pageNumber = PageNumber(nextCursor: "first")
            state.footerLoadingState = .loading
            let store = TestStore(initialState: state, reducer: FrontPageReducer.init) {
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
                $0.galleryClient = .frontPageNextPage(Self.new, cursor: nil, recordingInto: requestedCursors)
            }

            // The page after `first` holds only a gallery already listed, under a cursor of its own.
            await store.send(.fetchMoreGalleriesDone(.success(GalleriesResult(
                pageNumber: PageNumber(nextCursor: "repeat"), galleries: [Self.listed[1]]
            )))) {
                $0.footerLoadingState = .idle
                $0.pageNumber = PageNumber(nextCursor: "repeat")
            }
            await store.receive(\.fetchMoreGalleries) {
                $0.footerLoadingState = .loading
            }
            await store.receive(\.fetchMoreGalleriesDone) {
                $0.footerLoadingState = .idle
                $0.pageNumber = PageNumber()
                $0.galleries = Self.listed + Self.new
            }
        }
        #expect(requestedCursors.value == ["repeat"])
    }

    /// A site that hands back the cursor the request was made from has not moved: going on would ask for the same
    /// page again, forever.
    @MainActor
    @Test
    func aFrontPageOfRepeatsUnderTheSameCursorStops() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = FrontPageReducer.State()
            state.galleries = Self.listed
            state.pageNumber = PageNumber(nextCursor: "first")
            state.footerLoadingState = .loading
            let store = TestStore(initialState: state, reducer: FrontPageReducer.init) {
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
                $0.galleryClient = .unimplemented
            }

            await store.send(.fetchMoreGalleriesDone(.success(GalleriesResult(
                pageNumber: PageNumber(nextCursor: "first"), galleries: [Self.listed[0]]
            )))) {
                $0.footerLoadingState = .idle
            }
            await store.finish()
        }
    }

    /// The last page has no cursor, so a last page of repeats ends the list.
    @MainActor
    @Test
    func aLastFrontPageOfRepeatsStops() async {
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = FrontPageReducer.State()
            state.galleries = Self.listed
            state.pageNumber = PageNumber(nextCursor: "first")
            state.footerLoadingState = .loading
            let store = TestStore(initialState: state, reducer: FrontPageReducer.init) {
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
                $0.galleryClient = .unimplemented
            }

            await store.send(.fetchMoreGalleriesDone(.success(GalleriesResult(
                pageNumber: PageNumber(), galleries: Self.listed
            )))) {
                $0.footerLoadingState = .idle
                $0.pageNumber = PageNumber()
            }
            await store.finish()
        }
    }

    /// An empty first page keeps its cursor, so the fetch it starts has somewhere to go on from. It used to be
    /// dropped, and the fetch then had neither a cursor nor a last gallery and did nothing.
    @MainActor
    @Test
    func anEmptyFirstFrontPageGoesOnFromItsCursor() async {
        let requestedCursors = LockIsolated<[String]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = FrontPageReducer.State()
            state.loadingState = .loading
            let store = TestStore(initialState: state, reducer: FrontPageReducer.init) {
                $0.analyticsClient = .noop
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
                $0.galleryClient = .frontPageNextPage(Self.new, cursor: nil, recordingInto: requestedCursors)
            }

            await store.send(.fetchGalleriesDone(.success(GalleriesResult(
                pageNumber: PageNumber(nextCursor: "after-empty"), galleries: []
            )))) {
                $0.loadingState = .failed(.notFound)
                $0.pageNumber = PageNumber(nextCursor: "after-empty")
            }
            await store.receive(\.fetchMoreGalleries) {
                $0.footerLoadingState = .loading
            }
            await store.receive(\.fetchMoreGalleriesDone) {
                $0.footerLoadingState = .idle
                $0.loadingState = .idle
                $0.pageNumber = PageNumber()
                $0.galleries = Self.new
            }
        }
        #expect(requestedCursors.value == ["after-empty"])
    }

    /// Toplists number their pages. A ranking shifts while it is read, so the next page can repeat what is listed; its
    /// page index still moves, so the list goes on to the page after it.
    @MainActor
    @Test
    func toplistsGoOnPastARepeatedPageByItsIndex() async {
        let requestedPages = LockIsolated<[Int]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            var state = ToplistsReducer.State()
            state.rawGalleries[.yesterday] = Self.listed
            state.rawPageNumber[.yesterday] = PageNumber(current: 0, maximum: 2)
            state.rawLoadingState[.yesterday] = .idle
            let store = TestStore(initialState: state, reducer: ToplistsReducer.init) {
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
                $0.galleryClient = .toplistsPages(
                    [1: [Self.listed[1]], 2: Self.new], maximum: 2, recordingInto: requestedPages
                )
            }

            await store.send(.fetchMoreGalleries) {
                $0.rawFooterLoadingState[.yesterday] = .loading
            }
            await store.receive(\.fetchMoreGalleriesDone) {
                $0.rawFooterLoadingState[.yesterday] = .idle
                $0.rawPageNumber[.yesterday] = PageNumber(current: 1, maximum: 2)
            }
            await store.receive(\.fetchMoreGalleries) {
                $0.rawFooterLoadingState[.yesterday] = .loading
            }
            await store.receive(\.fetchMoreGalleriesDone) {
                $0.rawFooterLoadingState[.yesterday] = .idle
                $0.rawPageNumber[.yesterday] = PageNumber(current: 2, maximum: 2)
                $0.rawGalleries[.yesterday] = Self.listed + Self.new
            }
            // The last page: nothing is left to fetch.
            await store.send(.fetchMoreGalleries)
        }
        #expect(requestedPages.value == [1, 2])
    }
}

extension GalleryClient {
    /// Front Page's next page answers `galleries` under `cursor`, recording the cursor each request sent.
    fileprivate static func frontPageNextPage(
        _ galleries: [Gallery], cursor: String?, recordingInto requested: LockIsolated<[String]>
    ) -> Self {
        var client = Self.unimplemented
        client.fetchMoreFrontPageGalleries = { _, _, sentCursor in
            requested.withValue({ $0.append(sentCursor) })
            return GalleriesResult(pageNumber: PageNumber(nextCursor: cursor), galleries: galleries)
        }
        return client
    }

    /// Toplists answer each numbered page from `pages`, recording the page each request asked for.
    fileprivate static func toplistsPages(
        _ pages: [Int: [Gallery]], maximum: Int, recordingInto requested: LockIsolated<[Int]>
    ) -> Self {
        var client = Self.unimplemented
        client.fetchMoreToplistsGalleries = { _, _, page in
            requested.withValue({ $0.append(page) })
            return (pageNumber: PageNumber(current: page, maximum: maximum), galleries: pages[page] ?? [])
        }
        return client
    }
}
