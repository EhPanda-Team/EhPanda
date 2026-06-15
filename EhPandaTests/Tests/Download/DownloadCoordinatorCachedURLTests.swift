//
//  DownloadCoordinatorCachedURLTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadCoordinatorCachedURLTests {
    @Test
    func testIndexedDownloadUsesCachedLocalURLsUntilExplicitReload() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        let folderRelativePath = "Folder/[900_token] Cached"
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        let page1URL = folderURL.appendingPathComponent("900_token_1.jpg")
        let page2URL = folderURL.appendingPathComponent("900_token_2.jpg")
        let coverURL = folderURL.appendingPathComponent("900_token_cover.jpg")

        try storage.ensureRootDirectory()
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(manifest(), folderURL: folderURL)
        try Data([0x01]).write(to: page1URL, options: .atomic)
        await manager.reloadDownloadIndex()

        let initialDownload = try #require(await manager.fetchDownload(gid: "900"))
        #expect(initialDownload.localCoverURL == nil)
        #expect(initialDownload.localPageURLs == [1: page1URL])

        try Data([0x02]).write(to: page2URL, options: .atomic)
        try Data([0x03]).write(to: coverURL, options: .atomic)

        let cachedDownload = try #require(await manager.fetchDownload(gid: "900"))
        let cachedPageURLs = try await manager.loadLocalPageURLs(gid: "900").get()

        #expect(cachedDownload.localCoverURL == nil)
        #expect(cachedDownload.localPageURLs == [1: page1URL])
        #expect(cachedPageURLs == [1: page1URL])

        await manager.reloadDownloadIndex()

        let reloadedDownload = try #require(await manager.fetchDownload(gid: "900"))
        #expect(reloadedDownload.localCoverURL == coverURL)
        #expect(reloadedDownload.localPageURLs == [1: page1URL, 2: page2URL])
    }
}

private extension DownloadCoordinatorCachedURLTests {
    func manifest() -> DownloadManifest {
        DownloadManifest(
            gid: "900",
            host: .ehentai,
            token: "token",
            title: "Cached",
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: Date(timeIntervalSince1970: 1_000),
            rating: 4,
            pages: [1: "", 2: ""]
        )
    }
}
