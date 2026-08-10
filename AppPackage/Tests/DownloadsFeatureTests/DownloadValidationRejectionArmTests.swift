import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

/// CR-01: the REJECTION family's half of the classification-versus-mutation boundary — a claimed page
/// whose file is there and is structurally unusable (zero bytes, or not a regular file at all).
///
/// An `extension` of the reconciliation suite rather than a suite of its own, so these cases keep
/// that suite's contract, its fixtures and its `-only-testing` gate; the split is a file-length one.
///
/// The rejection family is the one the ordering defect lived in, and the reason is that it was the
/// only positive per-page determination the PROBE could make by itself. Absence is decided by a
/// listing and mismatch by a content pass, so neither of them can act while it is being gathered.
/// A rejection is decided by `probeAssetFile`, which — for every caller that did not opt out — also
/// DELETED the file it had just rejected, as housekeeping. Validation never opted out, so its
/// evidence gathering destroyed page files before the reconciliation's wholesale guard had
/// authorized anything, and the guard then refused to blank the very hashes whose files were
/// already gone. The record and the disk diverged in the one direction nothing can undo, marked
/// only by a session-scoped `validationErrors` entry that a relaunch drops.
///
/// So the boundary these cases pin is not about WHICH pages a pass may correct — that is settled by
/// D-SSOT-01/02/03 and pinned next door — but about WHEN it may touch anything at all: classify
/// first, authorize the whole combined set, and only then mutate disk and record together. Both
/// refusal cases therefore assert the FILE directly rather than only the manifest: a manifest-only
/// assertion passes unchanged against the defect, because the manifest is exactly what the refusal
/// did preserve.
extension DownloadValidationReconciliationTests {
    /// The smallest wholesale rejection: one claimed page whose file is zero bytes.
    ///
    /// The combined prospective blank set is that single page, and the record claims exactly one, so
    /// the all-or-nothing guard refuses — the same irreversibility defence the all-missing and
    /// all-mismatched shapes get, extended to the third positive determination. A refusal means
    /// nothing moved: the recorded hash stands, and the file the pass declined to blank for is still
    /// on disk with its bytes unchanged, so a later validate over a repaired filesystem can still
    /// reach the ordinary guards.
    ///
    /// The file assertion is the load-bearing one. Against the pre-fix ordering the manifest
    /// assertions below pass verbatim, because the guard really did refuse to write; what the guard
    /// could not undo was the deletion its own evidence gathering had already performed.
    @Test
    func testAWholesaleZeroBytePageRefusesWithItsFileStillOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215612",
            title: "Rejected",
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

