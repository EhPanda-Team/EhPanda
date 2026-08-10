@testable import AppFeature
import AppModels
import DownloadClient
import Foundation
import Testing

struct DownloadFolderOperationTests: DownloadFeatureTestCase {
    @Test
    func testCreateFolderListsFolderAndRejectsDuplicatesAndInvalidNames() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        try environment.storage.ensureRootDirectory()

        let created = await environment.manager.createFolder(name: "  Favorites  ")
        guard case .success = created else {
            Issue.record("Expected create to succeed, got \(created)")
            return
        }
        #expect(await environment.manager.fetchFolders() == ["Favorites"])

        let duplicate = await environment.manager.createFolder(name: "Favorites")
        guard case .failure = duplicate else {
            Issue.record("Expected duplicate create to fail")
            return
        }

        let invalid = await environment.manager.createFolder(name: "   ")
        guard case .failure = invalid else {
            Issue.record("Expected invalid name to fail")
            return
        }

        let galleryLike = await environment.manager.createFolder(name: "[123_token] Sample")
        guard case .failure = galleryLike else {
            Issue.record("Expected gallery-like name to fail")
            return
        }
    }

    @Test
    func testRenameFolderRepointsContainedDownloads() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "311"
        try writeGalleryFolder(storage: environment.storage, folderName: "Old Name", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.renameFolder(oldName: "Old Name", newName: "New Name")
        guard case .success = result else {
            Issue.record("Expected rename to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gid)
        #expect(await environment.manager.fetchFolders() == ["New Name"])
        #expect(download?.folderName == "New Name")
        #expect(download?.folderURL.path.contains("/New Name/") == true)
    }

    @Test
    func testRenameFolderRejectsActiveDownloadInside() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "312"
        try writeGalleryFolder(storage: environment.storage, folderName: "Busy", gid: gid)
        _ = await environment.manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await environment.manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await environment.manager.renameFolder(oldName: "Busy", newName: "Renamed")
        guard case .failure = result else {
            Issue.record("Expected rename to fail while downloading")
            return
        }
        #expect(await environment.manager.fetchFolders() == ["Busy"])
    }

    /// CR-03: `oldName` is public client input, so every spelling that is not a direct child of the
    /// download root must be refused BEFORE anything moves.
    ///
    /// Each argument asserts both sides of the refusal — the named source is still where it was and
    /// the requested destination was never created — because a returned error alone cannot tell a
    /// rejected request apart from a completed one that happened to report a failure afterwards.
    @Test(arguments: RenameEscapeSource.all)
    func testRenameFolderRefusesASourceThatIsNotADirectChild(
        escapeSource: RenameEscapeSource
    ) async throws {
        let environment = try makeEscapeEnvironment()
        defer { removeTemporaryItem(at: environment.containerURL) }
        let aliasTargetURL = environment.rootURL
            .appendingPathComponent("Alias Target", isDirectory: true)
        let nestedURL = aliasTargetURL.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedURL, withIntermediateDirectories: true)

        let oldName: String
        let preservedURL: URL
        switch escapeSource {
        case .parentDirectory:
            oldName = ".."
            preservedURL = environment.containerURL
        case .traversalToSibling:
            oldName = "../Outside"
            preservedURL = environment.outsideFolderURL
        case .absolutePath:
            oldName = environment.outsideFolderURL.path
            preservedURL = environment.outsideFolderURL
        case .nestedComponents:
            oldName = "Alias Target/Nested"
            preservedURL = nestedURL
        case .whitespacePaddedAlias:
            // Normalization would trim this into "Alias Target" — a REAL direct child the caller
            // never named. Refusing is the only answer that cannot rename the wrong folder.
            oldName = "  Alias Target  "
            preservedURL = aliasTargetURL
        case .separatorSanitizedAlias:
            // Normalization maps ":" to a space, so this too resolves onto "Alias Target".
            oldName = "Alias:Target"
            preservedURL = aliasTargetURL
        }
        let destinationURL = environment.rootURL
            .appendingPathComponent("Captured", isDirectory: true)

        let result = await environment.manager.renameFolder(oldName: oldName, newName: "Captured")

        // Disk first, verdict second. A rename that already moved something can still return a
        // failure, so the filesystem is the only witness that the request was refused rather than
        // performed; reading it before the early return also records it on a failing run.
        #expect(
            FileManager.default.fileExists(atPath: preservedURL.path),
            "The refused source must still be where the caller named it"
        )
        #expect(
            !FileManager.default.fileExists(atPath: destinationURL.path),
            "A refused rename must not create the destination it was asked for"
        )
        #expect(FileManager.default.fileExists(atPath: environment.rootURL.path))
        guard case .failure(.fileOperationFailed) = result else {
            Issue.record("Expected \(escapeSource) to be refused as an invalid folder name, got \(result)")
            return
        }
    }

    /// CR-03: a direct child that is a SYMBOLIC LINK passes every lexical check and still resolves
    /// outside the root, so containment has to be re-decided against the resolved filesystem.
    ///
    /// The outside target is asserted intact by its bytes, not merely by the link's survival: the
    /// harm this refuses is a move that reaches through the link, and only the target can witness it.
    @Test
    func testRenameFolderRefusesASymbolicLinkSourceEscapingTheRoot() async throws {
        let environment = try makeEscapeEnvironment()
        defer { removeTemporaryItem(at: environment.containerURL) }
        let linkURL = environment.rootURL.appendingPathComponent("Linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: environment.outsideFolderURL
        )
        let destinationURL = environment.rootURL
            .appendingPathComponent("Captured", isDirectory: true)

        let result = await environment.manager.renameFolder(oldName: "Linked", newName: "Captured")

        // Disk first, verdict second, for the reason recorded on the case above.
        #expect(FileManager.default.fileExists(atPath: environment.outsideFolderURL.path))
        let sentinelData = try Data(contentsOf: environment.outsideSentinelURL)
        #expect(sentinelData == Self.outsideSentinelData, "The outside target's bytes must be untouched")
        #expect(FileManager.default.fileExists(atPath: linkURL.path), "The link itself must survive")
        #expect(
            !FileManager.default.fileExists(atPath: destinationURL.path),
            "A refused rename must not create the destination it was asked for"
        )
        guard case .failure(.fileOperationFailed) = result else {
            Issue.record("Expected a symbolic-link source to be refused, got \(result)")
            return
        }
        let linkDestination = try FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path)
        #expect(
            URL(fileURLWithPath: linkDestination).standardizedFileURL.path
                == environment.outsideFolderURL.standardizedFileURL.path,
            "The link itself must still point where it did"
        )
    }

    @Test
    func testDeleteFolderRemovesContainedDownloadsAndQueueIntents() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "313"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Doomed", gid: gid)
        await environment.manager.reconcileDownloads()
        await environment.manager.testingSetQueuedGalleryIDs([gid])

        let result = await environment.manager.deleteFolder(name: "Doomed")
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        #expect(await environment.manager.fetchFolders().isEmpty)
        #expect(await environment.manager.fetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testDeleteDownloadRemovesSupersededSameIdentityFolders() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "314"
        let oldFolderURL = try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Saved",
            gid: gid,
            galleryFolderName: "[\(gid)_token] Old Title"
        )
        let currentFolderURL = try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Saved",
            gid: gid,
            galleryFolderName: "[\(gid)_token] Current Title"
        )
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.delete(gid: gid)
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        await environment.manager.reconcileDownloads()
        #expect(await environment.manager.fetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: oldFolderURL.path))
        #expect(!FileManager.default.fileExists(atPath: currentFolderURL.path))
    }

    @Test
    func testMoveDownloadRelocatesGalleryFolder() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "315"
        let sourceURL = try writeGalleryFolder(storage: environment.storage, folderName: "Source", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Target")
        guard case .success = result else {
            Issue.record("Expected move to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gid)
        #expect(download?.folderName == "Target")
        #expect(download?.folderURL.path.contains("/Target/") == true)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(await environment.manager.fetchFolders() == ["Source", "Target"])
    }

    @Test
    func testMoveDownloadIntoSameFolderIsNoOp() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "316"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Home", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Home")
        guard case .success = result else {
            Issue.record("Expected same-folder move to succeed, got \(result)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testMoveDownloadRejectsActivelyDownloadingGallery() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "317"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Working", gid: gid)
        _ = await environment.manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await environment.manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Elsewhere")
        guard case .failure = result else {
            Issue.record("Expected move of active download to fail")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testEnqueueKeepsExistingDownloadInItsFolder() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        await environment.manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryFolderName = environment.storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Original",
            gid: gallery.gid,
            galleryFolderName: galleryFolderName
        )
        _ = await environment.manager.reconcileDownloads()

        let payload = DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Requested Elsewhere",
            mode: .initial
        )
        let result = await environment.manager.enqueue(payload: payload)
        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gallery.gid)
        #expect(download?.folderName == "Original")
    }
}

