//
//  DownloadObserverBatchTests.swift
//  EhPandaTests
//

import Foundation
import CoreData
import ComposableArchitecture
import Kingfisher
import UIKit
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadObserverBatchTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorClearsInspectionWhenObservedDownloadDisappears() async {
        let download = sampleDownload(
            gid: "9988",
            title: "Observed Archive",
            status: .completed
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.yield([download])
                        continuation.yield([])
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(inspection) }
            )
        }
        store.exhaustivity = .off

        await store.send(.observeDownloads)
        await store.receive(\.observeDownloadsDone, [download])
        await store.receive(\.observeDownloadsDone, []) {
            $0.inspection = nil
            $0.stableInspection = nil
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadManagerBatchesObserverUpdatesDuringCachedPageRestore() async throws {
        let container = try makeInMemoryContainer()
        let pageCount = 20
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        try insertPersistedDownload(
            in: container, gid: gid, status: .downloading, completedPageCount: 0, pageCount: pageCount
        )

        let cacheKeys = try await setupBatchRestoreCachedImages(
            container: container, gid: gid, pageCount: pageCount
        )
        defer { cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) } }
        await waitUntilCacheReady(for: cacheKeys)

        let observationStream = await manager.observeDownloads()
        let emissionTask = Task<Int, Never> {
            var emissionCount = 0
            for await downloads in observationStream {
                guard let relevantDownload = downloads.first(where: { $0.gid == gid }) else { continue }
                emissionCount += 1
                if relevantDownload.completedPageCount == pageCount { break }
            }
            return emissionCount
        }

        let payload = try makeBatchRestorePayload(gid: gid, pageCount: pageCount)
        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let emissionCount = try await waitForTaskValue(
            emissionTask,
            timeout: .seconds(2),
            description: "observer updates for cached page restore"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(restoredCount == pageCount)
        #expect(stored?.completedPageCount == pageCount)
        #expect(emissionCount < pageCount)
        #expect(emissionCount <= 1 + Int(ceil(Double(pageCount) / 8.0)))
    }
}

// MARK: - Setup Helpers

private extension DownloadObserverBatchTests {
    @MainActor
    func setupBatchRestoreCachedImages(
        container: NSPersistentContainer,
        gid: String,
        pageCount: Int
    ) async throws -> Set<String> {
        let cachedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(cachedImage.jpegData(compressionQuality: 1))
        let imageURLs = try Dictionary(uniqueKeysWithValues: (1...pageCount).map { index in
            (index, try #require(URL(string: "https://example.com/pages/\(gid)-\(index).jpg")))
        })
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: imageURLs)
        let cacheKeys = Set(imageURLs.values.flatMap { $0.imageCacheKeys(includeStableAlias: true) })
        for cacheKey in cacheKeys {
            try await KingfisherManager.shared.cache.storeToDisk(imageData, forKey: cacheKey)
        }
        return cacheKeys
    }

    func makeBatchRestorePayload(gid: String, pageCount: Int) throws -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Cached Restore Gallery", rating: 4,
                tags: [], category: .doujinshi, uploader: "Uploader", pageCount: pageCount,
                postedDate: .now, coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: try #require(URL(string: "https://e-hentai.org/g/\(gid)/token") as URL?)
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Cached Restore Gallery", jpnTitle: nil,
                isFavorited: false, visibility: .yes, rating: 4, userRating: 0, ratingCount: 0,
                category: .doujinshi, language: .japanese, uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: pageCount, sizeCount: 12, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, options: DownloadOptionsSnapshot(), mode: .initial
        )
    }
}
