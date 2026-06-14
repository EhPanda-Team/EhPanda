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
        let completedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .completed
        )
        var initialState = DetailReducer.State()
        initialState.gallery = gallery
        initialState.galleryDetail = detail

        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = appLaunchAutomationClient(
                    autoDownloadGID: gallery.gid
                )
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
        store.exhaustivity = .off

        await store.send(.fetchDownloadBadgeDone(completedDownload)) {
            $0.downloadBadge = completedDownload.badge
            $0.hasLoadedDownloadBadge = true
        }
        await store.send(.runLaunchAutomationIfNeeded) {
            $0.didRunLaunchAutomation = true
        }
    }

    @MainActor
    @Test
    func testDetailReducerIgnoresStartDownloadWhilePreparing() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let enqueueCount = UncheckedBox(0)

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.isPreparingDownload = true

        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in
                    enqueueCount.value += 1
                }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )

        await store.send(.startDownload("Folder"))

        #expect(enqueueCount.value == 0)
        #expect(store.state.isPreparingDownload)
        #expect(store.state.downloadBadge == .none)
    }

    @MainActor
    @Test
    func testDetailReducerTogglesPauseForActiveDownload() async {
        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let pausedDownload = sampleDownload(
            gid: gallery.gid, title: gallery.title, status: .paused,
            pageCount: 26, completedPageCount: 7
        )
        let togglePauseCount = UncheckedBox(0)

        var initialState = DetailReducer.State()
        initialState.gid = gallery.gid
        initialState.gallery = gallery
        initialState.galleryDetail = detail
        initialState.downloadBadge = DownloadBadge(
            status: .active,
            progress: .init(completedPageCount: 7, pageCount: 26)
        )

        let store = makeTogglePauseStore(
            initialState: initialState,
            pausedDownload: pausedDownload,
            togglePauseCount: togglePauseCount
        )

        await store.send(.toggleDownloadPause) { $0.isPreparingDownload = true }
        await store.receive(\.toggleDownloadPauseDone) {
            $0.isPreparingDownload = false
            $0.downloadBadge = DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 7, pageCount: 26)
            )
            $0.hasLoadedDownloadBadge = true
        }
        await store.receive(\.fetchDownloadBadge)
        await store.receive(\.fetchDownloadBadgeDone, pausedDownload) {
            $0.downloadBadge = pausedDownload.badge
            $0.hasLoadedDownloadBadge = true
        }

        #expect(togglePauseCount.value == 1)
        #expect(store.state.downloadBadge == pausedDownload.badge)
        #expect(store.state.isPreparingDownload == false)
    }

}

// MARK: - Store Factory Helpers

private extension DetailReducerPauseAndGuardTests {
    func makeTogglePauseStore(
        initialState: DetailReducer.State,
        pausedDownload: DownloadedGallery,
        togglePauseCount: UncheckedBox<Int>
    ) -> TestStoreOf<DetailReducer> {
        let store = TestStore(
            initialState: initialState,
            reducer: DetailReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = { AsyncStream { continuation in continuation.finish() } }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in pausedDownload }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in
                    togglePauseCount.value += 1
                }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.hapticsClient = .noop
                $0.databaseClient = .noop
                $0.cookieClient = .noop
            }
        )
        store.exhaustivity = .off
        return store
    }
}
