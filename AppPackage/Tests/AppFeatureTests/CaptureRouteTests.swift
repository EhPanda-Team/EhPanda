import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import CustomDump
import DetailFeature
import DownloadClient
import Foundation
import HapticsClient
import HomeFeature
import LibraryClient
import LogsClient
import ReadingFeature
import SearchFeature
import SettingFeature
import Sharing
import Testing
import UserDefaultsClient

// A marketing capture opens each of its eight screens through the app's own navigation. These
// cases build each screen's route from the selection and drive the launch automation that follows
// it, through the actions a person's taps send, in a compact window and in a regular one.
struct CaptureRouteTests {
    // MARK: Routes

    @Test(arguments: CaptureScreen.allCases)
    func everyScreenHasARouteShowingTheSelectedGallery(_ screen: CaptureScreen) async throws {
        let fixture = try MarketingFixtureBuilder.standard().addingFlowPage().addingLiveTextRecord(LiveTextRecordFile())
        let scene = try makeScene(fixture, scenarioID: screen.rawValue)
        let popular = try await scene.homeClient.fetchPopularGalleries(.ehentai, Filter())
        // The flow gallery is built exactly as Home's card shows it.
        let gallery = try #require(popular.first(where: { $0.gid == MarketingFixtureBuilder.flowGID }))

        let expected: AppLaunchAutomation.CaptureRoute = switch screen {
        case .home:
            .home
        case .detail:
            .detail(gallery)
        case .comments:
            .comments(gallery)
        case .filters:
            .filters
        case .reading:
            .reading(gallery, page: MarketingFixtureBuilder.flowPage)
        case .readingLiveText:
            .readingLiveText(gallery, page: MarketingFixtureBuilder.flowPage)
        case .downloads:
            .downloads
        case .laboratory:
            .laboratory
        }
        expectNoDifference(scene.route, expected)
        // `Gallery` equality compares gids alone.
        switch scene.route {
        case .detail(let routed), .comments(let routed), .reading(let routed, _), .readingLiveText(let routed, _):
            expectNoDifference(routed.title, gallery.title)
            expectNoDifference(routed.coverURL, gallery.coverURL)
            expectNoDifference(routed.galleryURL, gallery.galleryURL)
        case .home, .filters, .downloads, .laboratory:
            break
        }
    }

    @Test
    func theLiveTextScreenOpensTheLiveTextGallery() async throws {
        let fixture = try MarketingFixtureBuilder.standard().addingFlowPage().showingLiveText(of: "102")
        let scene = try makeScene(fixture, scenarioID: CaptureScreen.readingLiveText.rawValue)
        let popular = try await scene.homeClient.fetchPopularGalleries(.ehentai, Filter())
        let gallery = try #require(popular.first(where: { $0.gid == "102" }))

        expectNoDifference(scene.route, .readingLiveText(gallery, page: MarketingFixtureBuilder.flowPage))
        expectNoDifference(scene.liveText?.gid, "102")
        expectNoDifference(scene.liveText?.page, MarketingFixtureBuilder.flowPage)
    }

