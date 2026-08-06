import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The ledger half of the reconciliation's REFUSAL family: what the card reports for the run that
/// FOLLOWS a refusal, rather than what the refusal itself does to the manifest.
///
/// An `extension` of the ledger suite rather than a suite of its own, so every case here keeps
/// that suite's membership, its traits and its test identity — the 15-41 relocation pattern applied
/// to additions. A new file because `DownloadContinuedSessionLedgerTests.swift` sits at 812 lines
/// against a `file_length` limit of 1000 at error severity, and stagings of this size would crowd
/// it. The file has since taken the route-binding pin (G-15-28) and the selected-page-retry
/// regression (G-15-27) on the same terms.
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
    /// 6-of-6 and `isIncomplete` stays false — so every SNAPSHOT-sourced writer of the session's
    /// trust set is closed to this gallery at once, both of them being `formUnion`s over
    /// `snapshot.incompleteGalleryIDs`, which by construction cannot contain a complete-reading
    /// record. The remaining writers all trace back to the run's own proof of page work: the insert
    /// at the preparation when a session is live, and the seed each session start takes from
    /// `provenPageWorkRunGIDs` (G-15-26). Without that proof the gallery contributes zero to the
    /// numerator for the entire six-page re-download and retires zero when it leaves.
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
    ///
    /// **The payload is production-shaped (G-15-28).** The `retryPages` call below stores this
    /// case's six indices in the coordinator's `queuedPageSelections` entry, and a production run
    /// reads that entry back into BOTH payload steps, so the payload handed to the preparation
    /// carries the selection its own route stored. Nothing asserted here moves as a result, and the
    /// reason survived G-15-27's closure: the gate now reads the run's own pending page list, which
    /// honors that selection — and this case's selection is all six pages, none of whose files are
    /// present, so the list is the full six either way. The faithful payload was the precondition
    /// that let the regression closing G-15-27 discriminate; it is not itself the fix.
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
        // The indices are this case's own `retryPages` set, so the payload carries what the route
        // stored rather than a selection typed independently of it.
        let payload = await makeRetriedPagesPayload(
            for: vanished,
            mode: .repair,
            retriedPageIndices: [1, 2, 3, 4, 5, 6],
            coordinator: manager
        )
        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: staged,
            folderURL: folderURL
        ).workingSeed

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
    /// whole run exactly as in the residual case above, so the run's own proof at the announcement is
    /// the only thing that can admit the gallery to the session's trust set — directly here, where a
    /// session is already live, and through the session-start seed otherwise (G-15-26). Staging both
    /// exits is what makes this a
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
    ///
    /// **The payload is production-shaped (G-15-28)**, on the same terms as the residual case
    /// above: the single index this case retries is what its route stored, so the payload the
    /// preparation receives carries it. Every assertion below is unmoved by G-15-27's closure too,
    /// and for a reason this staging supplies rather than inherits: the gate now reads the run's
    /// own pending list, and page 3 — the retried one — is the page whose file this case leaves
    /// absent, so that list is non-empty and the announcement fires exactly as before.
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

        // The index is this case's own `retryPages` set, so the payload carries what the route
        // stored rather than a selection typed independently of it.
        let payload = await makeRetriedPagesPayload(
            for: unlisted,
            mode: .repair,
            retriedPageIndices: [3],
            coordinator: manager
        )
        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: staged,
            folderURL: folderURL
        ).workingSeed

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

    /// G-15-27: a selected-page retry whose selected page is already present fetches NOTHING, and
    /// must therefore earn nothing.
    ///
    /// **The two page sets the announcement can be gated on, and why they differ.** The gate this
    /// case discriminates against compares the working folder's own shortfall — the seed's
    /// `existingPages` against the working manifest's page count — while the run's page loop is fed
    /// by `pendingPageIndices`, which reads `payload.pageSelection` FIRST and drops every page
    /// outside it before it ever asks whether a file is there. Whenever a selection is live those
    /// are different sets: the folder can be short of its manifest on pages this run was never
    /// asked to fetch. Here the folder is short by page 6 while the run is asked only for page 3,
    /// whose file is present — so the shortfall is one page and the run's pending work is empty.
    ///
    /// **The production route that reaches a present-file retry.** `performCacheCapture` restores a
    /// page from the image cache into the working folder, refreshes exactly that page's manifest
    /// hash and re-indexes, then clears only the gallery-level last error through
    /// `sanitizeLocalFilesIfNeeded(gid:clearingLastError:)`. The PER-PAGE record the inspector
    /// lists — `failedPageErrors[gid]`, read by `loadInspection` — is untouched by that route and
    /// is cleared only by `clearSelectedFailedPages` inside `retryPages` itself. So a page can
    /// still be offered to the user as failed while its file is already on disk, and tapping retry
    /// on it stores exactly that selection.
    ///
    /// **The discrimination, stated.** Against pre-fix source the gate reads the shortfall, which
    /// is non-zero, so the preparation announces and admits the gallery to the session's trust set;
    /// the reconciliation has just blanked the one genuinely absent page, so that announcement
    /// pushes a numerator of FIVE — five pages this run will not fetch, credited to it. After the
    /// fix the gate reads the run's own pending list, which is empty, so no push is issued at all
    /// and every recorded update still reads the queued window's zero.
    ///
    /// **Choreography.** Every push asserted over is production-issued: `retryPages`' own session
    /// ensure and its convergence pushes, and the preparation's announcement. This case issues
    /// none. It reaches the preparation through the testing forwarder, as both siblings do, and
    /// that is not a shortcut around production here — the injected task runner answers
    /// `.skippedOperation` without ever invoking the scheduled operation, so `performDownload` and
    /// with it the preparation are unreachable from the fixture's own scheduling. The forwarder is
    /// the only way in, and the payload it is handed is the one the route stored.
    @Test
    func testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero() async throws {
        let selective = SessionGallery(
            gid: "210393",
            title: "Selected",
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
        // Five of six page files. Page 6 is the absent one, so the folder is one page short of its
        // manifest; page 3 — the page this case retries — is present. No permissions are touched:
        // the mechanism under test is the SELECTION, and a second refusal mechanism would leave the
        // RED reading ambiguous about which gate fired.
        try writePageFiles(for: selective, in: fixture, indices: [1, 2, 3, 4, 5])
        await manager.reloadDownloadIndex()

        // Grounded in the production route rather than asserted about it: a complete-reading record
        // with a missing file reaches `.repair`, which is the mode `retryPages` stores a selection
        // for — an `.update` record is delegated to `retry`, which stores none.
        let staged = try #require(await manager.fetchDownload(gid: selective.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        try await manager.retryPages(gid: selective.gid, pageIndices: [3]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(selective.gid)_token] \(selective.title)"
        )
        // The index is this case's own `retryPages` set, so the payload carries what the route
        // stored rather than a selection typed independently of it.
        let payload = await makeRetriedPagesPayload(
            for: selective,
            mode: .repair,
            retriedPageIndices: [3],
            coordinator: manager
        )
        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: staged,
            folderURL: folderURL
        ).workingSeed

        // Non-vacuity FIRST, or the case could pass on a staging that never reached the gate: five
        // existing pages against a six-page working manifest is exactly the reading the pre-fix
        // gate fires on, and page 3's presence is what empties the run's own pending list.
        #expect(seed.existingPages.count == 5)
        #expect(seed.manifest.pageCount == 6)
        #expect(seed.existingPages[3] != nil)
        // The reconciliation blanked page 6, which is untouched by this plan and is why the pre-fix
        // crediting push carries five rather than the record's original six.
        #expect(await manager.fetchDownload(gid: selective.gid)?.completedPageCount == 5)

        // The outcome, by ABSENCE: production issued no push crediting this gallery's pages. It is
        // the only gallery in the session, so the numerator IS its contribution. The empty rejected
        // list is asserted alongside so an identity refusal cannot be mistaken for that absence.
        #expect(spy.progressUpdates.allSatisfy({ $0.completedUnitCount == 0 }))
        #expect(spy.progressUpdates.allSatisfy({ $0.subtitle == "0 / 6 pages · 1 gallery" }))
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// G-15-30's consequence 3, and the harm that makes it a blocker rather than a display nitpick:
    /// a refusal repair PAUSED after K of N pages must terminate at the work it actually did.
    ///
    /// The departure is the session's LAST gallery, so `reconcileContinuedSession` takes its drain
    /// branch: it pushes one terminal pair and then calls `finish(clientSessionID, true)`. An
    /// over-retirement there does not merely misreport a fraction — it reports a PAUSED repair to
    /// the user as a fully successful N-page completion, which is the outcome
    /// `reconcileRetiredSessionPages`' own doc forbids in its own words ("over-retiring is the
    /// defect").
    ///
    /// **Which of the two retirement orderings this staging exercises: the DEPARTURE-FIRST one.**
    /// No run is driven to an exit here — the preparation is reached through the testing forwarder,
    /// as every sibling case reaches it, and the injected runner answers `.skippedOperation` — so
    /// the run's own retirement never happens and the pause finds the run's outstanding page debt
    /// still recorded. The opposite ordering, where the run's own exit retires first and the
    /// departure follows, is covered by
    /// `testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued` in the run-proof file,
    /// which drives a real `processDownload` to a real exit ahead of its departure.
    ///
    /// **Non-vacuity is asserted before the outcome.** The refusal really refused (the record still
    /// reads six), the run really did owe all six pages, and two of them really landed through the
    /// production flush — so a terminal six can only be the record's ceiling rather than the work
    /// done.
    ///
    /// **Choreography.** Every push, start and departure is production-issued: `retryPages`' own
    /// session ensure, the preparation's announcement, `flushDownloadProgress` — the production
    /// flush the page loop itself calls — and `pause(gid:)`, whose `commitPause` removes the gallery
    /// from the queue store and converges through `scheduleNextIfNeeded`. This case issues no push,
    /// no start and no retirement of its own.
    @Test
    func testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid() async throws {
        let halted = SessionGallery(
            gid: "210394",
            title: "Halted",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [halted],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // No page file at all, so the residual exit refuses and the record reads complete
        // throughout — the family whose ceiling and whose remaining work are the same number.
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: halted.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        try await manager.retryPages(gid: halted.gid, pageIndices: [1, 2, 3, 4, 5, 6]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(halted.gid)_token] \(halted.title)"
        )
        let payload = await makeRetriedPagesPayload(
            for: halted,
            mode: .repair,
            retriedPageIndices: [1, 2, 3, 4, 5, 6],
            coordinator: manager
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: staged,
            folderURL: folderURL
        )

        // Non-vacuity: the refusal refused, and the run owes every one of the six pages.
        #expect(await manager.fetchDownload(gid: halted.gid)?.completedPageCount == 6)
        #expect(preparedRun.workingSeed.existingPages.isEmpty)
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])

        // K of N: two pages land through the production flush the page loop itself calls.
        try writePageFiles(for: halted, in: fixture, indices: [1, 2])
        var pendingResolvedPages = pageResults(for: halted, in: fixture, indices: [1, 2])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: halted.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        // The record cannot say the run made progress: it claimed all six pages before any landed.
        #expect(await manager.fetchDownload(gid: halted.gid)?.completedPageCount == 6)

        // The departure, through the product's own pause.
        try await manager.pause(gid: halted.gid).get()
        try await waitUntil {
            await manager.testingHasContinuedSession() == false
        }

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 2)
        #expect(terminalPair.totalUnitCount == 2)
        #expect(terminalPair.subtitle == "2 / 2 pages · 0 galleries")
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
