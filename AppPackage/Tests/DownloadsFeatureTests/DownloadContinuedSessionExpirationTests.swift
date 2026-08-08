import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// Expiration and teardown semantics of the continued-processing session: what the queue, the
/// scheduling-blocked bookkeeping, and the client seam must look like once the system — or a
/// cancel, or a stale handler — ends a session, plus the ordinary foreground path taken when no
/// session was ever granted.
///
/// Split whole out of `DownloadContinuedSessionTests`, which sits against the 1000-line
/// `file_length` gate. Every case moved with its body and its doc comment unchanged.
@Suite
struct DownloadContinuedSessionExpirationTests: DownloadFeatureTestCase {
    /// SC2's "consistent with an in-app cancel", checked literally rather than paraphrased: the
    /// expected state is computed by running the identical fixture and pausing each gallery
    /// through the coordinator's own pause entry point. A hard-coded status would still pass if
    /// pause itself changed, which is the divergence this case exists to catch.
    @Test
    func testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState() async throws {
        let gids = ["210070", "210071", "210072"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let baseline = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: .noop
        )
        defer { removeTemporaryItem(at: baseline.rootURL) }

        for gid in gids {
            _ = await baseline.manager.pause(gid: gid)
        }
        try await expireSession(of: fixture, spy: spy)

        let expired = await queueSnapshot(fixture.manager)
        let paused = await queueSnapshot(baseline.manager)
        #expect(expired == paused)
        #expect(expired.count == gids.count)
    }

    /// The scheduling-blocked set is the half of pause semantics no display status reveals, and it
    /// is per-gallery bookkeeping with a `defer` on the way out — so a bulk pause path that forgot
    /// to unwind it would leave the queue permanently unschedulable and look fine on screen.
    @Test
    func testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes() async throws {
        let gids = ["210080", "210081"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let baseline = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: .noop
        )
        defer { removeTemporaryItem(at: baseline.rootURL) }

        for gid in gids {
            _ = await baseline.manager.pause(gid: gid)
        }
        try await expireSession(of: fixture, spy: spy)

        let expiredBlocked = await fixture.manager.testingSchedulingBlockedGalleryIDs()
        let pausedBlocked = await baseline.manager.testingSchedulingBlockedGalleryIDs()
        #expect(expiredBlocked == pausedBlocked)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }

    /// Pause-all walks a snapshot of the schedulable set, so the order it walks in is an
    /// implementation detail the result must not depend on. It would, if any pause mutated state
    /// a later pause reads.
    @Test
    func testExpirationResultIsIndependentOfEnqueueOrder() async throws {
        let gids = ["210090", "210091", "210092"]
        let forwardSpy = BackgroundProcessingClientSpy()
        let forward = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            queuedGIDs: gids,
            client: forwardSpy.client
        )
        defer { removeTemporaryItem(at: forward.rootURL) }
        let reversedSpy = BackgroundProcessingClientSpy()
        let reversed = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            queuedGIDs: gids.reversed(),
            client: reversedSpy.client
        )
        defer { removeTemporaryItem(at: reversed.rootURL) }

        try await expireSession(of: forward, spy: forwardSpy)
        try await expireSession(of: reversed, spy: reversedSpy)

