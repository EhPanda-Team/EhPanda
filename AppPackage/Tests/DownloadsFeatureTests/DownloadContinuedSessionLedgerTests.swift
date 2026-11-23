import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing
import TestingSupport

/// The multi-gallery half of the continued session's arithmetic: what the card reports as galleries
/// leave the schedulable set — by finishing or by being paused — and what it reports when one of
/// them comes back. A user deletion is not a retirement and lives in
/// `DownloadContinuedSessionDeletionTests.swift`.
///
/// A new file rather than more cases in `DownloadContinuedSessionTests.swift` for a concrete
/// reason: that file already sits past 900 lines against a `file_length` limit of 1000 at error
/// severity, so the coverage this gap needs does not fit there.
///
/// A completion is staged the way the product does it — patch the gallery's record to a complete
/// manifest through the same index seam a page flush uses, then call `settleCompletedDownload(gid:)`,
/// which is what removes it from the queue store — and the *mid-queue* progress is pushed explicitly
/// between steps, so the recorded update list is a fact about the arithmetic rather than about
/// scheduling timing.
///
/// The *terminal* push is deliberately not taken that way. A directly invoked push after the last
/// settle is a call the product never makes at a drain — control takes the drain branch of
/// `reconcileContinuedSession` there — so pinning the drained value on one asserted nothing about
/// what the card is actually left showing, which is precisely how G-15-2B shipped green twice. Each
/// drain below therefore ends at `scheduleNextIfNeeded()`, the tail every queue mutation converges
/// on, and asserts the value that tail produced.
///
/// A pause is driven through the coordinator's own `pause(gid:)` instead, because that case exists
/// to prove the product's entry point reaches the ledger. It converges on `scheduleNextIfNeeded`,
/// whose tail reconciles the session, so that case asserts the last recorded update rather than a
/// list of them.
@Suite(.isolatedAppStorage)
struct DownloadContinuedSessionLedgerTests: DownloadFeatureTestCase {
    /// The pair a drained three-gallery queue owes, whatever order its galleries finished in.
    ///
    /// Both drains below assert their final push against this one value, so an ordering dependence
    /// fails whichever order introduced it. Comparing one run's last update against the other's
    /// directly would need a second full fixture inside a single case and would discriminate no
    /// better, while pinning the value here also states what the drain is worth.
    ///
    /// The gallery count is three at the drain and not zero, because **D-G2C-01** counts the
    /// denominator's coverage rather than the live schedulable set: all three galleries completed,
    /// so all three retired their full page counts into the ledger, and those twenty pages are the
    /// whole of the twenty this pair reports. A count of zero beside a denominator every one of
    /// them contributed to is the device-reported defect, read from the other end.
    static let drainedPair = PushedPair(
        completedUnitCount: 20,
        totalUnitCount: 20,
        subtitle: "20 / 20 pages · 3 galleries"
    )

    /// The pair a pause owes once a 10-page gallery with 6 finished has left a queue that also
    /// holds an untouched 4-page gallery.
    ///
    /// Two galleries, not one: the departed gallery retired six pages into the denominator, so six
    /// of the ten pages this pair reports are its. **D-G2C-01** counts every gallery whose pages Y
    /// still carries, and a departure that retires a positive count leaves its pages behind — so
    /// the gallery it belongs to stays named for as long as they are counted. A user deletion is
    /// the one departure that does not reach this pair: it withdraws the gallery instead (B-1, see
    /// `DownloadContinuedSessionDeletionTests`).
    static let departedPair = PushedPair(
        completedUnitCount: 6,
        totalUnitCount: 10,
        subtitle: "6 / 10 pages · 2 galleries"
    )

