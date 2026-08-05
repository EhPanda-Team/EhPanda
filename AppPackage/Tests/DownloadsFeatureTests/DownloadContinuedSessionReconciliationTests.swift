import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The reconciliation half of `DownloadContinuedSessionBasisTests`: what the coordinator is allowed
/// to BELIEVE a folder holds, and therefore allowed to blank, when the probe that reads it answers,
/// fails to answer, or reports an honest absence.
///
/// An `extension` of that same suite type rather than a suite of its own, so every case here
/// keeps its suite membership, its traits and its test identity: this file is a relocation for
/// headroom, not a re-partitioning of the proof surface. The sibling file
/// `DownloadContinuedSessionBasisTests.swift` keeps the other half — the counted basis and the
/// monotonic floor above it, which move without any folder being re-read at all.
///
/// Split out when that file reached 996 lines against a `file_length` limit of 1000 at error
/// severity, which is the same limit its own header gives as the reason it exists apart from
/// `DownloadContinuedSessionLedgerTests.swift`. Both files now hold real headroom, so the next
/// regression in either family can land where it belongs.
///
/// **Choreography discipline**, carried over because every case here relies on it. Record state
/// comes only from fixture manifests, `writePageFiles` and the production announcing preparation —
/// never from the ledger suite's manual index-patch seam, which stays private to that file
/// deliberately. Each case asserts on the announcement's OWN push, pinned by
/// `spy.progressUpdates.count == 1`, so the pair it reads is a fact about the production sequence
/// rather than about a push the test issued.
extension DownloadContinuedSessionBasisTests {
    /// G-15-9: the reconciliation must not destroy recorded hashes on a probe's NON-answer.
    ///
    /// `existingPageRelativePaths` is a best-effort probe that swallows failure at three levels —
    /// `existingAssetFileURLs` returned `[]` on any `contentsOfDirectory` failure,
    /// `sanitizeAssetFileIfNeeded` falls back to `canReadNonEmptyFile`, and that returns `false` on
    /// any open or read failure. While the empty answer only caused a re-fetch it was harmless.
    /// D-G5-01 made it authority for blanking, so one failed enumeration blanked EVERY claimed page
    /// of the gallery in a single pass, rewrote the manifest, published a 0-of-N record and — since
    /// D-G7-01's bracket — withdrew the full count from the floor, all unlogged.
    ///
    /// The staging is an execute-only working folder: with the read bit cleared,
    /// `contentsOfDirectory` throws `EACCES` while the by-name manifest read and the manifest
    /// rewrite both still work, so the failure is exactly a lost LISTING rather than a lost folder.
    /// That is the deterministic stand-in for the transient failure family this defends against —
    /// descriptor exhaustion, a transient `EBUSY`, and the data-protection denial a backgrounded
    /// continued-processing session runs directly into, none of which can be provoked on demand.
    ///
    /// Every claimed page's file is present here, so a SUCCESSFUL scan would blank nothing: what the
    /// case discriminates is the failed scan alone. The no-withdrawal half needs no separate
    /// mechanism — a refusal moves no index record, so D-G7-01's delta-keyed bracket subtracts zero
    /// by construction.
    @Test
    func testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing() async throws {
        let unlisted = SessionGallery(
            gid: "210370",
            title: "Unlisted",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [unlisted],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        let manager = fixture.manager
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(unlisted.gid)_token] \(unlisted.title)"
        )
        let originalPermissions = try #require(
            FileManager.default.attributesOfItem(atPath: folderURL.path)[.posixPermissions]
                as? NSNumber
        )
        defer {
            // Removing the tree needs the read bit back, so the restore runs ahead of the cleanup
            // in the same deferred block rather than racing it as a second one.
            restorePermissions(at: folderURL, to: originalPermissions)
            removeTemporaryItem(at: fixture.rootURL)
        }

        try writePageFiles(for: unlisted, in: fixture, indices: [1, 2, 3, 4])
        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: unlisted.gid))
        #expect(staged.completedPageCount == 4)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        // Owner write + execute, no read anywhere: listing is denied, path-addressed opens are not.
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o311)],
            ofItemAtPath: folderURL.path
        )

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: unlisted),
            existingDownload: staged,
            folderURL: folderURL
        )

        // Nothing blanked and nothing re-indexed: the record the card sums from is where it was.
        #expect(await manager.fetchDownload(gid: unlisted.gid)?.completedPageCount == 4)
        // The probe's answer stays a probe. An empty seed makes the run re-fetch, which is the
        // pre-D-G5-01 behavior this refusal deliberately falls back to.
        #expect(seed.existingPages.isEmpty)
        // The announcement's own push, and the only push recorded: no withdrawal was taken, because
        // the refusal moved no record for the bracket's delta to measure.
        #expect(spy.progressUpdates.count == 1)
        let refusalPair = try lastPushedPair(spy.progressUpdates)
        #expect(refusalPair.completedUnitCount == 4)
        #expect(refusalPair.totalUnitCount == 6)
        #expect(refusalPair.subtitle == "4 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)

        // Nothing written: the manifest on disk is the one the fixture staged, hash for hash.
        restorePermissions(at: folderURL, to: originalPermissions)
        let onDiskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(onDiskManifest.pages == manifest(for: unlisted).pages)
        #expect(onDiskManifest.completedPageCount == 4)
    }

    /// G-15-13: the same non-answer defence one level down, in the population the total-scan guard
    /// structurally cannot see.
    ///
    /// The case above defends the directory level. Its all-or-nothing companion —
    /// `blankedPageCount < manifest.completedPageCount` — disables itself the moment ONE claimed
    /// page survives, and one level down the per-file probe still conflated `file absent` with
    /// `file present but unprobeable`. A gallery with four claimed pages and three failed per-file
    /// probes yielded `3 < 4`: the guard passed, three recorded hashes were destroyed, the manifest
    /// was rewritten, the record was republished at 1-of-6 and D-G7-01's bracket withdrew three
    /// from the floor — for a movement that never physically happened, and irreversibly.
    ///
    /// The staging is the reachability class the verification narrowed the defect to, not the
    /// review's wider claim: descriptor exhaustion never reaches a metadata read and a locked
    /// device still gets an answer from one, so what is staged is `attributesOfItem` ITSELF
    /// throwing for many-but-not-all files. `PartialProbeFailureFileManager` throws from exactly
    /// that call for three of the four claimed pages, real `0o000` modes on the same three files
    /// make the probe's `FileHandle` fallback throw `EACCES` for real, and the folder is left
    /// readable so the directory listing succeeds throughout. Every other filesystem operation the
    /// production path takes is the real one.
    ///
    /// The no-withdrawal half needs no separate mechanism, exactly as in the wholesale case: a
    /// refusal moves no index record, so the delta-keyed bracket subtracts zero by construction.
    @Test
    func testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing() async throws {
        let partial = SessionGallery(
            gid: "210380",
            title: "Partial",
            pageCount: 6,
            completedPageCount: 4
        )
        // Three of the four claimed pages: the N-1 shape the all-or-nothing guard lets through.
        let unprobedPages = [2, 3, 4]
        // `makePageRelativePath`'s shape — the identity prefix, the page number, a dot — which no
        // other file in the working folder carries. Pinned against the production API below.
        let pathFragments = unprobedPages.map({ "\(partial.gid)_token_\($0)." })
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [partial],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            fileManager: PartialProbeFailureFileManager(
                pathFragments: pathFragments,
                error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError)
            )
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(partial.gid)_token] \(partial.title)"
        )

        try writePageFiles(for: partial, in: fixture, indices: [1, 2, 3, 4])
        let unprobedFileURLs = unprobedPages.map { page in
            folderURL.appendingPathComponent(
                fixture.storage.makePageRelativePath(
                    gid: partial.gid,
                    token: "token",
                    index: page,
                    fileExtension: "jpg"
                )
            )
        }
        // The double's fragments and the real page-file names are built by different routes, so the
        // staging is pinned rather than assumed: a naming change fails here rather than silently
        // disarming the double and leaving the case green against an unexercised probe.
        for (fileURL, fragment) in zip(unprobedFileURLs, pathFragments) {
            #expect(fileURL.lastPathComponent.contains(fragment))
        }
        let originalPermissions = try unprobedFileURLs.map { fileURL in
            try #require(
                FileManager.default.attributesOfItem(atPath: fileURL.path)[.posixPermissions]
                    as? NSNumber
            )
        }
        defer {
            // Declared after the tree removal so it runs BEFORE it, leaving a leaked temporary
            // tree inspectable. Nothing in the case's own assertions needs the modes back: the
            // three unreadable files are page files, and the manifest re-read below opens
            // `manifest.json`, whose mode was never touched.
            for (fileURL, permissions) in zip(unprobedFileURLs, originalPermissions) {
                restorePermissions(at: fileURL, to: permissions)
            }
        }

        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: partial.gid))
        #expect(staged.completedPageCount == 4)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        // No owner bits at all on the three files: the double throws the metadata read, the
        // content-read fallback then throws EACCES against the real filesystem, and the folder
        // itself is untouched so the enumeration keeps succeeding.
        for fileURL in unprobedFileURLs {
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o000)],
                ofItemAtPath: fileURL.path
            )
        }

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: partial),
            existingDownload: staged,
            folderURL: folderURL
        )

        // Nothing blanked and nothing re-indexed: the record the card sums from is where it was.
        #expect(await manager.fetchDownload(gid: partial.gid)?.completedPageCount == 4)
        // Page 1 is the only one the probe answered for. The other three are neither reused nor
        // destroyed: the run re-fetches them, which is the harmless pre-D-G5-01 arc.
        #expect(seed.existingPages.keys.sorted() == [1])
        // The announcement's own push, and the only push recorded: no withdrawal was taken, because
        // the refusal moved no record for the bracket's delta to measure.
        #expect(spy.progressUpdates.count == 1)
        let refusalPair = try lastPushedPair(spy.progressUpdates)
        #expect(refusalPair.completedUnitCount == 4)
        #expect(refusalPair.totalUnitCount == 6)
        #expect(refusalPair.subtitle == "4 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)

        // Nothing written: the manifest on disk is the one the fixture staged, hash for hash.
        let onDiskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(onDiskManifest.pages == manifest(for: partial).pages)
        #expect(onDiskManifest.completedPageCount == 4)
    }

    /// The companion that stops the per-file refusal from being satisfied by refusing everything.
    ///
    /// Same gallery shape over the real file manager, with two of the four claimed page files
    /// deleted outright — the route a user emptying the folder in the Files app takes. The listing
    /// succeeds and simply does not yield them, which is a POSITIVE absence rather than an
    /// unanswered question, so the reconciliation must still blank exactly those two: the record
    /// moves to 2-of-6, the rewritten manifest keeps non-empty hashes for pages 1 and 2 only, the
    /// blanking notice fires, and D-G7-01's bracket withdraws exactly the two pages the record lost.
    ///
    /// This case is green both before and after the classification lands, deliberately: it pins the
    /// side of the behaviour the fix must NOT move, so a fix that bought the mass-partial case by
    /// disabling partial blanking, raising the all-or-nothing threshold or special-casing the
    /// staged names fails here in the same run.
    @Test
    func testAGenuinePartialLossBlanksExactlyTheMissingPages() async throws {
        let lossy = SessionGallery(
            gid: "210381",
            title: "Lossy",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [lossy],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(lossy.gid)_token] \(lossy.title)"
        )

        try writePageFiles(for: lossy, in: fixture, indices: [1, 2, 3, 4])
        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: lossy.gid))
        #expect(staged.completedPageCount == 4)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        for page in [3, 4] {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: lossy.gid,
                token: "token",
                index: page,
                fileExtension: "jpg"
            )
            try FileManager.default.removeItem(at: folderURL.appendingPathComponent(relativePath))
        }

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: lossy),
            existingDownload: staged,
            folderURL: folderURL
        )

        // Exactly the two lost pages, and only them: the record the card sums from moved by two.
        #expect(await manager.fetchDownload(gid: lossy.gid)?.completedPageCount == 2)
        #expect(seed.existingPages.keys.sorted() == [1, 2])
        // One push, at the corrected basis: the record really moved, so the bracket withdrew the
        // counted two rather than nothing.
        #expect(spy.progressUpdates.count == 1)
        let correctedPair = try lastPushedPair(spy.progressUpdates)
        #expect(correctedPair.completedUnitCount == 2)
        #expect(correctedPair.totalUnitCount == 6)
        #expect(correctedPair.subtitle == "2 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)

        // Written, and written correctly: pages 1 and 2 keep their hashes, 3 and 4 are blanked.
        let onDiskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(onDiskManifest.completedPageCount == 2)
        #expect(onDiskManifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == [1, 2])
    }
}
