//
//  DetailReducerMetadataTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DetailReducerMetadataTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDetailReducerDoesNotRequestVersionMetadataForUndownloadedGallery() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = GalleryState(gid: gallery.gid)

        let store = makeMetadataTestStore(
            gid: gallery.gid, gallery: gallery,
            downloadValue: nil, updateCheckCount: updateCheckCount
        )
        store.exhaustivity = .off

        await store.send(
            .fetchGalleryDetailDone(
                .success(GalleryDetailResponse(
                    galleryDetail: detail, galleryState: galleryState, apiKey: "", greeting: nil
                ))
            )
        )
        await store.skipReceivedActions(strict: false)

        #expect(updateCheckCount.value == 0)
        #expect(store.state.galleryVersionMetadata == nil)
        #expect(store.state.shouldCheckForRemoteUpdates == false)
        _ = galleryState
    }

    @MainActor
    @Test
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesAfterDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = try sampleGalleryState(gid: gallery.gid)

        let completedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )
        let store = makeDownloadedMetadataTestStore(
            gid: gallery.gid, gallery: gallery,
            downloadValue: nil, updateCheckCount: updateCheckCount
        )
        store.exhaustivity = .off

        await store.send(.fetchGalleryDetailDone(.success(GalleryDetailResponse(
            galleryDetail: detail, galleryState: galleryState, apiKey: "", greeting: nil
        ))))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 0)

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
        #expect(store.state.galleryVersionMetadata != nil)
    }

    @MainActor
    @Test
    func testDetailReducerRequestsVersionMetadataWhenBadgeArrivesBeforeDetail() async throws {
        let updateCheckCount = UncheckedBox(0)
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryState = try sampleGalleryState(gid: gallery.gid)

        let completedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )
        let store = makeDownloadedMetadataTestStore(
            gid: gallery.gid, gallery: gallery,
            downloadValue: completedDownload, updateCheckCount: updateCheckCount
        )
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(completedDownload))
        await store.skipReceivedActions(strict: false)
        #expect(updateCheckCount.value == 0)

        await store.send(.fetchGalleryDetailDone(.success(GalleryDetailResponse(
            galleryDetail: detail, galleryState: galleryState, apiKey: "", greeting: nil
        ))))
        await drainDetailMetadataEffects(
            store,
            condition: {
                updateCheckCount.value == 1 && store.state.galleryVersionMetadata != nil
            }
        )

        #expect(updateCheckCount.value == 1)
        #expect(store.state.shouldCheckForRemoteUpdates)
        #expect(store.state.didRequestVersionMetadata)
        #expect(store.state.galleryVersionMetadata != nil)
    }
}

// MARK: - Store Factory Helpers

private extension DetailReducerMetadataTests {
    func makeMetadataTestStore(
        gid: String, gallery: Gallery,
        downloadValue: DownloadedGallery?, updateCheckCount: UncheckedBox<Int>
    ) -> TestStoreOf<DetailReducer> {
        var initialState = DetailReducer.State()
        initialState.gid = gid
        initialState.gallery = gallery
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
                    fetchVersionMetadata: { _, _ in
                        .success(sampleVersionMetadata(gid: gallery.gid, token: gallery.token))
                    },
                    updateRemoteVersion: { _, _ in
                        updateCheckCount.value += 1
                        return .none
                    },
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

    func makeDownloadedMetadataTestStore(
        gid: String, gallery: Gallery,
        downloadValue: DownloadedGallery?, updateCheckCount: UncheckedBox<Int>
    ) -> TestStoreOf<DetailReducer> {
        let updatedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )
        var initialState = DetailReducer.State()
        initialState.gid = gid
        initialState.gallery = gallery
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
}
