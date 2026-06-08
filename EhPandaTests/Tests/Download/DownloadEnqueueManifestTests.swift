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

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let queueStore = DownloadQueueStore(fileURL: storage.queueURL())
        let manager = DownloadManager(
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
            options: .init(threadLimit: 3),
            mode: .initial
        )

        let result = await manager.enqueue(payload: payload)

        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result).")
            return
        }

        let folderRelativePath = storage.makeFolderRelativePath(
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

        let queuedDownload = await manager.testingFetchDownload(gid: gallery.gid)
        #expect(queuedDownload?.status == .queued)
        #expect(queuedDownload?.pageCount == detail.pageCount)
    }
}
