//
//  DownloadedGalleryManifestModelTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadedGalleryManifestModelTests {
    @Test
    func testManifestCompletedPageCountDerivesFromNonEmptyHashes() throws {
        let manifest = try sampleManifest(pageHashes: [1: "sha256:a", 2: "", 3: nil])

        #expect(manifest.completedPageCount == 1)
        #expect(manifest.isComplete == false)
    }

    @Test
    func testManifestDerivedFieldsAreNotEncoded() throws {
        let manifest = try sampleManifest(pageHashes: [1: "sha256:a", 2: "sha256:b"])
        let encoded = try JSONEncoder().encode(manifest)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(manifest.pageCount == 2)
        #expect(manifest.galleryURL == URL(string: "https://e-hentai.org/g/123/token"))
        #expect(object["pageCount"] == nil)
        #expect(object["galleryURL"] == nil)
        #expect(object["coverFileHash"] == nil)
        #expect(object["coverRelativePath"] == nil)
        #expect(object["downloadOptions"] == nil)
        #expect(object["downloadedAt"] == nil)
    }

    @Test
    func testDownloadedGalleryViewModelUsesManifestAndRuntimeStatus() throws {
        let modificationDate = Date(timeIntervalSince1970: 1_234)
        let manifest = try sampleManifest(pageHashes: [1: "sha256:a", 2: "sha256:b"])

        let download = DownloadedGallery(
            manifest: manifest,
            folderURL: URL(fileURLWithPath: "/tmp/Folder/[123_token] Sample", isDirectory: true),
            folderName: "Folder",
            localCoverURL: nil,
            localPageURLs: [:],
            modificationDate: modificationDate,
            displayStatus: .queued
        )

        #expect(download.gid == "123")
        #expect(download.folderURL.lastPathComponent == "[123_token] Sample")
        #expect(download.displayStatus == .queued)
        #expect(download.onlineCoverURL == manifest.remoteCoverURL)
        #expect(download.completedPageCount == 2)
        #expect(download.lastDownloadedDate == modificationDate)
    }
}

private extension DownloadedGalleryManifestModelTests {
    func sampleManifest(pageHashes: [Int: String?]) throws -> DownloadManifest {
        DownloadManifest(
            gid: "123",
            host: .ehentai,
            token: "token",
            title: "Sample",
            jpnTitle: "サンプル",
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: Date(timeIntervalSince1970: 1_000),
            rating: 4,
            pages: Dictionary(
                uniqueKeysWithValues:
                    pageHashes.map { index, hash in (index, hash ?? "") }
            )
        )
    }
}
