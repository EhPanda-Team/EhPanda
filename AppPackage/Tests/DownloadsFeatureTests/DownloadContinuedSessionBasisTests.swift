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
/// What stays here is the basis MOVING. What a probe's answer, non-answer or honest absence
/// licenses the reconciliation to blank in the first place lives in
/// `DownloadContinuedSessionReconciliationTests.swift`, an `extension` of this same type, so those
/// cases keep their suite membership, traits and identity. They moved out when this file reached
/// 996 lines against the very limit the paragraph below gives as its own reason for existing.
///
/// A new file rather than more cases in `DownloadContinuedSessionLedgerTests.swift` for the reason
/// that file's own header gives for existing: it sits against a `file_length` limit of 1000 at
/// error severity. The shared pushed-pair vocabulary lives in `DownloadFeatureTestHelpers.swift` so
/// all three files assert with one set of helpers.
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
        // Still two galleries: the pause retired the corrected gallery at its honest lowered count
        // of two, and those two pages stay in the denominator, so D-G2C-01 goes on naming it beside
        // the survivor. The count therefore holds at two for the rest of the case — through both
        // survivor pushes and the drain — while only the fraction moves.
        #expect(departedPair.subtitle == "5 / 10 pages · 2 galleries")

        let survivorFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(survivor.gid)_token] \(survivor.title)"
        )
        let sessionID = try #require(await manager.testingContinuedSessionID())

        let pageFour = try landPageFiles([4], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: survivorFolderURL, pages: pageFour)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstSurvivorPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstSurvivorPair.subtitle == "6 / 10 pages · 2 galleries")

        let pageFive = try landPageFiles([5], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: survivorFolderURL, pages: pageFive)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let secondSurvivorPair = try lastPushedPair(spy.progressUpdates)
        #expect(secondSurvivorPair.subtitle == "7 / 10 pages · 2 galleries")

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
        #expect(terminalPair.subtitle == "10 / 10 pages · 2 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        // The dip sits between the START pair and the first push, never between two pushes, so the
        // series property the scheduler reads is intact across the whole correction.
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
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
        #expect(terminalPair.subtitle == "6 / 6 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
    }

    /// WR-01: the gallery that is actually downloading must stay in the card's numerator, its
    /// denominator and its gallery count even when the persisted queue no longer lists it.
    ///
    /// `schedulableDownloads()` is the read three consumers share — the pending-work gate
    /// `hasPendingWork()`, this card's own `schedulableSnapshot()`, and the expiration sweep
    /// `pauseAllSchedulable(expiring:)`. **The scheduler is not among them (G-15-24).**
    /// `scheduleNextIfNeededCore` reads `queueStore.gids` and then `indexedDownloads()` or
    /// `indexedDownloads(gids:)` for itself, reaching `isSchedulableDownload` through
    /// `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`. What the two share is the
    /// PREDICATE, not the read scope — which is why what this case asserts is the CARD's numerator
    /// rather than what the scheduler picks up next.
    ///
    /// The shared read scoped its index read by queue-store membership alone, while
    /// `isSchedulableDownload` accepts `displayStatus == .active` — the running gallery —
    /// independently of that membership. The predicate and the read therefore disagreed exactly when
    /// the running gallery was absent from a NON-EMPTY persisted queue, which is a state three
    /// production routes reach:
    /// `nextUnqueuedSchedulableDownload` exists precisely to run a gallery the queue has not caught
    /// up with, and both `handleProcessDownloadIncompleteError` and `settleDownloadFailure` remove
    /// the active gid from the queue store while `activeGalleryID` is still set and the deferred
    /// task teardown has not run.
    ///
    /// Two consequences, both in the false-stall family this plan closes. This case asserts the
    /// first: the running gallery's real progress leaves the pushed pair, and it is then detected
    /// as departed and retired at a frozen value while it is still downloading. The second —
    /// `pauseAllSchedulable(expiring:)` selects through this same call, so an expiration would skip
    /// pausing the one gallery actually consuming resources, the SC2 cancel half — is not narrated
    /// here any longer: the companion below stages the identical lag and drives that pause-all
    /// (WR-07).
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

    /// WR-07's companion: the SC2 cancel half of the lag regression, driven instead of narrated.
    ///
    /// The sibling above documents that `pauseAllSchedulable(expiring:)` selects through
    /// `schedulableDownloads()` and would therefore skip the one gallery actually consuming
    /// resources, then asserts only a subtitle. This case stages the identical lag and issues the
    /// expiration's own bulk pause, so the claim becomes the assertion: the RUNNING gallery the
    /// persisted queue forgot is among the paused set, alongside the sibling the queue still lists
    /// — D-11 pauses every schedulable download, and the 15-26 active-gallery union is what keeps
    /// the lagging runner inside that set.
    ///
    /// Production-issued throughout. The only pause-related call in the body is
    /// `testingPauseAllSchedulable(expiring:)`, the forwarder wrapping the production bulk pause;
    /// nothing between the lag step and the assertions touches either gallery's state by hand. The
    /// asserted shape is read off that pause path rather than invented: `writeInitialPauseRecord`
    /// cancels the active task, clears the gid's session state and drops it from the queue store,
    /// so `displayStatus(for:)` resolves an incomplete, unerrored, unqueued, non-active record to
    /// `.inactive`. That is also what discriminates the fix — without the union the runner is never
    /// selected, so it stays `activeGalleryID` and reads `.active` here.
    @Test
    func testAnExpirationPausesTheRunningGalleryWhenThePersistedQueueLagsBehindIt() async throws {
        let running = SessionGallery(
            gid: "210352",
            title: "Running",
            pageCount: 10,
            completedPageCount: 6
        )
        let queued = SessionGallery(gid: "210353", title: "Queued", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [running, queued],
            queuedGIDs: [running.gid, queued.gid],
            client: spy.client,
            // Parked rather than skipped, for the sibling's reason: the pause must have a genuinely
            // installed active task to cancel.
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
        #expect(await manager.testingActiveGalleryID() == running.gid)

        // The lag state, staged exactly as the sibling stages it: the running gallery leaves the
        // persisted queue while its task runs.
        await manager.testingSetQueuedGalleryIDs([queued.gid])

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles.last == "6 / 14 pages · 2 galleries")
        let sessionID = try #require(await manager.testingContinuedSessionID())

        await manager.testingPauseAllSchedulable(expiring: sessionID)

        // The bounded wait comes FIRST deliberately. A regression that drops the runner out of the
        // selected set leaves its task parked forever, and `cancellationObserved()` is an unbounded
        // rendezvous: reaching it before anything bounded would turn that regression into a hung
        // suite rather than a failure. `waitUntil` throws at its deadline, so the case ends there,
        // and once it has passed the handler has necessarily already recorded — the pause awaits
        // the cancelled task, whose `onCancel` runs before that await returns.
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        await control.cancellationObserved()
        #expect(await manager.testingActiveGalleryID() == nil)

        let pausedRunner = try #require(await manager.fetchDownload(gid: running.gid))
        #expect(pausedRunner.displayStatus == .inactive)
        #expect(pausedRunner.isIncomplete)
        // The set, not one member: the expiration pauses every schedulable download.
        let pausedSibling = try #require(await manager.fetchDownload(gid: queued.gid))
        #expect(pausedSibling.displayStatus == .inactive)
        #expect(pausedSibling.isIncomplete)
    }

    /// D-G7-01 on the route that STARTS the session: a `.redownload` of a counted errored record
    /// drops its basis to zero, and the card must dip once and then advance with the work.
    ///
    /// The staging is the one the prior rounds never performed. `DetailView` sends
    /// `.retryDownloadButtonTapped(store.downloadNeedsRepair ? .repair : .redownload)`, and under
    /// D-G5D-01 that predicate is a conjunction: an incomplete record AND a file-shaped failure
    /// code. So an errored gallery whose failure is networking-shaped — the ordinary interruption —
    /// resolves `.redownload` however many pages it has already landed, which is the route this
    /// case stages. A record with 0 < C < N satisfies `isIncomplete`, so D-G4-01's first half
    /// counts it RAW and the floor opens at C. The two existing `.redownload` cases in the ledger
    /// suite stage a 6-of-6 record instead: complete, therefore untrusted, therefore contributing
    /// zero to the floor, so their wipe moves a basis that was already zero. That vacuity is why a
    /// green suite was never evidence about this freeze.
    ///
    /// Nothing here is a blanking. `shouldReuseWorkingFolder` returns false for `.redownload`,
    /// `setupWorkingFolder` deletes the folder, and `ensureWorkingManifest` writes a fresh
    /// all-empty manifest and re-indexes it. The
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
        #expect(terminalPair.subtitle == "6 / 6 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        // The dip sits between the START pair and the first push, never between two pushes, so the
        // series property the scheduler reads is intact across the whole movement.
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
    }

    /// The same movement on the `.update` arm, over a gallery this session has already observed.
    ///
    /// `shouldReuseWorkingFolder` returns false for `.update` exactly as it does for `.redownload`,
    /// so the mover is the same one. What this case adds is the observation: the session watched
    /// this record reading incomplete — through `ensureContinuedSession`'s start snapshot and again
    /// through the retirement reconcile inside the pre-wipe push, both production admissions
    /// rather than asserted state — so at bracket time the credited-pages definition is reading
    /// the record raw, and the wipe's counted portion is exactly what the bracket must withdraw.
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
        #expect(terminalPair.subtitle == "5 / 5 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The same record movement with NO deletion and NO blanking anywhere near it: a `.repair`
    /// whose payload reports a different upstream page count.
    ///
    /// `shouldReuseWorkingFolder` returns true unconditionally for `.repair`, so the working folder
    /// and every page file in it survive this run. `ensureWorkingManifest` replaces the record all
    /// the same, because `validatedManifest` requires `manifest.pageCount ==
    /// payload.galleryDetail.pageCount` and returns nil on the mismatch — the state a gallery
    /// reaches when pages are added upstream, or when a crash truncates the stored manifest. A fresh
    /// all-empty manifest at the new page count is written and re-indexed, so the record falls from
    /// 4 of 6 to 0 of 8 with nothing deleted and nothing blanked.
    ///
    /// **What the card must and must not follow.** The record-inference design dipped the card to
    /// 0 of 8 here and re-earned the survivors one flush at a time — an artifact, because the four
    /// page files never left the folder. The run's announced basis values exactly what the
    /// preparation's scan probed: the four surviving files are inherited work the run will not
    /// re-fetch, so the pair moves 4-of-6 to 4-of-8 with no dip, and only pages five through eight
    /// are earned by landing. The record's own 4-to-0 movement still runs inside the preparation's
    /// D-G7-01 bracket — a floor left low re-latches at the very next push, which is the safe
    /// direction — while the numerator itself never leaves the evidence.
    @Test
    func testAPageCountMismatchFreshManifestKeepsProbedPagesCredited() async throws {
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
            folderURL: folderURL
        )

        let wiped = try #require(await manager.fetchDownload(gid: regrown.gid))
        #expect(wiped.completedPageCount == 0)
        #expect(wiped.pageCount == 8)
        #expect(spy.progressUpdates.count == 1)
        // The record just fell to 0 of 8, and the pair deliberately does not follow it: the four
        // page files survived the manifest replacement, the preparation's scan probed them, and
        // the announced basis carries them as inherited work the run will not re-fetch.
        let carriedPair = try lastPushedPair(spy.progressUpdates)
        #expect(carriedPair.completedUnitCount == 4)
        #expect(carriedPair.totalUnitCount == 8)
        #expect(carriedPair.subtitle == "4 / 8 pages · 1 gallery")

        let sessionID = try #require(await manager.testingContinuedSessionID())
        // Page 1 is inherited, not owed, so re-landing it moves nothing: the flush's subtraction
        // is inert outside the run's own to-do list and the union cannot count the page twice.
        let pageOne = try landPageFiles([1], of: regrown, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageOne)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "4 / 8 pages · 1 gallery")

        let remainingPages = try landPageFiles([2, 3, 4, 5, 6, 7, 8], of: regrown, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: remainingPages)
        await manager.settleCompletedDownload(gid: regrown.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 8)
        #expect(terminalPair.totalUnitCount == 8)
        #expect(terminalPair.subtitle == "8 / 8 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
    }

    /// WR-04: the bracket's SIBLINGS-only rule is a CONVENTION, and this is what detects a breach.
    ///
    /// It was recorded as proved by construction — the bracket's closure is not `async` while every
    /// caller of the self-bracketing advance is — and that reading is wrong. The closure is
    /// non-escaping and non-`Sendable`, so it inherits the enclosing actor isolation, and
    /// `advanceQueueIntentGeneration(for:)` is a SYNCHRONOUS actor-isolated method: written inside a
    /// bracket body it compiles today, and the inner movement's delta is then measured twice — once
    /// by its own bracket and again inside the outer one's span — and withdrawn twice, which drops
    /// the monotonic floor below the honest sum. Nothing named that breach until the depth counter.
    ///
    /// It belongs to this suite rather than to a scanning one because the bracket is the mechanism
    /// every case here depends on: the arithmetic these pushes assert is only honest while each
    /// deliberate movement withdraws its own delta exactly once.
    ///
    /// `withKnownIssue` is the pin rather than decoration: it fails when its body records *no*
    /// issue, so this case falls over the moment the counter or its report is dropped — which is how
    /// it was first run, against the undetected nesting.
    ///
    /// The advance AFTER the probe is the balance half, and it needs no seam of its own. It opens
    /// exactly one bracket, so it must record nothing; a depth that failed to unwind would make it —
    /// and every later movement in the process — read as nested, and an unexpected issue fails this
    /// case. Both generations are asserted because the report must stay purely additive: detection
    /// may not consume or skip the movement it reports on.
    @Test
    func testANestedCountedBasisMovementIsDetectedWhileASiblingIsNot() async throws {
        let gid = "210500"
        let manager = makeTestingDownloadCoordinator()

        await withKnownIssue {
            await manager.testingProbeNestedBasisMovement(gid: gid)
        }
        #expect(await manager.queueIntentGeneration(for: gid) == 1)

        await manager.advanceQueueIntentGeneration(for: gid)
        #expect(await manager.queueIntentGeneration(for: gid) == 2)
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionBasisTests {
    /// Lands page files the way a run does — the real bytes first — and returns the payload the
    /// production flush records them with.
    ///
    /// The two halves are deliberately not fused: every case keeps `flushManifestPageProgress` in
    /// its own body, because which writes are production-issued is the property this suite family
    /// exists to keep honest. The payload itself comes from the shared `pageResults`, which is
    /// what makes its "a naming change moves both together" guarantee actually hold here — a
    /// private duplicate of that construction is exactly the drift G-15-38 recorded.
    func landPageFiles(
        _ indices: [Int],
        of gallery: SessionGallery,
        in fixture: SessionFixture
    ) throws -> [DownloadCoordinator.PageResult] {
        try writePageFiles(for: gallery, in: fixture, indices: indices)
        return pageResults(for: gallery, in: fixture, indices: indices)
    }
}
