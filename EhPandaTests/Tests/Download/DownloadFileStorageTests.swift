//
//  DownloadFileStorageTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadFileStorageTests {
    @Test
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

        let manifest = try sampleManifest(pageCount: 2)
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

        #expect(loadedManifest == manifest)
        #expect(storage.validate(download: download) == .valid)
    }

    @Test
    func testEnsureRootDirectoryMarksDownloadsFolderExcludedFromBackup() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()

        let resourceValues = try rootURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(resourceValues.isExcludedFromBackup == true)
    }

    @Test
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

        #expect(
            storage.validate(download: download) == .missingFiles("Page 2 is missing.")
        )
    }

    @Test
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

        #expect(
            storage.validate(download: download) == .missingFiles("Page 1 is missing.")
        )
        #expect(
            FileManager.default.fileExists(
                atPath: folderURL.appendingPathComponent("pages/0001.jpg").path
            ) == false
        )
    }

    @Test
    func testCleanupTemporaryFoldersRemovesOnlyTemporaryArtifacts() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let temporaryURL = storage.temporaryFolderURL(gid: "123")
        let regularURL = storage.folderURL(relativePath: "123 - Sample")
        try FileManager.default.createDirectory(at: temporaryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: regularURL, withIntermediateDirectories: true)

        try storage.cleanupTemporaryFolders()

        #expect(FileManager.default.fileExists(atPath: temporaryURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: regularURL.path))
    }

    @Test
    func testCleanupTemporaryFoldersPreservesSpecifiedGalleryFolders() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let preservedURL = storage.temporaryFolderURL(gid: "123")
        let removedURL = storage.temporaryFolderURL(gid: "456")
        try FileManager.default.createDirectory(at: preservedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: removedURL, withIntermediateDirectories: true)

        try storage.cleanupTemporaryFolders(preservingGIDs: ["123"])

        #expect(FileManager.default.fileExists(atPath: preservedURL.path))
        #expect(FileManager.default.fileExists(atPath: removedURL.path) == false)
    }

    @Test
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

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2) == [
                1: "pages/0001.jpg",
                2: "pages/0002.png"
            ]
        )
    }

    @Test
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

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2) == [
                2: "pages/0002.png"
            ]
        )
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
    }

    @Test
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

        #expect(storage.isReadableAssetFile(at: fileURL))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func testMakeFolderRelativePathSanitizesSeparatorsWhitespaceAndLength() {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let unsafeTitle = "  /Alpha\\\\Beta:\n\tGamma   Delta \(String(repeating: "X", count: 200)).  "
        let relativePath = storage.makeFolderRelativePath(gid: "123", title: unsafeTitle)

        #expect(relativePath.hasPrefix("123 - "))
        #expect(relativePath.contains("/") == false)
        #expect(relativePath.contains("\\") == false)
        #expect(relativePath.contains(":") == false)
        #expect(relativePath.contains("\n") == false)
        #expect(relativePath.hasSuffix(" ") == false)
        #expect(relativePath.hasSuffix(".") == false)
        #expect(relativePath.count <= "123 - ".count + 96)
    }

    @Test
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

        #expect(try storage.readResumeState(folderURL: folderURL) == resumeState)
    }

    @Test
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
        #expect(try storage.readFailedPages(folderURL: folderURL) == snapshot)

        try storage.removeFailedPages(folderURL: folderURL)
        do {
            _ = try storage.readFailedPages(folderURL: folderURL)
            Issue.record("Expected readFailedPages to throw after removing the snapshot.")
        } catch {
        }
    }

    @Test
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
        let manifest = try sampleManifest(pageCount: 3)
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

        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest).path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("cover.jpg").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0002.jpg").path
            ) == false
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0003.jpg").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("nested/ignored.bin").path
            ) == false
        )
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

        let sourceStorage = DownloadFileStorage(rootURL: sourceRootURL, fileManager: .default)
        let destStorage = DownloadFileStorage(rootURL: destRootURL, fileManager: .default)
        try sourceStorage.ensureRootDirectory()
        try destStorage.ensureRootDirectory()

        let sourceFolderURL = sourceStorage.folderURL(relativePath: "123 - Source")
        let tempFolderURL = destStorage.temporaryFolderURL(gid: "123")
        try FileManager.default.createDirectory(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )

        let manifest = try DownloadManifest(
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
            pageCount: 2,
            coverRelativePath: "cover.jpg",
            galleryURL: try #require(URL(string: "https://e-hentai.org/g/123/token")),
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            versionSignature: "hash:v1",
            downloadedAt: .now,
            pages: [
                .init(index: 1, relativePath: "pages/0001.jpg"),
                .init(index: 2, relativePath: "../escape.jpg")
            ]
        )
        try sourceStorage.writeManifest(manifest, folderURL: sourceFolderURL)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: sourceFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        let escapeURL = sourceFolderURL.deletingLastPathComponent()
            .appendingPathComponent("escape.jpg")
        try Data([0x99]).write(to: escapeURL, options: .atomic)

        try destStorage.materializeRepairSeed(
            from: sourceFolderURL,
            manifest: manifest,
            to: tempFolderURL
        )

        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("pages/0001.jpg").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: tempFolderURL.appendingPathComponent("../escape.jpg")
                    .standardizedFileURL.path
            ) == false
        )
        #expect(
            FileManager.default.fileExists(
                atPath: destRootURL.appendingPathComponent("escape.jpg").path
            ) == false
        )
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

    func sampleManifest(pageCount: Int) throws -> DownloadManifest {
        try DownloadManifest(
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
            galleryURL: try #require(URL(string: "https://e-hentai.org/g/123/token")),
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
