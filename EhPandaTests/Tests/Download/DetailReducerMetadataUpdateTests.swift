//
//  DetailReducerMetadataUpdateTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DetailReducerMetadataUpdateTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDetailReducerObserveDownloadDoneAlsoTriggersMetadataCheckWithoutDuplicateRequests() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let completedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )

        let store = makeUpdateTestStore(
            gid: gallery.gid, gallery: gallery, detail: detail,
            updatedDownload: completedDownload,
            updateCheckCount: updateCheckCount
        )
        store.exhaustivity = .off

        await store.send(.observeDownloadDone(completedDownload))
        await drainDetailMetadataEffects(store, condition: { updateCheckCount.value == 1 })
        #expect(updateCheckCount.value == 1)

        await store.send(.observeDownloadDone(completedDownload))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 1)
    }

    @MainActor
    @Test
    func testDetailReducerRemoteUpdateFlagDoesNotStayStickyWhenBadgeReturnsToNone() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let completedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )

        let store = makeUpdateTestStore(
            gid: gallery.gid, gallery: gallery, detail: detail,
            updatedDownload: completedDownload,
            updateCheckCount: updateCheckCount
        )
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(completedDownload))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )
        #expect(updateCheckCount.value == 1)
        #expect(store.state.shouldCheckForRemoteUpdates)
        #expect(store.state.didRequestVersionMetadata)

        await store.send(.fetchDownloadBadgeDone(.none)) {
            $0.downloadBadge = .none
            $0.hasLoadedDownloadBadge = true
            $0.shouldCheckForRemoteUpdates = false
            $0.didRequestVersionMetadata = false
            $0.galleryVersionMetadata = nil
        }
        await store.skipReceivedActions(strict: false)

        #expect(store.state.shouldCheckForRemoteUpdates == false)
        #expect(store.state.didRequestVersionMetadata == false)
        #expect(store.state.galleryVersionMetadata == nil)
    }

    @MainActor
    @Test
    func testDetailReducerDeleteDownloadResetsMetadataState() async {
        let download = sampleDownload(gid: "7733", title: "Reset Context", status: .completed)
        var initialState = DetailReducer.State()
        initialState.gallery = download.gallery
        initialState.galleryVersionMetadata = sampleVersionMetadata(
            gid: download.gid, token: download.token
        )
        initialState.didRequestVersionMetadata = true
        initialState.shouldCheckForRemoteUpdates = true

        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = makeDeleteTestClient(download: download)
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.deleteDownloadDone(.success(()))) {
            $0.galleryVersionMetadata = nil
            $0.didRequestVersionMetadata = false
            $0.shouldCheckForRemoteUpdates = false
        }
        await store.skipReceivedActions(strict: false)

        #expect(store.state.shouldCheckForRemoteUpdates == false)
        #expect(store.state.didRequestVersionMetadata == false)
        #expect(store.state.galleryVersionMetadata == nil)
    }

}

// MARK: - Store Factory Helpers

private extension DetailReducerMetadataUpdateTests {
    func makeUpdateTestStore(
        gid: String, gallery: Gallery, detail: GalleryDetail,
        updatedDownload: DownloadedGallery,
        updateCheckCount: UncheckedBox<Int>
    ) -> TestStoreOf<DetailReducer> {
        var initialState = DetailReducer.State()
        initialState.gid = gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        return TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = .init(
                    observeDownloads: {
                        AsyncStream { continuation in continuation.finish() }
                    },
                    fetchDownloads: { [] },
                    fetchDownload: { _ in updatedDownload },
                    refreshDownloads: {},
                    resumeQueue: {},
                    badges: { _ in [:] },
                    fetchVersionMetadata: { _, _ in
                        .success(sampleVersionMetadata(gid: gallery.gid, token: gallery.token))
                    },
                    updateRemoteVersion: { _, _ in
                        updateCheckCount.value += 1
                        return updatedDownload
                    },
                    enqueue: { _ in .success(()) },
                    togglePause: { _ in .success(()) },
                    retry: { _, _ in .success(()) },
                    delete: { _ in .success(()) },
                    loadManifest: { _ in .failure(.notFound) },
                    loadLocalPageURLs: { _ in .success([:]) }
                )
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
    }

    func makeDeleteTestClient(download: DownloadedGallery) -> DownloadClient {
        .init(
            observeDownloads: {
                AsyncStream { continuation in continuation.finish() }
            },
            fetchDownloads: { [download] },
            fetchDownload: { gid in gid == download.gid ? download : nil },
            refreshDownloads: {},
            resumeQueue: {},
            badges: { _ in [:] },
            enqueue: { _ in .success(()) },
            togglePause: { _ in .success(()) },
            retry: { _, _ in .success(()) },
            delete: { _ in .success(()) },
            loadManifest: { _ in .failure(.notFound) },
            loadLocalPageURLs: { _ in .success([:]) }
        )
    }
}