        // Written through the production namer and then TRUNCATED, so the directory entry is one the
        // listing really yields and only the size question rejects it. A file that was never written
        // would stage the absence family instead, which this case is not about.
        try writePageFiles(for: gallery, in: fixture, indices: [1])
        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        try Data().write(to: pageOneURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        try expectAWholesaleRejectionChangedNothing(
            for: gallery,
            in: fixture,
            validation: validation,
            claimedHashes: claimedHashes,
            rejectedPageURL: pageOneURL
        )
        // The rejection's own staging, re-read from disk: still a regular file, still empty. This is
        // what "unchanged bytes" means for a file whose whole defect is that it has none.
        let attributes = try FileManager.default.attributesOfItem(atPath: pageOneURL.path)
        #expect((attributes[.type] as? FileAttributeType) == .typeRegular)
        #expect((attributes[.size] as? NSNumber)?.intValue == 0)

        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)
        #expect(download.canValidateImageData)
    }

    /// The same refusal for the other structural rejection: the page's path is not a regular file.
    ///
    /// Staged as a real directory at the page path, which is portable, deterministic and needs no
    /// double: `contentsOfDirectory` yields the entry, `attributesOfItem` answers `.typeDirectory`,
    /// and the probe rejects on the regular-file question rather than the size one. The two arms are
    /// separate cases rather than one parameterised over a staging closure because what they prove
    /// is that BOTH exits of the rejection branch respect the ordering — a fix applied to one exit
    /// only would leave the other case red.
    ///
    /// The destructive pre-fix path is worse here than for the zero-byte arm, which is why it is
    /// worth its own case: the housekeeping deletion is `removeItem`, so it takes the directory and
    /// everything under it while the record goes on claiming the page.
    @Test
    func testAWholesaleNonRegularPageRefusesWithItsPathStillOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215613",
            title: "NonRegular",
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

        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        try FileManager.default.createDirectory(at: pageOneURL, withIntermediateDirectories: true)
        await fixture.manager.reloadDownloadIndex()

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        try expectAWholesaleRejectionChangedNothing(
            for: gallery,
            in: fixture,
            validation: validation,
            claimedHashes: claimedHashes,
            rejectedPageURL: pageOneURL
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: pageOneURL.path)
        #expect((attributes[.type] as? FileAttributeType) == .typeDirectory)

        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)
        #expect(download.canValidateImageData)
    }

    /// The positive boundary: where the combined set is NOT wholesale, the authorized correction
    /// still happens — file removed, hash blanked, entry cleared, and all of it durable.
    ///
    /// Without this case the refusal cases alone would be satisfied by a validation that stopped
    /// correcting rejections altogether, which trades one record/disk divergence for a permanently
    /// over-claiming record. Two claimed pages, one of them valid, put the prospective set at one of
    /// two, so the guard authorizes; the ordering then runs forward instead of backward — authorize,
    /// remove, blank — and the removal is what keeps the blanked page repairable rather than
    /// laundered (D-SSOT-04), since `resolveSourceIfNeeded` only re-fetches pages whose file is
    /// missing and `finalizeDownload`'s merge would otherwise re-record the empty file's hash as
    /// truth.
    @Test
    func testAnAuthorizedRejectionRemovesOnlyTheRefutedPageAndBlanksItsHash() async throws {
        let gallery = SessionGallery(
            gid: "215614",
            title: "PartialRejection",
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

        // Page 1 carries the real hash of the bytes it holds, so it survives the content pass and the
        // combined set stays below the wholesale threshold; page 2 is truncated after writing.
        try writePageFiles(for: gallery, in: fixture, indices: [1, 2])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1])
        let pageOneURL = pageFileURL(for: gallery, in: fixture, index: 1)
        let pageTwoURL = pageFileURL(for: gallery, in: fixture, index: 2)
        try Data().write(to: pageTwoURL, options: .atomic)
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 2)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        // The clearance half: the operation classified every claimed page and wrote what they
        // licensed, so nothing operation-level is left to outrank the record.
        #expect(download.displayStatus == .inactive)
        #expect(download.lastError == nil)
        #expect(download.completedPageCount == 1)

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.pages[1]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 1)

        // Both halves of the authorized act, asserted apart: the refuted file is gone and the
        // surviving one is untouched.
        #expect(FileManager.default.fileExists(atPath: pageTwoURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: pageOneURL.path))
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        // The relaunch pin: a fresh coordinator over the same storage holds none of this session's
        // in-memory state, so a correct reading here was carried by the record alone.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 1)
        #expect(reread.canTogglePause)
        #expect(await relaunched.resumeMode(for: reread) == .repair)
    }

    /// WR-01's refusal side, and the first half of the crossing pair: a MIXED shape — one claimed
    /// page positively refuted with its file still on disk, one claimed page positively absent —
    /// whose combined prospective set is the whole record must blank nothing and remove nothing.
    ///
    /// The wholesale guard is a comparison against `manifest.completedPageCount`, so whatever
    /// quantity is put on its left-hand side decides what "all of them" means. 15-62 added a
    /// per-page hold for surviving rejections and reported it as a strengthening that "can only
    /// blank less"; the hold also removes the held page from the count the guard reads, and this
    /// shape is where that matters. Two claimed pages, one refuted and one absent: counting only
    /// the absence puts `1 < 2` and licenses blanking page 2, while the pass has in fact explained
    /// away every page the record claims — precisely the systematic shape the all-or-nothing
    /// defence exists for. A per-page protection must not be able to authorize an act the guard
    /// previously refused.
    ///
    /// Its sibling below stages the same folder with one extra usable page, so the two cases sit on
    /// opposite sides of the same discontinuity and the boundary between them is crossed by
    /// construction rather than assumed.
    @Test
    func testAMixedRejectedAndAbsentShapeRefusesTheWholesaleBlanking() async throws {
        let gallery = SessionGallery(
            gid: "215615",
            title: "MixedRefusal",
            pageCount: 2,
            completedPageCount: 2
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await stageAMixedRejectedAndAbsentShape(for: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages
        let refutedPageURL = pageFileURL(for: gallery, in: fixture, index: 1)

        let seedManifest = try await prepareTheRepairSeedManifest(for: gallery, in: fixture)

        // Handed back verbatim, in memory and on disk alike: a refusal that only declined to
        // persist would still have moved the record every later consumer reads.
        #expect(seedManifest.pages == claimedHashes)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages == claimedHashes)
        #expect(diskManifest.completedPageCount == 2)
        // The refusal's other half: an act the guard declined to authorize must not have happened
        // anyway. Pre-fix the removal was never reached for this file at all, which is what leaves
        // the record claiming a page over positively refuted bytes.
        #expect(
            FileManager.default.fileExists(atPath: refutedPageURL.path),
            "a refused wholesale reconciliation must leave the rejected page file on disk"
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: refutedPageURL.path)
        #expect((attributes[.size] as? NSNumber)?.intValue == 0)
        #expect(
            FileManager.default.fileExists(
                atPath: pageFileURL(for: gallery, in: fixture, index: 2).path
            ) == false
        )
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        let reread = try await relaunchedDownload(for: gallery, in: fixture)
        #expect(reread.completedPageCount == 2)
        #expect(reread.displayStatus == .completed)
    }

    /// WR-02's laundering mirror, and the second half of the crossing pair: the same folder with a
    /// third, usable claimed page puts the combined set BELOW the threshold, so the authorized act
    /// must run forward — remove the refuted file, blank its hash and the absence's, and leave the
    /// usable page's hash and file alone.
    ///
    /// This is the side that proves the fix is not a blanket refusal. It also pins the ordering the
    /// automatic route was missing: `probeAssetFileContent` returns a surviving rejection
    /// unconditionally — it never deletes, deliberately, because metadata never confirmed anything
    /// about the file — and the removal primitive was reachable only from the user-initiated
    /// Validate pass. So on the repair-seed route a page whose bytes were positively refuted kept
    /// its claimed hash indefinitely: the record went on describing a complete page over unusable
    /// bytes, which is the D-SSOT-04 shape from the other direction, and no automatic pass could
    /// ever clear it.
    @Test
    func testAMixedShapeBelowTheThresholdRemovesTheRefutedPageAndBlanksBoth() async throws {
        let gallery = SessionGallery(
            gid: "215616",
            title: "MixedAuthorized",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await stageAMixedRejectedAndAbsentShape(for: gallery, client: spy.client)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHashes = try fixture.storage.readManifest(folderURL: folderURL).pages
        let refutedPageURL = pageFileURL(for: gallery, in: fixture, index: 1)
        let usablePageURL = pageFileURL(for: gallery, in: fixture, index: 3)

        let seedManifest = try await prepareTheRepairSeedManifest(for: gallery, in: fixture)

        #expect(seedManifest.pages[1] == "")
        #expect(seedManifest.pages[2] == "")
        #expect(seedManifest.pages[3] == claimedHashes[3])
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages == seedManifest.pages)
        #expect(diskManifest.completedPageCount == 1)
        // The blanking and the removal are one act: a blank hash beside surviving bytes is the
        // laundering shape, and a removal beside a standing hash is the divergence.
        #expect(
            FileManager.default.fileExists(atPath: refutedPageURL.path) == false,
            "an authorized reconciliation must remove the file whose hash it blanked"
        )
        #expect(FileManager.default.fileExists(atPath: usablePageURL.path))
        try expectNoBlankHashedPageKeptItsFile(for: gallery, in: fixture)

        let reread = try await relaunchedDownload(for: gallery, in: fixture)
        #expect(reread.completedPageCount == 1)
        #expect(reread.displayStatus == .inactive)
    }
}

