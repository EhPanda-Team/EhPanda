//
//  DownloadsReducerRefreshTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadsReducerRefreshTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadsReducerDoesNotReconcileAfterPauseFailure() async {
        let download = sampleDownload(
            gid: "987655",
            title: "Queued Gallery",
            status: .queued,
            completedPageCount: 3
        )
        let reconcileCount = UncheckedBox(0)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [download] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.reconcileDownloads = {
                    reconcileCount.value += 1
                }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in throw AppError.networkingFailed }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone)
        await store.finish()

        #expect(reconcileCount.value == 0)
    }

    @MainActor
    @Test
    func testDownloadsReducerRefreshDownloadsUsesClientRefresh() async {
        let refreshCount = UncheckedBox(0)
        let reconcileCount = UncheckedBox(0)

        let store = TestStore(
            initialState: DownloadsReducer.State(),
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.reconcileDownloads = {
                    reconcileCount.value += 1
                }
                $0.downloadClient.refreshDownloads = {
                    refreshCount.value += 1
                }
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )

        await store.send(.refreshDownloads)
        await store.receive(\.refreshDownloadsDone)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchFoldersDone)

        #expect(refreshCount.value == 1)
        #expect(reconcileCount.value == 0)
    }

    @MainActor
    @Test
    func testDownloadsReducerOnAppearUsesCachedIndexWithoutRefresh() async {
        let fetchCount = UncheckedBox(0)
        let folderFetchCount = UncheckedBox(0)
        let refreshCount = UncheckedBox(0)

        let store = TestStore(
            initialState: DownloadsReducer.State(),
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = {
                    fetchCount.value += 1
                    return []
                }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {
                    refreshCount.value += 1
                }
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.fetchFolders = {
                    folderFetchCount.value += 1
                    return []
                }
            }
        )

        await store.send(.onAppear) {
            $0.hasLoadedInitialDownloads = true
        }
        await store.receive(\.fetchDownloads)
        await store.receive(\.observeDownloads)
        await store.receive(\.fetchFolders)
        await store.receive(\.fetchDownloadsDone) {
            $0.loadingState = .idle
        }
        await store.receive(\.fetchFoldersDone)

        #expect(fetchCount.value == 1)
        #expect(folderFetchCount.value == 1)
        #expect(refreshCount.value == 0)
    }

}
