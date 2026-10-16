import AnalyticsClient
@testable import AppFeature
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DetailFeature
import DownloadClient
import DownloadsFeature
import Foundation
import HapticsClient
import SettingFeature
import SwiftUI
import Testing

// A tapped download opens native inspector content at every window size, seeded for offline access.
// SwiftUI owns the adaptive column/sheet presentation; the app does not select it by device identity.
struct AppDownloadDetailRoutingTests: DownloadFeatureTestCase {
    @MainActor
    @Test(arguments: [
        WindowSizeClasses(horizontal: .regular, vertical: .regular),
        WindowSizeClasses(horizontal: .compact, vertical: .regular),
        WindowSizeClasses(horizontal: .regular, vertical: .compact)
    ])
    func everyWindowUsesTheSameSeededInspector(_ window: WindowSizeClasses) async {
        let download = sampleDownload(gid: "123456", title: "Completed Gallery", status: .completed)
        let store = makeStore(download: download, window: window)

        await store.send(.downloads(.galleryTapped(download.gid)))
        await store.receive(\.downloads.inspection.presented.details.onPresented)
        await store.skipReceivedActions(strict: false)
        await store.skipInFlightEffects(strict: false)

        #expect(store.state.downloadsState.inspection?.details?.detail.downloadBadge?.status == .completed)
        #expect(store.state.downloadsState.inspectionOriginID == download.gid)
        #expect(store.state.downloadsState.path.isEmpty)
        #expect(store.state.presentationState.gallery == nil)
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
