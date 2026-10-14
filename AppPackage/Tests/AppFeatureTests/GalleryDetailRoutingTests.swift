import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
import LogsClient
import Sharing
import Testing
import UserDefaultsClient

// Each tab host asks the app root to open a tapped gallery's detail, and the root routes it by the
// window's size classes: a window regular in both dimensions presents it modally, any other pushes
// it onto the host's stack. Home's route is covered with the capture routes, and Downloads' with
// its download-seeded detail; these cover Favorites and Search.
//
// `Gallery.preview` has no `galleryURL`, so the opened detail starts no request.
struct GalleryDetailRoutingTests {
    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .compactHeight])
    func favoritesPushesInAWindowCompactInEitherDimension(_ window: WindowSizeClasses) async {
        let store = makeStore(window: window)

        await store.send(.favorites(.galleryTapped(.preview)))
        await store.receive(\.favorites.delegate.openGalleryDetail, .preview)
        await store.receive(\.favorites.pushGalleryDetail, .preview)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.favoritesState.path.count == 1)
        #expect(store.state.presentationState.gallery == nil)
    }

    @MainActor
    @Test
    func favoritesPresentsInARegularWindow() async {
        let store = makeStore(window: .regular)

        await store.send(.favorites(.galleryTapped(.preview)))
        await store.receive(\.favorites.delegate.openGalleryDetail, .preview)
        await store.receive(\.presentation.presentGalleryDetail)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.presentationState.gallery?.detail.gallery == .preview)
        #expect(store.state.favoritesState.path.isEmpty)
    }

    @MainActor
    @Test(arguments: [WindowSizeClasses.compactWidth, .compactHeight])
    func searchPushesInAWindowCompactInEitherDimension(_ window: WindowSizeClasses) async {
        let store = makeStore(window: window)

        await store.send(.searchRoot(.galleryTapped(.preview)))
        await store.receive(\.searchRoot.delegate.openGalleryDetail, .preview)
        await store.receive(\.searchRoot.pushGalleryDetail, .preview)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.searchRootState.path.count == 1)
        #expect(store.state.presentationState.gallery == nil)
    }

    @MainActor
    @Test
    func searchPresentsInARegularWindow() async {
        let store = makeStore(window: .regular)

        await store.send(.searchRoot(.galleryTapped(.preview)))
        await store.receive(\.searchRoot.delegate.openGalleryDetail, .preview)
        await store.receive(\.presentation.presentGalleryDetail)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.presentationState.gallery?.detail.gallery == .preview)
        #expect(store.state.searchRootState.path.isEmpty)
    }
}

private extension GalleryDetailRoutingTests {
    @MainActor
    func makeStore(window: WindowSizeClasses) -> TestStoreOf<AppReducer> {
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
                    $0.appLaunchAutomationClient = .none
                    $0.cookieClient = .noop
                    $0.date = .constant(Date(timeIntervalSince1970: 0))
                    $0.defaultAppStorage = appStorage
                    $0.defaultInMemoryStorage = inMemoryStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                    $0.logsClient = .noop
                    $0.userDefaultsClient = .noop
                }
            )
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
