import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. It is applied
// per member rather than to the suite so the type's `DownloadFeatureTestCase` conformance
// stays nonisolated — a main-actor conformance cannot be used from the `@Sendable`
// dependency closures these stores install.
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
        let reconcileCount = LockedBox(0)
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
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
        let refreshCount = LockedBox(0)
        let reconcileCount = LockedBox(0)

        let store = TestStore(
            initialState: DownloadsReducer.State(),
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
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
                $0.downloadClient.fetchFolders = { [] }
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
        let fetchCount = LockedBox(0)
        let folderFetchCount = LockedBox(0)
        let refreshCount = LockedBox(0)

        let store = TestStore(
            initialState: DownloadsReducer.State(),
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
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

        await store.send(.onPresented) {
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
