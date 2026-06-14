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
        let gid = "700001"
        let title = "Offline Gallery"
        let folderURL = FileUtil.downloadsDirectoryURL
            .appendingPathComponent("[\(gid)_token] \(title)", isDirectory: true)
        let localPageURLs = [
            1: folderURL.appendingPathComponent("123_token_1.jpg"),
            2: folderURL.appendingPathComponent("123_token_2.jpg")
        ]
        let download = sampleDownload(
            gid: gid, title: title, status: .completed, pageCount: 2, completedPageCount: 2,
            folderURL: folderURL, localPageURLs: localPageURLs
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
        defer { try? FileManager.default.removeItem(at: folderURL) }
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("123_token_1.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("123_token_2.jpg"),
            options: .atomic
        )

        await store.send(.fetchDatabaseInfos(download.gid)) {
            $0.gallery = download.gallery
            $0.language = manifest.language
            $0.localPageURLs = [
                1: folderURL.appendingPathComponent("123_token_1.jpg"),
                2: folderURL.appendingPathComponent("123_token_2.jpg")
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
        let store = TestStore(
            initialState: initialState,
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.appDelegateClient = .noop
                $0.clipboardClient = .noop
                $0.cookieClient = .noop
                $0.databaseClient = .noop
                $0.deviceClient = .noop
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = { stream }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadLocalPageURLs = { gid in
                    #expect(gid == expectedGID)
                    loadCount.value += 1
                    return [:]
                }
                $0.hapticsClient = .noop
                $0.imageClient = .noop
                $0.urlClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }

    func makePreviewsStoreWithLoadCount(
        initialState: PreviewsReducer.State,
        stream: AsyncStream<[DownloadedGallery]>,
        expectedGID: String,
        loadCount: UncheckedBox<Int>
    ) -> TestStoreOf<PreviewsReducer> {
        let store = TestStore(
            initialState: initialState,
            reducer: PreviewsReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = { stream }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadLocalPageURLs = { gid in
                    #expect(gid == expectedGID)
                    loadCount.value += 1
                    return [:]
                }
                $0.databaseClient = .noop
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }
}
