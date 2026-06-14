//
//  DetailReducerDownloadTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DetailReducerDownloadTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDetailReducerStartDownloadEnqueuesGalleryWithSnapshotOptions() async throws {
        let capturedPayload = UncheckedBox<DownloadRequestPayload?>(nil)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let queuedDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .queued)
        let options = DownloadRequestOptions(
            threadLimit: 4,
            allowCellular: false,
            autoRetryFailedPages: false
        )
        let previewURL = try #require(URL(string: "https://example.com/1.jpg"))
        let store = makeDownloadTestStore(
            gallery: gallery, detail: detail,
            downloadValue: queuedDownload,
            configure: { state in
                state.galleryPreviewURLs = [1: previewURL]
                state.previewConfig = .large(rows: 2)
            },
            enqueue: { payload in
                capturedPayload.value = payload
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.startDownload(options, "Folder"))
        await store.skipReceivedActions(strict: false)

        #expect(capturedPayload.value?.gallery.gid == gallery.gid)
        #expect(capturedPayload.value?.galleryDetail == detail)
        #expect(capturedPayload.value?.previewConfig == .large(rows: 2))
        #expect(capturedPayload.value?.options == options)
        #expect(capturedPayload.value?.mode == .initial)
        #expect(store.state.downloadBadge == queuedDownload.badge)
    }

    @MainActor
    @Test
    func testDetailReducerStartDownloadUnlocksActionsAfterQueueing() async throws {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let queuedDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .queued)
        let options = DownloadRequestOptions()
        let previewURL = try #require(URL(string: "https://example.com/1.jpg"))
        let store = makeDownloadTestStore(
            gallery: gallery, detail: detail,
            downloadValue: queuedDownload,
            configure: { state in state.galleryPreviewURLs = [1: previewURL] },
            enqueue: { _ in .success(()) }
        )
        store.exhaustivity = .off

        await store.send(.startDownload(options, "Folder")) {
            $0.isPreparingDownload = true
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.startDownloadDone) {
            $0.isPreparingDownload = false
            $0.downloadBadge = DownloadBadge(
                status: .queued,
                progress: .init(completedPageCount: 0, pageCount: detail.pageCount)
            )
            $0.hasLoadedDownloadBadge = true
        }
        await store.receive(\.fetchDownloadBadge)
        await store.receive(\.fetchDownloadBadgeDone, queuedDownload) {
            $0.downloadBadge = queuedDownload.badge
            $0.hasLoadedDownloadBadge = true
        }
    }

    @MainActor
    @Test
    func testDetailReducerFetchDownloadFoldersPopulatesStateAndRefetchesAfterChanges() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let store = makeDownloadTestStore(
            gallery: gallery, detail: detail,
            downloadValue: nil,
            folders: { ["Library"] },
            enqueue: { _ in .success(()) }
        )
        store.exhaustivity = .off

        await store.send(.fetchDownloadFolders)
        await store.receive(\.fetchDownloadFoldersDone, ["Library"]) {
            $0.downloadFolders = ["Library"]
        }

        await store.send(.folderManager(.createFolderDone(.success(()))))
        await store.receive(\.fetchDownloadFolders)
        await store.skipReceivedActions(strict: false)
    }

    @MainActor
    @Test
    func testDetailReducerLaunchAutomationWaitsForResolvedDownloadBadge() async throws {
        let capturedPayload = UncheckedBox<DownloadRequestPayload?>(nil)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadRequestOptions()
        let previewURL = try #require(URL(string: "https://example.com/1.jpg"))

        let store = makeDownloadTestStore(
            gallery: gallery, detail: detail,
            downloadValue: nil,
            automationGID: gallery.gid,
            configure: { state in
                state.gid = ""
                state.galleryPreviewURLs = [1: previewURL]
            },
            enqueue: { payload in
                capturedPayload.value = payload
                return .success(())
            }
        )
        store.exhaustivity = .off

        await store.send(.runLaunchAutomationIfNeeded(options))
        #expect(capturedPayload.value == nil)
        #expect(store.state.didRunLaunchAutomation == false)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded(options)) {
            $0.didRunLaunchAutomation = true
        }
        await store.receive(\.startDownload)
        await store.skipReceivedActions(strict: false)

        #expect(capturedPayload.value?.gallery.gid == gallery.gid)
        #expect(capturedPayload.value?.folderName == Defaults.FilePath.automationDownloadFolder)
    }
}

// MARK: - Store Factory Helpers

private extension DetailReducerDownloadTests {
    func makeDownloadTestStore(
        gallery: Gallery, detail: GalleryDetail,
        downloadValue: DownloadedGallery?,
        automationGID: String? = nil,
        folders: @escaping @Sendable () -> [String] = { [] },
        configure: (inout DetailReducer.State) -> Void = { _ in },
        enqueue: @escaping @Sendable (DownloadRequestPayload) async -> Result<Void, AppError>
    ) -> TestStoreOf<DetailReducer> {
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        configure(&initialState)
        return TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in continuation.finish() }
                    },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in downloadValue },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    enqueue: enqueue,
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) },
                    fetchFolders: { folders() }
                )
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
                if let automationGID {
                    $0.appLaunchAutomationClient = appLaunchAutomationClient(
                        autoDownloadGID: automationGID
                    )
                }
            }
        )
    }
}