// MARK: - Root Confinement Cases

/// One argument per way a caller can name something that is not a direct child of the download root.
///
/// The first four reach outside or below the root. The last two name a REAL direct child by a
/// spelling that normalization would change, which is the case a boundary tempted to normalize its
/// source would pass — while renaming a folder nobody asked for.
enum RenameEscapeSource: String, Sendable {
    case parentDirectory
    case traversalToSibling
    case absolutePath
    case nestedComponents
    case whitespacePaddedAlias
    case separatorSanitizedAlias

    static let all: [RenameEscapeSource] = [
        .parentDirectory,
        .traversalToSibling,
        .absolutePath,
        .nestedComponents,
        .whitespacePaddedAlias,
        .separatorSanitizedAlias
    ]
}

// MARK: - Setup Helpers

private struct DownloadFolderOperationTestEnvironment {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let rootURL: URL
}

/// A download root nested one level inside a container the test owns.
///
/// The escape cases need something OUTSIDE the root to name, and the root's own parent is the
/// most direct such thing. Nesting keeps `..` pointing at a directory this test created and
/// removes, instead of at the shared system temporary directory.
private struct DownloadFolderEscapeEnvironment {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let containerURL: URL
    let rootURL: URL
    let outsideFolderURL: URL
    let outsideSentinelURL: URL
}

