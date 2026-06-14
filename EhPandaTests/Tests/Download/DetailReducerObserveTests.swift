//
//  DetailReducerObserveTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DetailReducerObserveTests: DownloadFeatureTestCase {
    @Test
    func testDetailCancellationIDsAreScopedByGallery() {
        let firstGalleryIDs = DetailReducer.CancelID.all(for: "100")
        let secondGalleryIDs = DetailReducer.CancelID.all(for: "200")

        #expect(firstGalleryIDs.count == 12)
        #expect(secondGalleryIDs.count == 12)
        #expect(Set(firstGalleryIDs).isDisjoint(with: Set(secondGalleryIDs)))
    }

    @MainActor
    @Test
    func testDetailReducerObservesDownloadBadgeTransitions() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let continuationBox = UncheckedBox<AsyncStream<[DownloadedGallery]>.Continuation?>(nil)
        let stream = AsyncStream<[DownloadedGallery]> { continuation in
            continuationBox.value = continuation
        }
        let store = makeObserveTestStore(gallery: gallery, detail: detail, stream: stream)
        store.exhaustivity = .off

        await store.send(.onAppear(gallery.gid, false)) {
            $0.gid = gallery.gid
            $0.showsNewDawnGreeting = false
            $0.hasLoadedDownloadBadge = false
            $0.didRunLaunchAutomation = false
        }
        await store.skipReceivedActions(strict: false)

        continuationBox.value?.yield([
            sampleDownload(gid: gallery.gid, title: gallery.title, status: .queued)
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = DownloadBadge(
                status: .queued,
                progress: .init(completedPageCount: 0, pageCount: 12)
            )
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.yield([
            sampleDownload(
                gid: gallery.gid, title: gallery.title, status: .downloading,
                pageCount: 26, completedPageCount: 7
            )
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = DownloadBadge(
                status: .active,
                progress: .init(completedPageCount: 7, pageCount: 26)
            )
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.yield([
            sampleDownload(
                gid: gallery.gid, title: gallery.title, status: .completed,
                pageCount: 26, completedPageCount: 26
            )
        ])
        await store.receive(\.observeDownloadDone) {
            $0.downloadBadge = DownloadBadge(
                status: .completed,
                progress: .init(completedPageCount: 26, pageCount: 26)
            )
            $0.hasLoadedDownloadBadge = true
        }

        continuationBox.value?.finish()
    }

    @MainActor
    @Test
    func testDetailReducerOpenReadingUsesLocalManifestWhenAvailable() async throws {
        let download = sampleDownload(gid: "888", title: "Offline Archive", status: .completed, pageCount: 2)
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        var initialState = DetailReducer.State()
        initialState.gallery = download.gallery
        initialState.galleryDetail = sampleGalleryDetail(gid: download.gid, title: download.title)

        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = makeLocalManifestClient(download: download, manifest: manifest)
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.openReading)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.readingState.contentSource == .local(download, manifest))
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

    @MainActor
    @Test
    func testDetailReducerOpenReadingFallsBackToRemoteWhenManifestUnavailable() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = makeNoManifestClient()
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.openReading)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.readingState.contentSource == .remote)
        if case .reading = store.state.route {
        } else {
            Issue.record("Expected reading route to be active.")
        }
    }

}

// MARK: - Store Factory Helpers

private extension DetailReducerObserveTests {
    func makeObserveTestStore(
        gallery: Gallery, detail: GalleryDetail,
        stream: AsyncStream<[DownloadedGallery]>
    ) -> TestStoreOf<DetailReducer> {
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        return TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: { stream },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in nil },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) }
                )
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
    }

    func makeLocalManifestClient(
        download: DownloadedGallery, manifest: DownloadManifest
    ) -> DownloadClient {
        .init(
            observeDownloads: {
                AsyncStream { continuation in continuation.finish() }
            },
            fetchDownloads: { [download] },
            fetchDownload: { gid in gid == download.gid ? download : nil },
            refreshDownloads: {},
            resumeQueue: {},
            badges: { gids in
                Dictionary(uniqueKeysWithValues: gids.map { ($0, download.badge) })
            },
            enqueue: { _ in .success(()) },
            togglePause: { _ in .success(()) },
            retry: { _, _ in .success(()) },
            delete: { _ in .success(()) },
            loadManifest: { gid in
                gid == download.gid ? .success((download, manifest)) : .failure(.notFound)
            }
        )
    }

    func makeNoManifestClient() -> DownloadClient {
        .init(
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
            delete: { _ in .success(()) },
            loadManifest: { _ in .failure(.notFound) }
        )
    }
}
