//
//  DownloadInspectorSkipTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
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
        let loadInspectionCount = UncheckedBox(0)

        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.loadingState = .idle

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in
                            continuation.finish()
                        }
                    },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in nil },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    retryPages: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) },
                    loadInspection: { _ in
                        loadInspectionCount.value += 1
                        return .success(inspection)
                    }
                )
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

        let store = TestStore(initialState: initialState, reducer: DownloadInspectorReducer.init)
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
