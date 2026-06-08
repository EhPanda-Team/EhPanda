//
//  DownloadFileStorageRepairTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadFileStorageRepairTests {
    @Test
    func testMaterializeRepairSeedCopiesOnlyManifestCoverAndExistingPageFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let sourceFolderURL = storage.folderURL(relativePath: "123 - Source")
        let tempFolderURL = storage.temporaryFolderURL(gid: "123")
        let manifest = try sampleManifest(pageCount: 3)
        try setupRepairSourceFiles(
            sourceFolderURL: sourceFolderURL, storage: storage, manifest: manifest
        )

        try storage.materializeRepairSeed(
            from: sourceFolderURL, manifest: manifest, to: tempFolderURL
        )

        verifyRepairSeedResult(tempFolderURL: tempFolderURL)
    }

    @Test
    func testMaterializeRepairSeedRejectsTraversalPathsInManifestPages() throws {
        let sourceRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: sourceRootURL)
            try? FileManager.default.removeItem(at: destRootURL)
        }

        let env = try setupTraversalTestEnvironment(
            sourceRootURL: sourceRootURL, destRootURL: destRootURL
        )

        try env.destStorage.materializeRepairSeed(
            from: env.sourceFolderURL, manifest: env.manifest, to: env.tempFolderURL
        )

        #expect(FileManager.default.fileExists(
            atPath: env.tempFolderURL.appendingPathComponent("pages/0001.jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: env.tempFolderURL.appendingPathComponent("../escape.jpg").standardizedFileURL.path
        ) == false)
        #expect(FileManager.default.fileExists(
            atPath: destRootURL.appendingPathComponent("escape.jpg").path
        ) == false)
    }

    @Test
    func testLinkOrCopyReadableAssetFallsBackToCopyWhenHardLinkFails() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let fileManager = LinkFailingFileManager()
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: fileManager)
        try storage.ensureRootDirectory()

        let sourceURL = rootURL.appendingPathComponent("source.bin")
        let destinationURL = rootURL.appendingPathComponent("nested/destination.bin")
        try Data([0x01, 0x02, 0x03]).write(to: sourceURL, options: .atomic)

        try storage.linkOrCopyReadableAsset(at: sourceURL, to: destinationURL)

        #expect(FileManager.default.fileExists(atPath: destinationURL.path))
        #expect(try Data(contentsOf: destinationURL) == Data([0x01, 0x02, 0x03]))
    }
}

private final class LinkFailingFileManager: FileManager {
    override func linkItem(at srcURL: URL, to dstURL: URL) throws {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
    }
}

private struct TraversalTestEnvironment {
    let sourceStorage: DownloadFileStorage
    let destStorage: DownloadFileStorage
    let sourceFolderURL: URL
    let tempFolderURL: URL
    let manifest: DownloadManifest
}

private extension DownloadFileStorageRepairTests {
    func setupTraversalTestEnvironment(
        sourceRootURL: URL, destRootURL: URL
    ) throws -> TraversalTestEnvironment {
        let sourceStorage = DownloadFileStorage(rootURL: sourceRootURL, fileManager: .default)
        let destStorage = DownloadFileStorage(rootURL: destRootURL, fileManager: .default)
        try sourceStorage.ensureRootDirectory()
        try destStorage.ensureRootDirectory()
        let sourceFolderURL = sourceStorage.folderURL(relativePath: "123 - Source")
        let tempFolderURL = destStorage.temporaryFolderURL(gid: "123")
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages, isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        let manifest = DownloadManifest(
            gid: "123", host: .ehentai, token: "token", title: "Sample", jpnTitle: nil,
            category: .doujinshi, language: .japanese, uploader: "Uploader", tags: [],
            postedDate: .now, pageCount: 2, coverRelativePath: "cover.jpg",
            rating: 4, downloadOptions: DownloadOptionsSnapshot(),
            downloadedAt: .now,
            pages: [
                .init(index: 1, relativePath: "pages/0001.jpg"),
                .init(index: 2, relativePath: "../escape.jpg")
            ]
        )
        try sourceStorage.writeManifest(manifest, folderURL: sourceFolderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: sourceFolderURL.appendingPathComponent("cover.jpg"), options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0001.jpg"), options: .atomic
        )
        let escapeURL = sourceFolderURL.deletingLastPathComponent().appendingPathComponent("escape.jpg")
        try Data([0x99]).write(to: escapeURL, options: .atomic)
        return TraversalTestEnvironment(
            sourceStorage: sourceStorage, destStorage: destStorage,
            sourceFolderURL: sourceFolderURL, tempFolderURL: tempFolderURL, manifest: manifest
        )
    }

    func setupRepairSourceFiles(
        sourceFolderURL: URL,
        storage: DownloadFileStorage,
        manifest: DownloadManifest
    ) throws {
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try storage.writeManifest(manifest, folderURL: sourceFolderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: sourceFolderURL.appendingPathComponent("cover.jpg"), options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0001.jpg"), options: .atomic
        )
        try Data([0x03]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0003.jpg"), options: .atomic
        )
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent("nested", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x09]).write(
            to: sourceFolderURL.appendingPathComponent("nested/ignored.bin"), options: .atomic
        )
    }

    func verifyRepairSeedResult(tempFolderURL: URL) {
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest).path
        ))
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent("cover.jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent("pages/0001.jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent("pages/0002.jpg").path
        ) == false)
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent("pages/0003.jpg").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: tempFolderURL.appendingPathComponent("nested/ignored.bin").path
        ) == false)
    }

    func makeStorage() -> (DownloadFileStorage, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            rootURL
        )
    }

    func sampleManifest(pageCount: Int) throws -> DownloadManifest {
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
            pageCount: pageCount,
            coverRelativePath: "cover.jpg",
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            downloadedAt: .now,
            pages: (1...pageCount).map {
                .init(index: $0, relativePath: "pages/\(String(format: "%04d", $0)).jpg")
            }
        )
    }
}
