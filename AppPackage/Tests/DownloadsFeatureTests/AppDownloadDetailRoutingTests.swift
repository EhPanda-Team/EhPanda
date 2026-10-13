import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import DownloadsFeature
import Foundation
import HapticsClient
import SwiftUI
import Testing

// A tapped download asks the app root to open its detail, and the root routes it by the window's
// size classes: a window regular in both dimensions presents it modally, any other pushes it onto
// the Downloads stack. Either way the detail is seeded from the download, so it renders offline.
// `@MainActor` sits on members so the `DownloadFeatureTestCase` conformance stays nonisolated.
struct AppDownloadDetailRoutingTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func aRegularWindowPresentsTheDownloadModally() async {
        let download = sampleDownload(gid: "123456", title: "Completed Gallery", status: .completed)
        let store = makeStore(download: download, window: .init(horizontal: .regular, vertical: .regular))

        await store.send(.downloads(.galleryTapped(download.gid)))
        await store.receive(\.downloads.delegate.openGalleryDetail, download)
        await store.receive(\.presentation.presentGalleryDetail)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.presentationState.detail?.downloadBadge?.status == .completed)
        #expect(store.state.downloadsState.path.isEmpty)
    }

    @MainActor
    @Test(arguments: [
        WindowSizeClasses(horizontal: .compact, vertical: .regular),
        WindowSizeClasses(horizontal: .regular, vertical: .compact)
    ])
    func aWindowCompactInEitherDimensionPushesTheDownload(_ window: WindowSizeClasses) async {
        let download = sampleDownload(gid: "123456", title: "Completed Gallery", status: .completed)
        let store = makeStore(download: download, window: window)

        await store.send(.downloads(.galleryTapped(download.gid)))
        await store.receive(\.downloads.delegate.openGalleryDetail, download)
        await store.receive(\.downloads.pushGalleryDetail, download)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.downloadsState.path.count == 1)
        #expect(store.state.presentationState.detail == nil)
    }
}

private extension AppDownloadDetailRoutingTests {
    @MainActor
    func makeStore(download: DownloadedGallery, window: WindowSizeClasses) -> TestStoreOf<AppReducer> {
        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = true
        initialState.windowSizeClasses = window
        initialState.downloadsState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.appLaunchAutomationClient = .none
                $0.cookieClient = .noop
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.downloadClient = .noop
                // The opened detail observes the library, which still holds the download, so the
                // badge it was seeded with stays in place.
                $0.downloadClient.observeDownloads = {
                    .init { continuation in
                        continuation.yield([download])
                        continuation.finish()
                    }
                }
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }
}
