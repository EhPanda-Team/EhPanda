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
        let expectedRefusal: FolderNameRefusal
        switch escapeSource {
        case .parentDirectory:
            oldName = ".."
            preservedURL = environment.containerURL
            expectedRefusal = .invalidName
        case .traversalToSibling:
            oldName = "../Outside"
            preservedURL = environment.outsideFolderURL
            expectedRefusal = .invalidName
        case .absolutePath:
            oldName = environment.outsideFolderURL.path
            preservedURL = environment.outsideFolderURL
            expectedRefusal = .invalidName
        case .nestedComponents:
            oldName = "Alias Target/Nested"
            preservedURL = nestedURL
            expectedRefusal = .invalidName
        case .whitespacePaddedAlias:
            // The property this argument protects is unchanged and unweakened: normalization would
            // trim this onto "Alias Target", a REAL direct child the caller never named, and the
            // boundary must never rename that folder. What changed is which true thing the refusal
            // says. A source is admitted as written and never rewritten, so this string can only
            // ever mean a directory literally called `"  Alias Target  "` — and there is none, so
            // the honest answer is `.notFound` rather than a claim about the name (CR-01).
            oldName = "  Alias Target  "
            preservedURL = aliasTargetURL
            expectedRefusal = .absentSource
        case .separatorSanitizedAlias:
            // The same re-derivation: normalization maps ":" to a space, so a REWRITING boundary
            // would land on "Alias Target". Nothing on disk is called `"Alias:Target"`, so the
            // admitted-but-absent answer is the one that reports the request truthfully.
            oldName = "Alias:Target"
            preservedURL = aliasTargetURL
            expectedRefusal = .absentSource
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
        expectRefusal(expectedRefusal, from: result, source: "\(escapeSource)")
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

    /// CR-02, the legitimate side of the same boundary: a delete that IS performed must take every
    /// persisted trace of the galleries it erased with it.
    ///
    /// The three record stores are asserted together because they are the three places a gallery
    /// whose folder is gone can go on being claimed. This case pins the convergence from the side
    /// where deletion happens; the escape suite below pins it from the side where it must not.
    @Test
    func testDeleteFolderRemovesContainedDownloadsAndQueueIntents() async throws {
        let environment = makeManager()
        defer { removeTemporaryItem(at: environment.rootURL) }
        let gid = "313"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Doomed", gid: gid)
        await environment.manager.reconcileDownloads()
        await environment.manager.testingSetQueuedGalleryIDs([gid])
        let taskStore = await environment.manager.backgroundTaskStore
        await taskStore.record(taskIdentifier: 3130, gid: gid, pageIndex: 0)

        let result = await environment.manager.deleteFolder(name: "Doomed")
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        #expect(await environment.manager.fetchFolders().isEmpty)
        #expect(await environment.manager.fetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: folderURL.path))
        let queueStore = await environment.manager.queueStore
        #expect(!queueStore.contains(gid), "A performed delete must drop the queue intent")
        #expect(
            await taskStore.records(for: gid).isEmpty,
            "A performed delete must drop the background-task records"
        )
    }

    /// CR-02: `name` is public client input too, so the destructive sibling of `renameFolder` has to
    /// refuse every spelling that is not a direct child of the download root — before anything is
    /// removed, and without stranding the records of a gallery it would otherwise have erased.
    ///
    /// Each argument asserts three things in this order: the would-be victim's BYTES are still on
    /// disk, the three persisted record stores still hold the staged gallery, and only then the
    /// returned error. Reading the disk before the verdict is what makes a call that removed
    /// something and then reported a failure impossible to pass. Asserting the records is what
    /// catches the divergence the nested argument produces, where the gallery folder is erased while
    /// the coordinator's exact `parentFolderName == name` cleanup key matches nothing, so every
    /// store goes on claiming a gallery that no longer exists.
    @Test(arguments: DeleteEscapeSource.all)
    func testDeleteFolderRefusesANameThatIsNotADirectChild(
        escapeSource: DeleteEscapeSource
    ) async throws {
        let environment = try makeEscapeEnvironment()
        defer { removeTemporaryItem(at: environment.containerURL) }
        let schedulerHold = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { schedulerHold.cancel() }
        let staging = try await stageDeleteEscapeVictims(
            environment: environment,
            schedulerHold: schedulerHold
        )
        let target = deleteEscapeTarget(escapeSource: escapeSource, environment: environment, staging: staging)

        let result = await environment.manager.deleteFolder(name: target.name)

        // Disk first, records second, verdict last, for the reason recorded on this case.
        #expect(
            FileManager.default.fileExists(atPath: target.preservedURL.path),
            "A refused delete must leave the object it would have reached exactly where it was"
        )
        #expect(
            FileManager.default.contents(atPath: target.sentinelURL.path) == target.sentinelData,
            "The refused target's bytes must be untouched"
        )
        #expect(FileManager.default.fileExists(atPath: staging.keeperFolderURL.path))
        #expect(
            FileManager.default.fileExists(atPath: staging.galleryFolderURL.path),
            "No refused name may reach a gallery folder below a user folder"
        )
        await expectStagedRecordsSurvive(environment: environment, staging: staging)
        if case .symlinkedDirectChild = escapeSource {
            #expect(
                FileManager.default.fileExists(atPath: staging.linkURL.path),
                "The link itself must survive rather than be removed as if it were the folder"
            )
            #expect(
                staging.linkURL.resolvingSymlinksInPath().standardizedFileURL.path
                    == staging.keeperFolderURL.resolvingSymlinksInPath().standardizedFileURL.path,
                "The link must still point where it did"
            )
        }
        expectRefusal(target.refusal, from: result, source: "\(escapeSource)")
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

