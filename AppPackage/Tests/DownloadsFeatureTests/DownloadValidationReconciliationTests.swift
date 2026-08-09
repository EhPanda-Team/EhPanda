import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

/// D-G5B-01 and D-SSOT-01: what a `.missingFiles` validation verdict is allowed to make DURABLE, and
/// what it must leave transient.
///
/// The suite is deliberately piecewise, because the contract is. On one side of the boundary the
/// validate-time reconciliation holds POSITIVE per-page evidence — a successful page-file scan that
/// names the pages whose files are gone, and a fresh content pass that names the pages whose files
/// are there and whose bytes no longer hash to what the record claims — and the record is corrected
/// on disk: the hashes of exactly those pages are blanked, every provably-mismatched file is removed
/// so the blanked page is genuinely repairable, the manifest is written, the index is updated, and
/// the transient `validationErrors` entry is dropped so nothing outranks the honest record. On the
/// other side the pass could not produce trustworthy evidence for every claimed page — a failed
/// scan, a page whose bytes could not be read at all, or a shape where every claimed page would be
/// blanked at once — the manifest is left verbatim where the guard refused, and the
/// `validationErrors` entry is what the user sees.
///
/// Each arm asserts its OWN regime and borrows nothing from the other's expectations: a single
/// blanket assertion across the boundary would either pin the refusal family to a correction it
/// never receives, or accept a durable arm that quietly did nothing. Both arms pin their reading
/// after a RELAUNCH — a second coordinator built over the same storage root — because durability is
/// the whole point of the durable arm and the refusal arm's residual is only honest if its
/// post-relaunch reading is stated rather than assumed.
struct DownloadValidationReconciliationTests: DownloadFeatureTestCase {
    /// The durable arm: a partially-missing gallery is corrected on disk by the validation that
    /// found it, so the record, the count and the start gates all read one truth.
    ///
    /// Three of the three claimed pages are recorded complete, pages 1 and 3 really exist with the
    /// bytes their hashes name, and page 2's file is gone — the reported scenario in miniature. The
    /// scan classifies every page, so the blanking covers the missing SET rather than the single
    /// page `storage.validate` short-circuits on, and the record afterwards reads 2 of 3 with no
    /// error over it: `.inactive`, which is what `canTogglePause` accepts and what `resumeMode`
    /// resolves to `.repair`.
    @Test
    func testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215601",
            title: "Reconciled",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 3])
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 2)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .inactive)
        #expect(download.lastError == nil)
        #expect(download.completedPageCount == 2)

        // Disk truth, not derived state: the persisted manifest is the basis every reading above is
        // supposed to come from, so it is read back directly.
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.pages[1]?.isEmpty == false)
        #expect(diskManifest.pages[3]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 2)

        // The relaunch pin: a fresh coordinator over the same storage holds none of this session's
        // in-memory state, so anything it still reads correctly was carried by the record alone.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 2)
        #expect(reread.canTogglePause)
        #expect(await relaunched.resumeMode(for: reread) == .repair)
    }

    /// The content-durable arm (D-SSOT-01): a page whose file is THERE and whose bytes no longer
    /// hash to the recorded value is corrected on disk by the validation that found it, exactly as a
    /// missing page is.
    ///
    /// A readable file whose fresh hash mismatches its record is a positive, page-scoped
    /// determination — the same evidence class as a positive absence — so it licenses durable
    /// blanking. The corrupt file is removed as part of that blanking (D-SSOT-04): a blanked page
    /// whose file survived would be skipped by `resolveSourceIfNeeded`'s missing-file filter and then
    /// re-hashed from the stale bytes by `finalizeDownload`'s `addingCurrentFileHashes` merge, which
    /// would launder the corruption into a record that validates clean forever.
    ///
    /// All three pages are recorded complete and all three files exist; only page 2's bytes were
    /// overwritten. The record afterwards reads 2 of 3 with no error over it — `.inactive`, which is
    /// what `canTogglePause` accepts and what `resumeMode` resolves to `.repair`.
    @Test
    func testValidatingAMismatchedPageBlanksItsHashAndRemovesItsFileOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215605",
            title: "Mismatched",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 2, 3])
        try corruptPageFile(for: gallery, in: fixture, index: 2)
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageImageCorrupted(page: 2)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .inactive)
        #expect(download.lastError == nil)
        #expect(download.completedPageCount == 2)

        // Disk truth, not derived state: the persisted manifest is the basis every reading above is
        // supposed to come from, so it is read back directly.
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.pages[1]?.isEmpty == false)
        #expect(diskManifest.pages[3]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 2)

        // The removal half of D-SSOT-01, asserted separately from the blanking half: the verified
        // pages keep their files, and only the page the content pass positively refuted lost one.
        let fileManager = FileManager.default
        let pageTwoURL = pageFileURL(for: gallery, in: fixture, index: 2)
        #expect(fileManager.fileExists(atPath: pageTwoURL.path) == false)
        #expect(fileManager.fileExists(atPath: pageFileURL(for: gallery, in: fixture, index: 1).path))
        #expect(fileManager.fileExists(atPath: pageFileURL(for: gallery, in: fixture, index: 3).path))
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        // The relaunch pin: a fresh coordinator over the same storage holds none of this session's
        // in-memory state, so anything it still reads correctly was carried by the record alone.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 2)
        #expect(reread.canTogglePause)
        #expect(await relaunched.resumeMode(for: reread) == .repair)
    }

    /// The mixed arm: absence and mismatch are the same evidence class, so ONE validate reconciles
    /// both families at once.
    ///
    /// Page 1 has no file and page 3's bytes were overwritten, so the prospective blank set is
    /// exactly `{1, 3}` out of four claimed pages. The evidence is also proven to be gathered fresh
    /// rather than taken from the verdict: `storage.validate` short-circuits at page 1 and never
    /// looks at page 3 at all, yet page 3 is reconciled — which a verdict-shaped implementation
    /// could not do.
    @Test
    func testValidatingAMixedMissingAndMismatchedGalleryReconcilesBothFamiliesAtOnce() async throws {
        let gallery = SessionGallery(
            gid: "215606",
            title: "Mixed",
            pageCount: 4,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        // Page 1 is never written, so it is the positively-absent family; page 3 is written, hashed
        // and then overwritten, so it is the positively-mismatched one.
        try writePageFiles(for: gallery, in: fixture, indices: [2, 3, 4])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [2, 3, 4])
        try corruptPageFile(for: gallery, in: fixture, index: 3)
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .inactive)
        #expect(download.lastError == nil)
        #expect(download.completedPageCount == 2)

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[1] == "")
        #expect(diskManifest.pages[3] == "")
        #expect(diskManifest.pages[2]?.isEmpty == false)
        #expect(diskManifest.pages[4]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 2)

        let fileManager = FileManager.default
        let pageThreeURL = pageFileURL(for: gallery, in: fixture, index: 3)
        #expect(fileManager.fileExists(atPath: pageThreeURL.path) == false)
        #expect(fileManager.fileExists(atPath: pageFileURL(for: gallery, in: fixture, index: 2).path))
        #expect(fileManager.fileExists(atPath: pageFileURL(for: gallery, in: fixture, index: 4).path))
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 2)
        #expect(await relaunched.resumeMode(for: reread) == .repair)
    }

    /// The combined-wholesale refusal (D-SSOT-02), and the ordering that makes it safe.
    ///
    /// The irreversibility defence has to cover the content arm too: a systematically wrong hash
    /// pipeline — a `fileHash` regression, an algorithm change — would mismatch EVERY readable page,
    /// which is precisely the shape the all-or-nothing guard exists to refuse. So the guard is
    /// evaluated over the COMBINED prospective blank set, absent ∪ mismatched, and it is evaluated
    /// BEFORE any destructive step.
    ///
    /// That ordering is what this case pins, and it is the reason the assertion on page 2's file is
    /// not decoration: page 1's file is gone and page 2's bytes are wrong, so the combined set covers
    /// both claimed pages and the whole reconciliation refuses. A guard evaluated after the removal
    /// would leave the record verbatim while the file it refused to blank for had already been
    /// destroyed — the record and the disk would then disagree in the one direction nothing can undo.
    @Test
    func testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved() async throws {
        let gallery = SessionGallery(
            gid: "215607",
            title: "Wholesale",
            pageCount: 2,
            completedPageCount: 2
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 2])
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages
        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        let pageTwoURL = pageFileURL(for: gallery, in: fixture, index: 2)
        try FileManager.default.removeItem(at: pageOneURL)
        try corruptPageFile(for: gallery, in: fixture, index: 2)
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)

        // The refusal's whole substance: both recorded hashes are still on disk, untouched.
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages == claimedHashes)
        #expect(diskManifest.completedPageCount == 2)
        // Guard-before-removal, pinned: the mismatched file the reconciliation would have removed is
        // still there, because the refusal preceded the first destructive act.
        #expect(FileManager.default.fileExists(atPath: pageTwoURL.path))

        // The documented residual, pinned rather than hidden: `validationErrors` is session-scoped by
        // design, and the record the refusal preserved still claims both pages — so a fresh process
        // reads this gallery as `.completed` until the user validates again. That is the
        // irreversibility defence working as designed, not a durability miss, and 15-57's widened
        // inspector retry is what starts such a record in-session.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .completed)
        #expect(reread.lastError == nil)
    }

    /// The read-failure hold (D-SSOT-03), pinned from both sides in one gallery.
    ///
    /// A page whose bytes cannot be read at all contributes a NON-ANSWER, and D-G13-01 holds
    /// absolutely that a non-answer is never authority to destroy a recorded hash — nor, here, its
    /// file. So the hold is per-page rather than wholesale: page 2's positive mismatch still
    /// reconciles durably while page 3 keeps both its hash and its file.
    ///
    /// What the hold costs is the `validationErrors` entry, and that is the whole of D-SSOT-05: the
    /// entry now signals only that the pass could not produce trustworthy evidence for every claimed
    /// page, which is exactly true here. The record is honest about page 2 and unchanged about page
    /// 3; the session says the operation was incomplete. The gallery stays startable through 15-57's
    /// widened inspector retry, which carries its page selection explicitly.
    ///
    /// The staging is the same reachability class the presence arm's holds use: real `0o000` modes
    /// make the content pass's `FileHandle` read throw `EACCES` for real, while the metadata probe
    /// still answers, so the page is one the presence scan positively YIELDED and only the content
    /// question went unanswered.
    @Test
    func testAnUnreadablePageHoldsWhileAMismatchedSiblingStillReconciles() async throws {
        let gallery = SessionGallery(
            gid: "215608",
            title: "Held",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 2, 3])
        try corruptPageFile(for: gallery, in: fixture, index: 2)
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages
        let pageThreeURL = pageFileURL(for: gallery, in: fixture, index: 3)
        let originalPermissions = try #require(
            FileManager.default.attributesOfItem(atPath: pageThreeURL.path)[.posixPermissions]
                as? NSNumber
        )
        defer {
            // Declared after the tree removal so it runs BEFORE it, leaving a leaked temporary tree
            // inspectable. No assertion below needs the mode back: the unreadable file is a page
            // file, and the manifest re-read opens `manifest.json`, whose mode was never touched.
            restorePermissions(at: pageThreeURL, to: originalPermissions)
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o000)],
            ofItemAtPath: pageThreeURL.path
        )
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageImageCorrupted(page: 2)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        // The operation-level surface, kept: the pass classified pages 1 and 2 and could not
        // classify page 3, so it cannot claim to have reconciled everything it judged.
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)
        #expect(download.completedPageCount == 2)

        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        // The positive-evidence half proceeded anyway: a hold on one page never blocks another
        // page's own determination.
        #expect(diskManifest.pages[2] == "")
        #expect(FileManager.default.fileExists(atPath: pageFileURL(for: gallery, in: fixture, index: 2).path) == false)
        // The hold's own half: page 3 keeps its recorded hash AND its file.
        #expect(diskManifest.pages[3] == claimedHashes[3])
        #expect(diskManifest.pages[3]?.isEmpty == false)
        #expect(FileManager.default.fileExists(atPath: pageThreeURL.path))
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)
    }

    /// The UNCLASSIFIED hold: a claimed page whose PRESENCE probe could not answer keeps the
    /// operation-level entry, even though a sibling page blanks durably in the same pass.
    ///
    /// This is the second per-file non-answer, one level above the read failure. Page 2's directory
    /// entry is listed by the enumeration and followed to a target that is not there, so it lands in
    /// `PageFileScan.unprobedPages`: neither a file the scan yielded nor a claimed page a successful
    /// listing positively failed to yield. The blanking loop already refuses to touch such a page and
    /// the wholesale guard already excludes it — the coverage answer was the one reader that never
    /// saw the population, so the pass reported that it had classified everything and the caller
    /// dropped the only signal saying otherwise.
    ///
    /// What that cost is pinned here from the far side rather than left implicit.
    /// `canValidateImageData` is `[.completed, .updateAvailable].contains(displayStatus) ||
    /// lastError?.code == .fileOperationFailed`, so a record left `.inactive` with no entry
    /// satisfies neither disjunct: the single sensor would be unreachable for the very page nobody
    /// could answer for. Keeping the entry is what keeps it reachable, and the assertion on
    /// `canValidateImageData` is the proof rather than the status assertion above it.
    ///
    /// The durable half is asserted in the same gallery deliberately: a hold that also blocked its
    /// sibling's correction would satisfy every status assertion here while doing nothing.
    @Test
    func testAnUnprobeablePageHoldsWhileAMissingSiblingStillReconciles() async throws {
        let gallery = SessionGallery(
            gid: "215609",
            title: "Unprobeable",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        // Page 1 is never written, so it is the positively-absent family; page 2's file becomes a
        // dangling symlink, so the listing yields its entry while the probe classifies nothing.
        try writePageFiles(for: gallery, in: fixture, indices: [2, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [2, 3])
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages
        try makeAssetFileUnprobeable(at: pageFileURL(for: gallery, in: fixture, index: 2))
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)
        #expect(download.completedPageCount == 2)
        // The reason the entry has to survive: it is the only disjunct left that keeps the sensor
        // reachable for the page this pass could not answer for.
        #expect(download.canValidateImageData)

        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        // The positive-evidence half proceeded anyway: a non-answer on one page never blocks
        // another page's own determination.
        #expect(diskManifest.pages[1] == "")
        // The hold's own half: page 2 keeps the hash nothing refuted.
        #expect(diskManifest.pages[2] == claimedHashes[2])
        #expect(diskManifest.pages[2]?.isEmpty == false)
        #expect(diskManifest.pages[3]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 2)
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        // The relaunch pin says both halves at once: the correction was carried by the record, and
        // the entry that kept the sensor reachable was session-scoped exactly as designed.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 2)
    }

    /// The refusal arm: blanking that would empty every claimed hash at once is refused, so the
    /// verdict stays the transient `validationErrors` entry it has always been.
    ///
    /// The single-page fixture is the smallest wholesale shape — one claimed page, no file — so the
    /// all-or-nothing guard fires. That guard is the irreversibility defence: the manifest was just
    /// read out of this very folder, so a listing that explains NO claimed page at all is more
    /// likely a shape neither per-page signal caught than proof that everything vanished. The
    /// on-disk hash is asserted intact precisely because a refusal and a blanking are otherwise
    /// indistinguishable from the derived status alone.
    @Test
    func testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives() async throws {
        let gallery = SessionGallery(
            gid: "215602",
            title: "Missing",
            pageCount: 1,
            completedPageCount: 1
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHash = try #require(
            fixture.storage.readManifest(folderURL: folderURL).pages[1]
        )

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)

        // The refusal's whole substance: the recorded hash is still on disk, untouched.
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[1] == claimedHash)
        #expect(diskManifest.completedPageCount == 1)

        // The documented residual, pinned rather than hidden: `validationErrors` is session-scoped
        // by design, and the record the refusal preserved still claims its page — so a fresh
        // process reads this gallery as `.completed` until the user validates again. That is the
        // irreversibility defence working as designed, not a durability miss; the wholesale shape
        // is exactly the one the guard cannot distinguish from a probe that explained nothing.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .completed)
        #expect(reread.lastError == nil)
    }

    /// The start arc, on production entry points end to end: the durable verdict produces a record
    /// the EXISTING resume machinery accepts.
    ///
    /// This is the whole point of the fix, so it is driven through `togglePause(gid:)` — the very
    /// call the inspector's Resume button makes — rather than through a synthetic enqueue. The old
    /// shape could not get here at all: a complete-claiming record under a `validationErrors` entry
    /// derives `.error`, and `togglePause`'s `.error` arm hard-fails with `.unknown`. Nothing new
    /// was built to fix that; the record was made honest, and honest records were always startable.
    ///
    /// **Determinism.** A single-gallery fixture would RACE here: `togglePause` → `resume` →
    /// `scheduleNextIfNeeded` assigns `activeGalleryID` before returning, and `displayStatus` checks
    /// `activeGalleryID` ahead of queue membership, so the status reads `.active` until
    /// `finishActiveTaskIfOwned` nils it on a later actor turn. Asserting `.queued` against that is
    /// a pin on a value whose derivation basis is still moving. So a second BLOCKER gallery takes
    /// the active slot first and never gives it back: the runner double suspends inside
    /// `BlockingRunnerControl.park()`, at its `withCheckedContinuation`, which resumes only when the
    /// test calls `release()` in teardown. `control.started()` is awaited before anything is
    /// asserted, so the blocker's occupancy is a production-issued fact rather than an assumption,
    /// and `scheduleNextIfNeededCore`'s `activeTask == nil` guard then refuses every promotion —
    /// making the target's `.queued` stable indefinitely instead of momentarily true.
    @Test
    func testAReconciledRecordResumesThroughTogglePauseIntoAQueuedRepair() async throws {
        let target = SessionGallery(
            gid: "215603",
            title: "Repairable",
            pageCount: 3,
            completedPageCount: 3
        )
        let blocker = SessionGallery(gid: "215604", title: "Blocking", pageCount: 2)
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [blocker, target],
            queuedGIDs: [blocker.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(
                runScheduledDownload: { _, _ in
                    await control.park()
                    return .skippedOperation
                }
            )
        )
        // Release before removal, so the parked runner is not holding a directory being deleted.
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }

        try writePageFiles(for: target, in: fixture, indices: [1, 3])
        try recordRealPageHashes(for: target, in: fixture, indices: [1, 3])
        await fixture.manager.reloadDownloadIndex()

        await fixture.manager.scheduleNextIfNeeded()
        await control.started()
        let blocking = try #require(await fixture.manager.fetchDownload(gid: blocker.gid))
        #expect(blocking.displayStatus == .active)

        let validation = await fixture.manager.validateImageData(gid: target.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 2)))
        let validated = try #require(await fixture.manager.fetchDownload(gid: target.gid))
        // The clearance proof: `validationErrors` outranks everything in the derivation, so
        // `.inactive` is only reachable once the entry is gone.
        #expect(validated.displayStatus == .inactive)
        #expect(validated.canTogglePause)

        try await fixture.manager.togglePause(gid: target.gid).get()

        let queued = try #require(await fixture.manager.fetchDownload(gid: target.gid))
        #expect(queued.displayStatus == .queued)
        #expect(queued.lastError == nil)
        #expect(await fixture.manager.queuedMode(for: queued) == .repair)
    }
}

