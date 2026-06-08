//
//  DownloadFileStorageHashTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadFileStorageHashTests {
    @Test
    func testValidateReportsCorruptedPageImageData() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (download, folderURL) = try makePreparedDownload(storage: storage)
        let pageTwoURL = folderURL.appendingPathComponent("pages/0002.jpg")

        let manifest = try storage.addingCurrentFileHashes(
            to: sampleManifest(pageCount: 2),
            folderURL: folderURL
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try Data([0x03]).write(to: pageTwoURL, options: .atomic)

        #expect(
            storage.validate(download: download)
                == .missingFiles("Page 2 image data is corrupted.")
        )
    }

    @Test
    func testRefreshManifestPageFileHashUpdatesSinglePageHash() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (download, folderURL) = try makePreparedDownload(storage: storage)
        let pageTwoURL = folderURL.appendingPathComponent("pages/0002.jpg")

        let manifest = try storage.addingCurrentFileHashes(
            to: sampleManifest(pageCount: 2),
            folderURL: folderURL
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try Data([0x03]).write(to: pageTwoURL, options: .atomic)

        let refreshedManifest = try storage.refreshManifestPageFileHash(
            folderURL: folderURL,
            pageIndex: 2
        )

        #expect(refreshedManifest.pages[0].fileHash == manifest.pages[0].fileHash)
        #expect(refreshedManifest.pages[1].fileHash != manifest.pages[1].fileHash)
        #expect(storage.validate(download: download) == .valid)
    }

    private func makePreparedDownload(
        storage: DownloadFileStorage
    ) throws -> (DownloadedGallery, URL) {
        try storage.ensureRootDirectory()
        let download = sampleDownload(folderRelativePath: "123 - Sample")
        let folderURL = storage.folderURL(relativePath: download.folderRelativePath)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )
        return (download, folderURL)
    }

    private func makeStorage() -> (DownloadFileStorage, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            rootURL
        )
    }

    private func sampleDownload(folderRelativePath: String) -> DownloadedGallery {
        DownloadedGallery(
            gid: "123",
            host: .ehentai,
            token: "token",
            title: "Sample",
            jpnTitle: nil,
            uploader: "Uploader",
            category: .doujinshi,
            tags: [],
            pageCount: 2,
            postedDate: .now,
            rating: 4,
            onlineCoverURL: URL(string: "https://example.com/cover.jpg"),
            folderRelativePath: folderRelativePath,
            coverRelativePath: "cover.jpg",
            status: .completed,
            completedPageCount: 2,
            lastDownloadedAt: .now,
            lastError: nil,
            downloadOptionsSnapshot: DownloadOptionsSnapshot(),
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v1"
        )
    }

    private func sampleManifest(pageCount: Int) throws -> DownloadManifest {
        DownloadManifest(
            gid: "123",
            host: .ehentai,
            token: "token",
            title: "Sample",
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            coverRelativePath: "cover.jpg",
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            pages: (1...pageCount).map {
                .init(index: $0, relativePath: "pages/\(String(format: "%04d", $0)).jpg")
            }
        )
    }
}
