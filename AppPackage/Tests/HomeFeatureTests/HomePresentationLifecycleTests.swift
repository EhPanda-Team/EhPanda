import Foundation
import AppModels
import ComposableArchitecture
import CustomDump
import DownloadClient
import Testing
@testable import HomeFeature

// Presentation-driven lifecycle: pushing a screen is what starts its work, so these tests assert the
// load effects fire on the navigation transition rather than on a view callback, and that the guards
// which used to live in the views keep a re-presentation from refetching.
//
// Only History is exercised end to end through the stack: its `fetchGalleries` reads local browsing
// history, so an empty history settles without a network request. The other sub-pages fetch over the
// network from a request type that takes no injectable session, so their presentation actions are
// asserted directly against a populated state instead (see 11-07-SUMMARY.md).
@MainActor
struct HomePresentationLifecycleTests {
    @Test
    func pushingHistoryStartsItsLoad() async {
        let store = makeHomeStore()

        await store.send(.miscTapped(.history)) {
            $0.path.append(.history(HistoryReducer.State()))
        }
        await store.receive(\.path[id: 0].history.onPresented)
        await store.receive(\.path[id: 0].history.observeDownloads)
        await store.receive(\.path[id: 0].history.fetchGalleries) {
            $0.path[id: 0, case: \.history]?.loadingState = .failed(.notFound)
        }
        await store.finish()
    }

    // Gallery detail is reached from five pushing hosts and two modal routes. The push shape goes
    // through `GalleryNavigation.presentationEffect`, asserted here on Home (whose path nests the
    // gallery stack under a `.gallery` case — the awkward embed of the five); the modal shape is
    // asserted in AppFeatureTests. `Gallery.preview` has no `galleryURL`, so the detail fetch
    // short-circuits and no network request is made.
    @Test
    func pushingGalleryDetailStartsItsLoad() async {
        let store = makeHomeStore()
        store.exhaustivity = .off

        await store.send(.pushGalleryDetail(.preview))
        await store.receive(\.path[id: 0].gallery.detail.onPresented)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.path.count == 1)
    }

    // A1: TCA's `forEach` cancels a child's in-flight effects when its element is popped, so the
    // long-running download observation started at presentation cannot outlive the screen.
    @Test
    func poppingCancelsTheChildObservation() async {
        let store = makeHomeStore(downloadClient: .neverEndingObservation)

        await store.send(.miscTapped(.history)) {
            $0.path.append(.history(HistoryReducer.State()))
        }
        await store.receive(\.path[id: 0].history.onPresented)
        await store.receive(\.path[id: 0].history.observeDownloads)
        await store.receive(\.path[id: 0].history.fetchGalleries) {
            $0.path[id: 0, case: \.history]?.loadingState = .failed(.notFound)
        }

        await store.send(.path(.popFrom(id: 0))) {
            $0.path.removeAll()
        }
        // Completes only because the orphaned observation was cancelled with its element.
        await store.finish()
    }

    @Test
    func homeTabPresentationSkipsFetchWhenAlreadyPopulated() async {
        let store = TestStore(
            initialState: {
                var state = HomeReducer.State()
                state.popularGalleries = [.preview]
                return state
            }(),
            reducer: HomeReducer.init
        )

        await store.send(.onPresented)
        await store.finish()
    }

    @Test
    func historyPresentationSkipsFetchWhenAlreadyPopulated() async {
        let store = TestStore(
            initialState: {
                var state = HistoryReducer.State()
                state.galleries = [.preview]
                return state
            }(),
            reducer: HistoryReducer.init,
            withDependencies: { $0.downloadClient = .noop }
        )

        await store.send(.onPresented)
        await store.receive(\.observeDownloads)
        await store.finish()
    }

    @Test
    func frontpagePresentationSkipsFetchWhenAlreadyPopulated() async {
        let store = TestStore(
            initialState: {
                var state = FrontpageReducer.State()
                state.galleries = [.preview]
                return state
            }(),
            reducer: FrontpageReducer.init
        )

        await store.send(.onPresented)
        await store.finish()
    }

    @Test
    func popularPresentationSkipsFetchWhenAlreadyPopulated() async {
        let store = TestStore(
            initialState: {
                var state = PopularReducer.State()
                state.galleries = [.preview]
                return state
            }(),
            reducer: PopularReducer.init
        )

        await store.send(.onPresented)
        await store.finish()
    }

    @Test
    func toplistsPresentationSkipsFetchWhenAlreadyPopulated() async {
        let store = TestStore(
            initialState: {
                var state = ToplistsReducer.State()
                state.rawGalleries[state.type] = [.preview]
                return state
            }(),
            reducer: ToplistsReducer.init
        )

        await store.send(.onPresented)
        await store.finish()
    }

    // Watched is login-gated: presenting it while logged out observes downloads but fetches nothing,
    // matching the `didLogin` check the view used to perform.
    @Test
    func watchedPresentationSkipsFetchWhenLoggedOut() async {
        let store = TestStore(
            initialState: WatchedReducer.State(),
            reducer: WatchedReducer.init,
            withDependencies: {
                $0.cookieClient = .noop
                $0.downloadClient = .noop
            }
        )

        await store.send(.onPresented)
        await store.receive(\.observeDownloads)
        await store.finish()
    }
}

private extension HomePresentationLifecycleTests {
    func makeHomeStore(downloadClient: DownloadClient = .noop) -> TestStoreOf<HomeReducer> {
        let appStorage = UserDefaults.inMemory

        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = HomeReducer.State()
            // Populated so the Home root's own presentation load stays out of these assertions.
            state.popularGalleries = [.preview]

            return TestStore(
                initialState: state,
                reducer: HomeReducer.init,
                withDependencies: {
                    $0.cookieClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.downloadClient = downloadClient
                    $0.date = .constant(.init(timeIntervalSince1970: 0))
                }
            )
        }
    }
}

private extension DownloadClient {
    // A stream that never yields and never finishes, so the test fails by hanging if the child's
    // observation survives its screen being popped.
    static var neverEndingObservation: Self {
        var client = Self.noop
        client.observeDownloads = { AsyncStream { _ in } }
        return client
    }
}