private extension DownloadValidationReconciliationTests {
    func galleryFolderURL(for gallery: SessionGallery, in fixture: SessionFixture) -> URL {
        fixture.storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
    }

    func pageFileURL(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        index: Int
    ) -> URL {
        galleryFolderURL(for: gallery, in: fixture)
            .appendingPathComponent(
                fixture.storage.makePageRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    index: index,
                    fileExtension: "jpg"
                )
            )
    }

    /// Overwrites a page file's bytes with different content of nonzero length.
    ///
    /// The file stays present and stays probe-usable — a regular file with a positive size — so the
    /// presence scan keeps yielding it. Only the CONTENT question changes its answer, which is what
    /// makes this the mismatch family rather than the absence family.
    func corruptPageFile(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        index: Int
    ) throws {
        try Data("corrupted-page-\(index)".utf8).write(
            to: pageFileURL(for: gallery, in: fixture, index: index),
            options: .atomic
        )
    }

    /// D-SSOT-04's structural pin: after a reconciliation, no page may carry a blank hash while its
    /// file is still on disk.
    ///
    /// That shape is the laundering hazard the content arm exists to preclude, and it is asserted
    /// over the whole manifest rather than only for the page a case happens to be about.
    /// `resolveSourceIfNeeded` filters a run's pending pages down to the ones whose file is MISSING,
    /// so a blanked page whose file survived is never fetched; `finalizeDownload`'s
    /// `addingCurrentFileHashes` merge then hashes exactly the blank-hash pages from the files
    /// currently on disk, re-recording the stale bytes as truth. The removal is what keeps the two
    /// mechanisms honest.
    func expectNoBlankHashedPageKeptItsFile(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) throws {
        let manifest = try fixture.storage.readManifest(
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        for page in manifest.pages.keys.sorted() where manifest.pages[page]?.isEmpty == true {
            let fileURL = pageFileURL(for: gallery, in: fixture, index: page)
            #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
        }
    }

    /// Replaces the fixture's placeholder hashes for `indices` with the real hashes of the page
    /// files `writePageFiles` just landed.
    ///
    /// Content validation compares recorded hashes against the bytes on disk, so a surviving page
    /// carrying a placeholder hash would be reported corrupted and short-circuit the verdict before
    /// it ever reached the genuinely missing page. Aligning the surviving pages is what makes the
    /// missing one the thing under test.
    func recordRealPageHashes(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        indices: [Int]
    ) throws {
        let pageRelativePaths = indices.reduce(into: [Int: String]()) { paths, index in
            paths[index] = fixture.storage.makePageRelativePath(
                gid: gallery.gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
        }
        try fixture.storage.refreshManifestPageFileHashes(
            folderURL: galleryFolderURL(for: gallery, in: fixture),
            pageRelativePaths: pageRelativePaths
        )
    }
}
