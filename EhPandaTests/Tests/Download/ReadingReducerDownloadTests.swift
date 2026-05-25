//
//  ReadingReducerDownloadTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
@MainActor
struct ReadingReducerDownloadTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDetailReducerDownloadedContextStoresVersionMetadataResult() async {
        let download = sampleDownload(
            gid: "889", title: "Offline Archive", status: .completed, pageCount: 2
        )
        let detail = sampleGalleryDetail(gid: download.gid, title: download.title)
        var initialState = DetailReducer.State(download: download)
        initialState.galleryDetail = detail
        let metadata = DownloadVersionMetadata(
            gid: detail.gid, token: download.token,
            currentGID: "990", currentKey: "chain-key",
            parentGID: download.gid, parentKey: download.token,
            firstGID: download.gid, firstKey: download.token
        )

        let store = TestStore(initialState: initialState) { DetailReducer() }
        await store.send(.fetchVersionMetadataDone(.success(metadata))) {
            $0.galleryVersionMetadata = metadata
        }
    }

    @MainActor
    @Test
    func testReadingReducerRemoteSourceLoadsLocalPagesAndSkipsRemoteFetchForDownloadedPage() async throws {
        let gallery = sampleGallery()
        let localPageURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        let remotePageURL = try #require(URL(string: "https://example.com/pages/0001.jpg"))
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.imageURLs = [1: remotePageURL]

        let store = makeLocalPageLoadStore(
            initialState: initialState, gallery: gallery, localPageURL: localPageURL
        )

        await store.send(.loadLocalPageURLs(gallery.gid))
        let requestID = store.state.localPageRequestID
        await store.receive(\.loadLocalPageURLsDone) { $0.localPageURLs = [1: localPageURL] }
        #expect(store.state.localPageRequestID == requestID)
        #expect(store.state.localPageURLs[1] == localPageURL)

        await store.send(.fetchImageURLs(1)) { $0.imageURLLoadingStates[1] = .idle }
    }

    @MainActor
    @Test
    func testReadingReducerLocalPageLoadClearsStaleRemoteImageFailure() async throws {
        let gallery = sampleGallery()
        let localPageURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.imageURLLoadingStates[1] = .failed(.webImageFailed)
        initialState.previewLoadingStates[1] = .failed(.webImageFailed)

        let store = makeLocalPageLoadStore(
            initialState: initialState, gallery: gallery, localPageURL: localPageURL
        )

        await store.send(.loadLocalPageURLs(gallery.gid))
        let requestID = store.state.localPageRequestID
        await store.receive(\.loadLocalPageURLsDone) {
            $0.localPageURLs = [1: localPageURL]
            $0.imageURLLoadingStates[1] = .idle
            $0.previewLoadingStates[1] = .idle
        }
        #expect(store.state.localPageRequestID == requestID)
    }

    @MainActor
    @Test
    func testReadingReducerOnWebImageSucceededCapturesCachedPageIntoDownloadProgress() async throws {
        let capturedCalls = UncheckedBox([CapturedPageCall]())
        let gallery = sampleGallery()
        let remotePageURL = try #require(URL(string: "https://example.com/pages/0001.jpg"))
        var initialState = ReadingReducer.State(contentSource: .remote)
        initialState.gallery = gallery
        initialState.imageURLs = [1: remotePageURL]

        let store = makeCapturePageStore(
            initialState: initialState, capturedCalls: capturedCalls
        )

        await store.send(.onWebImageSucceeded(1)) {
            $0.imageURLLoadingStates[1] = .idle
            $0.webImageLoadSuccessIndices.insert(1)
        }
        await store.receive(\.captureCachedPage)

        #expect(capturedCalls.value.count == 1)
        #expect(capturedCalls.value.first?.gid == gallery.gid)
        #expect(capturedCalls.value.first?.index == 1)
        #expect(capturedCalls.value.first?.imageURL == remotePageURL)
    }

}

// MARK: - Captured Page Call

private struct CapturedPageCall {
    let gid: String
    let index: Int
    let imageURL: URL?
}

// MARK: - Store Factory Helpers

private extension ReadingReducerDownloadTests {
    func makeLocalPageLoadStore(
        initialState: ReadingReducer.State,
        gallery: Gallery,
        localPageURL: URL
    ) -> TestStoreOf<ReadingReducer> {
        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: { AsyncStream { $0.yield([]); $0.finish() } },
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
                loadManifest: { _ in .failure(.notFound) },
                loadLocalPageURLs: { gid in
                    gid == gallery.gid ? .success([1: localPageURL]) : .failure(.notFound)
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off
        return store
    }

    func makeCapturePageStore(
        initialState: ReadingReducer.State,
        capturedCalls: UncheckedBox<[CapturedPageCall]>
    ) -> TestStoreOf<ReadingReducer> {
        let store = TestStore(initialState: initialState) {
            ReadingReducer()
        } withDependencies: {
            $0.appDelegateClient = .noop
            $0.clipboardClient = .noop
            $0.cookieClient = .noop
            $0.databaseClient = .noop
            $0.deviceClient = .noop
            $0.downloadClient = .init(
                observeDownloads: { AsyncStream { $0.finish() } },
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
                loadManifest: { _ in .failure(.notFound) },
                captureCachedPage: { gid, index, imageURL in
                    capturedCalls.value.append(CapturedPageCall(gid: gid, index: index, imageURL: imageURL))
                }
            )
            $0.hapticsClient = .noop
            $0.imageClient = .noop
            $0.urlClient = .noop
        }
        store.exhaustivity = .off
        return store
    }
}
