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
    @Test
    func testContainerDataSourceHandlesZeroPageGallery() {
        var gallery = sampleGallery()
        gallery.pageCount = 0
        var state = ReadingReducer.State()
        state.gallery = gallery

        var dualPageSetting = Setting()
        dualPageSetting.enablesDualPageMode = true
        dualPageSetting.readingDirection = .leftToRight
        dualPageSetting.exceptCover = true

        #expect(state.containerDataSource(setting: Setting(), isLandscape: false) == [])
        #expect(state.containerDataSource(setting: dualPageSetting, isLandscape: true) == [])
    }

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

        let store = TestStore(
            initialState: initialState,
            reducer: ReadingReducer.init,
            withDependencies: {
                $0.appDelegateClient = .noop
                $0.clipboardClient = .noop
                $0.cookieClient = .noop
                $0.databaseClient = .noop
                $0.deviceClient = .noop
                $0.downloadClient = .noop
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.captureCachedPage = { gid, index, imageURL in
                    capturedCalls.value.append((gid, index, imageURL))
                }
                $0.hapticsClient = .noop
                $0.imageClient = .noop
                $0.urlClient = .noop
            }
        )
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
        let gid = "777"
        let title = "Offline Archive"
        let folderURL = FileUtil.downloadsDirectoryURL
            .appendingPathComponent("[\(gid)_token] \(title)", isDirectory: true)
        let localPageURLs = [
            1: folderURL.appendingPathComponent("123_token_1.jpg"),
            2: folderURL.appendingPathComponent("123_token_2.jpg")
        ]
        let download = sampleDownload(
            gid: gid,
            title: title,
            status: .completed,
            pageCount: 2,
            folderURL: folderURL,
            localPageURLs: localPageURLs
        )
        let manifest = try sampleManifest(gid: download.gid, title: download.title)
        _ = try prepareLocalDownloadFiles(download: download, manifest: manifest)
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
