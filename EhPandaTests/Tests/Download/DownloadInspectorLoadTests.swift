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
            loadInspection: { _ in inspection }
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
                },
                loadInspection: { [initialState] _ in
                    guard let inspection = initialState.inspection else {
                        throw AppError.notFound
                    }
                    return inspection
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
            },
            loadInspection: { [initialState] _ in
                guard let inspection = initialState.inspection else {
                    throw AppError.notFound
                }
                return inspection
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
                        index: 1, status: .downloaded,
                        relativePath: "\(download.gid)_\(download.token)_1.jpg",
                        fileURL: URL(fileURLWithPath: "/tmp/0001.jpg"), failure: nil
                    ),
                    .init(
                        index: 2, status: .pending,
                        relativePath: "\(download.gid)_\(download.token)_2.jpg",
                        fileURL: nil, failure: nil
                    )
                ]
            )
        }

        #expect(retried.value == [2])
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerValidateImageDataUsesCurrentGallery() async {
        let validatedGID = UncheckedBox<String?>(nil)
        let download = sampleDownload(
            gid: "112236", title: "Validate Gallery",
            status: .completed, pageCount: 2
        )
        let inspection = sampleInspection(download: download)
        let refreshedInspection = DownloadInspection(
            download: download,
            coverURL: inspection.coverURL,
            pages: inspection.pages.map {
                .init(
                    index: $0.index,
                    status: .downloaded,
                    relativePath: $0.relativePath,
                    fileURL: $0.fileURL,
                    failure: nil
                )
            }
        )
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            validateImageData: { gid in
                validatedGID.value = gid
                return .valid
            },
            loadInspection: { gid in
                guard gid == download.gid else { throw AppError.notFound }
                return refreshedInspection
            }
        )
        store.exhaustivity = .off

        await store.send(.validateImageData) {
            $0.isValidatingImageData = true
        }
        await store.receive(\.validateImageDataDone) {
            $0.isValidatingImageData = false
            $0.hudConfig = .success(
                caption: L10n.Localizable.DownloadsView.Inspector.Hud.imageDataValid
            )
            $0.route = .hud
        }
        await store.receive(\.loadInspection)
        await store.receive(\.loadInspectionDone) {
            $0.inspection = refreshedInspection
            $0.stableInspection = refreshedInspection
            $0.loadingState = .idle
        }

        #expect(validatedGID.value == download.gid)
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerTogglePauseUsesCurrentGallery() async {
        let toggledGID = UncheckedBox<String?>(nil)
        let download = sampleDownload(
            gid: "112238", title: "Toggle Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            togglePause: { gid in
                toggledGID.value = gid
            },
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause)
        await store.receive(\.toggleDownloadPauseDone)

        #expect(toggledGID.value == download.gid)
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerTogglePauseUsesQueuedGallery() async {
        let toggledGID = UncheckedBox<String?>(nil)
        let download = sampleDownload(
            gid: "112240", title: "Queued Gallery",
            status: .queued, completedPageCount: 0
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            togglePause: { gid in
                toggledGID.value = gid
            },
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause)
        await store.receive(\.toggleDownloadPauseDone)

        #expect(toggledGID.value == download.gid)
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerTogglePauseIgnoredForNonPauseableStatus() async {
        let didToggle = UncheckedBox(false)
        let download = sampleDownload(
            gid: "112239", title: "Completed Gallery",
            status: .completed, pageCount: 2
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            togglePause: { _ in
                didToggle.value = true
            },
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause)

        #expect(!didToggle.value)
    }

}

extension DownloadInspectorLoadTests {
    @MainActor
    @Test
    func testDownloadInspectorReducerValidateImageDataIgnoredWithoutDownloadedPages() async {
        let didValidate = UncheckedBox(false)
        let download = sampleDownload(
            gid: "112237", title: "Validate Empty Gallery",
            status: .completed, pageCount: 2
        )
        let inspection = DownloadInspection(
            download: download,
            coverURL: download.coverURL,
            pages: [
                .init(
                    index: 1, status: .pending, relativePath: nil,
                    fileURL: nil, failure: nil
                ),
                .init(
                    index: 2, status: .failed,
                    relativePath: "\(download.gid)_\(download.token)_2.jpg",
                    fileURL: nil,
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            validateImageData: { _ in
                didValidate.value = true
                return .valid
            },
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.validateImageData)

        #expect(!didValidate.value)
    }

    @MainActor
    @Test
    func testDownloadInspectorReducerValidateImageDataShowsMissingFilesHUD() async {
        let download = sampleDownload(
            gid: "112241", title: "Missing Image Data Gallery",
            status: .completed, pageCount: 2
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            validateImageData: { _ in
                .missingFiles("Page 2 image data is corrupted.")
            },
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.validateImageData) {
            $0.isValidatingImageData = true
        }
        await store.receive(\.validateImageDataDone) {
            $0.isValidatingImageData = false
            $0.hudConfig = .error(caption: "Page 2 image data is corrupted.")
            $0.route = .hud
        }
        await store.receive(\.loadInspection)
        await store.receive(\.loadInspectionDone) {
            $0.inspection = inspection
            $0.stableInspection = inspection
            $0.loadingState = .idle
        }
    }
}

// MARK: - Store Factory Helpers

private extension DownloadInspectorLoadTests {
    func makeInspectorStore(
        gid: String,
        initialInspection: DownloadInspection? = nil,
        retryPages: (@Sendable (String, [Int]) async throws -> Void)? = nil,
        validateImageData: (@Sendable (String) async -> DownloadValidationState?)? = nil,
        togglePause: (@Sendable (String) async throws -> Void)? = nil,
        loadInspection: @escaping @Sendable (String) async throws -> DownloadInspection
    ) -> TestStoreOf<DownloadInspectorReducer> {
        var initialState = DownloadInspectorReducer.State(gid: gid)
        initialState.inspection = initialInspection
        if initialInspection != nil { initialState.loadingState = .idle }
        return TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in continuation.finish() }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.validateImageData = validateImageData ?? { _ in nil }
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = togglePause ?? { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = retryPages ?? { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadInspection = loadInspection
            }
        )
    }
}
