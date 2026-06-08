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
    func testManifestGalleryURLDerivesFromIdentityAndIsNotEncoded() throws {
        let manifest = try sampleManifest(pageHashes: [1: "sha256:a"])
        let encoded = try JSONEncoder().encode(manifest)
        let object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        #expect(manifest.galleryURL == URL(string: "https://e-hentai.org/g/123/token"))
        #expect(object["galleryURL"] == nil)
    }

    @Test
    func testDownloadedGalleryViewModelUsesManifestAndRuntimeStatus() throws {
        let modifiedAt = Date(timeIntervalSince1970: 1_234)
        let manifest = try sampleManifest(pageHashes: [1: "sha256:a", 2: "sha256:b"])

        let download = DownloadedGallery(
            manifest: manifest,
            folderRelativePath: "[123_token] Sample",
            modifiedAt: modifiedAt,
            displayStatus: .queued
        )

        #expect(download.gid == "123")
        #expect(download.folderRelativePath == "[123_token] Sample")
        #expect(download.status == .queued)
        #expect(download.completedPageCount == 2)
        #expect(download.lastDownloadedAt == modifiedAt)
        #expect(download.downloadOptionsSnapshot.threadLimit == 3)
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
            uploader: "Uploader",
            tags: [],
            postedDate: Date(timeIntervalSince1970: 1_000),
            pageCount: pageHashes.count,
            coverRelativePath: "123_token_cover.jpg",
            rating: 4,
            downloadOptions: .init(threadLimit: 3),
            downloadedAt: Date(timeIntervalSince1970: 1_111),
            pages: pageHashes.sorted(by: { $0.key < $1.key }).map { index, hash in
                .init(
                    index: index,
                    relativePath: "123_token_\(index).jpg",
                    fileHash: hash
                )
            }
        )
    }
}
