//
//  PreviewsReducerDownloadTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct PreviewsReducerDownloadTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testPreviewsReducerOpenReadingUsesLocalManifestWhenAvailable() async throws {
        let download = sampleDownload(
            gid: "991", title: "Preview Download", status: .completed, pageCount: 2, completedPageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        var initialState = PreviewsReducer.State()
        initialState.gallery = download.gallery

        let store = makePreviewsManifestStore(download: download, manifest: manifest)

        await store.send(.openReading(1))
        await store.skipReceivedActions(strict: false)

        if case .local(let actualDownload, let actualManifest) = store.state.readingState.contentSource {
            #expect(actualDownload == download)
            #expect(actualManifest == manifest)
        } else {
            Issue.record("Expected previews to open local reading content.")
        }
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

    @MainActor
    @Test
    func testPreviewsReducerClearsLocalPreviewURLsWhenObservedDownloadDisappears() async {
        let gallery = sampleGallery()
        let localURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery
        initialState.localPreviewURLs = [1: localURL]

        let store = makePreviewsNoManifestStore(initialState: initialState, withLoadLocalPageURLs: true)

        await store.send(.observeDownloadsDone([]))
        await store.receive(\.loadLocalPreviewURLs)
        let requestID = store.state.localPreviewRequestID
        await store.receive(\.loadLocalPreviewURLsDone) {
            $0.localPreviewURLs = [:]
        }
        #expect(store.state.localPreviewRequestID == requestID)
    }

    @MainActor
    @Test
    func testPreviewsReducerRemoteFallbackKeepsExistingLocalPreviewPages() async {
        let gallery = sampleGallery()
        let localURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var initialState = PreviewsReducer.State()
        initialState.gallery = gallery
        initialState.localPreviewURLs = [1: localURL]

        let store = makePreviewsNoManifestStore(initialState: initialState, withLoadLocalPageURLs: false)

        await store.send(.openReading(1))
        await store.receive(\.openReadingDone)
        guard case .reading = store.state.route else {
            Issue.record("Expected previews route to enter reading")
            return
        }
        #expect(store.state.readingState.contentSource == .remote)
        #expect(store.state.readingState.localPageURLs == [1: localURL])
    }

}

// MARK: - Store Factory Helpers

private extension PreviewsReducerDownloadTests {
    func makePreviewsManifestStore(
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) -> TestStoreOf<PreviewsReducer> {
        var initialState = PreviewsReducer.State()
        initialState.gallery = download.gallery
        let store = TestStore(
            initialState: initialState,
            reducer: PreviewsReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: { AsyncStream { continuation in continuation.finish() } },
                    fetchDownloads: { [download] },
                    fetchDownload: { gid in gid == download.gid ? download : nil },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { gid in
                        gid == download.gid ? .success((download, manifest)) : .failure(.notFound)
                    }
                )
                $0.databaseClient = .noop
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }

    func makePreviewsNoManifestClient(loadLocalPageURLs: Bool) -> DownloadClient {
        let loadLocalPageURLsResult: @Sendable (String) async -> Result<[Int: URL], AppError>
        if loadLocalPageURLs {
            loadLocalPageURLsResult = { _ in .success([:]) }
        } else {
            loadLocalPageURLsResult = { _ in .failure(.notFound) }
        }
        return .init(
            observeDownloads: { AsyncStream { continuation in continuation.finish() } },
            fetchDownloads: { [] },
            fetchDownload: { _ in nil },
            refreshDownloads: {},
            resumeQueue: {},
            badges: { _ in [:] },
            enqueue: { _ in .success(()) },
            togglePause: { _ in .success(()) },
            retry: { _, _ in .success(()) },
            delete: { _ in .success(()) },
            loadManifest: { _ in .failure(.notFound) },
            loadLocalPageURLs: loadLocalPageURLsResult
        )
    }

    func makePreviewsNoManifestStore(
        initialState: PreviewsReducer.State,
        withLoadLocalPageURLs: Bool
    ) -> TestStoreOf<PreviewsReducer> {
        let downloadClient = makePreviewsNoManifestClient(loadLocalPageURLs: withLoadLocalPageURLs)
        let store = TestStore(
            initialState: initialState,
            reducer: PreviewsReducer.init,
            withDependencies: {
                $0.downloadClient = downloadClient
                $0.databaseClient = .noop
                $0.hapticsClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }
}
