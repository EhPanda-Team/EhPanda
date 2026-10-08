import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
@testable import ReadingFeature
import Sharing
import Testing

// A capture route to the comments or the reader passes through its gallery's detail: once the
// detail has loaded, it sends what that screen's own control sends. A route that ends at the
// detail, a route to another gallery, or a detail still loading leaves the detail where it is.
// @MainActor sits on members, as in the other Detail suites: TCA's `TestStore` is main-actor-isolated.
@Suite
struct DetailCaptureRouteTests {
    @MainActor
    @Test
    func theCommentsOpenWithNoneHighlightedOnceTheDetailLoads() async {
        let store = makeStore(route: .comments(Self.gallery))

        await store.send(.runLaunchAutomationIfNeeded) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive { action in
            guard case let .delegate(.pushComments(gid, _, _, galleryURL, _, scrollCommentID)) = action else {
                return false
            }
            return gid == Self.gallery.gid && galleryURL == Self.gallery.galleryURL && scrollCommentID == nil
        }
        await store.finish()
    }

    @MainActor
    @Test(arguments: [
        AppLaunchAutomation.CaptureRoute.reading(gallery, page: 4),
        .readingLiveText(gallery, page: 4)
    ])
    func theReaderOpensOnTheRoutedPageOnceTheDetailLoads(_ route: AppLaunchAutomation.CaptureRoute) async {
        let store = makeStore(route: route)

        await store.send(.runLaunchAutomationIfNeeded) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.updateReadingProgress, 4)
        await store.receive(\.openReading)
        await store.receive(\.destination.presented.reading.onPresented)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.destination?.reading?.readingProgress == 4)
    }

    @MainActor
    @Test(arguments: [
        AppLaunchAutomation.CaptureRoute.detail(gallery),
        .comments(otherGallery),
        .reading(otherGallery, page: 4),
        .home,
        .laboratory
    ])
    func otherRoutesLeaveTheDetail(_ route: AppLaunchAutomation.CaptureRoute) async {
        let store = makeStore(route: route)

        await store.send(.runLaunchAutomationIfNeeded)
        await store.finish()

        #expect(store.state.destination == nil)
    }

    @MainActor
    @Test
    func aDetailStillLoadingWaits() async {
        let store = makeStore(route: .comments(Self.gallery), loaded: false)

        await store.send(.runLaunchAutomationIfNeeded)
        await store.finish()

        #expect(store.state.didRunLaunchAutomation == false)
    }

    private static let gallery = Gallery(
        gid: "42", token: "abc123", title: "Routed", rating: 4.5, tags: [],
        category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
    )

    private static let otherGallery = Gallery(
        gid: "43", token: "def456", title: "Elsewhere", rating: 4, tags: [],
        category: .manga, pageCount: 12, postedDate: .init(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: URL(string: "https://example.com/g/43/def456/")
    )

    @MainActor
    private func makeStore(
        route: AppLaunchAutomation.CaptureRoute,
        loaded: Bool = true
    ) -> TestStoreOf<DetailReducer> {
        let appStorage = UserDefaults.inMemory
        let store = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = DetailReducer.State(gallery: Self.gallery)
            if loaded {
                state.galleryDetail = .preview
            }
            return TestStore(initialState: state, reducer: DetailReducer.init) {
                $0.analyticsClient = .noop
                $0.appLaunchAutomationClient = AppLaunchAutomationClient(
                    current: { AppLaunchAutomation(captureRoute: route) }
                )
                // Writing reading progress and presenting the reader both read the date.
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.defaultAppStorage = appStorage
                $0.downloadClient = .noop
            }
        }
        store.exhaustivity = .off
        return store
    }
}
