//
//  DownloadEnqueueManifestTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadEnqueueManifestTests: DownloadFeatureTestCase {
    @Test
    func testEnqueueWritesInitialManifestAndQueueIntent() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )
        await manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: "Downloaded / Gallery")
        let payload = DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: .initial
        )

        // Warm the index the way launch does; enqueue then patches it in place.
        await manager.reloadDownloadIndex()
        let result = await manager.enqueue(payload: payload)

        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result).")
            return
        }

        let folderRelativePath = "Folder/" + storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        let manifest = try storage.readManifest(
            folderURL: storage.folderURL(relativePath: folderRelativePath)
        )

        #expect(queueStore.gids == [gallery.gid])
        #expect(manifest.gid == gallery.gid)
        #expect(manifest.token == gallery.token)
        #expect(manifest.pageCount == detail.pageCount)
        #expect(manifest.remoteCoverURL == detail.coverURL)
        #expect(manifest.pages.count == detail.pageCount)
        #expect(manifest.pages[1] == "")

        let manifestData = try Data(
            contentsOf: storage
                .folderURL(relativePath: folderRelativePath)
                .appendingPathComponent(Defaults.FilePath.downloadManifest)
        )
        let manifestObject = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        #expect(manifestObject["downloadOptions"] == nil)

        let queuedDownload = await manager.fetchDownload(gid: gallery.gid)
        #expect(queuedDownload?.displayStatus == .queued)
        #expect(queuedDownload?.onlineCoverURL == detail.coverURL)
        #expect(queuedDownload?.pageCount == detail.pageCount)
    }

    @Test
    func testEnqueuePreservesExistingManifestHashes() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            queueStore: queueStore
        )
        await manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let folderRelativePath = "Folder/" + storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        let pages = Dictionary(
            uniqueKeysWithValues: (1...detail.pageCount).map {
                ($0, "sha256:existing-\($0)")
            }
        )
        let existingManifest = DownloadManifest(
            gid: gallery.gid,
            host: .ehentai,
            token: gallery.token,
            title: gallery.title,
            jpnTitle: detail.jpnTitle,
            category: gallery.category,
            language: detail.language,
            remoteCoverURL: detail.coverURL,
            uploader: detail.uploader,
            tags: gallery.tags,
            postedDate: detail.postedDate,
            rating: detail.rating,
            pages: pages
        )
        try storage.writeManifest(existingManifest, folderURL: folderURL)

        // Warm the index the way launch does; enqueue then patches it in place.
        await manager.reloadDownloadIndex()
        let result = await manager.enqueue(payload: .init(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: .initial
        ))

        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result).")
            return
        }

        let preservedManifest = try storage.readManifest(folderURL: folderURL)
        #expect(preservedManifest.pages == pages)
        #expect(queueStore.gids == [gallery.gid])
        #expect(await manager.fetchDownload(gid: gallery.gid)?.completedPageCount == detail.pageCount)
    }
}