    @Test(arguments: [CaptureScreen.reading, .readingLiveText])
    func aReaderPageWhoseImageTheFixtureLacksIsRefused(_ screen: CaptureScreen) throws {
        let missingPage = "the fixture holds no image of page 1 of gallery \(MarketingFixtureBuilder.flowGID)"
        #expect(throws: CaptureFailure.malformedScene(missingPage)) {
            try makeScene(try MarketingFixtureBuilder.standard(), scenarioID: screen.rawValue)
        }
    }

    @Test
    func theCaptureRouteIsTheLaunchsOnlyAutomation() throws {
        let scene = try makeScene(try MarketingFixtureBuilder.standard(), scenarioID: "comments")
        let storage = try CaptureStorage.reset(at: makeTemporaryDirectory().appending(path: "EhPandaCapture"))

        try withDependencies {
            CaptureScenePreparation.isolate(
                &$0,
                scene: scene,
                storage: storage,
                libraryClient: .noop,
                downloads: .empty
            )
        } operation: {
            @Dependency(\.appLaunchAutomationClient) var appLaunchAutomationClient
            let automation = try #require(appLaunchAutomationClient.current())
            expectNoDifference(automation.captureRoute, scene.route)
            #expect(automation.initialTab == nil)
            #expect(automation.autoDownloadGID == nil)
            #expect(automation.loginCookies == nil)
            #expect(automation.galleryURL == nil)
        }
    }

    // MARK: Launch

    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .regular])
    func homeOpensWithoutNavigating(_ window: WindowSizeClasses) async {
        let store = makeStore(route: .home, window: window)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.finish()
    }

    @MainActor
    @Test
    func aGalleryScreenStartsWithATapOnItsCardThatACompactWindowPushes() async {
        let gallery = Self.gallery
        let store = makeStore(route: .comments(gallery), window: .compactWidth)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.home.galleryTapped, gallery)
        await store.receive(\.home.delegate.openGalleryDetail, gallery)
        await store.receive(\.home.pushGalleryDetail, gallery)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.homeState.path.last?.gallery?.detail?.gallery == gallery)
        #expect(store.state.presentationState.detail == nil)
    }

    @MainActor
    @Test
    func aGalleryScreenStartsWithATapOnItsCardThatARegularWindowPresents() async {
        let gallery = Self.gallery
        let store = makeStore(route: .reading(gallery, page: 4), window: .regular)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.home.galleryTapped, gallery)
        await store.receive(\.home.delegate.openGalleryDetail, gallery)
        await store.receive(\.presentation.presentGalleryDetail)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.presentationState.detail?.gallery == gallery)
        #expect(store.state.homeState.path.isEmpty)
    }

    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .regular])
    func filtersOpenFromTheSearchTab(_ window: WindowSizeClasses) async {
        let store = makeStore(route: .filters, window: window)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType, .search)
        await store.receive(\.searchRoot.filtersButtonTapped)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.tabBarState.tabBarItemType == .search)
        #expect(store.state.searchRootState.destination?.is(\.filters) == true)
    }

    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .regular])
    func downloadsOpenAsTheirTab(_ window: WindowSizeClasses) async {
        let store = makeStore(route: .downloads, window: window)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType, .downloads)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.tabBarState.tabBarItemType == .downloads)
    }

    @MainActor
    @Test
    func theLaboratoryOpensInTheSettingTabInACompactWindow() async {
        let store = makeStore(route: .laboratory, window: .compactWidth)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType, .setting)
        await store.receive(\.setting.settingRowTapped, .laboratory)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.tabBarState.tabBarItemType == .setting)
        #expect(store.state.settingState.path.last?.is(\.laboratory) == true)
        #expect(store.state.presentationState.destination == nil)
    }

    @MainActor
    @Test
    func theLaboratoryOpensInTheSettingSheetInARegularWindow() async {
        let store = makeStore(route: .laboratory, window: .regular)

        await store.send(.runLaunchAutomation) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.tabBar.setTabBarItemType, .setting)
        await store.receive(\.setting.settingRowTapped, .laboratory)
        await store.skipReceivedActions(strict: false)
        await store.finish()

        #expect(store.state.tabBarState.tabBarItemType == .home)
        #expect(store.state.presentationState.destination?.is(\.setting) == true)
        #expect(store.state.settingState.path.last?.is(\.laboratory) == true)
    }

    /// A gallery without a URL, so a pushed detail starts no request.
    private static let gallery = Gallery(
        gid: MarketingFixtureBuilder.flowGID,
        token: MarketingFixtureBuilder.token,
        title: "Flow",
        rating: 4,
        tags: [],
        category: .doujinshi,
        uploader: nil,
        pageCount: 31,
        postedDate: .distantPast,
        coverURL: nil,
        galleryURL: nil
    )
}

private extension CaptureRouteTests {
    @MainActor
    func makeStore(
        route: AppLaunchAutomation.CaptureRoute,
        window: WindowSizeClasses
    ) -> TestStoreOf<AppReducer> {
        let appStorage = UserDefaults.inMemory
        let inMemoryStorage = InMemoryStorage()

        let store = withDependencies {
            $0.defaultAppStorage = appStorage
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            var initialState = AppReducer.State()
            initialState.windowSizeClasses = window
            initialState.settingState.hasLoadedInitialSetting = true
            return TestStore(
                initialState: initialState,
                reducer: AppReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.appLaunchAutomationClient = AppLaunchAutomationClient(
                        current: { AppLaunchAutomation(captureRoute: route) }
                    )
                    $0.cookieClient = .noop
                    $0.date = .constant(UITestAutomation.fixedDate)
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.homeClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}

extension MarketingFixtureBuilder {
    /// The selection's flow gallery and the one page of it the standard fixture names.
    static let flowGID = "101"
    static let flowPage = 1
    static let flowPageData = Data("page".utf8)

    /// The fixture with the reading-live-text screen on `gid` instead of the flow gallery: the image
    /// of its page and a Live Text record of that page.
    func showingLiveText(of gid: String) throws -> Self {
        var fixture = self
        fixture.liveTextGallery = gid
        fixture.files += [
            FixtureFile(
                kind: .page,
                gid: gid,
                index: Self.flowPage,
                url: "https://abc.hath.network/h/0001/keystamp=0;fileindex=2;xres=1280/1.webp",
                path: "assets/\(gid)/pages/\(Self.flowPage).webp",
                mime: "image/webp",
                data: Self.flowPageData
            ),
            FixtureFile(
                kind: .liveText,
                gid: gid,
                index: Self.flowPage,
                url: nil,
                path: "records/\(gid)/liveText/\(Self.flowPage).json",
                mime: "application/json",
                data: try LiveTextRecordFile(gid: gid).data()
            )
        ]
        return fixture
    }

    /// The standard fixture plus the image of the flow gallery's page, which the reader shows.
    func addingFlowPage() -> Self {
        var fixture = self
        fixture.files.append(
            FixtureFile(
                kind: .page,
                gid: Self.flowGID,
                index: Self.flowPage,
                url: "https://abc.hath.network/h/0000/keystamp=0;fileindex=1;xres=1280/1.webp",
                path: "assets/\(Self.flowGID)/pages/\(Self.flowPage).webp",
                mime: "image/webp",
                data: Self.flowPageData
            )
        )
        return fixture
    }
}
