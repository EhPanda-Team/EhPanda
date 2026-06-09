//
//  ReadingReducerLocalTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct ReadingReducerLocalTests: DownloadFeatureTestCase {
    @MainActor
    func testReadingReducerOnWebImageSucceededDoesNotCaptureAlreadyLocalPage() async {
        let capturedCalls = UncheckedBox([(String, Int, URL?)]())
        let gallery = sampleGallery()
        let localPageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("0001.jpg")
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.localPageURLs = [1: localPageURL]

        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
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
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                captureCachedPage: { gid, index, imageURL in
                    capturedCalls.value.append((gid, index, imageURL))
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.onWebImageSucceeded(1)) {
            $0.imageURLLoadingStates[1] = .idle
            $0.webImageLoadSuccessIndices.insert(1)
        }
        await store.finish()

        #expect(capturedCalls.value.isEmpty)
    }

    @MainActor
    @Test
    func testReadingReducerLocalSourceLoadsOfflineImagesWithoutNetwork() async throws {
        let download = sampleDownload(
            gid: "777",
            title: "Offline Archive",
            status: .completed,
            pageCount: 2
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        let folderURL = try prepareLocalDownloadFiles(download: download, manifest: manifest)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let store = TestStore(
            initialState: ReadingReducer.State(contentSource: .local(download, manifest))
        ) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off

        await store.send(.fetchDatabaseInfos(download.gid))
        #expect(store.state.gallery.id == download.gid)
        #expect(store.state.imageURLs[1] == folderURL.appendingPathComponent("123_token_1.jpg"))
        #expect(store.state.imageURLs[2] == folderURL.appendingPathComponent("123_token_2.jpg"))

        await store.send(.fetchImageURLs(1)) {
            $0.imageURLLoadingStates[1] = .idle
        }
        await store.send(.reloadAllWebImages)

        #expect(store.state.imageURLs[1] == folderURL.appendingPathComponent("123_token_1.jpg"))
        #expect(store.state.imageURLs[2] == folderURL.appendingPathComponent("123_token_2.jpg"))
    }

}
