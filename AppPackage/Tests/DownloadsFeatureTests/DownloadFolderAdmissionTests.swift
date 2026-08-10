@testable import AppFeature
import AppModels
import DownloadClient
import Foundation
import Testing

/// The POSITIVE half of the user-folder name catalog: a folder the app's own listing produced must
/// be mutable from inside the app, whatever its name looks like.
///
/// The refusal catalog in `DownloadFolderOperationTests` pins the boundary only from above — every
/// one of its arguments must be refused, so it can fail only when the boundary is too LOOSE. That
/// is why a boundary too TIGHT shipped green twice. Its nearest-looking argument,
/// `whitespacePaddedAlias`, stages a padded spelling of a DIFFERENT real folder, never a folder
/// whose own on-disk name is the padded one, so the shape that matters was outside the catalog.
///
/// The shape is real rather than theoretical. `scanDownloads` promotes every visible
/// non-gallery-shaped directory under the root to a user folder with no name filter at all, and the
/// app ships with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` over a root inside
/// `Documents/`, so a folder created in the Files app named `Art  Books`, ` Photos`, `Manga\Vol1`
/// or `Misc etc.` is listed, is a usable download destination, and must therefore also be
/// deletable and renamable.
struct DownloadFolderAdmissionTests: DownloadFeatureTestCase {
    /// The listing produces the name verbatim, and the delete that follows converges every record.
    ///
    /// Disk first, records second, verdict last — the ordering the refusal catalog uses, mirrored
    /// to the success side. A delete that answered `.success` while leaving the folder, the page
    /// bytes or any of the three stores behind cannot pass under it.
    @Test(arguments: ListedFolderName.allCases)
    func testAListedNonNormalizedFolderDeletesWithRecordConvergence(
        listedName: ListedFolderName
    ) async throws {
        let schedulerHold = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { schedulerHold.cancel() }
        let environment = try await stageListedFolder(
            named: listedName,
            schedulerHold: schedulerHold
        )
        defer { removeTemporaryItem(at: environment.rootURL) }

        #expect(
            await environment.manager.fetchFolders() == [listedName.onDiskName],
            "The listing must produce this name verbatim — that it does while the mutations refuse it IS the gap"
        )

        let result = await environment.manager.deleteFolder(name: listedName.onDiskName)

        #expect(
            !FileManager.default.fileExists(atPath: environment.userFolderURL.path),
            "A listed folder the user asked to delete must be gone from the disk"
        )
        #expect(
            !FileManager.default.fileExists(atPath: environment.pageFileURL.path),
            "The contained gallery's page bytes go with the folder that held them"
        )
        await expectEveryStagedRecordCleared(environment: environment)
        guard case .success = result else {
            Issue.record("Expected the listed folder \(listedName.onDiskName) to delete, got \(result)")
            return
        }
    }

    /// The same folder renames, and the destination is still MINTED rather than admitted.
    ///
    /// The requested new name is deliberately one that normalization changes, so a single case
    /// pins both halves of the asymmetry this boundary rests on: the source is taken as written
    /// because the listing wrote it, and the destination is rewritten because the caller is asking
    /// for a name to be made.
    @Test(arguments: ListedFolderName.allCases)
    func testAListedNonNormalizedFolderRenamesAndRepointsItsDownloads(
        listedName: ListedFolderName
    ) async throws {
        let schedulerHold = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { schedulerHold.cancel() }
        let environment = try await stageListedFolder(
            named: listedName,
            schedulerHold: schedulerHold
        )
        defer { removeTemporaryItem(at: environment.rootURL) }
        let mintedName = try #require(
            DownloadStore.normalizedUserFolderName(Self.requestedDestinationName)
        )
        #expect(mintedName != Self.requestedDestinationName, "The destination must exercise minting")

        #expect(await environment.manager.fetchFolders() == [listedName.onDiskName])

        let result = await environment.manager.renameFolder(
            oldName: listedName.onDiskName,
            newName: Self.requestedDestinationName
        )

        let movedGalleryURL = environment.rootURL
            .appendingPathComponent(mintedName, isDirectory: true)
            .appendingPathComponent(environment.galleryFolderURL.lastPathComponent, isDirectory: true)
        let movedPageURL = movedGalleryURL
            .appendingPathComponent(environment.pageFileURL.lastPathComponent)
        #expect(
            !FileManager.default.fileExists(atPath: environment.userFolderURL.path),
            "The source the caller named must be the directory that moved"
        )
        #expect(
            FileManager.default.contents(atPath: movedPageURL.path) == Self.pageData,
            "The contained gallery's bytes must arrive under the minted destination"
        )
        #expect(await environment.manager.fetchFolders() == [mintedName])
        let download = await environment.manager.fetchDownload(gid: environment.gid)
        #expect(download?.folderName == mintedName, "The record must repoint onto the minted name")
        guard case .success = result else {
            Issue.record("Expected the listed folder \(listedName.onDiskName) to rename, got \(result)")
            return
        }
    }
}

// MARK: - Listed Name Catalog

