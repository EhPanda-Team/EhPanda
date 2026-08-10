@testable import AppFeature
import AppModels
import AppTools
import DownloadClient
import Foundation
import Testing

struct DownloadCoordinatorRepairSeedTests: DownloadFeatureTestCase {
    @Test
    func testRepairSeedReusesCompletedFilesWhenPageCountMatches() async throws {
        let gid = "repair-seed-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

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
        removeTemporaryItem(at: folderURL)
        let workingSeed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        ).workingSeed

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

    /// D-G5-01 on the route G-15-5 names: a `.repair` whose working folder lost one page file must
    /// come out of `prepareWorkingSeedAnnouncingProgress` with a record that reads incomplete.
    ///
    /// Before the reconciliation the manifest came back verbatim — `shouldReuseWorkingFolder`
    /// returns `true` unconditionally for `.repair`, `ensureWorkingManifest` finds a valid manifest
    /// and returns it, and nothing blanked the vanished page — so the record went on claiming all
    /// three pages for the whole run. That is the lie D-G4-01's raw-counting half reads, and it is
    /// why the repair's card could only ever report zero session pages.
    @Test
    func testARepairWithAVanishedPageFileMarksTheRecordIncomplete() async throws {
        try await expectVanishedPageIsReconciled(mode: .repair)
    }

    /// The same reconciliation on D-G4-01's fourth route: a bare re-enqueue that reuses a complete
    /// manifest (Table 1 row 5).
    ///
    /// `.initial` reuses the working folder whenever the probed manifest's gid, token and page count
    /// all match, so it reaches `ensureWorkingManifest`'s verbatim-return branch exactly as `.repair`
    /// does. Pinning it here is what makes the fix invariant-scoped rather than a patch on the one
    /// branch the gap report named.
    @Test
    func testAnInitialReuseOfACompleteManifestReconcilesVanishedPages() async throws {
        try await expectVanishedPageIsReconciled(mode: .initial)
    }

    /// The guard on the other side: an honest complete record is left byte-identical.
    ///
    /// The reconciliation writes only when it blanked something, so a working folder whose files are
    /// all present must survive `prepareWorkingSeedAnnouncingProgress` with the same manifest it
    /// went in with. Without this, a rewrite-always implementation would pass both cases above while
    /// churning the manifest on every run — and D-G4-01's ceiling guarantee depends on a complete
    /// record staying complete.
    @Test
    func testARepairWithAllFilesPresentRewritesNothing() async throws {
        let gid = "reconcile-intact-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let folderURL = try stageCompleteReadingFolder(
            storage: storage,
            gid: gid,
            presentPageIndices: [1, 2, 3]
        )
        let stagedManifest = try storage.readManifest(folderURL: folderURL)
        await manager.reloadDownloadIndex()
        let existingDownload = try #require(await manager.fetchDownload(gid: gid))

