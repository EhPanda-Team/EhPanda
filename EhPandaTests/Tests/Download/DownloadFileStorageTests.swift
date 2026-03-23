//
//  DownloadFileStorageTests.swift
//  EhPandaTests
//

import Foundation
import XCTest
@testable import EhPanda

final class DownloadFileStorageTests: XCTestCase {
    func testWriteReadAndValidateManifest() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let download = sampleDownload(folderRelativePath: "123 - Sample")
        let folderURL = storage.folderURL(relativePath: download.folderRelativePath)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )

        let manifest = sampleManifest(pageCount: 2)
        try storage.writeManifest(manifest, folderURL: folderURL)
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

        let loadedManifest = try storage.readManifest(folderURL: folderURL)

        XCTAssertEqual(loadedManifest, manifest)
        XCTAssertEqual(storage.validate(download: download), .valid)
    }

    func testEnsureRootDirectoryMarksDownloadsFolderExcludedFromBackup() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()

        let resourceValues = try rootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(resourceValues.isExcludedFromBackup, true)
    }

    func testValidateReportsMissingPageFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let download = sampleDownload(folderRelativePath: "123 - Sample")
        let folderURL = storage.folderURL(relativePath: download.folderRelativePath)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try storage.writeManifest(sampleManifest(pageCount: 2), folderURL: folderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        XCTAssertEqual(
            storage.validate(download: download),
            .missingFiles("Page 2 is missing.")
        )
    }

    func testValidateRemovesZeroBytePageFilesAndRequiresRepair() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let download = sampleDownload(folderRelativePath: "123 - Sample")
        let folderURL = storage.folderURL(relativePath: download.folderRelativePath)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try storage.writeManifest(sampleManifest(pageCount: 2), folderURL: folderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data().write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        XCTAssertEqual(
            storage.validate(download: download),
            .missingFiles("Page 1 is missing.")
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: folderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )
    }

    func testCleanupTemporaryFoldersRemovesOnlyTemporaryArtifacts() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let temporaryURL = storage.temporaryFolderURL(gid: "123")
        let regularURL = storage.folderURL(relativePath: "123 - Sample")
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: regularURL, withIntermediateDirectories: true)

        try storage.cleanupTemporaryFolders()

        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: regularURL.path))
    }

    func testCleanupTemporaryFoldersPreservesSpecifiedGalleryFolders() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let preservedURL = storage.temporaryFolderURL(gid: "123")
        let removedURL = storage.temporaryFolderURL(gid: "456")
        try FileManager.default.createDirectory(at: preservedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: removedURL, withIntermediateDirectories: true)

        try storage.cleanupTemporaryFolders(preservingGIDs: ["123"])

        XCTAssertTrue(FileManager.default.fileExists(atPath: preservedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedURL.path))
    }

    func testExistingPageRelativePathsDetectsCompletedPages() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.temporaryFolderURL(gid: "123")
        let pagesURL = folderURL.appendingPathComponent(
            Defaults.FilePath.downloadPages,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: pagesURL.appendingPathComponent("0001.jpg"), options: .atomic)
        try Data([0x02]).write(to: pagesURL.appendingPathComponent("0002.png"), options: .atomic)
        try Data([0x03]).write(to: pagesURL.appendingPathComponent("0027.jpg"), options: .atomic)
        try Data([0x04]).write(to: pagesURL.appendingPathComponent("invalid.jpg"), options: .atomic)

        XCTAssertEqual(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2),
            [
                1: "pages/0001.jpg",
                2: "pages/0002.png"
            ]
        )
    }

    func testExistingPageRelativePathsRemovesZeroByteFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.temporaryFolderURL(gid: "123")
        let pagesURL = folderURL.appendingPathComponent(
            Defaults.FilePath.downloadPages,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
        let emptyPageURL = pagesURL.appendingPathComponent("0001.jpg")
        try Data().write(to: emptyPageURL, options: .atomic)
        try Data([0x02]).write(to: pagesURL.appendingPathComponent("0002.png"), options: .atomic)

        XCTAssertEqual(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2),
            [
                2: "pages/0002.png"
            ]
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyPageURL.path))
    }

    func testIsReadableAssetFileDoesNotDeleteFileWhenAttributesLookupFails() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let fileManager = ThrowingAttributesFileManager(failingPath: rootURL.path)
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: fileManager)

        try storage.ensureRootDirectory()
        let fileURL = rootURL.appendingPathComponent("cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: fileURL, options: .atomic)
        fileManager.failingPath = fileURL.path

        XCTAssertTrue(storage.isReadableAssetFile(at: fileURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testMakeFolderRelativePathSanitizesSeparatorsWhitespaceAndLength() {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let unsafeTitle = "  /Alpha\\\\Beta:\n\tGamma   Delta \(String(repeating: "X", count: 200)).  "
        let relativePath = storage.makeFolderRelativePath(gid: "123", title: unsafeTitle)

        XCTAssertTrue(relativePath.hasPrefix("123 - "))
        XCTAssertFalse(relativePath.contains("/"))
        XCTAssertFalse(relativePath.contains("\\"))
        XCTAssertFalse(relativePath.contains(":"))
        XCTAssertFalse(relativePath.contains("\n"))
        XCTAssertFalse(relativePath.hasSuffix(" "))
        XCTAssertFalse(relativePath.hasSuffix("."))
        XCTAssertLessThanOrEqual(relativePath.count, "123 - ".count + 96)
    }

    func testWriteAndReadResumeState() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.temporaryFolderURL(gid: "123")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let resumeState = DownloadResumeState(
            mode: .update,
            versionSignature: "hash:v2",
            pageCount: 27,
            downloadOptions: .init(
                threadMode: .quadruple,
                allowCellular: false,
                autoRetryFailedPages: false
            )
        )
        try storage.writeResumeState(resumeState, folderURL: folderURL)

        XCTAssertEqual(
            try storage.readResumeState(folderURL: folderURL),
            resumeState
        )
    }

    func testWriteReadAndRemoveFailedPagesSnapshot() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.temporaryFolderURL(gid: "123")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let snapshot = DownloadFailedPagesSnapshot(
            pages: [
                .init(
                    index: 3,
                    relativePath: "pages/0003.jpg",
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]
        )

        try storage.writeFailedPages(snapshot, folderURL: folderURL)
        XCTAssertEqual(try storage.readFailedPages(folderURL: folderURL), snapshot)

        try storage.removeFailedPages(folderURL: folderURL)
        XCTAssertThrowsError(try storage.readFailedPages(folderURL: folderURL))
    }

    func testMaterializeRepairSeedCopiesOnlyManifestCoverAndExistingPageFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let sourceFolderURL = storage.folderURL(relativePath: "123 - Source")
        let tempFolderURL = storage.temporaryFolderURL(gid: "123")
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        let manifest = sampleManifest(pageCount: 3)
        try storage.writeManifest(manifest, folderURL: sourceFolderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: sourceFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x03]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0003.jpg"),
            options: .atomic
        )
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent("nested", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x09]).write(
            to: sourceFolderURL.appendingPathComponent("nested/ignored.bin"),
            options: .atomic
        )

        try storage.materializeRepairSeed(
            from: sourceFolderURL,
            manifest: manifest,
            to: tempFolderURL
        )

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("cover.jpg").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0002.jpg").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0003.jpg").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("nested/ignored.bin").path
            )
        )
    }

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

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try Data(contentsOf: destinationURL), Data([0x01, 0x02, 0x03]))
    }
}

private final class ThrowingAttributesFileManager: FileManager {
    var failingPath: String

    init(failingPath: String) {
        self.failingPath = failingPath
        super.init()
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if path == failingPath {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
        }
        return try super.attributesOfItem(atPath: path)
    }
}

private final class LinkFailingFileManager: FileManager {
    override func linkItem(at srcURL: URL, to dstURL: URL) throws {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
    }
}

private extension DownloadFileStorageTests {
    func makeStorage() -> (DownloadFileStorage, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            rootURL
        )
    }

    func sampleDownload(
        status: DownloadStatus = .completed,
        folderRelativePath: String
    ) -> DownloadedGallery {
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
            status: status,
            completedPageCount: status == .completed ? 2 : 0,
            lastDownloadedAt: .now,
            lastError: nil,
            downloadOptionsSnapshot: DownloadOptionsSnapshot(),
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v1"
        )
    }

    func sampleManifest(pageCount: Int) -> DownloadManifest {
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
            galleryURL: URL(string: "https://e-hentai.org/g/123/token")!,
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            versionSignature: "hash:v1",
            downloadedAt: .now,
            pages: (1...pageCount).map {
                .init(index: $0, relativePath: "pages/\(String(format: "%04d", $0)).jpg")
            }
        )
    }
}