/// One argument per shape a folder name can take that this app would never MINT but its listing
/// readily PRODUCES.
///
/// `CaseIterable` rather than a hand-maintained array: an argument list written out by hand can
/// silently lose a member, and every member here exists because normalization rewrites it.
enum ListedFolderName: String, Sendable, CaseIterable {
    case doubleSpace
    case leadingSpace
    case backslash
    case trailingDot

    /// The folder's OWN name on disk. Never created through `createFolder`, which would normalize
    /// it, and never an alias of some other real folder — that is the refusal catalog's shape.
    var onDiskName: String {
        switch self {
        case .doubleSpace:
            return "Art  Books"
        case .leadingSpace:
            return " Photos"
        case .backslash:
            return "Manga\\Vol1"
        case .trailingDot:
            return "Misc etc."
        }
    }

    /// What the app's own name generator would rewrite `onDiskName` into.
    ///
    /// Asserted rather than assumed, so a case can never quietly become a name normalization
    /// leaves alone and stop discriminating — which is how a fixture ends up unable to reach the
    /// shape it was written for.
    var mintedSpelling: String {
        switch self {
        case .doubleSpace:
            return "Art Books"
        case .leadingSpace:
            return "Photos"
        case .backslash:
            return "Manga Vol1"
        case .trailingDot:
            return "Misc etc"
        }
    }
}

// MARK: - Setup Helpers

/// A download root holding exactly one user folder, itself holding one fully indexed gallery.
private struct DownloadFolderAdmissionEnvironment {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let rootURL: URL
    let userFolderURL: URL
    let galleryFolderURL: URL
    let pageFileURL: URL
    let gid: String
}

private extension DownloadFolderAdmissionTests {
    static var pageData: Data {
        Data("listed page".utf8)
    }

    /// A destination spelling normalization changes, so every rename case proves minting survives.
    static var requestedDestinationName: String {
        "  Renamed  Destination  "
    }

    static var schedulerHoldGalleryID: String {
        "admission-suite-scheduler-hold"
    }

    /// Stages the folder under its own non-normalized name, with a real indexed gallery inside it
    /// and an entry in each of the three persisted record stores.
    ///
    /// The directory is created with `FileManager` rather than through `createFolder`, which is the
    /// whole point: `createFolder` mints, and a minted name could never reach the shape under test.
    ///
    /// `schedulerHold` is installed as a FOREIGN active task before the queue intent exists, for
    /// the reason the refusal catalog records: otherwise the staged intent makes
    /// `scheduleNextIfNeeded` start a real run for this gallery, and that run's failure path
    /// removes the gid from the queue store — an independent actor deciding the very assertions
    /// these cases make. The hold names a gid no staged folder contains, so nothing else changes.
    func stageListedFolder(
        named listedName: ListedFolderName,
        schedulerHold: Task<Void, Never>
    ) async throws -> DownloadFolderAdmissionEnvironment {
        #expect(
            DownloadStore.normalizedUserFolderName(listedName.onDiskName) == listedName.mintedSpelling,
            "This argument must be a name the generator rewrites, or it discriminates nothing"
        )
        #expect(listedName.mintedSpelling != listedName.onDiskName)

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let gid = "319"
        let userFolderURL = rootURL
            .appendingPathComponent(listedName.onDiskName, isDirectory: true)
        let galleryFolderURL = userFolderURL
            .appendingPathComponent("[\(gid)_token] Sample", isDirectory: true)
        try FileManager.default.createDirectory(
            at: galleryFolderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Sample", pageCount: 2),
            folderURL: galleryFolderURL
        )
        let pageFileURL = galleryFolderURL.appendingPathComponent("page-1.bin")
        try Self.pageData.write(to: pageFileURL)

        await manager.testingInstallActiveTask(
            gid: Self.schedulerHoldGalleryID,
            task: schedulerHold
        )
        await manager.reconcileDownloads()
        await manager.testingSetQueuedGalleryIDs([gid])
        let taskStore = await manager.backgroundTaskStore
        await taskStore.record(taskIdentifier: 3190, gid: gid, pageIndex: 0)

        return .init(
            storage: storage,
            manager: manager,
            rootURL: rootURL,
            userFolderURL: userFolderURL,
            galleryFolderURL: galleryFolderURL,
            pageFileURL: pageFileURL,
            gid: gid
        )
    }

    /// The success-side mirror of the refusal catalog's survival assertions: the same four places a
    /// gallery can go on being claimed, asserted empty rather than intact.
    func expectEveryStagedRecordCleared(
        environment: DownloadFolderAdmissionEnvironment
    ) async {
        #expect(
            await environment.manager.fetchDownload(gid: environment.gid) == nil,
            "A performed delete must drop the index entry"
        )
        let queueStore = await environment.manager.queueStore
        #expect(
            !queueStore.contains(environment.gid),
            "A performed delete must drop the queue intent"
        )
        let taskStore = await environment.manager.backgroundTaskStore
        #expect(
            await taskStore.records(for: environment.gid).isEmpty,
            "A performed delete must drop the background-task records"
        )
        #expect(
            await environment.manager.fetchFolders().isEmpty,
            "A performed delete must drop the folder from the listing"
        )
    }
}
