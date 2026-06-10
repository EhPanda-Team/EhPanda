//
//  DetailReducerPauseAndGuardTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct DetailReducerPauseAndGuardTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDetailReducerLaunchAutomationDoesNotRedownloadWhenBadgeIsResolved() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let options = DownloadRequestOptions()
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.appLaunchAutomationClient = appLaunchAutomationClient(
                autoDownloadGID: gallery.gid
            )
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(.downloaded)) {
            $0.downloadBadge = .downloaded
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded(options)) {
            $0.didRunLaunchAutomation = true
        }
    }

    @MainActor
    @Test
    func testDetailReducerIgnoresStartDownloadWhilePreparing() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let enqueueCount = UncheckedBox(0)
        let options = DownloadRequestOptions()

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.isPreparingDownload = true

        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                enqueue: { _ in
                    enqueueCount.value += 1
                    return .success(())
                },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }

        await store.send(.startDownload(options))

        #expect(enqueueCount.value == 0)
        #expect(store.state.isPreparingDownload)
        #expect(store.state.downloadBadge == .none)
    }

    @MainActor
    @Test
    func testDetailReducerTogglesPauseForActiveDownload() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let togglePauseCount = UncheckedBox(0)

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.downloadBadge = .downloading(7, 26)

        let store = makeTogglePauseStore(initialState: initialState, togglePauseCount: togglePauseCount)

        await store.send(.toggleDownloadPause) { $0.isPreparingDownload = true }
        await store.receive(\.toggleDownloadPauseDone) {
            $0.isPreparingDownload = false
            $0.downloadBadge = .paused(7, 26)
            $0.hasLoadedDownloadBadge = true
        }
        await store.receive(\.fetchDownloadBadge)
        await store.receive(\.fetchDownloadBadgeDone, .paused(7, 26)) {
            $0.downloadBadge = .paused(7, 26)
            $0.hasLoadedDownloadBadge = true
        }

        #expect(togglePauseCount.value == 1)
        #expect(store.state.downloadBadge == .paused(7, 26))
        #expect(store.state.isPreparingDownload == false)
    }

}

// MARK: - Store Factory Helpers

private extension DetailReducerPauseAndGuardTests {
    func makeTogglePauseStore(
        initialState: DetailReducer.State,
        togglePauseCount: UncheckedBox<Int>
    ) -> TestStoreOf<DetailReducer> {
        let store = TestStore(initialState: initialState) {
            DetailReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: { AsyncStream { continuation in continuation.finish() } },
                fetchDownloads: { [] },
                fetchDownload: { _ in nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { gids in
                    Dictionary(uniqueKeysWithValues: gids.map { ($0, .paused(7, 26)) })
                },
                enqueue: { _ in .success(()) },
                togglePause: { _ in
                    togglePauseCount.value += 1
                    return .success(())
                },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
            $0.hapticsClient = .noop
            $0.databaseClient = .noop
            $0.cookieClient = .noop
        }
        store.exhaustivity = .off
        return store
    }
}
