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
        let pageTwoURL = folderURL.appendingPathComponent("123_token_2.jpg")

        let manifest = try storage.addingCurrentFileHashes(
            to: sampleManifest(pageCount: 2),
            folderURL: folderURL
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try Data([0x03]).write(to: pageTwoURL, options: .atomic)

        #expect(
            storage.validate(download: download, verifiesContentHashes: true)
                == .missingFiles("Page 2 image data is corrupted.")
        )
    }

    @Test
    func testRefreshManifestPageFileHashUpdatesSinglePageHash() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (download, folderURL) = try makePreparedDownload(storage: storage)
        let pageTwoURL = folderURL.appendingPathComponent("123_token_2.jpg")

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

        #expect(refreshedManifest.pages[1] == manifest.pages[1])
        #expect(refreshedManifest.pages[2] != manifest.pages[2])
        #expect(storage.validate(download: download, verifiesContentHashes: true) == .valid)
    }

    @Test
    func testAddingCurrentFileHashesPreservesExistingHashesAndFillsEmptyHashes() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (_, folderURL) = try makePreparedDownload(storage: storage)
        let pageOneURL = folderURL.appendingPathComponent("123_token_1.jpg")
        let existingPageOneHash = "sha256:already-flushed"
        try Data([0x09]).write(to: pageOneURL, options: .atomic)
        let manifest = try sampleManifest(
            pageHashes: [
                1: existingPageOneHash,
                2: ""
            ]
        )

        let hashedManifest = try storage.addingCurrentFileHashes(
            to: manifest,
            folderURL: folderURL
        )

        #expect(hashedManifest.pages[1] == existingPageOneHash)
        #expect(hashedManifest.pages[2]?.hasPrefix("sha256:") == true)
        #expect(hashedManifest.pages[2]?.isEmpty == false)
    }

    private func makePreparedDownload(
        storage: DownloadFileStorage
    ) throws -> (DownloadedGallery, URL) {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "123 - Sample")
        let download = sampleDownload(folderURL: folderURL)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("123_token_cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("123_token_1.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("123_token_2.jpg"),
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

    private func sampleDownload(folderURL: URL) -> DownloadedGallery {
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
            folderURL: folderURL,
            displayStatus: .completed,
            completedPageCount: 2,
            lastDownloadedAt: .now,
            lastError: nil
        )
    }

    private func sampleManifest(pageCount: Int) throws -> DownloadManifest {
        try sampleManifest(
            pageHashes: pageCount > 0
                ? Dictionary(uniqueKeysWithValues: (1...pageCount).map { ($0, "") })
                : [:]
        )
    }

    private func sampleManifest(pageHashes: [Int: String]) throws -> DownloadManifest {
        DownloadManifest(
            gid: "123",
            host: .ehentai,
            token: "token",
            title: "Sample",
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            rating: 4,
            pages: pageHashes
        )
    }
}