    /// The direct regression for the device-reported gap, at full size: three queued galleries, and
    /// the largest finishes first.
    ///
    /// Under the old basis the second push already read 10 of 10 pages with the queue two thirds
    /// full, because a completed gallery's pages left the numerator and the denominator together.
    /// The ledger puts them back on both sides, so the total holds at 20 across every completion
    /// while the count climbs.
    ///
    /// The gallery count holds at three for the same reason the denominator holds at twenty. Under
    /// **D-G2C-01** the two are one statement: a completion retires the gallery's pages into Y, so
    /// the gallery goes on being represented by Y and goes on being counted. The subtitle series
    /// below is therefore a constant three beside a constant twenty, with only the numerator
    /// moving — the shape that makes the card truthful on every frame rather than only on the last
    /// one the OS may or may not repaint.
    @Test
    func testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount() async throws {
        let large = SessionGallery(gid: "210200", title: "Large", pageCount: 10)
        let middle = SessionGallery(gid: "210201", title: "Middle", pageCount: 6)
        let small = SessionGallery(gid: "210202", title: "Small", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, middle, small],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: large, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: large.gid)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: middle, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: middle.gid)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: small, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: small.gid)
        await fixture.manager.scheduleNextIfNeeded()

        #expect(spy.progressUpdates.map(\.completedUnitCount) == [0, 10, 16, 20])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [20, 20, 20, 20])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "0 / 20 pages · 3 galleries",
            "10 / 20 pages · 3 galleries",
            "16 / 20 pages · 3 galleries",
            "20 / 20 pages · 3 galleries"
        ])
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
        let finalPair = try lastPushedPair(spy.progressUpdates)
        #expect(finalPair == Self.drainedPair)
        // The drain completed the session exactly once, and every push it made was accepted while
        // the session still owned the card. The rejected list is what fails if the terminal push
        // is ever moved after the completion: the spy routes it there rather than dropping it.
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The same three sizes in a fresh fixture, finished smallest first.
    ///
    /// An ordering dependence here would mean one departure mutates what a later departure reads —
    /// a rejoining gallery double-counted, or a retired value overwritten by a stale observation.
    /// Pause-all already carries an order-independence case in the sibling suite for that reason.
    @Test
    func testReportedTotalsDoNotDependOnCompletionOrder() async throws {
        let large = SessionGallery(gid: "210210", title: "Large", pageCount: 10)
        let middle = SessionGallery(gid: "210211", title: "Middle", pageCount: 6)
        let small = SessionGallery(gid: "210212", title: "Small", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, middle, small],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: small, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: small.gid)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: middle, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: middle.gid)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: large, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: large.gid)
        await fixture.manager.scheduleNextIfNeeded()

        #expect(spy.progressUpdates.map(\.completedUnitCount) == [0, 4, 10, 20])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [20, 20, 20, 20])
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
        let finalPair = try lastPushedPair(spy.progressUpdates)
        #expect(finalPair == Self.drainedPair)
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The reachable empty-live-sum input: a session outliving its work for the moment between the
    /// queue emptying and the scheduling tail completing it. A push taken in that window sums
    /// nothing live at all, and here the emptying is a real completion rather than a bare dequeue.
    ///
    /// What holds the pair up is the ledger, not the monotonic floor: the departing gallery retires
    /// all six of its pages to both sides, so completed equals total *because* nothing is
    /// outstanding — the one moment a 1.0 fraction is honest. Under the old basis this same staging
    /// pushed `2 / 2 pages`, a full card with two thirds of the work never done, so the case now
    /// fails on the pre-fix code instead of passing verbatim on it.
    ///
    /// Those six retired pages are also the whole of Y, so the drained card names one gallery
    /// rather than none (**D-G2C-01**). It is the positive-retirement side of the boundary read on
    /// a completion; the zero-retirement side is
    /// `testDrainingTheQueueCompletesTheSessionWithSuccess` in `DownloadContinuedSessionTests`,
    /// where the gallery finished nothing and drains to `0 galleries`.
    ///
    /// A genuinely zero denominator — a session outliving work nobody finished at all — is reached
    /// under the ledger only when the departing gallery finished no pages, so that guard is not
    /// lost but moved: the case below supplies it.
    ///
    /// It lives here rather than beside that drain case because `DownloadContinuedSessionTests.swift`
    /// had come within a few lines of its 1000-line limit; this is the move `15-22-SUMMARY.md` sanctioned.
    ///
    /// The terminal push is taken through `scheduleNextIfNeeded` rather than invoked directly. The
    /// pair it owes is unchanged; what changes is that the product now makes the call, and a value
    /// pinned on a call the product never makes is what hid G-15-2B.
    @Test
    func testEmptySchedulableSetStillPushesAPositiveTotal() async throws {
        let gid = "210045"
        let title = "Departing"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: title, pageCount: 6, completedPageCount: 2)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gid)_token] \(title)"
            ),
            manifest: manifest(
                for: .init(gid: gid, title: title, pageCount: 6, completedPageCount: 6)
            )
        )
        await fixture.manager.settleCompletedDownload(gid: gid)
        await fixture.manager.scheduleNextIfNeeded()

        let update = try #require(spy.progressUpdates.last)
        #expect(update.totalUnitCount >= 1)
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [2, 6])
        #expect(update.totalUnitCount == 6)
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "2 / 6 pages · 1 gallery",
            "6 / 6 pages · 1 gallery"
        ])
        #expect(spy.finishSuccesses == [true])
    }

    /// The zero-denominator guard, inherited from `testEmptySchedulableSetStillPushesAPositiveTotal`
    /// above.
    ///
    /// That case now stages its departure as a real completion, so it no longer reaches a genuinely
    /// empty sum: under the ledger, both sides are zero only when the departing gallery finished no
    /// pages at all. This is that input — a session outliving work nobody touched. The live sum is
    /// zero, the ledger is zero, and `DownloadProgress.displayPageCount` floors the denominator at
    /// one page so the card still renders a well-formed fraction rather than dividing by zero.
    @Test
    func testASessionOutlivingWorkNobodyFinishedStillPushesAPositiveTotal() async throws {
        let gid = "210220"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Untouched", pageCount: 6)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        // A departure with nothing to retire, which is the only way both sides reach zero now.
        await fixture.manager.testingSetQueuedGalleryIDs([])
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let update = try #require(spy.progressUpdates.last)
        #expect(update.totalUnitCount >= 1)
        #expect(update.completedUnitCount >= 0)
        #expect(update.completedUnitCount <= update.totalUnitCount)
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "0 / 6 pages · 1 gallery",
            "0 / 1 page · 0 galleries"
        ])
    }

    /// D-G2-01 on the pause path: a gallery leaving by pause retires exactly the pages it had
    /// already finished, and its unfinished pages leave the denominator with it.
    ///
    /// The departure is driven through the coordinator's own `pause(gid:)` rather than the
    /// queue-set test seam, because what this case is for is that the product's pause reaches the
    /// ledger at all. Retiring the wrong value is visible either way: retiring the paused gallery's
    /// full 10 pages keeps 4 pages in the denominator that this session will never do, pinning the
    /// card below 1.0 for as long as it lives, and retiring nothing at all rewinds the numerator
    /// from 6 to 0, which is the stall signal the scheduler reads before it forcibly expires the
    /// tasks that look most stuck.
    @Test
    func testPausedGalleryRetiresOnlyItsFinishedPages() async throws {
        let large = SessionGallery(
            gid: "210230",
            title: "Paused",
            pageCount: 10,
            completedPageCount: 6
        )
        let small = SessionGallery(gid: "210231", title: "Surviving", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            // Pausing converges on scheduling, which would otherwise start the surviving gallery's
            // download for real. Skipping the operation keeps the convergence and drops the network.
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let openingPair = try firstPushedPair(spy.progressUpdates)
        #expect(openingPair.completedUnitCount == 6)
        #expect(openingPair.totalUnitCount == 14)
        #expect(openingPair.subtitle == "6 / 14 pages · 2 galleries")

        try await fixture.manager.pause(gid: large.gid).get()

        // Asserted on the last update rather than against a list of a known length: `pause`
        // converges through `scheduleNextIfNeeded`, and the surviving gallery's skipped scheduling
        // converges again behind it, so how many pushes land is a property of the convergence path
        // and not of this case's subject. The arithmetic is what is under test, and every push
        // after the pause owes the same pair.
        let pausedPair = try lastPushedPair(spy.progressUpdates)
        #expect(pausedPair.completedUnitCount == 6)
        #expect(pausedPair.totalUnitCount == 10)
        #expect(pausedPair.subtitle == "6 / 10 pages · 2 galleries")
        #expect(pausedPair == Self.departedPair)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        // A pause must never be able to report the session finished.
        #expect(pausedPair.completedUnitCount < pausedPair.totalUnitCount)
    }

    /// A gallery that leaves the schedulable set and comes back is worth its pages once.
    ///
    /// Resuming a paused download is an ordinary tap — D-07 makes it a qualifying one, and D-06
    /// folds the returning work into the live session rather than starting a second — so the third
    /// push here is a state the product reaches, not a contrivance. It must read exactly
    /// `6 / 14` again. `12 / 24` is the failure this case exists for: the same six finished pages
    /// counted in the ledger and in the live sum at once, a card claiming more finished pages than
    /// the queue contains, and a denominator inflated by a gallery that is present exactly once.
    /// That is the shape a ledger accumulated into a scalar takes: with no per-gallery key there is
    /// nothing to correct when a gallery returns.
    ///
    /// The gallery count says the same thing about **D-G2C-01**'s own dedupe. It reads two on all
    /// three frames: the departing gallery had six finished pages, so it is counted as a positive
    /// retirement while away, and on its return the reconcile drops that ledger entry before the
    /// live set counts it again. Counted once either way — a middle frame reading one would mean a
    /// gallery whose pages are still in Y went unnamed, and a rejoined frame reading three would be
    /// the ledger and the live set both claiming it.
    ///
    /// The departure and the rejoin are staged through the queue-set test seam rather than through
    /// `pause` and `resume`, and deliberately so: this case is about a single arithmetic hazard, and
    /// it asserts the whole pushed series, so it must not also depend on how many times the
    /// scheduling tail happens to converge. The product's own departure primitives are covered by
    /// the pause case above, which asserts its last update for exactly that reason.
    @Test
    func testResumedGalleryIsCountedOnce() async throws {
        let large = SessionGallery(
            gid: "210250",
            title: "Departing",
            pageCount: 10,
            completedPageCount: 6
        )
        let small = SessionGallery(gid: "210251", title: "Surviving", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.testingSetQueuedGalleryIDs([small.gid])
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.testingSetQueuedGalleryIDs([large.gid, small.gid])
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.completedUnitCount) == [6, 6, 6])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [14, 10, 14])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "6 / 14 pages · 2 galleries",
            "6 / 10 pages · 2 galleries",
            "6 / 14 pages · 2 galleries"
        ])
        // Stated as an equality as well as as literals: what the rejoin owes is *the first pair
        // back*, whatever that pair happens to be worth.
        let openingPair = try firstPushedPair(spy.progressUpdates)
        let rejoinedPair = try lastPushedPair(spy.progressUpdates)
        #expect(rejoinedPair == openingPair)
    }

    /// G-15-4 on the opening pair: a complete gallery queued for an update opens the card at zero.
    ///
    /// `shouldSchedule` returns `true` on `isQueuedWorkItem` before it ever consults `isIncomplete`,
    /// so the redo is schedulable — correctly, it has to run — and the old basis then read the
    /// manifest's six finished pages as six of six session pages. `start` arrived at its own
    /// ceiling, `lastPushedCompletedPageCount` latched there, and the monotonic floor pinned the
    /// card at 100% for the rest of the session: the pinned-card failure the retirement ledger
    /// exists to eliminate, reached through a different door, and one the scheduler reads as a
    /// stalled task before it force-expires the least-progressing ones. Those six pages are the
    /// redo's *target* rather than this session's progress, which is what D-G4-01 says.
    ///
    /// Driven through `retry`, the product's own update tap: it resolves the mode, enqueues,
    /// schedules and only then ensures the session, so the opening pair is the one a real update
    /// produces rather than one a test staged. The gallery starts out unqueued so that tap is the
    /// only thing that can make it schedulable.
    @Test
    func testACompleteGalleryQueuedForUpdateOpensTheCardAtZero() async throws {
        let redo = SessionGallery(gid: "210270", title: "Redo", pageCount: 6, completedPageCount: 6)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [redo],
            queuedGIDs: [],
            client: spy.client,
            // The tap schedules for real; skipping the operation keeps the convergence and drops
            // the network, exactly as the pause case above does.
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        try await manager.retry(gid: redo.gid, mode: .update).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        #expect(spy.startCompletedUnitCounts.last == 0)
        #expect(spy.startTotalUnitCounts.last == 6)
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let openingPair = try lastPushedPair(spy.progressUpdates)
        #expect(openingPair.completedUnitCount == 0)
        #expect(openingPair.totalUnitCount == 6)
        #expect(openingPair.subtitle == "0 / 6 pages · 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The retirement half of D-G4-01: a redo that never ran retires nothing when it is cancelled.
    ///
    /// D-G2-01 makes a departed gallery's record authoritative, which is what lets a gallery
    /// completing between two pushes retire its full count. For a redo the session never watched
    /// doing work, that record is authoritative about the *manifest* rather than about the session:
    /// retiring its six pages would put six pages the session never downloaded on both sides of the
    /// fraction and report a finished session. The trust set is what keeps the two rules apart, and
    /// it is one formula still — no call site classifies why a gallery left.
    ///
    /// Staged by enqueueing the complete manifest directly rather than through `retry`, because
    /// that is the second route into the same defect: a bare re-enqueue never touches `queuedModes`
    /// at all, so a mode-keyed basis would have missed it entirely. It is also the route with no
    /// scheduling in it, which is what makes the drain here a single, unraced terminal push.
    @Test
    func testCancellingANeverStartedUpdateRetiresNothing() async throws {
        let redo = SessionGallery(gid: "210280", title: "Redo", pageCount: 6, completedPageCount: 6)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(galleries: [redo], client: spy.client)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        #expect(spy.startSubtitles == ["0 / 6 pages · 1 gallery"])

        let download = try #require(await fixture.manager.indexedDownloads(gids: [redo.gid]).first)
        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()

        // Nothing retired, so both sides reach zero and the display floor supplies the one page —
        // the same shape `testASessionOutlivingWorkNobodyFinishedStillPushesAPositiveTotal` reaches
        // from a gallery that finished nothing, which is exactly what this session observed here.
        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 0)
        #expect(terminalPair.totalUnitCount == 1)
        #expect(terminalPair.subtitle == "0 / 1 page · 0 galleries")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }

    /// The survivors' half: cancelling a never-started redo must not move the fraction it leaves.
    ///
    /// Under the old basis the queue opened at nine of fourteen — three pages genuinely downloaded
    /// plus six that predate the session — and the numerator floor then held the card at nine for
    /// as long as the session lived, so the surviving gallery's real work could never show. The
    /// redo's pages leave the denominator with it because it never ran, and the numerator holds at
    /// the three pages that were actually finished.
    @Test
    func testAMidQueueUpdateCancelDoesNotInflateTheSurvivors() async throws {
        let redo = SessionGallery(gid: "210290", title: "Redo", pageCount: 6, completedPageCount: 6)
        let ordinary = SessionGallery(
            gid: "210291",
            title: "Ordinary",
            pageCount: 8,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [redo, ordinary],
            queuedGIDs: [ordinary.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        try await manager.retry(gid: redo.gid, mode: .redownload).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        #expect(spy.startSubtitles.last == "3 / 14 pages · 2 galleries")

        let download = try #require(await manager.indexedDownloads(gids: [redo.gid]).first)
        try await manager.cancelQueuedWorkItem(download, mode: .redownload).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        // No task is active before the cancel either, so that wait can return ahead of the push that
        // carries the survivors' pair: the session's consumer applies the cancel on its own schedule,
        // and a hosted run whose process was not scheduled for minutes read the opening pair (14, two
        // galleries) here. The wait is for the push to land; what it must say is asserted below.
        await waitUntilSettled {
            spy.progressUpdates.last?.totalUnitCount == 8
        }

        // Asserted on the last update for the reason the pause case states: the cancel converges
        // through scheduling, and the surviving gallery's skipped scheduling converges again behind
        // it, so how many pushes land belongs to the convergence path rather than to this subject.
        let survivingPair = try lastPushedPair(spy.progressUpdates)
        #expect(survivingPair.completedUnitCount == 3)
        #expect(survivingPair.totalUnitCount == 8)
        #expect(survivingPair.subtitle == "3 / 8 pages · 1 gallery")
        // The numerator never reaches nine, on any push and on the start: that value is the whole
        // defect, and a series that merely ends correctly could still have shown it on the way.
        #expect(spy.startCompletedUnitCounts == [3])
        #expect(spy.progressUpdates.allSatisfy({ $0.completedUnitCount == 3 }))
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The other half of the basis: a redo the session *does* watch running earns its record back.
    ///
    /// Nothing here may be masked. The moment the redo's own manifest writes make the record
    /// incomplete its finished pages count raw, with no dependence on the trust set having caught
    /// up; and once the session has watched it doing real work, its completion flush reports the
    /// full count even though the record reads complete again by then. That second half is what
    /// keeps the cadence suite's pinned series intact, and it is what makes the drain here read six
    /// of six rather than rewinding to the zero this gallery opened at.
    ///
    /// The terminal count follows the same retirement: six pages retired is a positive retirement,
    /// so **D-G2C-01** keeps the redo named at the drain. The zero-retirement sibling —
    /// `testCancellingANeverStartedUpdateRetiresNothing`, the same gallery shape cancelled before it
    /// ran — drains to zero galleries instead, and the two together are the boundary.
    @Test
    func testARedoObservedRunningEarnsItsRecordBackAtTheDrain() async throws {
        let redo = SessionGallery(gid: "210300", title: "Redo", pageCount: 6, completedPageCount: 6)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(galleries: [redo], client: spy.client)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        // The redo's first manifest writes land: the record reads incomplete, so the basis counts
        // it raw on the very next push rather than waiting for the session to have trusted it.
        await patchManifest(of: redo, completedPageCount: 2, in: fixture)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let midRunPair = try lastPushedPair(spy.progressUpdates)
        #expect(midRunPair.completedUnitCount == 2)
        #expect(midRunPair.totalUnitCount == 6)
        #expect(midRunPair.subtitle == "2 / 6 pages · 1 gallery")

        await completeManifest(of: redo, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: redo.gid)
        await fixture.manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 1 gallery")
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// G-15-5 end to end, at the one missing page where the defect is deterministic.
    ///
    /// A `.repair` runs precisely because files are missing, yet before D-G5-01 the manifest went on
    /// claiming every page: `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
    /// and `ensureWorkingManifest` returns the valid manifest verbatim. `isIncomplete` stayed false,
    /// so D-G4-01's basis counted zero session pages for the whole run and the untrusted departure
    /// retired zero — a terminal `0 / 1 page · 0 galleries` reported with a successful completion.
    /// That is the maximally stalled reading D-11's expiration policy punishes by pausing every
    /// schedulable download, so 15-24 traded a pinned-100% card for a pinned-zero one.
    ///
    /// K=1 is the case record honesty alone cannot rescue, which is why the run-start announcement
    /// exists. Trust is admitted only inside a push's reconcile; the tap-time convergence push
    /// snapshots before the spawned run prepares its seed, and the single completion flush restores
    /// completeness before its own push. With one missing page there is no third push, so without
    /// the announcement the incomplete window is real on disk and observed by nobody.
    ///
    /// Every record state here comes from the disk contract or a production write — the fixture's
    /// complete manifest, the run's own preparation, the production flush — and every push is
    /// production-issued: the opening is read off `start`, the mid-run pair is the announcement's
    /// own, and the terminal is the drain's. The case owns only the macro-ordering production itself
    /// guarantees: prepare, then flush, then settle.
    ///
    /// **The payload is production-shaped (G-15-28).** This case drives `retryPages` too, so it
    /// belongs to the same double-building family as the two refusal cases: its route stores the
    /// single retried index in `queuedPageSelections`, and a production run reads that entry back
    /// into both payload steps. Carrying the selection moves nothing this case asserts, and the
    /// reason survived G-15-27's closure rather than depending on the gate ignoring the selection:
    /// the gate now reads the run's own pending page list, which honors that selection, and page 3
    /// — the retried one — is precisely the page whose file this staging leaves absent. The list is
    /// therefore non-empty and the announcement fires exactly as it did.
    @Test
    func testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull() async throws {
        let repair = SessionGallery(
            gid: "210310",
            title: "Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [repair],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: repair, in: fixture, indices: [1, 2, 4, 5, 6])
        await manager.reloadDownloadIndex()

        // Grounded in the production route rather than asserted about it: the missingFiles branch is
        // what turns a complete-reading record with a vanished file into a repair.
        let staged = try #require(await manager.fetchDownload(gid: repair.gid))
        #expect(staged.completedPageCount == 6)
        #expect(await manager.resumeMode(for: staged) == .repair)

        try await manager.retryPages(gid: repair.gid, pageIndices: [3]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        // The queued window still counts zero, which is D-G4-01's guarantee and not a regression:
        // nothing has run yet, so the manifest's six pages are the redo's target.
        #expect(spy.startSubtitles.last == "0 / 6 pages · 1 gallery")

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(repair.gid)_token] \(repair.title)"
        )
        // The index is this case's own `retryPages` set, so the payload carries what the route
        // stored rather than a selection typed independently of it.
        let payload = try await makeRetriedPagesPayload(
            for: repair,
            mode: .repair,
            retriedPageIndices: [3],
            coordinator: manager
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            folderURL: folderURL
        )

        #expect(await manager.fetchDownload(gid: repair.gid)?.completedPageCount == 5)
        // Asserted by presence rather than by position: a straggling convergence push may land on
        // either side of the preparation, and both values it can carry are admitted by the series
        // properties below.
        #expect(spy.progressUpdates.map(\.subtitle).contains("5 / 6 pages · 1 gallery"))

        let pageThreeRelativePath = fixture.storage.makePageRelativePath(
            gid: repair.gid,
            token: "token",
            index: 3,
            fileExtension: "jpg"
        )
        try Data("page-3".utf8).write(
            to: folderURL.appending(path: pageThreeRelativePath),
            options: .atomic
        )
        try await manager.flushManifestPageProgress(
            folderURL: folderURL,
            pages: [
                DownloadCoordinator.PageResult(
                    index: 3,
                    relativePath: pageThreeRelativePath,
                    imageURL: nil
                )
            ]
        )

        await manager.settleCompletedDownload(gid: repair.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
    }

    /// WR-03 folded into the closure: an announcement landing inside the client-start main-actor hop
    /// must act on the seeded state.
    ///
    /// This interleaving is reachable on the canonical `retryPages` route, where the run is scheduled
    /// before the trailing `ensureContinuedSession`. The announcement's push deliberately runs its
    /// reconcile ahead of the nil-client guard, so it records membership and trust while there is no
    /// card to paint. The seed precedes the hop, so that recording replaces the seeded observation
    /// instead of being overwritten by it. Seeded after the hop, the start assigned the opening
    /// snapshot over both collections: it saw a still-complete record, so the trust the announcement
    /// had just earned was discarded, and at one missing page that reproduced the pinned zero
    /// exactly.
    ///
    /// The gate makes the ordering a fact rather than a race: the start parks inside the spy, the
    /// production preparation runs against a coordinator whose session id is already stamped, and the
    /// start is released only afterwards. The drain reads six of six here.
    @Test
    func testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed() async throws {
        let repair = SessionGallery(
            gid: "210320",
            title: "Interleaved",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [repair],
            queuedGIDs: [repair.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        try writePageFiles(for: repair, in: fixture, indices: [1, 2, 4, 5, 6])
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: repair.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        let gate = spy.armStartGate()
        defer { gate.release() }
        let sessionStart = Task { await manager.testingEnsureContinuedSession() }
        await gate.entered()

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(repair.gid)_token] \(repair.title)"
        )
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: repair),
            folderURL: folderURL
        )

        #expect(await manager.fetchDownload(gid: repair.gid)?.completedPageCount == 5)
        // The announcement's push records its reconcile and then skips the card at the nil-client
        // guard, so the held-open hop paints nothing. Trust exists only in coordinator state here,
        // which is exactly why the seed's semantics decide the outcome.
        #expect(spy.progressUpdates.isEmpty)

        gate.release()
        await sessionStart.value

        let pageThreeRelativePath = fixture.storage.makePageRelativePath(
            gid: repair.gid,
            token: "token",
            index: 3,
            fileExtension: "jpg"
        )
        try Data("page-3".utf8).write(
            to: folderURL.appending(path: pageThreeRelativePath),
            options: .atomic
        )
        try await manager.flushManifestPageProgress(
            folderURL: folderURL,
            pages: [
                DownloadCoordinator.PageResult(
                    index: 3,
                    relativePath: pageThreeRelativePath,
                    imageURL: nil
                )
            ]
        )

        await manager.settleCompletedDownload(gid: repair.gid)
        await manager.scheduleNextIfNeeded()

        let terminalPair = try lastPushedPair(spy.progressUpdates)
        #expect(terminalPair.completedUnitCount == 6)
        #expect(terminalPair.totalUnitCount == 6)
        #expect(terminalPair.subtitle == "6 / 6 pages · 1 gallery")
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
    }
}
