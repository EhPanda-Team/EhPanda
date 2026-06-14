//
//  DownloadInspectorRetryTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DownloadInspectorRetryTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorKeepsRetriedPagesPendingWhileRetryWorkRemainsActive() async {
        let download = sampleDownload(
            gid: "112236", title: "Retry Pending Gallery",
            status: .partial, completedPageCount: 1
        )
        let refreshedInspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = sampleInspection(download: download)
        initialState.stableInspection = sampleInspection(download: download)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in .success(refreshedInspection) }
        )
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(refreshedInspection))) {
            $0.inspection = .init(
                download: download, coverURL: refreshedInspection.coverURL,
                pages: [
                    refreshedInspection.pages[0],
                    .init(
                        index: 2, status: .pending,
                        relativePath: "\(download.gid)_\(download.token)_2.jpg",
                        fileURL: nil, failure: nil
                    )
                ]
            )
            $0.loadingState = .idle
            $0.retryingPageIndices = [2]
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorClearsRetryingPagesAfterRetrySettlesWithFailure() async {
        let initialDownload = sampleDownload(
            gid: "112237", title: "Retry Failure Gallery",
            status: .partial, completedPageCount: 1
        )
        let settledDownload = sampleDownload(
            gid: "112237", title: "Retry Failure Gallery", status: .partial,
            completedPageCount: 1, lastError: .init(code: .networkingFailed, message: "Network Error")
        )
        let settledInspection = sampleInspection(download: settledDownload)
        var initialState = DownloadInspectorReducer.State(gid: initialDownload.gid)
        initialState.inspection = sampleInspection(download: initialDownload)
        initialState.stableInspection = sampleInspection(download: initialDownload)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in .success(settledInspection) }
        )
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(settledInspection))) {
            $0.inspection = settledInspection
            $0.stableInspection = settledInspection
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorRestoresStableInspectionWhenRetryReloadFails() async {
        let download = sampleDownload(
            gid: "112238", title: "Retry Reload Failure Gallery",
            status: .partial, completedPageCount: 1
        )
        let stableInspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = .init(
            download: download, coverURL: stableInspection.coverURL,
            pages: [
                stableInspection.pages[0],
                .init(
                    index: 2, status: .pending,
                    relativePath: "\(download.gid)_\(download.token)_2.jpg",
                    fileURL: nil, failure: nil
                )
            ]
        )
        initialState.stableInspection = stableInspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in .failure(.networkingFailed) }
        )
        store.exhaustivity = .off

        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .failure(.networkingFailed))) {
            $0.inspection = stableInspection
            $0.loadingState = .failed(.networkingFailed)
            $0.retryingPageIndices = []
        }
    }

}

// MARK: - Store Factory Helpers

private extension DownloadInspectorRetryTests {
    func makeRetryTestStore(
        initialState: DownloadInspectorReducer.State,
        loadInspection: @escaping @Sendable (String) async -> Result<DownloadInspection, AppError>
    ) -> TestStoreOf<DownloadInspectorReducer> {
        TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in continuation.finish() }
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
                    loadInspection: loadInspection
                )
            }
        )
    }
}
