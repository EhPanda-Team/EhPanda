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

        await manager.ensureContinuedSession()
        #expect(spy.startSubtitles.last == "7 / 14 pages · 2 galleries")

        let correctedFolderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(corrected.gid)_token] \(corrected.title)"
        )
        _ = try await manager.prepareWorkingSeedAnnouncingProgress(
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
        await manager.pushContinuedSessionProgress(sessionID: sessionID)
        let firstSurvivorPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstSurvivorPair.subtitle == "6 / 10 pages · 1 gallery")

        let pageFive = try landPageFiles([5], of: survivor, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: survivorFolderURL, pages: pageFive)
        await manager.pushContinuedSessionProgress(sessionID: sessionID)
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
        let sessionStart = Task { await manager.ensureContinuedSession() }
        await gate.entered()

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(seeded.gid)_token] \(seeded.title)"
        )
        _ = try await manager.prepareWorkingSeedAnnouncingProgress(
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
        await manager.pushContinuedSessionProgress(sessionID: sessionID)
        // The discriminator: with the seed merged the floor is 2, so the honest 3 shows.
        let firstPair = try lastPushedPair(spy.progressUpdates)
        #expect(firstPair.subtitle == "3 / 6 pages · 1 gallery")

        let pageFour = try landPageFiles([4], of: seeded, in: fixture)
        try await manager.flushManifestPageProgress(folderURL: folderURL, pages: pageFour)
        await manager.pushContinuedSessionProgress(sessionID: sessionID)
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

        await manager.ensureContinuedSession()
        #expect(spy.startSubtitles.last == "6 / 14 pages · 2 galleries")

        control.release()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
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
}