/// One argument per way a caller can name something `deleteFolder` must not remove.
///
/// The first three reach outside the download root. The last three reach a real object inside it
/// that the caller did not name, which is the half a lexical prefix check cannot answer: a gallery
/// folder BELOW a user folder, a spelling normalization would resolve onto a different real folder,
/// and a direct child that is a link to one.
/// Which of the two true things the boundary says about an unacceptable name an argument is pinned
/// to.
///
/// They are not interchangeable, and collapsing them to "some failure" is what let three arguments
/// pass over the defect before the boundary existed. `.invalidName` is a claim about the REQUEST —
/// this string is not a usable direct-child name. `.absentSource` is a claim about the DISK — the
/// boundary accepted the name as written and found nothing at it, which is the only thing left to
/// say once a source is never rewritten onto some other real folder.
enum FolderNameRefusal: String, Sendable {
    case invalidName
    case absentSource
}

enum DeleteEscapeSource: String, Sendable {
    case parentDirectory
    case traversalToSibling
    case absolutePath
    case nestedGalleryFolder
    case whitespacePaddedAlias
    case symlinkedDirectChild

    static let all: [DeleteEscapeSource] = [
        .parentDirectory,
        .traversalToSibling,
        .absolutePath,
        .nestedGalleryFolder,
        .whitespacePaddedAlias,
        .symlinkedDirectChild
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

/// The objects a delete escape would reach, staged as real bytes inside a real indexed gallery.
///
/// A gallery folder rather than an empty directory, because the harm the nested argument does is
/// unbounded data loss INSIDE the root together with three record stores that go on claiming it.
private struct DownloadDeleteEscapeStaging {
    let gid: String
    let keeperFolderURL: URL
    let galleryFolderURL: URL
    let pageFileURL: URL
    let linkURL: URL
}

/// What one `DeleteEscapeSource` argument names and what must survive it, byte for byte.
private struct DownloadDeleteEscapeTarget {
    let name: String
    let preservedURL: URL
    let sentinelURL: URL
    let sentinelData: Data
    let refusal: FolderNameRefusal
}

private extension DownloadFolderOperationTests {
    static var outsideSentinelData: Data {
        Data("outside".utf8)
    }

    static var keeperPageData: Data {
        Data("keeper page".utf8)
    }

    static var keeperFolderName: String {
        "Keeper"
    }

    static var linkedFolderName: String {
        "Linked"
    }

    /// Stages what a delete escape would reach: a real direct child holding a real gallery folder
    /// with real page bytes, indexed and present in all three persisted record stores.
    ///
    /// The symbolic link is created AFTER the reconcile deliberately, so the scan indexes the
    /// gallery exactly once — through `Keeper` — and the link is a filesystem-only direct child,
    /// which is precisely what a caller naming it would be reaching through.
    ///
    /// `schedulerHold` is installed as a FOREIGN active task before the queue intent exists.
    /// Without it the staged intent makes `scheduleNextIfNeeded` start a real run for this gallery,
    /// and that run's own failure path removes the gid from the queue store — an independent
    /// actor mutating the very records these cases assert `deleteFolder` left alone, which would
    /// decide the outcome by timing. The hold names a gid no argument's folder contains, so it
    /// changes nothing else: `deleteFolder` cancels the active task only for a contained gallery.
    func stageDeleteEscapeVictims(
        environment: DownloadFolderEscapeEnvironment,
        schedulerHold: Task<Void, Never>
    ) async throws -> DownloadDeleteEscapeStaging {
        let gid = "318"
        let keeperFolderURL = environment.rootURL
            .appendingPathComponent(Self.keeperFolderName, isDirectory: true)
        let galleryFolderURL = keeperFolderURL
            .appendingPathComponent("[\(gid)_token] Sample", isDirectory: true)
        try FileManager.default.createDirectory(
            at: galleryFolderURL,
            withIntermediateDirectories: true
        )
        try environment.storage.writeManifest(
            sampleManifest(gid: gid, title: "Sample", pageCount: 2),
            folderURL: galleryFolderURL
        )
        let pageFileURL = galleryFolderURL.appendingPathComponent("page-1.bin")
        try Self.keeperPageData.write(to: pageFileURL)
        await environment.manager.testingInstallActiveTask(
            gid: "escape-suite-scheduler-hold",
            task: schedulerHold
        )
        await environment.manager.reconcileDownloads()
        await environment.manager.testingSetQueuedGalleryIDs([gid])
        let taskStore = await environment.manager.backgroundTaskStore
        await taskStore.record(taskIdentifier: 3180, gid: gid, pageIndex: 0)
        let linkURL = environment.rootURL
            .appendingPathComponent(Self.linkedFolderName, isDirectory: true)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: keeperFolderURL)
        return .init(
            gid: gid,
            keeperFolderURL: keeperFolderURL,
            galleryFolderURL: galleryFolderURL,
            pageFileURL: pageFileURL,
            linkURL: linkURL
        )
    }

    func deleteEscapeTarget(
        escapeSource: DeleteEscapeSource,
        environment: DownloadFolderEscapeEnvironment,
        staging: DownloadDeleteEscapeStaging
    ) -> DownloadDeleteEscapeTarget {
        switch escapeSource {
        case .parentDirectory:
            return .init(
                name: "..",
                preservedURL: environment.containerURL,
                sentinelURL: environment.outsideSentinelURL,
                sentinelData: Self.outsideSentinelData,
                refusal: .invalidName
            )
        case .traversalToSibling:
            return .init(
                name: "../Outside",
                preservedURL: environment.outsideFolderURL,
                sentinelURL: environment.outsideSentinelURL,
                sentinelData: Self.outsideSentinelData,
                refusal: .invalidName
            )
        case .absolutePath:
            return .init(
                name: environment.outsideFolderURL.path,
                preservedURL: environment.outsideFolderURL,
                sentinelURL: environment.outsideSentinelURL,
                sentinelData: Self.outsideSentinelData,
                refusal: .invalidName
            )
        case .nestedGalleryFolder:
            // Lexical prefix containment admits this, so the gallery folder is removed outright
            // while the exact `parentFolderName == name` cleanup key never matches it.
            return .init(
                name: "\(Self.keeperFolderName)/\(staging.galleryFolderURL.lastPathComponent)",
                preservedURL: staging.galleryFolderURL,
                sentinelURL: staging.pageFileURL,
                sentinelData: Self.keeperPageData,
                refusal: .invalidName
            )
        case .whitespacePaddedAlias:
            // The property is unchanged and unweakened: normalization would trim this onto the REAL
            // folder "Keeper", a different directory than the caller named, and no delete may reach
            // it. What changed is which true thing the refusal says. A source is admitted as
            // written and never rewritten, so this string can only ever mean a directory literally
            // called `"  Keeper  "` — and there is none, so `.notFound` is the honest answer and a
            // claim about the NAME would be the misleading one (CR-01).
            return .init(
                name: "  \(Self.keeperFolderName)  ",
                preservedURL: staging.keeperFolderURL,
                sentinelURL: staging.pageFileURL,
                sentinelData: Self.keeperPageData,
                refusal: .absentSource
            )
        case .symlinkedDirectChild:
            return .init(
                name: Self.linkedFolderName,
                preservedURL: staging.keeperFolderURL,
                sentinelURL: staging.pageFileURL,
                sentinelData: Self.keeperPageData,
                refusal: .invalidName
            )
        }
    }

    /// Asserts a refusal is the SPECIFIC one its argument is pinned to, never merely "some failure".
    ///
    /// Both catalogs assert through here so neither can drift into accepting the other's answer:
    /// an argument pinned to `.invalidName` that starts reporting `.notFound` has had its name
    /// admitted, and an argument pinned to `.absentSource` that starts reporting `.invalidName` has
    /// had the boundary tightened back onto a name the listing can produce.
    func expectRefusal(
        _ refusal: FolderNameRefusal,
        from result: Result<Void, AppError>,
        source: String
    ) {
        switch (refusal, result) {
        case (.invalidName, .failure(.fileOperationFailed)),
             (.absentSource, .failure(.notFound)):
            return
        default:
            Issue.record("Expected \(source) to be refused as \(refusal.rawValue), got \(result)")
        }
    }

    /// Every persisted trace of the staged gallery, asserted unchanged after a refusal.
    ///
    /// `downloadIndex`, the queue store and the background-task store are the three places a
    /// gallery whose folder was erased can go on being claimed, so a refusal has to leave all three
    /// exactly as it found them — and a nested name that DID erase the folder leaves all three
    /// standing, which is the divergence half of this gap.
    func expectStagedRecordsSurvive(
        environment: DownloadFolderEscapeEnvironment,
        staging: DownloadDeleteEscapeStaging
    ) async {
        #expect(
            await environment.manager.fetchDownload(gid: staging.gid) != nil,
            "A refused delete must leave the gallery indexed"
        )
        let queueStore = await environment.manager.queueStore
        #expect(
            queueStore.contains(staging.gid),
            "A refused delete must leave the queue intent in place"
        )
        let taskStore = await environment.manager.backgroundTaskStore
        #expect(
            await !taskStore.records(for: staging.gid).isEmpty,
            "A refused delete must leave the background-task records in place"
        )
        #expect(
            await environment.manager.fetchFolders().contains(Self.keeperFolderName),
            "A folder nothing was deleted from must still be listed"
        )
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
