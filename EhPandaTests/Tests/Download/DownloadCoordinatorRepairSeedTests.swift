//
//  DownloadCoordinatorRepairSeedTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadCoordinatorRepairSeedTests: DownloadFeatureTestCase {
    @Test
    func testRepairSeedReusesCompletedFilesWhenPageCountMatches() async throws {
        let gid = "repair-seed-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let sourceFolderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Existing")
        let existingDownload = sampleDownload(
            gid: gid, title: "Mixed Version", status: .missingFiles,
            pageCount: 2, completedPageCount: 2,
            folderURL: sourceFolderURL
        )
        try setupRepairSeedFiles(
            storage: storage,
            sourceFolderURL: sourceFolderURL,
            gid: gid
        )

        let payload = makeRepairSeedPayload(gid: gid)
        let folderRelativePath = await manager.folderRelativePath(
            for: payload,
            parentFolderName: existingDownload.folderName
        )
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try? FileManager.default.removeItem(at: folderURL)
        let workingSeed = try await manager.prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )

        let pageOneRelativePath = storage.makePageRelativePath(
            gid: gid, token: "token", index: 1, fileExtension: "jpg"
        )
        let pageTwoRelativePath = storage.makePageRelativePath(
            gid: gid, token: "token", index: 2, fileExtension: "jpg"
        )
        let coverRelativePath = storage.makeCoverRelativePath(
            gid: gid, token: "token", fileExtension: "jpg"
        )
        let manifest = workingSeed.manifest
        #expect(manifest.gid == gid)
        #expect(workingSeed.existingPages == [
            1: pageOneRelativePath,
            2: pageTwoRelativePath
        ])
        #expect(workingSeed.coverRelativePath == coverRelativePath)
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent(pageOneRelativePath).path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent(pageTwoRelativePath).path
            )
        )
    }

    @Test
    func testDownloadCoordinatorLoadLocalPageURLsRemovesZeroBytePage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 13)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let (emptyPageURL, goodPageURL) = try setupZeroBytePageFiles(
            rootURL: rootURL, gid: gid, storage: storage
        )
        await manager.reloadDownloadIndex()

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == nil)
        #expect(pageURLs[2] == goodPageURL)
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
    }

    @Test
    func testRescanLocalPageURLsDropsExternallyDeletedPage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 71)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let folderURL = rootURL.appendingPathComponent(
            "Folder/\(gid) - Rescan", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: folderURL, withIntermediateDirectories: true
        )
        try JSONEncoder().encode(sampleManifest(gid: gid, title: "Rescan")).write(
            to: folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        let pageOneURL = folderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 1, fileExtension: "jpg")
        )
        let pageTwoURL = folderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 2, fileExtension: "jpg")
        )
        try Data([0x01]).write(to: pageOneURL, options: .atomic)
        try Data([0x02]).write(to: pageTwoURL, options: .atomic)
        await manager.reloadDownloadIndex()

        #expect(await manager.rescanLocalPageURLs(gid: gid) == [1: pageOneURL, 2: pageTwoURL])

        try FileManager.default.removeItem(at: pageOneURL)

        #expect(await manager.rescanLocalPageURLs(gid: gid) == [2: pageTwoURL])
    }

}

// MARK: - Repair Seed Helpers

private extension DownloadCoordinatorRepairSeedTests {
    func setupRepairSeedFiles(
        storage: DownloadStore,
        sourceFolderURL: URL,
        gid: String
    ) throws {
        try FileManager.default.createDirectory(
            at: sourceFolderURL,
            withIntermediateDirectories: true
        )
        let oldManifest = try sampleManifest(
            gid: gid, title: "Mixed Version",
            pageCount: 2
        )
        try JSONEncoder().encode(oldManifest).write(
            to: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makePageRelativePath(gid: gid, token: "token", index: 1, fileExtension: "jpg")
            ),
            options: .atomic
        )
        try Data([0x02]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makePageRelativePath(gid: gid, token: "token", index: 2, fileExtension: "jpg")
            ),
            options: .atomic
        )
    }

    func makeRepairSeedPayload(gid: String) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Mixed Version",
                rating: 4, tags: [], category: .doujinshi,
                uploader: "Uploader", pageCount: 2, postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Mixed Version", jpnTitle: nil,
                isFavorited: false, visibility: .yes,
                rating: 4, userRating: 0, ratingCount: 1,
                category: .doujinshi, language: .japanese,
                uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: 2,
                sizeCount: 1, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, folderName: "Folder", mode: .repair
        )
    }

    func setupZeroBytePageFiles(
        rootURL: URL, gid: String, storage: DownloadStore
    ) throws -> (URL, URL) {
        let completedFolderURL = rootURL.appendingPathComponent(
            "Folder/\(gid) - Pause Race", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: completedFolderURL,
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        let emptyPageURL = completedFolderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 1, fileExtension: "jpg")
        )
        try Data().write(to: emptyPageURL, options: .atomic)
        let goodPageURL = completedFolderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 2, fileExtension: "jpg")
        )
        try Data([0x02]).write(to: goodPageURL, options: .atomic)
        return (emptyPageURL, goodPageURL)
    }
}
