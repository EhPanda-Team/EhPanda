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
    func testDownloadManagerReconcilePreservesIndexedTemporaryFolder() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 31)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] Indexed")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Indexed", pageCount: 2),
            folderURL: folderURL
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        let localPages = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.status == .paused)
        #expect(stored?.completedPageCount == 0)
        #expect(FileManager.default.fileExists(atPath: temporaryFolderURL.path))
        #expect(localPages[1] == temporaryFolderURL.appendingPathComponent("pages/0001.jpg"))
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
        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] Indexed")
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
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: [
                    .init(
                        index: 1,
                        relativePath: "\(gid)_token_1.jpg",
                        fileHash: "sha256:done"
                    )
                ]
            ),
            folderURL: folderURL
        )

        let updateBadge = await manager.updateRemoteVersion(
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

        #expect(updateBadge == .updateAvailable)
        #expect(updatedDownload?.displayStatus == .updateAvailable)
        #expect(updatedDownload?.status == .updateAvailable)

        let currentBadge = await manager.updateRemoteVersion(
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

        #expect(currentBadge == .downloaded)
        #expect(currentDownload?.displayStatus == .completed)
        #expect(currentDownload?.status == .completed)
    }

}
