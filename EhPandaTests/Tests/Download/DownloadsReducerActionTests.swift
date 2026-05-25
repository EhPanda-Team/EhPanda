//
//  DownloadsReducerActionTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadsReducerActionTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadsReducerKeepsIdleStateForEmptyLibrary() async {
        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
        }

        await store.send(.fetchDownloadsDone([])) {
            $0.loadingState = .idle
        }

        #expect(store.state.downloads == [])
    }

    @MainActor
    @Test
    func testDownloadsReducerSeedsOnlineDetailStateFromDownload() async {
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
        }
        store.exhaustivity = .off

        await store.send(.setNavigation(.detail(download.gid)))

        #expect(store.state.route == .detail(download.gid))
        #expect(store.state.detailState.wrappedValue?.gid == download.gid)
        #expect(store.state.detailState.wrappedValue?.gallery.id == download.gid)
        #expect(store.state.detailState.wrappedValue?.downloadBadge == .downloaded)
        #expect(store.state.detailState.wrappedValue?.shouldCheckForRemoteUpdates == true)
    }

    @MainActor
    @Test
    func testDownloadsReducerUpdateActionUsesDownloadClientRetry() async {
        let retried = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .updateAvailable,
            latestRemoteVersionSignature: "hash:v2"
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
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
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { gid, mode in
                    if mode == .update {
                        retried.value.append(gid)
                    }
                    return .success(())
                },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.updateDownload(download.gid))
        await store.receive(\.updateDownloadDone)

        #expect(retried.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerDeleteActionUsesDownloadClientDelete() async {
        let deleted = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "654321",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
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
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { gid in
                    deleted.value.append(gid)
                    return .success(())
                },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.deleteDownload(download.gid))
        await store.receive(\.deleteDownloadDone)

        #expect(deleted.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerOpenReadingLoadsManifestAndRoutesToReader() async throws {
        let download = sampleDownload(
            gid: "135790",
            title: "Readable Gallery",
            status: .completed,
            pageCount: 2
        )
        let manifest = try sampleManifest(
            gid: download.gid,
            title: download.title,
            pageCount: 2,
            versionSignature: "hash:v1"
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
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
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { gid in
                    gid == download.gid ? .success((download, manifest)) : .failure(.notFound)
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.openReading(download.gid))
        await store.receive(\.openReadingDone)

        #expect(store.state.route == .reading(download.gid))
        #expect(store.state.readingState.contentSource == .local(download, manifest))
    }

    @MainActor
    @Test
    func testDownloadsReducerValidateImageDataUsesDownloadClient() async {
        let validated = UncheckedBox(false)
        let store = TestStore(initialState: DownloadsReducer.State()) {
            DownloadsReducer()
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
                validateImageData: {
                    validated.value = true
                },
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.validateImageData)
        await store.receive(\.validateImageDataDone)

        #expect(validated.value)
    }

    @MainActor
    @Test
    func testDownloadsReducerTogglePauseActionUsesDownloadClientPause() async {
        let toggled = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "987654",
            title: "Downloading Gallery",
            status: .downloading,
            completedPageCount: 9
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(initialState: initialState) {
            DownloadsReducer()
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
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { gid in
                    toggled.value.append(gid)
                    return .success(())
                },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) }
            )
        }
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone)

        #expect(toggled.value == [download.gid])
    }

}
