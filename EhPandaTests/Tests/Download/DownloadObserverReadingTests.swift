//
//  DownloadObserverReadingTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DownloadObserverReadingTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testReadingReducerLocalSourceWithoutGalleryStateDoesNotStayLoading() async throws {
        let download = sampleDownload(
            gid: "700001", title: "Offline Gallery", status: .completed, pageCount: 2, completedPageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        let store = TestStore(
            initialState: ReadingReducer.State(contentSource: .local(download, manifest))
        ) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off
        let folderURL = download.folderURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(download.folderRelativePath, isDirectory: true)

        await store.send(.fetchDatabaseInfos(download.gid)) {
            $0.gallery = download.gallery
            $0.language = manifest.language
            $0.localPageURLs = [
                1: folderURL.appendingPathComponent("pages/0001.jpg"),
                2: folderURL.appendingPathComponent("pages/0002.jpg")
            ]
            $0.previewConfig = .normal(rows: 4)
            $0.previewURLs = $0.localPageURLs
            $0.thumbnailURLs = $0.localPageURLs
            $0.imageURLs = $0.localPageURLs
            $0.originalImageURLs = $0.localPageURLs
            $0.databaseLoadingState = .idle
        }
        await store.finish()

        #expect(store.state.databaseLoadingState == .idle)
        #expect(store.state.readingProgress == 0)
    }

    @MainActor
    @Test
    func testReadingReducerDoesNotReloadLocalPagesWhenOnlyOtherGalleryChanges() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .completed)
        let otherDownload = sampleDownload(gid: "900001", title: "Other Gallery", status: .queued)
        let updatedOtherDownload = sampleDownload(
            gid: otherDownload.gid, title: otherDownload.title,
            status: .downloading, pageCount: 12, completedPageCount: 4
        )
        let (stream, continuation) = makeObserverStream()
        let loadCount = UncheckedBox(0)

        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery

        let store = makeReadingStoreWithLoadCount(
            initialState: initialState, stream: stream,
            expectedGID: gallery.gid, loadCount: loadCount
        )

        await store.send(.observeDownloads(gallery.gid))
        continuation.yield([relevantDownload, otherDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPageURLs, gallery.gid)
        await store.receive(\.loadLocalPageURLsDone)
        #expect(loadCount.value == 1)

        continuation.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))
        #expect(loadCount.value == 1)

        continuation.finish()
        await store.finish()
    }

    @MainActor
    @Test
    func testPreviewsReducerDoesNotReloadLocalPreviewsWhenOnlyOtherGalleryChanges() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .completed)
        let otherDownload = sampleDownload(gid: "900002", title: "Other Preview Gallery", status: .queued)
        let updatedOtherDownload = sampleDownload(
            gid: otherDownload.gid, title: otherDownload.title,
            status: .paused, pageCount: 12, completedPageCount: 2
        )
        let (stream, continuation) = makeObserverStream()
        let loadCount = UncheckedBox(0)

        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery

        let store = makePreviewsStoreWithLoadCount(
            initialState: initialState, stream: stream,
            expectedGID: gallery.gid, loadCount: loadCount
        )

        await store.send(.observeDownloads(gallery.gid))
        continuation.yield([relevantDownload, otherDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPreviewURLs, gallery.gid)
        await store.receive(\.loadLocalPreviewURLsDone)
        #expect(loadCount.value == 1)

        continuation.yield([relevantDownload, updatedOtherDownload])
        try? await Task.sleep(for: .milliseconds(50))
        #expect(loadCount.value == 1)

        continuation.finish()
        await store.finish()
    }

}

// MARK: - Store Factory Helpers

private extension DownloadObserverReadingTests {
    func makeObserverStream()
        -> (AsyncStream<[DownloadedGallery]>, AsyncStream<[DownloadedGallery]>.Continuation) {
        var continuation: AsyncStream<[DownloadedGallery]>.Continuation!
        let stream = AsyncStream<[DownloadedGallery]> { continuation = $0 }
        return (stream, continuation)
    }

    func makeReadingStoreWithLoadCount(
        initialState: ReadingReducer.State,
        stream: AsyncStream<[DownloadedGallery]>,
        expectedGID: String,
        loadCount: UncheckedBox<Int>
    ) -> TestStoreOf<ReadingReducer> {
        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: { stream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    #expect(gid == expectedGID)
                    loadCount.value += 1
                    return .success([:])
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    func makePreviewsStoreWithLoadCount(
        initialState: PreviewsReducer.State,
        stream: AsyncStream<[DownloadedGallery]>,
        expectedGID: String,
        loadCount: UncheckedBox<Int>
    ) -> TestStoreOf<PreviewsReducer> {
        let store = TestStore(initialState: initialState) {
            PreviewsReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: { stream },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    #expect(gid == expectedGID)
                    loadCount.value += 1
                    return .success([:])
                }
            )
            $0.databaseClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off
        return store
    }
}
