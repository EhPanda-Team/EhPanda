//
//  DownloadVersionSignatureTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadVersionSignatureTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerReconcilePreservesIndexedFinalFolder() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 31)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Indexed")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Indexed", pageCount: 2),
            folderURL: folderURL
        )

        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        let pageURL = folderURL.appendingPathComponent("\(gid)_token_1.jpg")
        try Data([0x01]).write(
            to: pageURL,
            options: .atomic
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        let localPages = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.displayStatus == .inactive)
        #expect(stored?.completedPageCount == 0)
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
        #expect(localPages[1] == pageURL)
    }

    @MainActor
    @Test
    func testUpdateRemoteVersionUsesIndexedSessionFlag() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Indexed")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            DownloadManifest(
                gid: gid,
                host: .ehentai,
                token: "token",
                title: "Indexed",
                jpnTitle: nil,
                category: .doujinshi,
                language: .japanese,
                remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: [1: "sha256:done"]
            ),
            folderURL: folderURL
        )
        await manager.reloadDownloadIndex()

        let updateResult = await manager.updateRemoteVersion(
            gid: gid,
            metadata: DownloadVersionMetadata(
                gid: gid,
                token: "token",
                currentGID: gid,
                currentKey: "new-token",
                parentGID: gid,
                parentKey: "token",
                firstGID: gid,
                firstKey: "token"
            )
        )
        let updatedDownload = await manager.testingFetchDownload(gid: gid)

        #expect(updateResult?.displayStatus == .updateAvailable)
        #expect(updatedDownload?.displayStatus == .updateAvailable)
        #expect(updatedDownload?.displayStatus == .updateAvailable)

        let currentResult = await manager.updateRemoteVersion(
            gid: gid,
            metadata: DownloadVersionMetadata(
                gid: gid,
                token: "token",
                currentGID: gid,
                currentKey: "token",
                parentGID: gid,
                parentKey: "token",
                firstGID: gid,
                firstKey: "token"
            )
        )
        let currentDownload = await manager.testingFetchDownload(gid: gid)

        #expect(currentResult?.displayStatus == .completed)
        #expect(currentDownload?.displayStatus == .completed)
        #expect(currentDownload?.displayStatus == .completed)
    }

}
