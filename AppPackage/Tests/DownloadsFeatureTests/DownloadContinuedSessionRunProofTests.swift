import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The session-LIFECYCLE half of the run's proof of page work: what the card reports when a session
/// boundary falls somewhere other than around the run.
///
/// An `extension` of the ledger suite rather than a suite of its own, so every case here keeps that
/// suite's membership, its traits and its test identity — the 15-41 relocation pattern applied to
/// additions, exactly as `DownloadContinuedSessionLedgerRefusalTests.swift` does. A new file rather
/// than more cases in that one: those are REFUSAL cases, staged around what
/// `reconcileWorkingManifestAgainstPageFiles` declines to do, while these are staged around what the
/// SESSION did while the run was in flight. The refusal file has already grown twice (15-46's
/// route-binding pin, 15-47's selected-page regression) and mixing a second axis into it would make
/// neither readable.
///
/// **The invariant the trio pins (G-15-26).** The proof a run records at its own preparation — this
/// run has pages of its own to fetch — is a fact about the RUN, while the session's trust set is
/// SESSION-scoped: `markContinuedSessionEnded` clears it, and `ensureContinuedSession` re-derives it
/// from scratch. Recording the proof only into that collection therefore lost it on two orderings
/// production actually produces:
///
/// 1. **An `.unavailable` teardown with the queue still running.** That event arm ends the session
///    and does nothing else — its own log line says the queue then runs foreground-only — so the
///    in-flight repair keeps running with its trust erased. Three of the four arms that yield the
///    event fire inside the store's own `start`, so a scheduler refusal is the ordinary outcome
///    rather than an exotic one.
/// 2. **A run that started before any session existed.** The live client resumes the persisted queue
///    at launch, and D-07 forbids that path from starting a session, so a persisted-queue gid whose
///    record reads complete while its files are gone prepares its seed with no session id at all.
///
/// Both produce G-15-23's card: a complete-reading repair contributing zero for an entire N-page
/// re-download, which is the maximally stalled reading D-11's expiration policy punishes by pausing
/// every schedulable download. The third case is the same rule read from the other side — a proof
/// that OUTLIVES its run re-credits a later redo of the same gallery, which is D-G4-01's ceiling
/// defect reached through the remedy rather than through the gate.
///
/// **Choreography discipline**, carried over from both sibling files and extended by this round's
/// standing rule. Record state comes only from fixture manifests, `writePageFiles` and production
/// routes. Every push, every start and every run-end this file asserts over is PRODUCTION-issued:
/// the session ensure, its convergence pushes, the preparation's own announcement, the session
/// type's own event stream, and `processDownload`'s own exit. No case issues a push, a start, a
/// teardown or a retirement of its own — in particular the second case reaches the teardown through
/// the production event handler rather than through the testing teardown forwarder, because the
/// arm's own behaviour (it ends the session and does nothing else) is part of what the case pins.
extension DownloadContinuedSessionLedgerTests {
    /// Ordering 2: the repair whose seed was prepared before any session existed.
    ///
    /// **Why the record still reads complete when the session starts.** The staging writes no page
    /// file at all, so `reconcileWorkingManifestAgainstPageFiles` finds a successful scan that
    /// accounts for none of the six claimed pages: `blankedPageCount` reaches six and the residual
    /// guard `blankedPageCount < manifest.completedPageCount` refuses. Nothing is blanked and nothing
    /// is republished, so `isIncomplete` stays false for the whole run and the snapshot-sourced half
    /// of D-G4-01's predicate can never admit this gallery — by construction, since
    /// `incompleteGalleryGenerations` is built from `isIncomplete`. The run's own proof is the only
    /// admission this family can reach.
    ///
    /// **The suspension the ordering hinges on**, derived from `ensureContinuedSession` rather than
    /// assumed: the card's OPENING subtitle is built from `schedulableSnapshot()`, taken after the
    /// function's synchronous reset block and before `await backgroundProcessingClient.start(...)`.
    /// The client start is the first suspension whose far side the subtitle is already fixed on — the
    /// spy suspends there too, its `start` closure beginning with `await Task.yield()` before it
    /// records anything — so a seed landing with the POST-start merges cannot move this reading. It
    /// would pass a mid-session assertion and leave the card's opening at zero, which is the failure
    /// this case is written to catch.
    ///
    /// The precondition is asserted rather than assumed: without it a case that accidentally had a
    /// live session at the preparation would be asserting the ordinary in-session path and proving
    /// nothing about this one.
    ///
    /// **Where this case's proof lives, and why it moved (G-15-30).** It used to be the opening
    /// subtitle: a kept proof opened the card at the record's six pages and a lost one at zero. That
    /// difference existed only because membership unlocked the record's WHOLE count, which for this
    /// family is the work the run has not done — so the reading the case pinned was the defect. The
    /// corrected basis credits the record minus what the run still owes, which at the opening is
    /// zero for a kept proof and zero for a lost one alike, leaving the opening with nothing to
    /// discriminate. The proof therefore moved to the PROGRESSION: pages are landed through the
    /// production flush after the start and the credited work must RISE, which only a trusted
    /// gallery's can. The opening is still asserted, as the card's honest first reading, but it is
    /// no longer what this case rests on.
    @Test
    func testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession() async throws {
        let resumed = SessionGallery(
            gid: "210400",
            title: "Resumed",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [resumed],
            queuedGIDs: [resumed.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // No page file is staged: the folder holds the fixture manifest and nothing else, so the
        // residual exit fires and the record reads complete for the whole run.
        await manager.reloadDownloadIndex()

        // Grounded in the production route rather than asserted about it: a complete-reading record
        // whose files are gone reaches `.repair` through the missing-files branch.
        let staged = try #require(await manager.fetchDownload(gid: resumed.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        // The precondition this case is entirely about: the run prepares its seed with no session
        // live, which is what a queue resumed at launch does under D-07.
        #expect(!(await manager.testingHasContinuedSession()))
        #expect(spy.startCount == 0)

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(resumed.gid)_token] \(resumed.title)"
        )
        // No selection: this repair is reached through the fixture's own queue rather than through
        // `retryPages`, and nil is the faithful stored value for exactly that route.
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: resumed),
            existingDownload: staged,
            folderURL: folderURL
        )

        // Non-vacuity: the refusal really refused, and the run really does have all six pages of
        // work, so a zero opening below can only mean the proof was lost rather than never earned.
        #expect(await manager.fetchDownload(gid: resumed.gid)?.completedPageCount == 6)
        #expect(preparedRun.workingSeed.existingPages.isEmpty)
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])
        // With no session there is no card, so the preparation issues no push on either side of the
        // fix; the whole outcome rides on the START below.
        #expect(spy.progressUpdates.isEmpty)

        await manager.testingEnsureContinuedSession()

        #expect(spy.startCount == 1)
        // DEMOTED, not deleted (G-15-30). This reading used to be the case's proof, back when
        // membership unlocked the record's whole count and a kept proof opened the card at six.
        // Under the corrected basis the opening is the same number whether the proof survived or
        // was lost — the run owes all six pages at this instant, so the credited work is zero either
        // way — which makes it a fact about the card's honest opening rather than a discriminator.
        // Asserting it AS the proof would re-freeze a constant, which is the shape that produced
        // this gap.
        let openingCredit = try #require(spy.startCompletedUnitCounts.last)
        #expect(openingCredit == 0)
        #expect(spy.startTotalUnitCounts.last == 6)
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        // THE DISCRIMINATOR. Pages landing through the production flush are credited only for a
        // gallery this session trusts: an untrusted complete-reading record contributes zero at
        // every push no matter how many pages land, because its record cannot move either. So a
        // rise here is reachable only through the proof this run recorded while no session existed.
        try writePageFiles(for: resumed, in: fixture, indices: [1, 2])
        var pendingResolvedPages = pageResults(for: resumed, in: fixture, indices: [1, 2])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: resumed.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        // The record is where it was, so the rise is the session's accounting and nothing else.
        #expect(await manager.fetchDownload(gid: resumed.gid)?.completedPageCount == 6)
        let creditAfterLanding = try lastPushedPair(spy.progressUpdates).completedUnitCount
        #expect(creditAfterLanding > openingCredit)
        #expect(creditAfterLanding == 2)
        // Asserted alongside, so an identity refusal cannot be mistaken for the outcome.
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// Ordering 1: the session torn down by `.unavailable` while the repair keeps running.
    ///
    /// The same fixture as above, with a session live at the preparation so the run demonstrably
    /// EARNS its trust first — the announcement's own push credits the six pages, which is asserted
    /// before the teardown so the case cannot pass on a run that never earned anything. The teardown
    /// then erases the session-scoped trust set, and the question is what the NEXT session opens at.
    ///
    /// **The teardown is production-issued.** The event is delivered through the session's own
    /// stream and handled by `handleContinuedSessionEvent`'s `.unavailable` arm, which calls
    /// `markContinuedSessionEnded` and nothing else. Reaching it through the testing teardown
    /// forwarder instead would stage the teardown while skipping the arm whose "and nothing else" is
    /// half of what makes this ordering harmful.
    ///
    /// **The suspension the ordering hinges on**, derived rather than assumed: the delivery itself.
    /// `ensureContinuedSession` consumes the stream from a detached `continuedSessionTask`, whose
    /// `for await event in clientSession.events` is the suspension the emitted event resumes, so the
    /// teardown lands asynchronously with respect to this case's own execution. The case therefore
    /// waits on the observable outcome — `testingHasContinuedSession()` going false — rather than
    /// assuming the emission landed. The spy's terminal contract matches the live store's: both
    /// `.expired` and `.unavailable` reach the stream through `endSession`, which releases the held
    /// identity and finishes the stream in the same step, which is what lets a successor session
    /// start at all.
    ///
    /// The queue's continued pending work is asserted rather than assumed, because
    /// `ensureContinuedSession` guards on it and a case that had silently drained the queue would
    /// report no second start rather than a wrong one.
    ///
    /// **Where this case's proof lives, and why it moved (G-15-30).** Both halves used to be
    /// subtitle constants: session 1's announcement pushing the record's six pages stood for "trust
    /// earned", and session 2's opening reading six again stood for "trust survived". Both readings
    /// existed only because membership unlocked the record's WHOLE count, which for a refused repair
    /// is the work the run has not done. The corrected basis makes each of them a rise in credited
    /// work across production-issued pushes instead: two pages land in session 1 and the numerator
    /// must reach two, two more land in session 2 and it must reach four. Neither rise is reachable
    /// for a gallery its session does not trust, because a complete-reading record contributes zero
    /// at every push and cannot move on its own.
    @Test
    func testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession() async throws {
        let interrupted = SessionGallery(
            gid: "210401",
            title: "Interrupted",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [interrupted],
            queuedGIDs: [interrupted.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: interrupted.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.testingEnsureContinuedSession()
        // The precondition for THIS ordering: a session really is live when the run prepares.
        #expect(await manager.testingHasContinuedSession())
        #expect(spy.startSubtitles == ["0 / 6 pages · 1 gallery"])

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(interrupted.gid)_token] \(interrupted.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: interrupted),
            existingDownload: staged,
            folderURL: folderURL
        )

        // The run EARNED its trust inside session 1, and two pages landed through the production
        // flush prove it: the record is complete-reading, so an untrusted gallery would have been
        // credited zero for them. Without this the teardown below would have nothing to strip and
        // the case would pass on a run that never earned anything.
        var lastFlushDate = Date.distantPast
        try writePageFiles(for: interrupted, in: fixture, indices: [1, 2])
        var firstBatch = pageResults(for: interrupted, in: fixture, indices: [1, 2])
        try await manager.flushDownloadProgress(
            context: .init(gid: interrupted.gid, folderURL: folderURL),
            pendingResolvedPages: &firstBatch,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        #expect(await manager.fetchDownload(gid: interrupted.gid)?.completedPageCount == 6)
        let creditInFirstSession = try lastPushedPair(spy.progressUpdates).completedUnitCount
        #expect(creditInFirstSession == 2)

        spy.emit(.unavailable)
        try await waitUntil {
            await manager.testingHasContinuedSession() == false
        }

        // The queue is still running, which is the whole premise of the ordering.
        #expect(await manager.hasPendingWork())

        await manager.testingEnsureContinuedSession()
        #expect(spy.startCount == 2)

        // THE DISCRIMINATOR. Two more pages land through the production flush inside session 2, and
        // the credited work must rise again — which the second session can only do for a gallery it
        // trusts, and it can only trust this one through the proof it seeded from the still-running
        // run. The record never moves, so nothing else can supply the rise.
        try writePageFiles(for: interrupted, in: fixture, indices: [3, 4])
        var secondBatch = pageResults(for: interrupted, in: fixture, indices: [3, 4])
        try await manager.flushDownloadProgress(
            context: .init(gid: interrupted.gid, folderURL: folderURL),
            pendingResolvedPages: &secondBatch,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        #expect(await manager.fetchDownload(gid: interrupted.gid)?.completedPageCount == 6)
        let creditInSecondSession = try lastPushedPair(spy.progressUpdates).completedUnitCount
        #expect(creditInSecondSession > creditInFirstSession)
        #expect(creditInSecondSession == 4)
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The lifetime boundary: a proof must NOT survive its own run into a later redo of the same
    /// gallery.
    ///
    /// This is D-G4-01's ceiling read from the other side, and it is the case that stops the remedy
    /// from over-correcting. A proof keyed by gallery id and never retired keeps the SESSION trust
    /// it granted standing, so a later redo of that gallery selects the credited branch instead of
    /// the queued window's zero and opens at its record's count less whatever page debt the dead run
    /// left behind — the pinned-high card the retirement ledger exists to prevent, reached through
    /// the fix for the pinned-ZERO one.
    ///
    /// **Why the first run lands two pages, which it did not have to before (G-15-30).** With the
    /// proof a bare membership, an un-retired entry credited the redo the record's whole count and
    /// the staging needed no page work to show it. With the proof carrying the pages the run still
    /// owes, an un-retired entry that owes ALL of them subtracts back to exactly the zero this case
    /// asserts — the stale debt cancels the stale trust and the assertion goes vacuous again, for a
    /// new reason. Paying two of the six inside the first run breaks that cancellation: a surviving
    /// entry then credits the redo those two pages, and the case fails on the difference.
    ///
    /// **This case is green on BOTH sides of the retirement's introduction unless that landing is
    /// staged, and its green there is VACUOUS.** A green reading is not by itself evidence of a pin.
    /// Its standing rests entirely on the sensitivity reading: with the retirement removed this case
    /// must FAIL, on the redo's card opening at the pages the dead run had already paid instead of
    /// at zero, and must return to green when it is restored. Until that failure has been OBSERVED,
    /// this case must not be reported as closing the lifetime risk.
    ///
    /// **The run-end is production-issued.** The proof is recorded through the preparation forwarder,
    /// as every sibling case reaches the preparation; the RUN'S OWN EXIT is then driven by calling
    /// `processDownload(gid:)`, the coordinator's production run entry point, whose stubbed detail
    /// fetch fails offline and whose general failure catch and `defer` are the exit the retirement
    /// has to cover. Nothing here calls a retirement forwarder — none exists, deliberately.
    ///
    /// **The suspension the ordering hinges on**, derived rather than assumed: `processDownload`
    /// suspends at `try await fetchNormalizeAndDownload(...)`, whose `GalleryDetailRequest.response()`
    /// is answered by the injected stub protocol with a transport failure, and the `defer` runs when
    /// that throw unwinds through the catch. The retirement is synchronous inside that `defer`, so it
    /// has landed by the time the awaited call returns; only `finishActiveTaskIfOwned`'s convergence
    /// is detached, which is why the redo below waits for active ownership to clear before mobilizing
    /// the queue again.
    ///
    /// The redo is `retry(gid:mode:)`, the product's own tap: it resolves the mode, enqueues,
    /// schedules and only then ensures the session, so the opening pair asserted below is the one a
    /// real redo produces rather than one this case staged.
    @Test
    func testAProofDoesNotOutliveItsRunIntoALaterRedo() async throws {
        let redone = SessionGallery(
            gid: "210402",
            title: "Redone",
            pageCount: 6,
            completedPageCount: 6
        )
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [redone],
            queuedGIDs: [redone.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: redone.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)
        #expect(!(await manager.testingHasContinuedSession()))

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(redone.gid)_token] \(redone.title)"
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: redone),
            existingDownload: staged,
            folderURL: folderURL
        )
        // Non-vacuity: this run really did prove page work, so there is a proof for the redo to
        // inherit if nothing retires it.
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])

        // Two of the six paid inside the first run, so a surviving entry would credit the redo
        // those two rather than subtracting back to the zero this case asserts. No session is live,
        // so this issues no push; the debt falls all the same, which is the point.
        try writePageFiles(for: redone, in: fixture, indices: [1, 2])
        var pendingResolvedPages = pageResults(for: redone, in: fixture, indices: [1, 2])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: redone.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        #expect(spy.progressUpdates.isEmpty)

        // The run's own exit, taken through production: the detail fetch fails offline and
        // `processDownload` unwinds through its general failure catch and its `defer`.
        await manager.processDownload(gid: redone.gid)
        #expect(await manager.fetchDownload(gid: redone.gid)?.lastError != nil)
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        // A fresh redo of the SAME gallery, through the product's own tap.
        try await manager.retry(gid: redone.gid, mode: .redownload).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        // The redo has not run, so its record's six pages are the redo's TARGET rather than this
        // session's progress. Inheriting the previous run's proof is what would open it at six.
        #expect(spy.startCount == 1)
        #expect(spy.startCompletedUnitCounts.last == 0)
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The same lifetime boundary read from its other side: a run that cannot prove it owns the
    /// gallery's slot retires NOTHING, and the entry it leaves standing is the owner's to retire.
    ///
    /// **What this pins.** `isSupersededByALiveRun`'s generation-less arm. `processDownload`'s
    /// `generation` is public and defaults to `nil`, and only the scheduler ever stamps one, so a
    /// run can reach the retirement gate with nothing to compare. The policy is that such a run is
    /// treated as superseded — leaving the entry to the live owner costs one stale proof until that
    /// owner exits, while retiring on its behalf drops a live successor's proof and is the G-15-26
    /// zero-progress card reached through its own fix. The arm answered that way by optional
    /// promotion before it was written as a branch; this case is what makes the equivalence an
    /// executed fact rather than a reading off the type system.
    ///
    /// **This case is the mirror of `testAProofDoesNotOutliveItsRunIntoALaterRedo` and shares its
    /// staging deliberately**, so the single difference between them is the one thing under test:
    /// there the exiting run owns the slot and the redo opens at zero, here a live run owns it at a
    /// stamped generation while the exiting run carries none, and the redo opens at the two pages
    /// the earlier run had already paid.
    ///
    /// **Its standing rests on the sensitivity reading, not on green.** With the branch inverted —
    /// `return false` for the generation-less case — the retirement fires, the debt is cleared, the
    /// next session's seed cannot find this gallery and the opening credit falls to zero. Until that
    /// failure has been OBSERVED this case must not be reported as pinning the arm.
    ///
    /// **Everything asserted over is production-issued.** The proof is recorded through the
    /// preparation forwarder as every sibling case records it; the run's exit is
    /// `processDownload(gid:)`, the public entry point, taken at its own `generation` default so the
    /// gate really is reached with `nil`; the redo is `retry(gid:mode:)`, the product's own tap,
    /// which enqueues, schedules and only then ensures the session. No retirement forwarder is
    /// called — none exists, deliberately — and no push is issued by this case.
    ///
    /// **The suspension the ordering hinges on**, derived rather than assumed and identical to the
    /// mirror's: `processDownload` suspends at `try await fetchNormalizeAndDownload(...)`, whose
    /// detail fetch the injected stub answers with a transport failure, and the `defer` runs as that
    /// throw unwinds through the general failure catch. The gate is read synchronously inside that
    /// `defer`, so its answer has landed by the time the awaited call returns.
    ///
    /// **Why no scheduled run intervenes.** `scheduleNextIfNeededCore` will not start a second run
    /// while `activeTask` is live, and the installed run keeps it live for the whole case — which is
    /// the premise rather than a convenience — so the card's opening is read before any successor
    /// prepares a seed of its own.
    @Test
    func testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot() async throws {
        let contested = SessionGallery(
            gid: "210408",
            title: "Contested",
            pageCount: 6,
            completedPageCount: 6
        )
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [contested],
            queuedGIDs: [contested.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: contested.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)
        #expect(!(await manager.testingHasContinuedSession()))

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(contested.gid)_token] \(contested.title)"
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: contested),
            existingDownload: staged,
            folderURL: folderURL
        )
        // Non-vacuity: the entry really exists before the exit, so there is a proof for the gate to
        // spare — or to take, if the arm answers the other way.
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])

        // Two of the six paid inside this run, exactly as the mirror pays them and for the same
        // reason: a surviving entry that still owes ALL six subtracts back to zero and the reading
        // goes vacuous. No session is live, so this issues no push.
        try writePageFiles(for: contested, in: fixture, indices: [1, 2])
        var pendingResolvedPages = pageResults(for: contested, in: fixture, indices: [1, 2])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: contested.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        #expect(spy.progressUpdates.isEmpty)

        // A live run takes this gallery's active slot at a stamped generation, which is the state
        // the gate's whole question is about.
        await manager.testingInstallActiveTask(gid: contested.gid, task: Task {})
        // Non-vacuity: the slot really is held, and by THIS gallery, so the gate reaches its
        // generation comparison rather than returning early on the ownership guard.
        #expect(await manager.testingHasActiveTask())
        #expect(await manager.testingActiveGalleryID() == contested.gid)

        // The generation-less exit, through the public entry point at its own default.
        await manager.processDownload(gid: contested.gid)
        #expect(await manager.fetchDownload(gid: contested.gid)?.lastError != nil)
        // Still held: `finishActiveTaskIfOwned` refused this run too, so the premise the gate was
        // read under is still observably true after the exit rather than merely before it.
        #expect(await manager.testingHasActiveTask())

        // THE DISCRIMINATOR. A redo through the product's own tap starts a session, and a session
        // seeds its trust from the surviving debts' keys. A retired entry leaves this
        // complete-reading record untrusted, contributing zero at every push and unable to move on
        // its own; a spared one credits the record less the four pages still owed.
        try await manager.retry(gid: contested.gid, mode: .redownload).get()

        #expect(spy.startCount == 1)
        #expect(spy.startCompletedUnitCounts.last == 2)
        #expect(spy.startTotalUnitCounts.last == 6)
        #expect(spy.startSubtitles.last == "2 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// G-15-30's consequence 2: the numerator must CLIMB while the pages climb, for a family whose
    /// record cannot move at all.
    ///
    /// The push exists for liveness rather than decoration — the scheduler force-expires the tasks
    /// reporting the least progress — so a numerator that holds one value for the whole re-download
    /// is a stall signal whatever that value is. This case is deliberately written as a SERIES
    /// property rather than as an expected string, because a pinned reading is exactly what it must
    /// refuse: it fails against a numerator frozen at zero and against one frozen at the record's
    /// ceiling alike, which no assertion on a single constant can do.
    ///
    /// Three production flush batches rather than two, so the series has to hold at least three
    /// distinct values; a staging that merely moved once could otherwise pass. `flushDownloadProgress`
    /// is the production flush the page loop itself calls, forced here because a case must not
    /// depend on the throttle's wall clock.
    ///
    /// The record is asserted unmoved at the end for the same reason the sibling refusal cases
    /// assert it: the refusal returned the manifest verbatim, so every value in the series comes
    /// from what the session credits rather than from anything the record did.
    @Test
    func testARefusalRepairsIntermediatePushesStrictlyIncrease() async throws {
        let climbing = SessionGallery(
            gid: "210405",
            title: "Climbing",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [climbing],
            queuedGIDs: [climbing.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: climbing.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles == ["0 / 6 pages · 1 gallery"])

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(climbing.gid)_token] \(climbing.title)"
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: climbing),
            existingDownload: staged,
            folderURL: folderURL
        )
        // Non-vacuity: the folder can supply nothing, so all six pages are this run's own work.
        #expect(preparedRun.workingSeed.existingPages.isEmpty)
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])

        var lastFlushDate = Date.distantPast
        for batch in [[1, 2], [3, 4], [5, 6]] {
            try writePageFiles(for: climbing, in: fixture, indices: batch)
            var pendingResolvedPages = pageResults(for: climbing, in: fixture, indices: batch)
            try await manager.flushDownloadProgress(
                context: .init(gid: climbing.gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: true
            )
        }

        // The record never moved, so the series is entirely the session's own accounting.
        #expect(await manager.fetchDownload(gid: climbing.gid)?.completedPageCount == 6)

        let numerators = spy.progressUpdates.map(\.completedUnitCount)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        #expect(Set(numerators).count >= 3)
        #expect(numerators.last == 6)
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The other half of the series property above: the record reads INCOMPLETE, its claims are
    /// positively refuted, and the numerator must climb from the evidence rather than freeze at
    /// the claim (G-15-34).
    ///
    /// This is the family the round-18 verification derived as the blocker's production route: a
    /// PARTIALLY downloaded gallery whose claimed page files are deleted through the Files app.
    /// The reconciliation's all-or-nothing guard refuses — blanking every claimed page of a
    /// nominally successful listing is more likely a shape the per-page signals missed — so the
    /// record goes on claiming four pages that are not there. The record-inference basis counted
    /// those claims raw for as long as the record read incomplete, then subtracted the run's debt
    /// only once it read complete: a piecewise credit whose two branches disagree at the
    /// crossover, which is exactly where the numerator dropped and the floor froze it
    /// (4, 5, 5, 5, 5, 6 in the round's worked example).
    ///
    /// The announced basis reads the evidence instead: a SUCCESSFUL listing that yields no claimed
    /// file is a positive absence, so nothing is inherited, and the correction from the record's
    /// claim of four to the evidence's zero is excused from the floor by the announcement's own
    /// D-G7-01 bracket. The series is then the run's own landings and nothing else. Like its
    /// sibling this is a SERIES property over three production flush batches rather than one
    /// expected string, because a frozen numerator is exactly what a single-constant assertion
    /// cannot refuse — it fails against a freeze at the claim, at zero, and at the floor's
    /// unwithdrawn four alike.
    ///
    /// **This case CROSSES the announcement's discontinuity rather than starting past it, and the
    /// assertions are split on it.** Production reaches a run through the scheduling tail and every
    /// convergence on that tail pushes, so the card really does hold the record's claim of four
    /// before the announcement corrects it to the evidence's zero. Driving the preparation with no
    /// convergence ahead of it observed the second regime alone, and the strict never-rewinds
    /// assertion this case used to carry was therefore true by STAGING rather than by production:
    /// any convergence landing in that window — which scheduling alone decides — makes the excused
    /// correction read as a rewind, and a spurious one was once recorded that way. The claim regime
    /// is staged here through `scheduleNextIfNeeded`, the very call the run-exit convergence makes,
    /// and quiesced before the announcement so no push is in flight across it.
    ///
    /// The series is then asserted PER REGIME, which is what the coordinator actually guarantees:
    /// the claim regime holds the record's four, the announcement is the one downward step the
    /// D-G7-01 bracket excuses, and the climb out of it may never lose ground. A blanket assertion
    /// over both regimes asserts a monotonicity the accounting basis deliberately breaks.
    @Test
    func testAnIncompleteRefusalRepairsPushesClimbFromTheEvidence() async throws {
        let vanished = SessionGallery(
            gid: "210409",
            title: "Vanished",
            pageCount: 6,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [vanished],
            queuedGIDs: [vanished.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        // No page file is ever written: the four claimed pages are exactly the Files-app deletion
        // shape, positively absent under a listing that succeeds.
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(staged.completedPageCount == 4)
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.testingEnsureContinuedSession()
        // The card opens on the record's claim — no scan has run yet, so four is the best reading
        // the session has.
        #expect(spy.startSubtitles == ["4 / 6 pages · 1 gallery"])

        // The claim regime, reached through the production convergence tail rather than asserted
        // from the start's own subtitle. Two pushes land: this call's own reconcile, and the
        // reconcile the inert run's completion tail issues from `finishActiveTaskIfOwned`. Waiting
        // for both is what leaves nothing in flight across the announcement below, so the regime
        // boundary the assertions split on is a position this case fixed rather than one the
        // scheduler happened to hand it.
        await manager.scheduleNextIfNeeded()
        try await waitUntil {
            spy.progressUpdates.count == 2
        }
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [4, 4])

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(vanished.gid)_token] \(vanished.title)"
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: vanished),
            existingDownload: staged,
            folderURL: folderURL
        )
        // The all-or-nothing guard refused: the record still claims four, verbatim.
        #expect(await manager.fetchDownload(gid: vanished.gid)?.completedPageCount == 4)
        // Non-vacuity: the folder supplies nothing, so all six pages are this run's own work.
        #expect(preparedRun.workingSeed.existingPages.isEmpty)
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])
        // The claims left the numerator with the bracket's excuse, not past the floor's mask: the
        // announcement's own push already reads the evidence.
        let announcedPair = try lastPushedPair(spy.progressUpdates)
        #expect(announcedPair.completedUnitCount == 0)
        #expect(announcedPair.subtitle == "0 / 6 pages · 1 gallery")
        // Where the regimes meet. Read from the quiesced series above rather than assumed, so a
        // convergence path that pushes a different number of times before the announcement moves
        // this index instead of breaking the case.
        let announcedIndex = spy.progressUpdates.count - 1

        var lastFlushDate = Date.distantPast
        for batch in [[1, 2], [3, 4], [5, 6]] {
            try writePageFiles(for: vanished, in: fixture, indices: batch)
            var pendingResolvedPages = pageResults(for: vanished, in: fixture, indices: batch)
            try await manager.flushDownloadProgress(
                context: .init(gid: vanished.gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: true
            )
        }

        // Unlike the complete-reading sibling, the flushes DO move this record: every landing is
        // recorded, so the claims end the run true again.
        #expect(await manager.fetchDownload(gid: vanished.gid)?.completedPageCount == 6)

        let numerators = spy.progressUpdates.map(\.completedUnitCount)
        // Everything ahead of the announcement reads the record's claim: nothing has landed yet,
        // and the claim is all the session can know until the run measures its own work.
        #expect(numerators.prefix(announcedIndex).allSatisfy({ $0 == 4 }))
        // The climb, which is this case's subject, taken from the announcement onward. The step
        // INTO it is the correction the D-G7-01 bracket excuses and is deliberately outside the
        // assertion; every step after it may never lose ground.
        let announcedSeries = Array(spy.progressUpdates.dropFirst(announcedIndex))
        expectTheCompletedSeriesNeverLosesGround(announcedSeries)
        #expect(Set(announcedSeries.map(\.completedUnitCount)).count >= 3)
        #expect(numerators.last == 6)
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The outliving-trust arm: once a run is over, the gallery it proved page work for contributes
    /// NOTHING further while it merely waits in the queue.
    ///
    /// D-G4-01's queued-window zero says a redo's target pages are not this session's progress. A
    /// run's proof is what suspends that rule for the run's own duration, so the rule has to come
    /// back when the run ends — otherwise a failed refusal repair keeps its record's full count
    /// credited for the rest of the session, on a gallery that is doing nothing at all.
    ///
    /// **Which of the two retirement orderings this staging exercises: the RUN-FIRST one.** The run
    /// is driven to a real exit through `processDownload`, whose stubbed detail fetch fails offline
    /// and whose `defer` therefore runs BEFORE the departure the same failure causes — the failure
    /// persistence removes the gallery from the queue store, and the departure is only detected by
    /// the reconcile inside the push that `finishActiveTaskIfOwned`'s detached convergence issues
    /// afterwards. The opposite ordering, where an outside pause departs a gallery whose run is
    /// still holding its measurement, is covered by
    /// `testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid` in the refusal file.
    ///
    /// **The second gallery is load-bearing rather than scenery.** Without it the failure empties
    /// the queue, `reconcileContinuedSession` drains and finishes the session, and the queued window
    /// this case is about would belong to a different session. `keeper` never runs — the injected
    /// runner answers `.skippedOperation` — so it holds exactly one thing steady: pending work.
    ///
    /// **What the terminal numerator is, and why it is not zero.** The two pages this session really
    /// fetched are held by the monotonic floor, which is what stops a numerator rewind from reading
    /// to the scheduler as a task losing ground. The gallery's OWN contribution is what returns to
    /// zero, and the denominator is what shows it back in the queue: a terminal pair of two over
    /// sixteen across two galleries is the session's real work beside the whole queue it still
    /// covers, while the record's untouched six is credited nowhere.
    ///
    /// **This case pins the basis retirement's whole point.** A run's measurement dies with the
    /// run, at `retireRunProgressBasis`, and nothing re-admits the gallery afterwards: the
    /// observation set records only records seen reading incomplete, which this record — complete
    /// for the entire run, the reconciliation having refused — never once did. With the basis
    /// retired and no observation, the credited-pages definition answers zero for a
    /// complete-reading record, so a failed refusal repair sitting in the queue contributes
    /// nothing. A retirement left out would instead leave the finished run's arithmetic standing
    /// for a gallery doing nothing at all, and this terminal pair is where that would surface.
    @Test
    func testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued() async throws {
        let abandoned = SessionGallery(
            gid: "210406",
            title: "Abandoned",
            pageCount: 6,
            completedPageCount: 6
        )
        let keeper = SessionGallery(gid: "210407", title: "Keeper", pageCount: 10)
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [abandoned, keeper],
            queuedGIDs: [abandoned.gid, keeper.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: abandoned.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles == ["0 / 16 pages · 2 galleries"])

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(abandoned.gid)_token] \(abandoned.title)"
        )
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: abandoned),
            existingDownload: staged,
            folderURL: folderURL
        )
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])

        // Two pages of real work, so the trust the run earned is OBSERVED rather than argued: an
        // untrusted complete-reading record contributes zero at every push, whatever lands.
        try writePageFiles(for: abandoned, in: fixture, indices: [1, 2])
        var pendingResolvedPages = pageResults(for: abandoned, in: fixture, indices: [1, 2])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: abandoned.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        #expect(spy.progressUpdates.map(\.completedUnitCount).contains(2))

        // The run's own exit, taken through production.
        await manager.processDownload(gid: abandoned.gid)
        #expect(await manager.fetchDownload(gid: abandoned.gid)?.lastError != nil)
        // Waited on a production observation rather than on active-task quiescence: the exit's own
        // convergence reschedules the surviving gallery, so the active slot legitimately flickers
        // here and a quiescence poll can read it true and false in the same breath.
        //
        // The awaited event is the first `pushContinuedSessionProgress` issued after the failed run
        // exits — the push whose membership sweep retires this gallery's frozen two-page credit and
        // drops the four observed pages it never fetched. The DENOMINATOR is what that crossing
        // moves: 16 becomes 2 retired plus the keeper's 10, so 12, and no earlier push can read 12.
        // The gallery COUNT is deliberately not waited on: under D-G2C-01 a departure that retires
        // a positive count keeps its gallery named, so the count holds at two straight through this
        // departure and would satisfy a count-keyed barrier on entry without observing anything.
        try await waitUntil {
            spy.progressUpdates.last?.subtitle.contains("/ 12 pages") == true
        }

        // Back in the queue, through the product's own tap, inside the SAME session.
        try await manager.retry(gid: abandoned.gid, mode: .repair).get()
        // The mirror crossing, and a barrier rather than a subject: the enqueue-side reconcile drops
        // the ledger entry and resumes counting the gallery live, restoring Y to 16. Fresh because
        // the last update reads 12 when this wait begins. Without it the final pair below could be
        // read off the departure frame.
        try await waitUntil {
            spy.progressUpdates.last?.subtitle.contains("/ 16 pages") == true
        }
        #expect(spy.startCount == 1)
        #expect(await manager.fetchDownload(gid: abandoned.gid)?.completedPageCount == 6)

        let finalPair = try lastPushedPair(spy.progressUpdates)
        #expect(finalPair.completedUnitCount == 2)
        #expect(finalPair.totalUnitCount == 16)
        #expect(finalPair.subtitle == "2 / 16 pages · 2 galleries")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionLedgerTests {
    /// A session whose transport is the shared stub protocol, keyed to one case's own identifier.
    ///
    /// File-private because this file holds the only consumer: it is the seam that lets the third
    /// case drive a REAL `processDownload` to a real exit without reaching the network. The shape is
    /// `makeStubbedDownloadCoordinator`'s, kept identical so both reach the stub the same way —
    /// an ephemeral configuration carrying the protocol class and the per-case header — rather than
    /// registering the protocol process-wide, which would leak across the target's parallel suites.
    func makeStubbedURLSession(stubSessionID: String) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: stubSessionID
        ]
        return URLSession(configuration: configuration)
    }
}
