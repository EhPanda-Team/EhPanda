import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
@testable import ReadingFeature
import Sharing
import Testing

// A capture route that ends on the reading screen shows the reader with its control panel, with the
// action a tap on the page sends, once the reader is presented. The reading-live-text screen, a route
// to another gallery and a launch without a route leave the panel hidden.
// @MainActor sits on members: TCA's `TestStore` is main-actor-isolated.
@Suite
struct ReadingCaptureRouteTests {
    @MainActor
    @Test
    func theReadingScreenShowsThePanelOnceTheReaderIsPresented() async {
        let store = makeStore(route: .reading(.preview, page: 4))

        await store.send(.onPresented)
        await store.receive(\.toggleShowsPanel) {
            $0.showsPanel = true
        }
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test(arguments: [
        AppLaunchAutomation.CaptureRoute.readingLiveText(.preview, page: 4),
        .reading(otherGallery, page: 4),
        .detail(.preview),
        nil
    ])
    func otherLaunchesLeaveThePanelHidden(_ route: AppLaunchAutomation.CaptureRoute?) async {
        let store = makeStore(route: route)

        await store.send(.onPresented)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.showsPanel == false)
    }
}

private extension ReadingCaptureRouteTests {
    static let otherGallery = Gallery(
        gid: "43", token: "def456", title: "Elsewhere", rating: 4, tags: [],
        category: .manga, pageCount: 12, postedDate: .init(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: URL(string: "https://example.com/g/43/def456/")
    )

    @MainActor
    func makeStore(route: AppLaunchAutomation.CaptureRoute?) -> TestStoreOf<ReadingReducer> {
        let inMemoryStorage = InMemoryStorage()

        return withDependencies {
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            let store = TestStore(
                initialState: ReadingReducer.State(gallery: .preview),
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.appLaunchAutomationClient = AppLaunchAutomationClient(
                        current: { route.map({ AppLaunchAutomation(captureRoute: $0) }) }
                    )
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.date = .constant(Date(timeIntervalSince1970: 0))
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
            store.exhaustivity = .off(showSkippedAssertions: false)
            return store
        }
    }
}
