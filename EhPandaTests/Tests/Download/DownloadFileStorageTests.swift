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
    func testExistingPageRelativePathsDetectsFinalAssetFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: folderURL.appendingPathComponent("123_token_1.webp"), options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_2.jpg"), options: .atomic)
        try Data([0x03]).write(to: folderURL.appendingPathComponent("123_token_27.jpg"), options: .atomic)
        try Data([0x04]).write(to: folderURL.appendingPathComponent("123_token_cover.jpg"), options: .atomic)

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2) == [
                1: "123_token_1.webp",
                2: "123_token_2.jpg"
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
    func testExistingPageRelativePathsRemovesZeroByteFinalAssetFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let emptyPageURL = folderURL.appendingPathComponent("123_token_1.jpg")
        try Data().write(to: emptyPageURL, options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_2.png"), options: .atomic)

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, expectedPageCount: 2) == [
                2: "123_token_2.png"
            ]
        )
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
    }

    @Test
    func testExistingCoverRelativePathDetectsFinalAssetFile() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_cover.jpg"), options: .atomic)

        #expect(storage.existingCoverRelativePath(folderURL: folderURL) == "123_token_cover.jpg")
    }

    @Test
    func testIsReadableAssetFileDoesNotDeleteFileWhenAttributesLookupFails() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let fileURL = rootURL.appendingPathComponent("cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: fileURL, options: .atomic)
        let storage = DownloadFileStorage(
            rootURL: rootURL,
            fileManager: ThrowingAttributesFileManager(failingPath: fileURL.path)
        )

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
    func testFinalFolderRelativePathUsesIdentityPrefixAndSanitizedTitle() {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let unsafeTitle = "  /Alpha\\\\Beta:\n\tGamma   Delta.  "
        let relativePath = storage.makeFolderRelativePath(gid: "123", token: "tok/en", title: unsafeTitle)

        #expect(relativePath == "[123_tok_en] Alpha Beta Gamma Delta")
    }

    @Test
    func testFinalAssetRelativePathsUseIdentityAndUnpaddedPageIndex() {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        #expect(
            storage.makePageRelativePath(gid: "123", token: "token", index: 7, fileExtension: "JPG")
                == "123_token_7.jpg"
        )
        #expect(
            storage.makeCoverRelativePath(gid: "123", token: "token", fileExtension: "PNG")
                == "123_token_cover.png"
        )
    }

    @Test
    func testScanDownloadFoldersReadsOnlyFoldersWithManifests() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let downloadFolderURL = storage.folderURL(relativePath: "[123_token] Sample")
        let ignoredFolderURL = storage.folderURL(relativePath: "[456_token] Missing manifest")
        let hiddenFolderURL = storage.folderURL(relativePath: ".tmp-789")
        try FileManager.default.createDirectory(at: downloadFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hiddenFolderURL, withIntermediateDirectories: true)
        try storage.writeManifest(sampleManifest(pageCount: 2), folderURL: downloadFolderURL)

        let records = try storage.scanDownloadFolders()

        #expect(records.map(\.relativePath) == ["[123_token] Sample"])
        #expect(records.first?.manifest.gid == "123")
        #expect(records.first?.folderURL == downloadFolderURL)
    }

    @Test
    func testExistingFinalAssetFileURLsUseIdentityPrefix() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let pageURL = folderURL.appendingPathComponent("123_token_2.webp")
        let coverURL = folderURL.appendingPathComponent("123_token_cover.jpg")
        try Data([0x01]).write(to: pageURL, options: .atomic)
        try Data([0x02]).write(to: coverURL, options: .atomic)

        #expect(storage.existingPageFileURL(folderURL: folderURL, gid: "123", token: "token", index: 2) == pageURL)
        #expect(storage.existingCoverFileURL(folderURL: folderURL, gid: "123", token: "token") == coverURL)
    }
}

private final class ThrowingAttributesFileManager: FileManager {
    let failingPath: String

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
