import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The ledger half of the reconciliation's REFUSAL family: what the card reports for the run that
/// FOLLOWS a refusal, rather than what the refusal itself does to the manifest.
///
/// An `extension` of the ledger suite rather than a suite of its own, so both cases keep that
/// suite's membership, its traits and its test identity — the 15-41 relocation pattern applied to
/// additions. A new file because `DownloadContinuedSessionLedgerTests.swift` sits at 812 lines
/// against a `file_length` limit of 1000 at error severity, and two stagings of this size would
/// crowd it.
///
/// Ledger cases rather than reconciliation ones, deliberately. The refusal cases in
/// `DownloadContinuedSessionReconciliationTests` assert the refusal itself — nothing blanked,
/// nothing written, nothing withdrawn — over records that already read INCOMPLETE. These two
/// assert what the SESSION goes on to report when the refused record reads COMPLETE, which is the
/// state that starves the trust basis (G-15-23): the record stays complete for the whole run, the
/// flush path only ever moves it upward, and the gallery therefore departed untrusted and retired
/// zero — a terminal `0 / 1 page · 0 galleries` card over an N-page re-download, which is the
/// maximally stalled reading D-11's expiration policy punishes by pausing every schedulable
/// download.
///
/// The family is covered rather than one branch: `reconcileWorkingManifestAgainstPageFiles` has
/// three refusal exits, and the two staged here are the two a complete-reading record can reach
/// on the `.repair` route — the all-or-nothing residual and the failed directory enumeration. The
/// per-file exit is the same shape one page at a time.
///
/// **Choreography discipline**, carried over from both sibling files. Record state comes only from
/// fixture manifests, `writePageFiles` and production routes — never from the ledger file's
/// private index-patch seam, which stays private to that file deliberately — and every push
/// asserted is production-issued: the session ensure inside `retryPages`, its convergence pushes,
/// the preparation's own announcement, and the drain's.
extension DownloadContinuedSessionLedgerTests {
    /// G-15-23 at K=N: a repair whose pages are ALL gone, over a record that reads complete.
    ///
    /// The residual guard — `blankedPageCount < manifest.completedPageCount` — refuses here by
    /// design, because blanking all six claimed pages of a manifest just read out of this very
    /// folder is more likely a shape the positive signals missed than proof that six files vanished
    /// at once. That refusal is the round-11/12/13 defence and must not move. What it costs is this
    /// case's subject: nothing blanked means nothing republished, so the record goes on reading
    /// 6-of-6, `isIncomplete` stays false, and the only writers of the session's trust set are two
    /// `formUnion`s over `snapshot.incompleteGalleryIDs` — which by construction cannot contain a
    /// complete-reading record. Without an explicit admission at the run's own preparation the
    /// gallery contributes zero to the numerator for the entire six-page re-download and retires
    /// zero when it leaves.
    ///
    /// The staging is the K=1 case with exactly one difference: no page file is written at all. The
    /// route is grounded rather than asserted about — `resumeMode` resolves `.repair` through its
    /// missing-files branch, which its own doc names as one of exactly two states that still reach
    /// it — and the queued window is pinned at zero, which is D-G4-01's ceiling guarantee and the
    /// thing a fix that granted trust at queue time would break.
    ///
    /// `expectTheFractionReachesOneOnlyAtTheDrain` is deliberately NOT asserted here, and the
    /// omission is a fact about the family rather than a weakened assertion. A trusted
    /// complete-reading record honestly rides at its own ceiling for a refused repair: the record
    /// genuinely claims six pages, the refusal is precisely the defence against destroying those
    /// six recorded hashes, so the fraction reaches one before the drain BY DESIGN. The harm this
    /// case pins is the pinned-ZERO run, not the ceiling — and the ceiling itself is pinned by the
    /// queued-window assertion above and by `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero`
    /// in the sibling file.
    @Test
    func testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull() async throws {
        let vanished = SessionGallery(
            gid: "210390",
            title: "Vanished",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [vanished],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // No page file is staged at all: the folder holds the fixture manifest and nothing else, so
        // a successful scan accounts for none of the six claimed pages and the residual exit fires.
        await manager.reloadDownloadIndex()

        // Grounded in the production route rather than asserted about it: a complete-reading record
        // whose files are gone reaches `.repair` through the missing-files branch.
        let staged = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        try await manager.retryPages(gid: vanished.gid, pageIndices: [1, 2, 3, 4, 5, 6]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        // The queued window still counts zero, which is D-G4-01's guarantee and not a regression:
        // nothing has run yet, so the manifest's six pages are the repair's target.
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(vanished.gid)_token] \(vanished.title)"
        )
        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: vanished),
            existingDownload: staged,
            folderURL: folderURL
        )

        // The refusal blanked nothing and republished nothing, so the record is where it was.
        #expect(await manager.fetchDownload(gid: vanished.gid)?.completedPageCount == 6)
        // And the folder really can supply nothing: the run's own page work is all six pages.
        #expect(seed.existingPages.isEmpty)
        // Asserted by presence rather than by position: a straggling convergence push may land on
        // either side of the preparation, and both values it can carry are admitted by the series
        // property below.
        #expect(spy.progressUpdates.map(\.subtitle).contains("6 / 6 pages · 1 gallery"))

        try writePageFiles(for: vanished, in: fixture, indices: [1, 2, 3, 4, 5, 6])
        try await manager.flushManifestPageProgress(
            folderURL: folderURL,
            pages: pageResults(for: vanished, in: fixture, indices: [1, 2, 3, 4, 5, 6])
        )

        await manager.settleCompletedDownload(gid: vanished.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
    }

    /// The same starvation reached through the DIRECTORY-level refusal, which is the exit no amount
    /// of page-file staging can reach.
    ///
    /// `scanSucceeded` false means the enumeration itself failed, so the whole answer is a
    /// non-answer and nothing is blanked (G-15-9). The record therefore reads complete for the
    /// whole run exactly as in the residual case above, and the announcement is the only place that
    /// can admit the gallery to the session's trust set. Staging both exits is what makes this a
    /// FAMILY closure rather than a fix for the branch a report named: a refusal of any kind over a
    /// complete-reading record produces the identical zero-progress run.
    ///
    /// The staging is the wholesale-failure shape from `DownloadContinuedSessionReconciliationTests`
    /// — an execute-only working folder, so `contentsOfDirectory` throws `EACCES` while the by-name
    /// manifest read still works and the failure is exactly a lost LISTING rather than a lost
    /// folder — with the permissions-restoring `defer` discipline that keeps a failed assertion from
    /// stranding an unreadable fixture tree. Five of the six page files are present and one is
    /// genuinely missing, which is what grounds `resumeMode` at `.repair` through the same
    /// missing-files branch; the mode is resolved BEFORE the read bit is cleared, so the drop
    /// isolates the enumeration and nothing else.
    @Test
    func testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust() async throws {
        let unlisted = SessionGallery(
            gid: "210391",
            title: "Unlistable",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [unlisted],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
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
        let manager = fixture.manager
        try writePageFiles(for: unlisted, in: fixture, indices: [1, 2, 4, 5, 6])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: unlisted.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        try await manager.retryPages(gid: unlisted.gid, pageIndices: [3]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

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
        #expect(await manager.fetchDownload(gid: unlisted.gid)?.completedPageCount == 6)
        // The probe's non-answer stays a probe, so the seed can supply nothing and the run re-fetches
        // everything — six pages of real work behind a record that says it has none.
        #expect(seed.existingPages.isEmpty)
        #expect(spy.progressUpdates.map(\.subtitle).contains("6 / 6 pages · 1 gallery"))
        #expect(spy.rejectedProgressUpdates.isEmpty)

        restorePermissions(at: folderURL, to: originalPermissions)
        try writePageFiles(for: unlisted, in: fixture, indices: [3])
        try await manager.flushManifestPageProgress(
            folderURL: folderURL,
            pages: pageResults(for: unlisted, in: fixture, indices: [3])
        )

        await manager.settleCompletedDownload(gid: unlisted.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
    }

    /// The binding between what `makeRetriedPagesPayload` feeds a payload and what the route
    /// actually stores — owned here rather than assumed by every case that uses the helper.
    ///
    /// `performRetryPages` writes the run's selection into the coordinator's `queuedPageSelections`
    /// entry for the gid, and `fetchNormalizeAndDownload` reads exactly that entry back as the raw
    /// selection it hands BOTH payload steps. The helper reproduces the route's transform instead
    /// of copying a literal, so a later change to how `retryPages` normalizes a caller's indices
    /// fails this case rather than silently un-faithing every double in the family again. The two
    /// sides are deliberately different types — the coordinator entry is `[Int]`, the payload's
    /// selection is `Set<Int>?` — so the comparison bridges them explicitly.
    ///
    /// **The production event that holds the entry in place while the assertion runs** is
    /// `processScheduledDownload`'s `.skippedOperation` arm: it releases active ownership through
    /// `finishActiveTaskIfOwned`, which touches no queue intent at all, so a schedule that runs no
    /// operation leaves the selection standing for the run that follows — which is precisely why
    /// the run can still read it. Nothing else in this staging can clear it: every production clear
    /// of `queuedPageSelections` runs from a settle, a failure persistence, a pause, a resume, a
    /// queued-item cancel or a folder deletion, and this case drives none of them.
    @Test
    func testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores() async throws {
        let selective = SessionGallery(
            gid: "210392",
            title: "Selective",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [selective],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // Two pages genuinely missing, which is what grounds `resumeMode` at `.repair` through the
        // missing-files branch — `retryPages` delegates an `.update` record to `retry`, which
        // stores no selection at all.
        try writePageFiles(for: selective, in: fixture, indices: [1, 3, 5, 6])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: selective.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        // Unordered and duplicated on purpose: what the route stores is its own transform of these
        // indices, never the literal a case typed.
        let requestedPageIndices = [4, 2, 2]
        try await manager.retryPages(gid: selective.gid, pageIndices: requestedPageIndices).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        let stored = try #require(await manager.queuedPageSelections[selective.gid])
        #expect(stored == [2, 4])

        let payload = await makeRetriedPagesPayload(
            for: selective,
            mode: .repair,
            retriedPageIndices: requestedPageIndices,
            coordinator: manager
        )
        #expect(payload.pageSelection == Set(stored))
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionLedgerTests {
    /// The results a production flush is handed for pages `writePageFiles` has just landed.
    ///
    /// File-private rather than promoted beside `writePageFiles`: both consumers are in this file,
    /// and the shared helper surface earns a member when a second suite needs it. The relative
    /// paths come from the same production API the writer used, so a naming change moves both
    /// together rather than leaving a flush pointed at a file that is not there.
    func pageResults(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        indices: [Int]
    ) -> [DownloadCoordinator.PageResult] {
        indices.map { index in
            DownloadCoordinator.PageResult(
                index: index,
                relativePath: fixture.storage.makePageRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    index: index,
                    fileExtension: "jpg"
                ),
                imageURL: nil
            )
        }
    }
}