private extension DownloadFolderOperationTests {
    static var outsideSentinelData: Data {
        Data("outside".utf8)
    }

    func makeEscapeEnvironment() throws -> DownloadFolderEscapeEnvironment {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let rootURL = containerURL.appendingPathComponent("Downloads", isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()
        let outsideFolderURL = containerURL.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideFolderURL, withIntermediateDirectories: true)
        let outsideSentinelURL = outsideFolderURL.appendingPathComponent("sentinel.txt")
        try Self.outsideSentinelData.write(to: outsideSentinelURL)
        return .init(
            storage: storage,
            manager: manager,
            containerURL: containerURL,
            rootURL: rootURL,
            outsideFolderURL: outsideFolderURL,
            outsideSentinelURL: outsideSentinelURL
        )
    }

    func makeManager() -> DownloadFolderOperationTestEnvironment {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        return .init(storage: storage, manager: manager, rootURL: rootURL)
    }

    @discardableResult
    func writeGalleryFolder(
        storage: DownloadStore,
        folderName: String,
        gid: String,
        galleryFolderName: String? = nil
    ) throws -> URL {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(
            relativePath: "\(folderName)/\(galleryFolderName ?? "[\(gid)_token] Sample")"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Sample", pageCount: 2),
            folderURL: folderURL
        )
        return folderURL
    }
}
