//
//  DownloadInspectorLoadTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DownloadInspectorLoadTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorReducerLoadsInspection() async {
        let download = sampleDownload(
            gid: "246810", title: "Inspector Gallery",
            status: .failed, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            loadInspection: { _ in .success(inspection) }
        )
        store.exhaustivity = .off

        await store.send(.loadInspection)
        await store.receive(\.loadInspectionDone) {
            $0.inspection = inspection
            $0.stableInspection = inspection
            $0.loadingState = .idle
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerRetryPageUsesDownloadClientRetryPages() async {
        await confirmation(expectedCount: 1) { confirm in
            let retried = UncheckedBox<[Int]>([])
            let download = sampleDownload(
                gid: "112233", title: "Retry Page Gallery",
                status: .failed, completedPageCount: 1
            )
            var initialState = DownloadInspectorReducer.State(gid: download.gid)
            initialState.inspection = sampleInspection(download: download)
            initialState.loadingState = .idle
            let store = makeInspectorStore(
                gid: download.gid,
                initialInspection: initialState.inspection,
                retryPages: { _, pageIndices in
                    retried.value = pageIndices
                    confirm()
                    return .success(())
                },
                loadInspection: { [initialState] _ in
                    guard let inspection = initialState.inspection else {
                        return .failure(.notFound)
                    }
                    return .success(inspection)
                }
            )
            store.exhaustivity = .off

            await store.send(.retryPage(2))
            #expect(retried.value == [2])
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerRetryFailedPagesMarksFailedPagesPending() async {
        let retried = UncheckedBox<[Int]>([])
        let download = sampleDownload(
            gid: "112235", title: "Retry Failed Pages Gallery",
            status: .partial, completedPageCount: 1
        )
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = sampleInspection(download: download)
        initialState.loadingState = .idle
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: initialState.inspection,
            retryPages: { _, pageIndices in
                retried.value = pageIndices
                return .success(())
            },
            loadInspection: { [initialState] _ in
                guard let inspection = initialState.inspection else {
                    return .failure(.notFound)
                }
                return .success(inspection)
            }
        )
        store.exhaustivity = .off

        await store.send(.retryFailedPages) {
            guard let inspection = $0.inspection else { return }
            $0.inspection = .init(
                download: inspection.download,
                coverURL: inspection.coverURL,
                pages: [
                    .init(
                        index: 1, status: .downloaded, relativePath: "pages/0001.jpg",
                        fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"), failure: nil
                    ),
                    .init(
                        index: 2, status: .pending, relativePath: "pages/0002.jpg",
                        fileURL: nil, failure: nil
                    )
                ]
            )
        }

        #expect(retried.value == [2])
    }

}

// MARK: - Store Factory Helpers

private extension DownloadInspectorLoadTests {
    func makeInspectorStore(
        gid: String,
        initialInspection: DownloadInspection? = nil,
        retryPages: (@Sendable (String, [Int]) async -> Result<Void, AppError>)? = nil,
        loadInspection: @escaping @Sendable (String) async -> Result<DownloadInspection, AppError>
    ) -> TestStoreOf<DownloadInspectorReducer> {
        var initialState = DownloadInspectorReducer.State(gid: gid)
        initialState.inspection = initialInspection
        if initialInspection != nil { initialState.loadingState = .idle }
        return TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in continuation.finish() }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                retryPages: retryPages ?? { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: loadInspection
            )
        }
    }
}