        let forwardSnapshot = await queueSnapshot(forward.manager)
        let reversedSnapshot = await queueSnapshot(reversed.manager)
        #expect(forwardSnapshot == reversedSnapshot)
        #expect(
            await forward.manager.testingSchedulingBlockedGalleryIDs()
                == (await reversed.manager.testingSchedulingBlockedGalleryIDs())
        )
    }

    /// An expiration clears liveness before it pauses anything, and each of those pauses
    /// reschedules — so the scheduling tail runs several times against an ended session. Nothing
    /// it does may reach the client: the identifier is already gone, and a completion for a
    /// session the system ended is a call the seam should never make.
    ///
    /// This is also the one drain-shaped exit that is deliberately excluded from D-G2B-01's
    /// terminal push: the store completed the task inside its own expiration handler before the
    /// event was ever delivered, so no card survives to repaint. The rejected list staying empty is
    /// the stronger half of that claim — the coordinator's own guard refused before anything
    /// reached the client seam, which is what the handler's end-before-pause ordering depends on.
    @Test
    func testEndedSessionReceivesNoFurtherUpdateOrCompletion() async throws {
        let gids = ["210100", "210101"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let updatesBeforeExpiration = spy.progressUpdates.count
        #expect(updatesBeforeExpiration == 1)

        try await expireSession(of: fixture, spy: spy, ensuresSession: false)
        await fixture.manager.scheduleNextIfNeeded()
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.count == updatesBeforeExpiration)
        #expect(spy.rejectedProgressUpdates.isEmpty)
        #expect(spy.finishCount == 0)
    }

    /// The consuming task is never cancelled from outside — the stream finishing behind the
    /// expiration is what ends it. Awaiting that task to completion is the proof, and it is also
    /// why no case here has to poll for the pause-all to settle.
    @Test
    func testConsumingTaskEndsOnItsOwnAfterExpiration() async throws {
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: ["210110"]),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionTask = try #require(await fixture.manager.testingContinuedSessionTask())
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish"
        )

        #expect(!sessionTask.isCancelled)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
        #expect(await fixture.manager.testingContinuedSessionTask() == nil)
    }

    /// SC3 as amended: with no fallback tier left, an unavailable session is not a degraded mode
    /// but the ordinary foreground one. Proved by running the same page work twice and comparing
    /// the results gallery for gallery — same statuses, same errors, same manifest page counts —
    /// so a page can be neither lost nor written twice on the path that has no session.
    @Test
    func testUnavailableSessionLeavesQueueStateEqualToTheInertClient() async throws {
        let gid = "210120"

        let unavailable = try await runPageFlushScenario(client: .unavailable, gid: gid)
        let inert = try await runPageFlushScenario(client: .noop, gid: gid)

        #expect(unavailable == inert)
        #expect(unavailable.count == 1)
        #expect(unavailable.allSatisfy({ $0.lastError == nil }))
        #expect(unavailable.allSatisfy({ $0.completedPageCount == $0.pageCount }))
    }

    /// The silence is the contract: nothing thrown out of the tap that asked for the session,
    /// nothing recorded as a download failure, and no session left believing it is live.
    @Test
    func testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession() async throws {
        let gid = "210130"
        let context = try await makeInactiveCoordinator(gid: gid, client: .unavailable)
        defer { context.cleanUp() }

        // `.get()` is the assertion: the mobilizing tap must still report success even though the
        // session it asked for was refused outright.
        try await context.manager.togglePause(gid: gid).get()
        try await waitUntil {
            await !context.manager.testingHasContinuedSession()
        }

        let download = try #require(await context.manager.fetchDownload(gid: gid))
        #expect(download.lastError == nil)
        #expect(!(await context.manager.testingHasContinuedSession()))

        _ = await context.manager.pause(gid: gid)
    }

    /// CR-02: a superseded session's trailing teardown used to clear whatever session was live
    /// when it finally re-entered the actor. The interleave that produces it — a drain completing
    /// S1 while its consuming task is still suspended, then a tap starting S2 before that task
    /// resumes — has no deterministic staging, but its effect does: a teardown carrying a foreign
    /// id, driven directly here. Before the fix it detached the live session, after which nothing
    /// pushed progress and nothing completed it.
    @Test
    func testStaleTeardownDoesNotClearANewerSession() async throws {
        let gid = "210140"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { context.cleanUp() }

        try await context.manager.togglePause(gid: gid).get()
        let sessionID = try #require(await context.manager.testingContinuedSessionID())
        #expect(spy.startCount == 1)
        #expect(await context.manager.testingHasContinuedSession())

        await context.manager.testingMarkContinuedSessionEnded(sessionID: UUID())

        // Still live, and still pushing: the foreign teardown touched nothing.
        #expect(await context.manager.testingHasContinuedSession())
        await context.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(spy.progressUpdates.count == 1)

        // The correct-id path still tears the session down end to end.
        _ = await context.manager.pause(gid: gid)
        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(!(await context.manager.testingHasContinuedSession()))
    }

    /// WR-04: the update, redownload and repair cancel mutated the queue without reaching the
    /// convergence point every other mutation exits through, so a cancel that emptied the
    /// schedulable set left the session live with nothing able to complete it — after which the
    /// system force-expired the card as stalled and the D-11 policy paused downloads the user
    /// never touched. Ordinary tap reachability: `toggleDownloadPause` routes a queued update here.
    @Test
    func testCancellingTheLastQueuedWorkItemCompletesTheSession() async throws {
        let gid = "210150"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Updating", pageCount: 5, completedPageCount: 1)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        #expect(spy.startCount == 1)
        #expect(await fixture.manager.testingHasContinuedSession())

        let download = try #require(await fixture.manager.indexedDownloads(gids: [gid]).first)
        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(spy.progressUpdates.last?.subtitle == "1 / 1 page · 1 gallery")
        #expect(!(await fixture.manager.testingHasContinuedSession()))

        // D-07: the next queue-mobilizing moment starts a fresh session rather than folding into
        // the dead one — and that one still drains, so the case leaves nothing live behind it.
        await fixture.manager.testingSetQueuedGalleryIDs([gid])
        await fixture.manager.testingEnsureContinuedSession()
        #expect(spy.startCount == 2)

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishCount == 2)
        #expect(spy.finishSuccesses == [true, true])
        // One terminal string per drained session, and the same one both times: the single page
        // this gallery finished retires, and its four unfinished pages leave with the departure.
        // That retirement is what the gallery count reports too — a retirement above zero keeps the
        // gallery represented by the denominator it contributed to, so each drained session names
        // the one gallery its single page belongs to (D-G2C-01). Both sessions read the same
        // because the second is a fresh one whose ledger opens empty and whose entire Y is that one
        // persisted-complete page, retired again by its own pause-drain.
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "1 / 1 page · 1 gallery",
            "1 / 1 page · 1 gallery"
        ])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionExpirationTests {
    /// Everything about one gallery that a pause is allowed to change, plus the two facts a lost
    /// or duplicated page would move. Compared as a whole so a divergence anywhere fails, rather
    /// than only where an assertion happened to look.
    struct GalleryStateSnapshot: Equatable {
        let gid: String
        let displayStatus: DownloadDisplayStatus
        let completedPageCount: Int
        let pageCount: Int
        let lastError: DownloadFailure?
    }

    func queueSnapshot(_ manager: DownloadCoordinator) async -> [GalleryStateSnapshot] {
        let downloads = await manager.indexedDownloads()
        return downloads
            .map({
                GalleryStateSnapshot(
                    gid: $0.gid,
                    displayStatus: $0.displayStatus,
                    completedPageCount: $0.completedPageCount,
                    pageCount: $0.pageCount,
                    lastError: $0.lastError
                )
            })
            .sorted(by: { $0.gid < $1.gid })
    }

    /// Galleries with differing page counts and differing amounts already done, so a comparison
    /// against the pause baseline cannot pass by accident on identical rows.
    func expirationGalleries(gids: [String]) -> [SessionGallery] {
        gids.enumerated().map { offset, gid in
            SessionGallery(
                gid: gid,
                title: "Expiring \(offset)",
                pageCount: 4 + offset * 3,
                completedPageCount: offset
            )
        }
    }

    /// Fires the expiration and returns once the coordinator has finished acting on it.
    ///
    /// The settle point is the consuming task itself rather than a polled predicate: the handler's
    /// pause-all runs inside that task, so awaiting it is exact. Capturing the task before firing
    /// is what makes that possible — the handler nils it on the way through.
    func expireSession(
        of fixture: SessionFixture,
        spy: BackgroundProcessingClientSpy,
        ensuresSession: Bool = true
    ) async throws {
        if ensuresSession {
            await fixture.manager.testingEnsureContinuedSession()
        }
        let sessionTask = try #require(await fixture.manager.testingContinuedSessionTask())
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish after expiration"
        )
    }

    /// Runs one gallery's worth of page flushes against `client` and reports the resulting queue
    /// state. Same gid in every run, so two runs' snapshots compare directly.
    func runPageFlushScenario(
        client: BackgroundProcessingClient,
        gid: String
    ) async throws -> [GalleryStateSnapshot] {
        let title = "Unavailable Path"
        let pageCount = 12
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: title, pageCount: pageCount)],
            client: client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(gid)_token] \(title)"
        )

        await fixture.manager.testingEnsureContinuedSession()

        var pendingResolvedPages = [DownloadCoordinator.PageResult]()
        var lastFlushDate = Date.distantPast
        for index in 1...pageCount {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            try Data([UInt8(index)]).write(
                to: folderURL.appendingPathComponent(relativePath),
                options: .atomic
            )
            pendingResolvedPages.append(
                .init(index: index, relativePath: relativePath, imageURL: nil)
            )
            try await fixture.manager.flushDownloadProgress(
                context: .init(gid: gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: false
            )
        }
        try await fixture.manager.flushDownloadProgress(
            context: .init(gid: gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        return await queueSnapshot(fixture.manager)
    }
}

private extension BackgroundProcessingClient {
    /// Answers every start with an identified session that immediately reports unavailable —
    /// what the Simulator reports, and what the system reports when it will not grant a task.
    ///
    /// **Why all three closures suspend before they do anything.** The live value forwards onto
    /// `ContinuedProcessingSession`, a `@MainActor` type, so every endpoint hops off the calling
    /// actor — and while a call is over there the coordinator's actor is reentrant. A double that
    /// answers synchronously does not merely run faster; it certifies that window as impossible.
    /// Three lines of `ensureContinuedSession` exist for nothing but surviving it: the ownership
    /// re-check behind the start (`DownloadClient+ContinuedSession.swift:358`), the additive floor
    /// seed that folds in a withdrawal landing inside the hop (`:373`), and the merged trust seed
    /// that folds in a push landing there (`:403-407`). Every case below runs this double through
    /// exactly that stretch, so with the hop removed their coverage of those three was nominal.
    ///
    /// The family makes it the one least able to afford an atomic double, per
    /// `DownloadContinuedSessionRunProofTests`' suite doc: `.unavailable` is the ORDINARY outcome
    /// rather than an exotic one, and three of the four arms that yield it fire inside the store's
    /// own start.
    ///
    /// The suspensions mirror `BackgroundProcessingClientSpy`'s three rather than inventing a
    /// second convention, and the rule is no longer honoured by convention alone:
    /// `DownloadSourceInventoryTests.testClientDoubleSuspensionSitesMatchTheRecordedCensus` counts
    /// them, so a closure that stops yielding fails a build.
    static let unavailable = Self(
        start: { _, _, _, _ in
            await Task.yield()
            let events = AsyncStream<BackgroundProcessingEvent> { continuation in
                continuation.yield(.unavailable)
                continuation.finish()
            }
            return BackgroundProcessingSession(id: UUID(), events: events)
        },
        updateProgress: { _, _, _, _ in
            await Task.yield()
        },
        finish: { _, _ in
            await Task.yield()
        }
    )
}
