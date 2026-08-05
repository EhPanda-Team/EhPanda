import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The session's counted basis and the monotonic floor above it: what the card reports when the
/// coordinator itself CORRECTS that basis (D-G6-01) or SCOPES the read that computes it (WR-01).
///
/// The sibling ledger suite owns what the card reports as galleries join and leave. This one owns
/// the two ways the basis can move without a gallery moving: D-G5-01's reconciliation lowering an
/// already-counted record mid-run, and the schedulable-work authority reading a gid set that omits
/// the gallery it is running. Both produce the same observable — a numerator that stops advancing
/// while real work proceeds — which is the maximally stalled reading D-11's expiration policy
/// punishes by pausing every schedulable download.
///
/// A new file rather than more cases in `DownloadContinuedSessionLedgerTests.swift` for the reason
/// that file's own header gives for existing: it sits against a `file_length` limit of 1000 at
/// error severity. The shared pushed-pair vocabulary lives in `DownloadFeatureTestHelpers.swift` so
/// both suites assert with one set of helpers.
///
/// **Choreography discipline.** Record state comes only from fixture manifests, `writePageFiles`,
/// the production announcing preparation, and production flushes — never from the ledger suite's
/// manual index-patch seam, which stays private to that file deliberately. Departures are the
/// product's own `pause`. The correction's push is the announcing wrapper's own. The only
/// test-issued pushes are macro-cadence ones between settled steps, which is this suite family's
/// documented idiom for asserting arithmetic rather than scheduling timing.
@Suite
struct DownloadContinuedSessionBasisTests: DownloadFeatureTestCase {
    /// D-G6-01, at the one shape a serial queue can actually fail in: a counted gallery is
    /// corrected, departs WITHOUT re-earning the blanked pages, and the survivor's next pushes
    /// must still advance.
    ///
    /// Blanking K pages of one gallery in a two-gallery queue is vacuous on its own. The queue is
    /// serial — `scheduleNextIfNeededCore` returns early on `guard activeTask == nil` — so nothing
    /// else downloads during the repair, and a repair that restores all K pages ends where it
    /// started: the card is frozen for the same span it was frozen for before D-G5-01 landed. The
    /// reachable REGRESSION is the case where the blanked pages are never re-earned by the gallery
    /// that lost them. Here the correction is followed by a pause part-way: the ledger retires the
    /// reconciled gallery at its HONEST lowered count while the floor still holds the pre-blanking
    /// total, so every page the surviving gallery downloads is invisible until the queue climbs
    /// back over that floor — a band exactly K pushes wide.
    ///
    /// The one-time dip at step three is the fix, not a defect: the correction is real, the card
    /// says so once, and then it climbs. The frozen alternative is what the scheduler reads as a
    /// task losing ground before it force-expires the least-progressing ones.
    @Test
    func testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes() async throws {
        let corrected = SessionGallery(
            gid: "210330",
            title: "Corrected",
            pageCount: 6,
            completedPageCount: 4
        )
        let survivor = SessionGallery(
            gid: "210331",
            title: "Surviving",
            pageCount: 8,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [corrected, survivor],
            client: spy.client,
            // The pause converges on scheduling, which would otherwise start the surviving
            // gallery's download for real. Skipping the operation keeps the convergence and drops
            // the network, exactly as the ledger suite's departure cases do.
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // Pages 3 and 4 are claimed by the fixture manifest and their files are absent: K = 2.
        try writePageFiles(for: corrected, in: fixture, indices: [1, 2])
        await manager.reloadDownloadIndex()

        // Grounded in the production route rather than asserted about it: a record with vanished
        // files resolves `.repair`, and it is counted RAW from session start because it already
        // reads incomplete (D-G4-01's first half).
        let staged = try #require(await manager.fetchDownload(gid: corrected.gid))
        #expect(staged.completedPageCount == 4)
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "7 / 14 pages · 2 galleries")

        let correctedFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(corrected.gid)_token] \(corrected.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: corrected),
            existingDownload: staged,
            folderURL: correctedFolderURL
        )

        #expect(await manager.fetchDownload(gid: corrected.gid)?.completedPageCount == 2)
        // The announcement's own push, and the only push recorded so far: no test-issued push
        // exists before it, so the honest lowered pair is a fact about the production sequence.
        #expect(spy.progressUpdates.count == 1)
        let correctionPair = try lastPushedPair(spy.progressUpdates)
        #expect(correctionPair.completedUnitCount == 5)
        #expect(correctionPair.totalUnitCount == 14)
        #expect(correctionPair.subtitle == "5 / 14 pages · 2 galleries")

        try await manager.pause(gid: corrected.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        // Asserted on the last update rather than against a list of a known length, for the reason
        // the ledger suite's pause case states: how many pushes a convergence lands belongs to the
        // convergence path, and every push after the departure owes the same pair.
        let departedPair = try lastPushedPair(spy.progressUpdates)
        #expect(departedPair.completedUnitCount == 5)
        #expect(departedPair.totalUnitCount == 10)
        #expect(departedPair.subtitle == "5 / 10 pages · 1 gallery")

        let survivorFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(survivor.gid)_token] \(survivor.title)"
        )
        let sessionID = try #require(await manager.testingContinuedSessionID())

        let pageFour = try landPageFiles([4], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: survivorFolderURL, pages: pageFour)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstSurvivorPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstSurvivorPair.subtitle == "6 / 10 pages · 1 gallery")

        let pageFive = try landPageFiles([5], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: survivorFolderURL, pages: pageFive)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let secondSurvivorPair = try lastPushedPair(spy.progressUpdates)
        #expect(secondSurvivorPair.subtitle == "7 / 10 pages · 1 gallery")

        let remainingPages = try landPageFiles([6, 7, 8], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(
            folderURL: survivorFolderURL,
            pages: remainingPages
        )
        await manager.settleCompletedDownload(gid: survivor.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 10)
        #expect(terminalPair.totalUnitCount == 10)
        #expect(terminalPair.subtitle == "10 / 10 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        // The dip sits between the START pair and the first push, never between two pushes, so the
        // series property the scheduler reads is intact across the whole correction.
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
    }

    /// The floor's second absorber, made deterministic: a withdrawal landing inside the client
    /// start's main-actor hop must survive the seeding that follows it.
    ///
    /// On the canonical `retryPages` route the run is scheduled BEFORE the trailing
    /// `ensureContinuedSession`, so a correction can land precisely inside that hop — where the
    /// floor was just reset to zero. The seed then folded the pre-hop snapshot in, and while it
    /// ASSIGNED that snapshot it re-installed a total that still counted the blanked pages: the
    /// same overwrite class 15-25 closed for the two trust collections, reappearing on the scalar
    /// the moment the scalar gained a hop-window writer.
    ///
    /// The START pair is legitimately unchanged by the correction. The card's opening is the
    /// snapshot taken at start time by design; what the merge corrects is the FLOOR, and the very
    /// next push is where the difference becomes visible. The gate makes the ordering a fact rather
    /// than a race: the start parks inside the spy, the production preparation runs against a
    /// coordinator whose session id is already stamped, and the start is released only afterwards.
    @Test
    func testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed() async throws {
        let seeded = SessionGallery(
            gid: "210340",
            title: "Seeded",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [seeded],
            queuedGIDs: [seeded.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: seeded, in: fixture, indices: [1, 2])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: seeded.gid))
        #expect(staged.completedPageCount == 4)
        #expect(await manager.resumeMode(for: staged) == .repair)

        let gate = spy.armStartGate()
        defer { gate.release() }
        let sessionStart = Task { await manager.testingEnsureContinuedSession() }
        await gate.entered()

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(seeded.gid)_token] \(seeded.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: seeded),
            existingDownload: staged,
            folderURL: folderURL
        )

        #expect(await manager.fetchDownload(gid: seeded.gid)?.completedPageCount == 2)
        // The announcement's push records its reconcile and then skips the card at the nil-client
        // guard, so the held-open hop paints nothing and the withdrawal drove the freshly reset
        // floor to −2 — a value that exists only as coordinator state.
        #expect(spy.progressUpdates.isEmpty)

        gate.release()
        await sessionStart.value

        // The pre-hop pair, unchanged by design: the opening is the snapshot at start time.
        #expect(spy.startSubtitles == ["4 / 6 pages · 1 gallery"])

        let sessionID = try #require(await manager.testingContinuedSessionID())
        let pageThree = try landPageFiles([3], of: seeded, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageThree)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        // The discriminator: with the seed merged the floor is 2, so the honest 3 shows.
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "3 / 6 pages · 1 gallery")

        let pageFour = try landPageFiles([4], of: seeded, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageFour)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        // The honest value meets the stale floor here, so this pair reads the same either way.
        let secondPair = try lastPushedPair(spy.progressUpdates)
        #expect(secondPair.subtitle == "4 / 6 pages · 1 gallery")

        let remainingPages = try landPageFiles([5, 6], of: seeded, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: remainingPages)
        await manager.settleCompletedDownload(gid: seeded.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
    }

    /// WR-01: the gallery that is actually downloading must stay in the card's numerator, its
    /// denominator and its gallery count even when the persisted queue no longer lists it.
    ///
    /// `schedulableDownloads()` is the one authority for selecting work the scheduler can run, but
    /// it scoped its index read by queue-store membership alone, while `isSchedulableDownload`
    /// accepts `displayStatus == .active` — the running gallery — independently of that membership.
    /// The predicate and the read therefore disagreed exactly when the running gallery was absent
    /// from a NON-EMPTY persisted queue, which is a state three production routes reach:
    /// `nextUnqueuedSchedulableDownload` exists precisely to run a gallery the queue has not caught
    /// up with, and both `handleProcessDownloadIncompleteError` and `settleDownloadFailure` remove
    /// the active gid from the queue store while `activeGalleryID` is still set and the deferred
    /// task teardown has not run.
    ///
    /// Two consequences, both in the false-stall family this plan closes. The running gallery's
    /// real progress leaves the pushed pair and it is then detected as departed and retired at a
    /// frozen value while it is still downloading; and `pauseAllSchedulable(expiring:)` selects
    /// through this same call, so an expiration would skip pausing the one gallery actually
    /// consuming resources — the SC2 cancel half.
    @Test
    func testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt() async throws {
        let running = SessionGallery(
            gid: "210350",
            title: "Running",
            pageCount: 10,
            completedPageCount: 6
        )
        let queued = SessionGallery(gid: "210351", title: "Queued", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [running, queued],
            queuedGIDs: [running.gid, queued.gid],
            client: spy.client,
            // Parked rather than skipped: this case needs a genuinely installed active task, so the
            // coordinator's `activeGalleryID` is set while the assertions run.
            taskRunner: DownloadTaskRunner(
                runScheduledDownload: { _, _ in
                    await withTaskCancellationHandler {
                        await control.park()
                    } onCancel: {
                        control.recordCancellation()
                        control.release()
                    }
                    return .skippedOperation
                }
            )
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager

        await manager.scheduleNextIfNeeded()
        await control.started()

        // The lag state: the running gallery leaves the persisted queue while it downloads.
        await manager.testingSetQueuedGalleryIDs([queued.gid])

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "6 / 14 pages · 2 galleries")

        control.release()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
    }

    /// D-G7-01 on the route that STARTS the session: a `.redownload` of a counted errored record
    /// drops its basis to zero, and the card must dip once and then advance with the work.
    ///
    /// The staging is the one the prior rounds never performed. `DetailView` sends
    /// `.retryDownloadButtonTapped(store.downloadNeedsRepair ? .repair : .redownload)`, and
    /// `DetailReducer.downloadNeedsRepair` requires `badge.progress.completedPageCount == 0`, so an
    /// errored gallery with ANY downloaded page fails that guard and the button resolves
    /// `.redownload`. A record with 0 < C < N satisfies `isIncomplete`, so D-G4-01's first half
    /// counts it RAW and the floor opens at C. The two existing `.redownload` cases in the ledger
    /// suite stage a 6-of-6 record instead: complete, therefore untrusted, therefore contributing
    /// zero to the floor, so their wipe moves a basis that was already zero. That vacuity is why a
    /// green suite was never evidence about this freeze.
    ///
    /// Nothing here is a blanking. `shouldReuseWorkingFolder` returns false for `.redownload`,
    /// `setupWorkingFolder` deletes the folder, `repairSeed` declines a non-`.repair` payload, and
    /// `ensureWorkingManifest` writes a fresh all-empty manifest and re-indexes it. The
    /// reconciliation is then handed that all-empty manifest, blanks nothing, and returns at its
    /// `blankedPageCount == 0` guard — which is exactly why a withdrawal attached to the blanking
    /// loop never fires on this route.
    @Test
    func testARedownloadOfACountedGalleryWithdrawsItsBasisSoTheNextPushAdvances() async throws {
        let errored = SessionGallery(
            gid: "210360",
            title: "Errored",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [errored],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: errored, in: fixture, indices: [1, 2, 3, 4])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: errored.gid))
        #expect(staged.completedPageCount == 4)
        #expect(staged.isIncomplete)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(errored.gid)_token] \(errored.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeStartPayload(for: errored, mode: .redownload),
            existingDownload: staged,
            folderURL: folderURL
        )

        #expect(await manager.fetchDownload(gid: errored.gid)?.completedPageCount == 0)
        // The announcement's own push, and the only push recorded so far: no test-issued push
        // exists before it, so the honest dip is a fact about the production sequence.
        #expect(spy.progressUpdates.count == 1)
        let dipPair = try lastPushedPair(spy.progressUpdates)
        #expect(dipPair.completedUnitCount == 0)
        #expect(dipPair.totalUnitCount == 6)
        #expect(dipPair.subtitle == "0 / 6 pages · 1 gallery")

        let sessionID = try #require(await manager.testingContinuedSessionID())
        let pageOne = try landPageFiles([1], of: errored, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageOne)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "1 / 6 pages · 1 gallery")

        let pageTwo = try landPageFiles([2], of: errored, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageTwo)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let secondPair = try lastPushedPair(spy.progressUpdates)
        #expect(secondPair.subtitle == "2 / 6 pages · 1 gallery")

        let remainingPages = try landPageFiles([3, 4, 5, 6], of: errored, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: remainingPages)
        await manager.settleCompletedDownload(gid: errored.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        // The dip sits between the START pair and the first push, never between two pushes, so the
        // series property the scheduler reads is intact across the whole movement.
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
    }

    /// The same movement on the `.update` arm, over a gallery this session has already trusted.
    ///
    /// `shouldReuseWorkingFolder` returns false for `.update` exactly as it does for `.redownload`,
    /// so the mover is the same one. What this case adds is the second disjunct of the
    /// counted-basis predicate: `observedIncompleteSessionGIDs` admits this gid through
    /// `ensureContinuedSession`'s start-snapshot `formUnion` and again through the retirement
    /// reconcile inside the pre-wipe push, both production admissions rather than asserted state.
    /// At bracket time both disjuncts therefore hold — the record still reads incomplete AND the
    /// session has watched it — which is the shape a trusted gallery presents.
    ///
    /// The pre-wipe push also moves the floor by the push's own re-latch rather than by the start
    /// seed alone, so the withdrawal is measured against a latched floor here. Its cost is that the
    /// honest dip lands between two pushes instead of between the start pair and the first push, so
    /// this case deliberately does not assert the never-rewinds series property; the sibling
    /// `.redownload` case above covers that ordering, and the visible one-time dip is D-G6-01's
    /// recorded and accepted consequence.
    @Test
    func testAnUpdateOfATrustedGalleryWithdrawsItsCountedPortion() async throws {
        let trusted = SessionGallery(
            gid: "210361",
            title: "Trusted",
            pageCount: 5,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [trusted],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: trusted, in: fixture, indices: [1, 2, 3])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: trusted.gid))
        #expect(staged.completedPageCount == 3)
        #expect(staged.isIncomplete)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "3 / 5 pages · 1 gallery")

        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let trustedPair = try lastPushedPair(spy.progressUpdates)
        #expect(trustedPair.subtitle == "3 / 5 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(trusted.gid)_token] \(trusted.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeStartPayload(for: trusted, mode: .update),
            existingDownload: staged,
            folderURL: folderURL
        )

        #expect(await manager.fetchDownload(gid: trusted.gid)?.completedPageCount == 0)
        let dipPair = try lastPushedPair(spy.progressUpdates)
        #expect(dipPair.completedUnitCount == 0)
        #expect(dipPair.totalUnitCount == 5)
        #expect(dipPair.subtitle == "0 / 5 pages · 1 gallery")

        let pageOne = try landPageFiles([1], of: trusted, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageOne)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "1 / 5 pages · 1 gallery")

        let remainingPages = try landPageFiles([2, 3, 4, 5], of: trusted, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: remainingPages)
        await manager.settleCompletedDownload(gid: trusted.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 5)
        #expect(terminalPair.totalUnitCount == 5)
        #expect(terminalPair.subtitle == "5 / 5 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The same basis movement with NO deletion and NO blanking anywhere near it: a `.repair` whose
    /// payload reports a different upstream page count.
    ///
    /// `shouldReuseWorkingFolder` returns true unconditionally for `.repair`, so the working folder
    /// and every page file in it survive this run. `ensureWorkingManifest` replaces the record all
    /// the same, because `validatedManifest` requires `manifest.pageCount ==
    /// payload.galleryDetail.pageCount` and returns nil on the mismatch — the state a gallery
    /// reaches when pages are added upstream, or when a crash truncates the stored manifest. A fresh
    /// all-empty manifest at the new page count is written and re-indexed, so the record falls from
    /// 4 of 6 to 0 of 8 with nothing deleted and nothing blanked.
    ///
    /// This is the case that falsifies any mechanism-keyed fix: there is no folder wipe to key on
    /// and no blanking loop to key on, only the index-record delta.
    @Test
    func testAPageCountMismatchFreshManifestWithdrawsTheCountedBasis() async throws {
        let regrown = SessionGallery(
            gid: "210362",
            title: "Regrown",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [regrown],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: regrown, in: fixture, indices: [1, 2, 3, 4])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: regrown.gid))
        #expect(staged.completedPageCount == 4)
        #expect(staged.isIncomplete)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "4 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(regrown.gid)_token] \(regrown.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeStartPayload(for: regrown, mode: .repair, pageCountOverride: 8),
            existingDownload: staged,
            folderURL: folderURL
        )

        let wiped = try #require(await manager.fetchDownload(gid: regrown.gid))
        #expect(wiped.completedPageCount == 0)
        #expect(wiped.pageCount == 8)
        #expect(spy.progressUpdates.count == 1)
        let dipPair = try lastPushedPair(spy.progressUpdates)
        #expect(dipPair.completedUnitCount == 0)
        #expect(dipPair.totalUnitCount == 8)
        #expect(dipPair.subtitle == "0 / 8 pages · 1 gallery")

        let sessionID = try #require(await manager.testingContinuedSessionID())
        let pageOne = try landPageFiles([1], of: regrown, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageOne)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "1 / 8 pages · 1 gallery")

        let remainingPages = try landPageFiles([2, 3, 4, 5, 6, 7, 8], of: regrown, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: remainingPages)
        await manager.settleCompletedDownload(gid: regrown.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 8)
        #expect(terminalPair.totalUnitCount == 8)
        #expect(terminalPair.subtitle == "8 / 8 pages · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
    }

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
            restoreFolderPermissions(at: folderURL, to: originalPermissions)
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
        restoreFolderPermissions(at: folderURL, to: originalPermissions)
        let onDiskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(onDiskManifest.pages == manifest(for: unlisted).pages)
        #expect(onDiskManifest.completedPageCount == 4)
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionBasisTests {
    /// Lands page files the way a run does — the real bytes first — and returns the payload the
    /// production flush records them with.
    ///
    /// The two halves are deliberately not fused: every case keeps `flushManifestPageProgress` in
    /// its own body, because which writes are production-issued is the property this suite family
    /// exists to keep honest.
    func landPageFiles(
        _ indices: [Int],
        of gallery: SessionGallery,
        in fixture: SessionFixture
    ) throws -> [DownloadCoordinator.PageResult] {
        try writePageFiles(for: gallery, in: fixture, indices: indices)
        return indices.map { index in
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

    /// Puts a folder staged execute-only back to its original mode, so the fixture tree can be
    /// enumerated and removed.
    ///
    /// Idempotent on purpose: the wholesale-failure case restores once to re-read the manifest and
    /// once more in its `defer`. A failure here strands the temporary tree rather than affecting the
    /// assertions, so it is recorded as an issue instead of thrown from a deferred block.
    func restoreFolderPermissions(at folderURL: URL, to permissions: NSNumber) {
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: permissions],
                ofItemAtPath: folderURL.path
            )
        } catch {
            Issue.record("Restoring the fixture folder's permissions failed: \(error)")
        }
    }
}
