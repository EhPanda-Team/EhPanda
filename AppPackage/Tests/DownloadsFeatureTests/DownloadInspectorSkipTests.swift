import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. It is applied
// per member rather than to the suite so the type's `DownloadFeatureTestCase` conformance
// stays nonisolated — a main-actor conformance cannot be used from the `@Sendable`
// dependency closures these stores install.
struct DownloadInspectorSkipTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorSkipsReloadWhenObservedDownloadDidNotChange() async {
        let download = sampleDownload(
            gid: "112244",
            title: "Stable Inspector Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let loadInspectionCount = LockedBox(0)

        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.loadingState = .idle

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadInspection = { _ in
                    loadInspectionCount.value += 1
                    return inspection
                }
            }
        )
        store.exhaustivity = .off

        await store.send(.observeDownloadsDone([download]))
        #expect(loadInspectionCount.value == 0)
    }

    @MainActor
    @Test
    func testDownloadInspectorIgnoresStaleInspectionResponses() async {
        let originalDownload = sampleDownload(
            gid: "112245",
            title: "Stale Inspector Gallery",
            status: .partial,
            completedPageCount: 1
        )
        let refreshedDownload = sampleDownload(
            gid: "112245",
            title: "Stale Inspector Gallery",
            status: .partial,
            completedPageCount: 2
        )
        let staleInspection = sampleInspection(download: originalDownload)
        let refreshedInspection = sampleInspection(download: refreshedDownload)

        let firstRequestID = UUID()
        let secondRequestID = UUID()
        var initialState = DownloadInspectorReducer.State(gid: originalDownload.gid)
        initialState.loadingState = .loading
        initialState.inspectionRequestID = secondRequestID

        let store = TestStore(initialState: initialState, reducer: DownloadInspectorReducer.init) {
            $0.analyticsClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.loadInspectionDone(firstRequestID, .success(staleInspection)))
        #expect(store.state.inspection == nil)

        await store.send(.loadInspectionDone(secondRequestID, .success(refreshedInspection))) {
            $0.inspection = refreshedInspection
            $0.stableInspection = refreshedInspection
            $0.loadingState = .idle
        }
    }

}
