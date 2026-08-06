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
    /// `incompleteGalleryIDs` is built from `isIncomplete`. The run's own proof is the only admission
    /// this family can reach.
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
        #expect(spy.startCompletedUnitCounts.last == 6)
        #expect(spy.startTotalUnitCounts.last == 6)
        #expect(spy.startSubtitles.last == "6 / 6 pages · 1 gallery")
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

        // The run earned its trust inside session 1, and the announcement's own push proves it. The
        // record is still complete-reading, so this credit can only have come from the proof.
        #expect(await manager.fetchDownload(gid: interrupted.gid)?.completedPageCount == 6)
        #expect(spy.progressUpdates.map(\.subtitle).contains("6 / 6 pages · 1 gallery"))

        spy.emit(.unavailable)
        try await waitUntil {
            await manager.testingHasContinuedSession() == false
        }

        // The queue is still running, which is the whole premise of the ordering.
        #expect(await manager.hasPendingWork())

        await manager.testingEnsureContinuedSession()

        #expect(spy.startCount == 2)
        #expect(spy.startSubtitles.last == "6 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The lifetime boundary: a proof must NOT survive its own run into a later redo of the same
    /// gallery.
    ///
    /// This is D-G4-01's ceiling read from the other side, and it is the case that stops the remedy
    /// from over-correcting. A run-scoped proof keyed by gallery id and never retired makes every
    /// later redo of that gallery open at its record's full page count — the pinned-100% card the
    /// retirement ledger exists to prevent, reached through the fix for the pinned-ZERO one.
    ///
    /// **This case is green on BOTH sides of the fix, and its pre-fix green is VACUOUS.** Before the
    /// fix there is no run-scoped collection at all, so there is nothing for a redo to inherit and
    /// the case cannot fail here however wrong the eventual retirement turns out to be. A green
    /// reading on both sides is therefore not, by itself, evidence of a pin. Its standing rests
    /// entirely on the sensitivity reading taken when the retirement lands: with the retirement
    /// removed this case must FAIL, on the redo's card opening at the record's six pages instead of
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
