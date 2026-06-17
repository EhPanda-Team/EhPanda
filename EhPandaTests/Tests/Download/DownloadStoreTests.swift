//
//  DownloadStoreTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

struct DownloadStoreTests {
    @Test
    func testWriteReadAndValidateManifest() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "123 - Sample")
        let download = sampleDownload(folderURL: folderURL)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
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
        let manifest = try storage.addingCurrentFileHashes(
            to: sampleManifest(pageCount: 2),
            folderURL: folderURL
        )
        try storage.writeManifest(manifest, folderURL: folderURL)

        let loadedManifest = try storage.readManifest(folderURL: folderURL)

        #expect(loadedManifest == manifest)
        #expect(storage.validate(download: download, verifiesContentHashes: true) == .valid)
    }

    @Test
    func testPurgeBackgroundTransferHoldingDirectoryRemovesOrphans() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let holdingDirectory = storage.backgroundTransferHoldingDirectoryURL()
        try FileManager.default.createDirectory(
            at: holdingDirectory, withIntermediateDirectories: true
        )
        let orphan = holdingDirectory.appendingPathComponent("orphan.tmp")
        try Data([0x01]).write(to: orphan, options: .atomic)
        #expect(FileManager.default.fileExists(atPath: orphan.path))

        storage.purgeBackgroundTransferHoldingDirectory()

        #expect(FileManager.default.fileExists(atPath: orphan.path) == false)
        #expect(FileManager.default.fileExists(atPath: holdingDirectory.path) == false)
    }

    @Test
    func testReadManifestRejectsEmptyPages() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "123 - Empty")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try storage.writeManifest(sampleManifest(pageCount: 0), folderURL: folderURL)

        #expect(
            throws: AppError.fileOperationFailed(
                L10n.Localizable.DownloadStore.Validation.manifestCorrupted
            )
        ) {
            try storage.readManifest(folderURL: folderURL)
        }
    }

    @Test
    func testReadManifestRejectsNonContiguousPages() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "123 - Sparse")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try storage.writeManifest(sampleManifest(pageHashes: [1: "", 3: ""]), folderURL: folderURL)

        #expect(
            throws: AppError.fileOperationFailed(
                L10n.Localizable.DownloadStore.Validation.manifestCorrupted
            )
        ) {
            try storage.readManifest(folderURL: folderURL)
        }
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
        let folderURL = storage.folderURL(relativePath: "123 - Sample")
        let download = sampleDownload(folderURL: folderURL)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("123_token_cover.jpg"),
            options: .atomic
        )
        let page1URL = folderURL.appendingPathComponent("123_token_1.jpg")
        try Data([0x01]).write(to: page1URL, options: .atomic)
        try storage.writeManifest(
            sampleManifest(pageHashes: [
                1: try storage.fileHash(at: page1URL),
                2: "sha256:missing"
            ]),
            folderURL: folderURL
        )

        #expect(
            storage.validate(download: download, verifiesContentHashes: true) == .missingFiles("Page 2 is missing.")
        )
    }

    @Test
    func testValidateRemovesZeroBytePageFilesAndRequiresRepair() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "123 - Sample")
        let download = sampleDownload(folderURL: folderURL)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0xFF, 0xD8, 0xFF]).write(
            to: folderURL.appendingPathComponent("123_token_cover.jpg"),
            options: .atomic
        )
        try Data().write(
            to: folderURL.appendingPathComponent("123_token_1.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("123_token_2.jpg"),
            options: .atomic
        )
        let page2URL = folderURL.appendingPathComponent("123_token_2.jpg")
        try storage.writeManifest(
            sampleManifest(pageHashes: [
                1: "sha256:missing",
                2: try storage.fileHash(at: page2URL)
            ]),
            folderURL: folderURL
        )

        #expect(
            storage.validate(download: download, verifiesContentHashes: true) == .missingFiles("Page 1 is missing.")
        )
        #expect(
            FileManager.default.fileExists(
                atPath: folderURL.appendingPathComponent("123_token_1.jpg").path
            ) == false
        )
    }

    @Test
    func testExistingPageRelativePathsDetectsFinalAssetFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: folderURL.appendingPathComponent("123_token_1.webp"), options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_2.jpg"), options: .atomic)
        try Data([0x03]).write(to: folderURL.appendingPathComponent("123_token_27.jpg"), options: .atomic)
        try Data([0x04]).write(to: folderURL.appendingPathComponent("123_token_cover.jpg"), options: .atomic)
        let manifest = sampleManifest(pageCount: 2)

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, manifest: manifest) == [
                1: "123_token_1.webp",
                2: "123_token_2.jpg"
            ]
        )
    }

    @Test
    func testExistingPageRelativePathsMatchesExactUnpaddedPageIndices() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: folderURL.appendingPathComponent("123_token_1.webp"), options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_10.jpg"), options: .atomic)
        try Data([0x03]).write(to: folderURL.appendingPathComponent("123_token_01.jpg"), options: .atomic)
        try Data([0x04]).write(to: folderURL.appendingPathComponent("123_token_11.jpg"), options: .atomic)
        let manifest = sampleManifest(pageCount: 10)

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, manifest: manifest) == [
                1: "123_token_1.webp",
                10: "123_token_10.jpg"
            ]
        )
    }

    @Test
    func testExistingPageRelativePathsIgnoresLegacyPagesFolder() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        let pagesFolderURL = folderURL.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pagesFolderURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: pagesFolderURL.appendingPathComponent("0001.jpg"), options: .atomic)
        let manifest = sampleManifest(pageCount: 1)

        #expect(storage.existingPageRelativePaths(folderURL: folderURL, manifest: manifest) == [:])
        #expect(FileManager.default.fileExists(atPath: pagesFolderURL.path))
    }

    @Test
    func testExistingPageRelativePathsRemovesZeroByteFinalAssetFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let emptyPageURL = folderURL.appendingPathComponent("123_token_1.jpg")
        try Data().write(to: emptyPageURL, options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_2.png"), options: .atomic)
        let manifest = sampleManifest(pageCount: 2)

        #expect(
            storage.existingPageRelativePaths(folderURL: folderURL, manifest: manifest) == [
                2: "123_token_2.png"
            ]
        )
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
    }

    @Test
    func testExistingPageRelativePathsIgnoresZeroByteLegacyFiles() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        let pagesURL = folderURL.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)
        let emptyPageURL = pagesURL.appendingPathComponent("0001.jpg")
        try Data().write(to: emptyPageURL, options: .atomic)
        try Data([0x02]).write(to: pagesURL.appendingPathComponent("0002.png"), options: .atomic)
        let manifest = sampleManifest(pageCount: 2)

        #expect(storage.existingPageRelativePaths(folderURL: folderURL, manifest: manifest) == [:])
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path))
    }

    @Test
    func testExistingCoverRelativePathDetectsFinalAssetFile() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: folderURL.appendingPathComponent("other_token_cover.jpg"), options: .atomic)
        try Data([0x02]).write(to: folderURL.appendingPathComponent("123_token_cover.jpg"), options: .atomic)
        let manifest = sampleManifest(pageCount: 1)

        #expect(
            storage.existingCoverRelativePath(folderURL: folderURL, manifest: manifest)
                == "123_token_cover.jpg"
        )
    }

    @Test
    func testIsReadableAssetFileDoesNotDeleteFileWhenAttributesLookupFails() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let fileURL = rootURL.appendingPathComponent("123_token_cover.jpg")
        try Data([0xFF, 0xD8, 0xFF]).write(to: fileURL, options: .atomic)
        let storage = DownloadStore(
            rootURL: rootURL,
            fileManager: ThrowingAttributesFileManager(failingPath: fileURL.path)
        )

        #expect(storage.isReadableAssetFile(at: fileURL))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func testMakeFolderRelativePathSanitizesSeparatorsWhitespaceAndLength() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let unsafeTitle = "  /Alpha\\\\Beta:\n\tGamma   Delta \(String(repeating: "X", count: 200)).  "
        let relativePath = storage.makeFolderRelativePath(gid: "123", token: "token", title: unsafeTitle)

        #expect(relativePath.hasPrefix("[123_token] "))
        #expect(relativePath.contains("/") == false)
        #expect(relativePath.contains("\\") == false)
        #expect(relativePath.contains(":") == false)
        #expect(relativePath.contains("\n") == false)
        #expect(relativePath.hasSuffix(" ") == false)
        #expect(relativePath.hasSuffix(".") == false)
        #expect(relativePath.utf8.count <= 255)

        let cjkRelativePath = storage.makeFolderRelativePath(
            gid: "123",
            token: "token",
            title: String(repeating: "語", count: 120)
        )
        #expect(cjkRelativePath.utf8.count <= 255)
        try FileManager.default.createDirectory(
            at: storage.folderURL(relativePath: "Folder/\(cjkRelativePath)"),
            withIntermediateDirectories: true
        )
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
        let downloadFolderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
        let ignoredFolderURL = storage.folderURL(relativePath: "Folder/[456_token] Missing manifest")
        let hiddenFolderURL = storage.folderURL(relativePath: "Folder/[789_token] Missing manifest")
        try FileManager.default.createDirectory(at: downloadFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: hiddenFolderURL, withIntermediateDirectories: true)
        try storage.writeManifest(sampleManifest(pageCount: 2), folderURL: downloadFolderURL)

        let records = try storage.scanDownloadFolders()

        #expect(records.map(\.relativePath) == ["Folder/[123_token] Sample"])
        #expect(records.first?.manifest.gid == "123")
        #expect(records.first?.folderURL == downloadFolderURL)
        #expect(records.first?.parentFolderName == "Folder")
    }

    @Test
    func testScanDownloadsIgnoresRootGalleryFoldersAndListsEmptyUserFolders() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        // A gallery folder dropped directly at the root stays invisible.
        let rootGalleryURL = storage.folderURL(relativePath: "[123_token] Sample")
        try FileManager.default.createDirectory(at: rootGalleryURL, withIntermediateDirectories: true)
        try storage.writeManifest(sampleManifest(pageCount: 2), folderURL: rootGalleryURL)
        // A broken gallery-like folder without a manifest is not a user folder.
        let brokenGalleryURL = storage.folderURL(relativePath: "[456_token] Broken")
        try FileManager.default.createDirectory(at: brokenGalleryURL, withIntermediateDirectories: true)
        // User folders are listed even when empty.
        let emptyFolderURL = storage.userFolderURL(name: "Empty Folder")
        try FileManager.default.createDirectory(at: emptyFolderURL, withIntermediateDirectories: true)
        // A populated user folder yields records carrying its name.
        let galleryFolderURL = storage.folderURL(relativePath: "Library/[789_token] Inside")
        try FileManager.default.createDirectory(at: galleryFolderURL, withIntermediateDirectories: true)
        try storage.writeManifest(
            DownloadManifest(
                gid: "789",
                host: .ehentai,
                token: "token",
                title: "Inside",
                jpnTitle: nil,
                category: .doujinshi,
                language: .japanese,
                remoteCoverURL: nil,
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: [1: "", 2: ""]
            ),
            folderURL: galleryFolderURL
        )

        let scanResult = try storage.scanDownloads()

        #expect(scanResult.userFolders == ["Empty Folder", "Library"])
        #expect(scanResult.records.map(\.relativePath) == ["Library/[789_token] Inside"])
        #expect(scanResult.records.first?.parentFolderName == "Library")
    }

    @Test
    func testUserFolderNameNormalizationRejectsInvalidNames() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        #expect(storage.normalizedUserFolderName("  My Folder  ") == "My Folder")
        #expect(storage.normalizedUserFolderName("a/b:c") == "a b c")
        #expect(storage.normalizedUserFolderName("...") == nil)
        #expect(storage.normalizedUserFolderName("   ") == nil)
        #expect(storage.normalizedUserFolderName("") == nil)
        #expect(storage.normalizedUserFolderName(".hidden") == "hidden")
        #expect(storage.normalizedUserFolderName("[123_token] Sample") == nil)

        let cjkName = try #require(
            storage.normalizedUserFolderName(String(repeating: "語", count: 120))
        )
        #expect(cjkName.utf8.count <= 255)
        try FileManager.default.createDirectory(
            at: storage.userFolderURL(name: cjkName),
            withIntermediateDirectories: true
        )
    }

    @Test
    func testExistingFinalAssetFileURLsUseIdentityPrefix() throws {
        let (storage, rootURL) = makeStorage()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[123_token] Sample")
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

private extension DownloadStoreTests {
    func makeStorage() -> (DownloadStore, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            DownloadStore(rootURL: rootURL, fileManager: .default),
            rootURL
        )
    }

    func sampleDownload(
        displayStatus: DownloadDisplayStatus = .completed,
        folderURL: URL
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
            folderURL: folderURL,
            displayStatus: displayStatus,
            completedPageCount: displayStatus == .completed ? 2 : 0,
            lastDownloadedDate: .now,
            lastError: nil
        )
    }

    func sampleManifest(pageCount: Int) -> DownloadManifest {
        sampleManifest(
            pageHashes: pageCount > 0
                ? Dictionary(uniqueKeysWithValues: (1...pageCount).map { ($0, "") })
                : [:]
        )
    }

    func sampleManifest(pageHashes: [Int: String]) -> DownloadManifest {
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