        let workingSeed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeReconcilePayload(gid: gid, mode: .repair),
            existingDownload: existingDownload,
            folderURL: folderURL
        ).workingSeed

        #expect(workingSeed.manifest == stagedManifest)
        #expect(try storage.readManifest(folderURL: folderURL) == stagedManifest)
        #expect(workingSeed.manifest.completedPageCount == 3)
        #expect(workingSeed.existingPages.keys.sorted() == [1, 2, 3])
    }

    /// A zero-byte page is EXCLUDED from the resolved URLs, and the read that excludes it leaves the
    /// file alone.
    ///
    /// The exclusion is the property this route owes and it is unchanged: the asset probe positively
    /// rejects an empty file, so it never becomes a page URL a reader could open. What changed is the
    /// second half, and the change is deliberate. `loadLocalPageURLs` serves the index record built
    /// by `reloadDownloadIndex` — the pull-to-refresh and foreground-return route — and after
    /// D-SSOT-07 that record's completeness comes from the manifest while its page URLs are rendering
    /// resources only. A probe that deleted the file here would let a routine refresh destroy a page
    /// the manifest still claims, leaving the page reading `.downloaded` over nothing, licensed by no
    /// reconciliation and invisible until the user runs Validate.
    ///
    /// The housekeeping was not lost, only moved behind the one path entitled to act. CR-03 then
    /// narrowed that set to what the entitlement actually licenses: the repair seed alone names the
    /// discarding flag, because every page it removes is one the same bracketed preparation blanks
    /// the record for. `validate`, the finalize merge, the capture target and the coordinator's
    /// former folder sweep were never in that position — they delete and reconcile nothing — so they
    /// are reads now, and the sweep, which existed for the deletion and nothing else, is gone.
    /// This case pins the file's SURVIVAL rather than dropping the assertion: a display path that
    /// starts deleting again fails here.
    @Test
    func testDownloadCoordinatorLoadLocalPageURLsExcludesAZeroBytePageWithoutDeletingIt() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 13)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let (emptyPageURL, goodPageURL) = try setupZeroBytePageFiles(
            rootURL: rootURL, gid: gid, storage: storage
        )
        await manager.reloadDownloadIndex()

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == nil)
        #expect(pageURLs[2] == goodPageURL)
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path))
    }

    /// The other side of the same boundary: the one path that IS entitled to act still discards.
    ///
    /// The repair seed's entitlement is not its position but the pairing — the destination scan's
    /// refusals become positive absences that `reconcileWorkingManifestAgainstPageFiles` blanks
    /// inside the same D-G7-01 bracket, so the record and the disk move together. Pinning both sides
    /// in the same file is what keeps "reads classify, acts act" a boundary rather than a blanket:
    /// without this case, a fix that simply stopped deleting everywhere would look correct.
    ///
    /// This replaces the coordinator-sweep case that used to stand here. That sweep discarded both
    /// of its probe results and existed for the deletion alone, which is exactly the read-path
    /// mutation CR-03 removed, so the case pinned the defect rather than a contract.
    @Test
    func testTheRepairSeedStillDiscardsAZeroBytePageAndBlanksIt() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 17)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let (emptyPageURL, goodPageURL) = try setupZeroBytePageFiles(
            rootURL: rootURL, gid: gid, storage: storage
        )
        // Both pages are CLAIMED, so the refusal has a recorded hash to be paired against — the
        // fixture's own manifest records neither, which would make the pairing vacuous. Two claimed
        // pages also keep the blank set below the all-or-nothing threshold, so the guard authorizes.
        let folderURL = emptyPageURL.deletingLastPathComponent()
        var claimed = try storage.readManifest(folderURL: folderURL)
        claimed.pages = [1: "sha256:stale-one", 2: "sha256:stale-two"]
        try storage.writeManifest(claimed, folderURL: folderURL)
        await manager.reloadDownloadIndex()
        let download = try #require(await manager.fetchDownload(gid: gid))

        let workingSeed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairSeedPayload(gid: gid),
            existingDownload: download,
            folderURL: folderURL
        ).workingSeed

        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: goodPageURL.path))
        // The pairing, not just the deletion: the removed page's recorded hash went with it, and it
        // went DURABLY — the record on disk is what a relaunch would read.
        #expect(workingSeed.manifest.pages[1] == "")
        #expect(workingSeed.manifest.pages[2] == "sha256:stale-two")
        let diskManifest = try storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[1] == "")
        #expect(diskManifest.pages[2] == "sha256:stale-two")
    }

    /// The SOURCE folder is the gallery's own indexed record, so nothing on the seed route is
    /// entitled to delete inside it (WR-02).
    ///
    /// `repairSeed` hands `materializeRepairSeed` `download.folderURL` — the CURRENTLY INDEXED
    /// folder — and the source page scan used to name the discarding flag, removing refused page
    /// files there while writing nothing to that folder's manifest. What the route blanks is the
    /// destination's COPY, a different record, so the source went on claiming pages the app itself
    /// had destroyed.
    ///
    /// Three conditions are jointly required to observe that, and this case stages all three.
    /// (1) The run must NOT complete: `removeSupersededFolders` runs only from the completion
    /// handler (`DownloadClient+Execution.swift`), so a failed, cancelled or terminated run is what
    /// leaves the stale folder standing with its claim — and stopping after the preparation IS that
    /// interruption, since the seed materializes inside it and nothing past it sweeps.
    /// (2) The destination path must DIFFER from the source, which an upstream title change
    /// produces. (3) The source must be ALL-REFUSED, so no page is copied and the destination's
    /// directory mtime is set by the manifest copy alone, while the source's is bumped afterwards by
    /// the deletions — which is how the lying folder came to win `deduplicatedDownloadIndex`'s
    /// `displayDate` arbitration.
    ///
    /// Pre-fix all three zero-byte page files vanish while the source manifest still claims all
    /// three. The index-winner assertion is the first one's CONSEQUENCE rather than an independent
    /// property — what makes the winner honest is that nothing was deleted — and it is written as a
    /// conjunction deliberately, because the gap is about the arbitration exposing the lie and not
    /// only about the lie existing. It discriminates exactly when the source wins, which is the
    /// pre-fix mtime ordering; it is vacuous once the deleted set is empty, which is the point.
    @Test
    func testAnInterruptedRepairWithRenameKeepsTheSourceRecordAndItsFilesInAgreement() async throws {
        let gid = "repair-source-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let sourceFolderURL = try stageAllRefusedSourceFolder(storage: storage, gid: gid)
        let stagedPageURLs = stagedSourcePageURLs(
            storage: storage, gid: gid, folderURL: sourceFolderURL
        )
        await manager.reloadDownloadIndex()
        let existingDownload = try #require(await manager.fetchDownload(gid: gid))

        // The rename shape, derived the way production derives it rather than assumed: the working
        // folder is `folderRelativePath(for:parentFolderName:)`'s answer for a payload whose title
        // differs from the staged folder's, and the arguments the seed receives are then exactly the
        // ones `repairSeed` returns for this record.
        let payload = makeReconcilePayload(gid: gid, mode: .repair)
        let folderURL = storage.folderURL(
            relativePath: await manager.folderRelativePath(
                for: payload,
                parentFolderName: existingDownload.folderName
            )
        )
        #expect(folderURL.standardizedFileURL != sourceFolderURL.standardizedFileURL)

        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )

        // Record/disk agreement at the SOURCE, taken from the manifest as it stands AFTER the act
        // rather than from the staging, so the other admissible fix — reconciling the source folder
        // under its own guards — would pass here on its own terms instead of being ruled out.
        let sourceManifest = try storage.readManifest(folderURL: sourceFolderURL)
        let sourceClaimedPages = Set(sourceManifest.pages.filter({ !$0.value.isEmpty }).keys)
        let deletedSourcePages = Set(
            stagedPageURLs
                .filter({ !FileManager.default.fileExists(atPath: $0.value.path) })
                .keys
        )
        #expect(deletedSourcePages.sorted() == [])
        #expect(sourceClaimedPages.intersection(deletedSourcePages) == [])

        // The index winner, read back through a REBUILT coordinator so the basis is the persisted
        // one a relaunch meets rather than this manager's in-memory index.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let indexedWinner = try #require(await relaunched.fetchDownload(gid: gid))
        let winnerManifest = try storage.readManifest(folderURL: indexedWinner.folderURL)
        let winnerClaimedPages = Set(winnerManifest.pages.filter({ !$0.value.isEmpty }).keys)
        let deletedPagesInWinner: Set<Int> = indexedWinner.folderURL.standardizedFileURL
            == sourceFolderURL.standardizedFileURL ? deletedSourcePages : []
        #expect(winnerClaimedPages.intersection(deletedPagesInWinner) == [])
    }

    @Test
    func testRescanLocalPageURLsDropsExternallyDeletedPage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 71)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

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
    /// Drives `prepareWorkingSeedAnnouncingProgress` over a three-page working folder that claims
    /// every page while page 3's file is gone, and states what D-G5-01 owes afterwards.
    ///
    /// Shared by the `.repair` and `.initial` cases because the rule is the same one at the same
    /// site: both modes reach `ensureWorkingManifest`'s verbatim-return branch, and the whole point
    /// of reconciling at the convergence point is that neither route needs its own arithmetic.
    func expectVanishedPageIsReconciled(mode: DownloadStartMode) async throws {
        let gid = "reconcile-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let folderURL = try stageCompleteReadingFolder(
            storage: storage,
            gid: gid,
            presentPageIndices: [1, 2]
        )
        let stagedManifest = try storage.readManifest(folderURL: folderURL)
        await manager.reloadDownloadIndex()
        let existingDownload = try #require(await manager.fetchDownload(gid: gid))
        #expect(existingDownload.completedPageCount == 3)

        let workingSeed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeReconcilePayload(gid: gid, mode: mode),
            existingDownload: existingDownload,
            folderURL: folderURL
        ).workingSeed

        #expect(workingSeed.manifest.completedPageCount == 2)
        #expect(workingSeed.manifest.pages[3] == "")
        #expect(workingSeed.manifest.pages[1] == stagedManifest.pages[1])
        #expect(workingSeed.manifest.pages[2] == stagedManifest.pages[2])
        // Re-read rather than trusted from the returned value: the index and every later consumer
        // read the persisted manifest, so a reconciliation that only mutated memory would leave the
        // lie exactly where the session's basis finds it.
        let persistedManifest = try storage.readManifest(folderURL: folderURL)
        #expect(persistedManifest.completedPageCount == 2)
        #expect(persistedManifest.pages == workingSeed.manifest.pages)
        #expect(workingSeed.existingPages.keys.sorted() == [1, 2])
        // The `.repair` folder-reuse contract still holds: reconciling the record must never take a
        // surviving page file with it.
        for index in [1, 2] {
            let pageURL = folderURL.appendingPathComponent(
                storage.makePageRelativePath(gid: gid, token: "token", index: index, fileExtension: "jpg")
            )
            #expect(FileManager.default.fileExists(atPath: pageURL.path))
        }
        #expect(await manager.fetchDownload(gid: gid)?.completedPageCount == 2)
    }

    /// Writes a working folder whose manifest claims all three pages as finished while only
    /// `presentPageIndices` have files on disk — the complete-reading record with vanished files
    /// that a repair exists to fix.
    func stageCompleteReadingFolder(
        storage: DownloadStore,
        gid: String,
        presentPageIndices: [Int]
    ) throws -> URL {
        let folderURL = storage.folderURL(
            relativePath: "Folder/\(storage.makeFolderRelativePath(gid: gid, token: "token", title: "Reconcile"))"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        var manifest = try sampleManifest(gid: gid, title: "Reconcile", pageCount: 3)
        manifest.pages = Dictionary(
            uniqueKeysWithValues: (1...3).map { ($0, "sha256:page-\($0)") }
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        for index in presentPageIndices {
            try Data([UInt8(index)]).write(
                to: folderURL.appendingPathComponent(
                    storage.makePageRelativePath(gid: gid, token: "token", index: index, fileExtension: "jpg")
                ),
                options: .atomic
            )
        }
        return folderURL
    }

    /// A three-page record claiming every page while every page file is zero bytes — the all-refused
    /// shape, staged under a title that differs from `makeReconcilePayload`'s so the working folder
    /// the repair resolves is a different path.
    ///
    /// The cover is staged USABLE on purpose. The cover scan is the site that keeps its entitlement,
    /// so a refused cover would be legitimately deleted here and this case's page inventory would
    /// need an exception that says nothing about the rule under test.
    func stageAllRefusedSourceFolder(storage: DownloadStore, gid: String) throws -> URL {
        let folderURL = storage.folderURL(
            relativePath: "Folder/\(storage.makeFolderRelativePath(gid: gid, token: "token", title: "Original"))"
        )
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        var manifest = try sampleManifest(gid: gid, title: "Original", pageCount: 3)
        manifest.pages = Dictionary(
            uniqueKeysWithValues: (1...3).map { ($0, "sha256:page-\($0)") }
        )
        try storage.writeManifest(manifest, folderURL: folderURL)
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        for index in 1...3 {
            try Data().write(
                to: folderURL.appendingPathComponent(
                    storage.makePageRelativePath(gid: gid, token: "token", index: index, fileExtension: "jpg")
                ),
                options: .atomic
            )
        }
        return folderURL
    }

    /// The staged page files' URLs, so "which files did the act remove" is answered against the
    /// inventory that was written rather than against whatever the folder happens to hold.
    func stagedSourcePageURLs(
        storage: DownloadStore,
        gid: String,
        folderURL: URL
    ) -> [Int: URL] {
        Dictionary(
            uniqueKeysWithValues: (1...3).map { index in
                (
                    index,
                    folderURL.appendingPathComponent(
                        storage.makePageRelativePath(
                            gid: gid, token: "token", index: index, fileExtension: "jpg"
                        )
                    )
                )
            }
        )
    }

    func makeReconcilePayload(
        gid: String,
        mode: DownloadStartMode
    ) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Reconcile",
                rating: 4, tags: [], category: .doujinshi,
                uploader: "Uploader", pageCount: 3, postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Reconcile", jpnTitle: nil,
                isFavorited: false, visibility: .yes,
                rating: 4, userRating: 0, ratingCount: 1,
                category: .doujinshi, language: .japanese,
                uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: 3,
                sizeCount: 1, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, folderName: "Folder", mode: mode
        )
    }

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
    ) throws -> (emptyPageURL: URL, goodPageURL: URL) {
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
