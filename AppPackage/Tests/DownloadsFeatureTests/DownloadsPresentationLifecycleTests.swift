import Foundation
import AppModels
import ComposableArchitecture
import Testing
import DownloadClient
@testable import DownloadsFeature
@testable import AppFeature

// The Downloads tab root and its inspector sheet used to start themselves from view `onAppear`;
// both are now started by the transition that presents them.
@MainActor
struct DownloadsPresentationLifecycleTests: DownloadFeatureTestCase {
    @Test
    func activatingTheDownloadsTabStartsItsLoad() async {
        let store = TestStore(initialState: AppReducer.State(), reducer: AppReducer.init) {
            $0.cookieClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.downloadClient = .noop
        }
        store.exhaustivity = .off

        // The tab starts on Home, so selecting Downloads is a genuine activation, not a reselect.
        await store.send(.tabBar(.setTabBarItemType(.downloads))) {
            $0.tabBarState.tabBarItemType = .downloads
        }
        await store.receive(\.downloads.onPresented) {
            $0.downloadsState.hasLoadedInitialDownloads = true
        }
        await store.receive(\.downloads.fetchDownloads)
        await store.receive(\.downloads.observeDownloads)
        await store.receive(\.downloads.fetchFolders)
        await store.finish()
    }

    @Test
    func presentingTheInspectorStartsItsInspection() async {
        let download = sampleDownload(
            gid: "135791", title: "Inspected Gallery",
            status: .failed, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)

        let store = TestStore(initialState: .init(), reducer: DownloadsReducer.init) {
            $0.downloadClient = .noop
            $0.downloadClient.loadInspection = { _ in inspection }
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.inspectorButtonTapped(download.gid))
        #expect(store.state.destination?.inspector?.gid == download.gid)
        await store.receive(\.destination.presented.inspector.onPresented)
        await store.receive(\.destination.presented.inspector.loadInspection)
        await store.receive(\.destination.presented.inspector.observeDownloads)
        await store.receive(\.destination.presented.inspector.loadInspectionDone)

        #expect(store.state.destination?.inspector?.inspection == inspection)
        await store.finish()
    }
}
