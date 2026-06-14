//
//  DownloadObserverRefreshTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DownloadObserverRefreshTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testReadingReducerEmitsOneFinalRefreshWhenRelevantDownloadDisappears() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .completed)
        let (stream, continuation) = makeObserverStream()
        let loadCount = UncheckedBox(0)

        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery

        let store = makeReadingObserverStore(
            initialState: initialState,
            stream: stream,
            loadLocalPageURLs: { _ in
                loadCount.value += 1
                return [:]
            }
        )

        await store.send(.observeDownloads(gallery.gid))
        continuation.yield([relevantDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPageURLs, gallery.gid)
        await store.receive(\.loadLocalPageURLsDone)

        continuation.yield([])
        await store.receive(\.observeDownloadsDone, [])
        await store.receive(\.loadLocalPageURLs, gallery.gid)
        await store.receive(\.loadLocalPageURLsDone)

        #expect(loadCount.value == 2)
        continuation.finish()
        await store.finish()
    }

    @MainActor
    @Test
    func testPreviewsReducerEmitsOneFinalRefreshWhenRelevantDownloadDisappears() async {
        let gallery = sampleGallery()
        let relevantDownload = sampleDownload(gid: gallery.gid, title: gallery.title, status: .completed)
        let (stream, continuation) = makeObserverStream()
        let loadCount = UncheckedBox(0)

        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery

        let store = makePreviewsObserverStore(
            initialState: initialState,
            stream: stream,
            loadLocalPageURLs: { _ in
                loadCount.value += 1
                return [:]
            }
        )

        await store.send(.observeDownloads(gallery.gid))
        continuation.yield([relevantDownload])
        await store.receive(\.observeDownloadsDone, [relevantDownload])
        await store.receive(\.loadLocalPreviewURLs, gallery.gid)
        await store.receive(\.loadLocalPreviewURLsDone)

        continuation.yield([])
        await store.receive(\.observeDownloadsDone, [])
        await store.receive(\.loadLocalPreviewURLs, gallery.gid)
        await store.receive(\.loadLocalPreviewURLsDone)

        #expect(loadCount.value == 2)
        continuation.finish()
        await store.finish()
    }

}

// MARK: - Store Factory Helpers

private extension DownloadObserverRefreshTests {
    func makeObserverStream() -> (AsyncStream<[DownloadedGallery]>, AsyncStream<[DownloadedGallery]>.Continuation) {
        var continuation: AsyncStream<[DownloadedGallery]>.Continuation!
        let stream = AsyncStream<[DownloadedGallery]> { continuation = $0 }
        return (stream, continuation)
    }

    func makeReadingObserverStore(
        initialState: ReadingReducer.State,
        stream: AsyncStream<[DownloadedGallery]>,
        loadLocalPageURLs: @escaping @Sendable (String) async throws -> [Int: URL]
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
                $0.downloadClient = makeObserveDownloadClient(
                    stream: stream, loadLocalPageURLs: loadLocalPageURLs
                )
                $0.hapticsClient = .noop
                $0.imageClient = .noop
                $0.urlClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }

    func makePreviewsObserverStore(
        initialState: PreviewsReducer.State,
        stream: AsyncStream<[DownloadedGallery]>,
        loadLocalPageURLs: @escaping @Sendable (String) async throws -> [Int: URL]
    ) -> TestStoreOf<PreviewsReducer> {
        let store = TestStore(
            initialState: initialState,
            reducer: PreviewsReducer.init,
            withDependencies: {
                $0.downloadClient = makeObserveDownloadClient(
                    stream: stream, loadLocalPageURLs: loadLocalPageURLs
                )
                $0.databaseClient = .noop
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }

    func makeObserveDownloadClient(
        stream: AsyncStream<[DownloadedGallery]>,
        loadLocalPageURLs: @escaping @Sendable (String) async throws -> [Int: URL]
    ) -> DownloadClient {
        var client = DownloadClient.noop
        client.observeDownloads = { stream }
        client.fetchDownloads = { [] }
        client.fetchDownload = { _ in nil }
        client.refreshDownloads = {}
        client.enqueue = { _ in }
        client.togglePause = { _ in }
        client.retry = { _, _ in }
        client.delete = { _ in }
        client.loadManifest = { _ in throw AppError.notFound }
        client.loadLocalPageURLs = loadLocalPageURLs
        return client
    }
}