private extension DownloadValidationReconciliationTests {
    /// The refusal contract itself, shared by both rejection families because it is one contract:
    /// the verdict is reported, the record is byte-identical, and the refuted path is still there.
    ///
    /// Stated once rather than per family so the two arms cannot drift into asserting different
    /// amounts of preservation, which is how a family ends up green over a weaker promise than its
    /// sibling. Each caller adds only the assertions about the staging it chose.
    func expectAWholesaleRejectionChangedNothing(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        validation: DownloadValidationState?,
        claimedHashes: [Int: String],
        rejectedPageURL: URL
    ) throws {
        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        // The load-bearing assertion of this whole file: a pass that refused to write must not have
        // destroyed the evidence it refused to write about.
        #expect(
            FileManager.default.fileExists(atPath: rejectedPageURL.path),
            "a refusing validate must leave the rejected page file on disk"
        )
        let diskManifest = try fixture.storage.readManifest(
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        #expect(diskManifest.pages == claimedHashes)
        #expect(diskManifest.completedPageCount == 1)
    }

    /// The crossing fixture the two mixed-shape cases share, differing only in `gallery.pageCount`.
    ///
    /// Page 1 is a claimed page whose file is a readable zero-byte regular file and whose METADATA
    /// read throws. That is not a convenience: it is the one production exit that yields a
    /// SURVIVING rejection for a caller that asked the probe to discard. `probeAssetFile` falls
    /// back to `probeAssetFileContent` when `attributesOfItem` throws, and that fallback answers an
    /// immediate end-of-file with `.rejected(fileRemains: true)` unconditionally — metadata never
    /// confirmed a zero-byte regular file, so the housekeeping deletion the metadata path performs
    /// is deliberately not warranted there. Staging the refusal any other way would let the
    /// discarding scan delete the file and collapse the page back into an ordinary absence, which
    /// is a different family and pins nothing about the guard's basis.
    ///
    /// Everything else stays real: the directory listing, the existence check and the `FileHandle`
    /// read all run against the filesystem, and the double throws from `attributesOfItem` for page
    /// 1's path fragment and from nothing else. Page 2 is claimed with no file at all — the
    /// positive absence — and every page from 3 up is claimed with a usable file, so the caller
    /// chooses which side of the wholesale threshold it lands on purely by how many pages the
    /// record claims.
    func stageAMixedRejectedAndAbsentShape(
        for gallery: SessionGallery,
        client: BackgroundProcessingClient
    ) async throws -> SessionFixture {
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            fileManager: PartialProbeFailureFileManager(
                // `makePageRelativePath`'s shape for page 1 — the identity prefix, the page number,
                // a dot — which no other file in the fixture folder carries.
                pathFragments: ["\(gallery.gid)_token_1."],
                error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
            )
        )
        let usablePages = (1...gallery.pageCount).filter({ $0 >= 3 })
        try writePageFiles(for: gallery, in: fixture, indices: [1] + usablePages)
        // Written through the production namer and then truncated, so the listing really yields the
        // entry and only the content question refuses it.
        try Data().write(
            to: pageFileURL(for: gallery, in: fixture, index: 1),
            options: .atomic
        )
        await fixture.manager.reloadDownloadIndex()
        return fixture
    }

    /// Drives the production repair-seed preparation over the fixture's own folder and returns the
    /// manifest it hands back.
    ///
    /// `.repair` reuses its working folder unconditionally, so the gallery folder IS the working
    /// folder and the preparation reaches `reconcileWorkingManifestAgainstPageFiles` over exactly
    /// the shape the staging wrote. Going through the announcing entry point rather than the silent
    /// one is what keeps the case on the route production takes.
    func prepareTheRepairSeedManifest(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) async throws -> DownloadManifest {
        let existingDownload = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        let prepared = try await fixture.manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: gallery),
            existingDownload: existingDownload,
            folderURL: galleryFolderURL(for: gallery, in: fixture)
        )
        return prepared.workingSeed.manifest
    }

    /// The record a relaunch would read: a second coordinator over the same storage root, holding
    /// none of this session's in-memory state, so whatever it reports was carried by the record.
    ///
    /// Its store takes the real file manager rather than the staging double — a relaunch has no
    /// probe failure — which is also what makes the surviving-file readings above durable claims
    /// about the disk rather than about the injection.
    func relaunchedDownload(
        for gallery: SessionGallery,
        in fixture: SessionFixture
    ) async throws -> DownloadedGallery {
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        return try #require(await relaunched.fetchDownload(gid: gallery.gid))
    }
}
