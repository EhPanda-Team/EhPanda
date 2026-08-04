import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The multi-gallery half of the continued session's arithmetic: what the card reports as galleries
/// leave the schedulable set — by finishing, by being paused, by being deleted — and what it
/// reports when one of them comes back.
///
/// A new file rather than more cases in `DownloadContinuedSessionTests.swift` for a concrete
/// reason: that file already sits past 900 lines against a `file_length` limit of 1000 at error
/// severity, so the coverage this gap needs does not fit there.
///
/// A completion is staged the way the product does it — patch the gallery's record to a complete
/// manifest through the same index seam a page flush uses, then call `settleCompletedDownload(gid:)`,
/// which is what removes it from the queue store — and progress is pushed explicitly between steps,
/// so the recorded update list is a fact about the arithmetic rather than about scheduling timing.
///
/// A pause and a delete are driven through the coordinator's own `pause(gid:)` and `delete(gid:)`
/// instead, because those cases exist to prove the product's entry points reach the ledger. Both
/// converge on `scheduleNextIfNeeded`, whose tail reconciles the session, so those cases assert the
/// last recorded update rather than a list of them.
@Suite
struct DownloadContinuedSessionLedgerTests: DownloadFeatureTestCase {
    /// The pair a drained three-gallery queue owes, whatever order its galleries finished in.
    ///
    /// Both drains below assert their final push against this one value, so an ordering dependence
    /// fails whichever order introduced it. Comparing one run's last update against the other's
    /// directly would need a second full fixture inside a single case and would discriminate no
    /// better, while pinning the value here also states what the drain is worth.
    static let drainedPair = PushedPair(
        completedUnitCount: 20,
        totalUnitCount: 20,
        subtitle: "20 / 20 pages · 0 galleries"
    )

    /// The pair both departure paths owe once a 10-page gallery with 6 finished has left a queue
    /// that also holds an untouched 4-page gallery.
    ///
    /// Named once and asserted from both cases, so a pause and a delete are pinned to each other
    /// rather than to two copies of one literal. The ledger reaches this value by different routes:
    /// the paused gallery still has a record to read, while the deleted one has none and is worth
    /// only what the last observation says it finished. D-G2-01 is precisely the claim that those
    /// two routes cannot disagree.
    static let departedPair = PushedPair(
        completedUnitCount: 6,
        totalUnitCount: 10,
        subtitle: "6 / 10 pages · 1 gallery"
    )

    /// Everything about a pushed update except the session identity it rode on, so two runs driven
    /// by different sessions compare directly.
    struct PushedPair: Equatable {
        let completedUnitCount: Int64
        let totalUnitCount: Int64
        let subtitle: String
    }

    /// The direct regression for the device-reported gap, at full size: three queued galleries, and
    /// the largest finishes first.
    ///
    /// Under the old basis the second push already read 10 of 10 pages with the queue two thirds
    /// full, because a completed gallery's pages left the numerator and the denominator together.
    /// The ledger puts them back on both sides, so the total holds at 20 across every completion
    /// while the count climbs.
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

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: large, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: large.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: middle, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: middle.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: small, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: small.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.completedUnitCount) == [0, 10, 16, 20])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [20, 20, 20, 20])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "0 / 20 pages · 3 galleries",
            "10 / 20 pages · 2 galleries",
            "16 / 20 pages · 1 gallery",
            "20 / 20 pages · 0 galleries"
        ])
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
        let finalPair = try lastPushedPair(spy.progressUpdates)
        #expect(finalPair == Self.drainedPair)
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

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: small, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: small.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: middle, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: middle.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await completeManifest(of: large, in: fixture)
        await fixture.manager.settleCompletedDownload(gid: large.gid)
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.completedUnitCount) == [0, 4, 10, 20])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [20, 20, 20, 20])
        try expectTheFractionReachesOneOnlyAtTheDrain(spy.progressUpdates)
        let finalPair = try lastPushedPair(spy.progressUpdates)
        #expect(finalPair == Self.drainedPair)
    }

    /// The zero-denominator guard, inherited from `testEmptySchedulableSetStillPushesAPositiveTotal`
    /// in `DownloadContinuedSessionTests`.
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

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        // A departure with nothing to retire, which is the only way both sides reach zero now.
        await fixture.manager.testingSetQueuedGalleryIDs([])
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

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

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

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
        #expect(pausedPair.subtitle == "6 / 10 pages · 1 gallery")
        #expect(pausedPair == Self.departedPair)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
        // A pause must never be able to report the session finished.
        #expect(pausedPair.completedUnitCount < pausedPair.totalUnitCount)
    }

    /// D-G2-01 on the delete path, which is the one with no record left to read.
    ///
    /// Deleting removes the gallery's folders and takes it out of the index, so the ledger cannot
    /// ask what it finished and falls back to the last observation. Both wrong answers are
    /// available there: dropping the six pages rewinds the numerator, and promoting the gallery to
    /// its full 10 pages claims work that was never done. The pair is asserted against the pause
    /// case's own constant as well as its literal, because a delete accounted differently from a
    /// pause would mean the single formula D-G2-01 describes had quietly become two.
    @Test
    func testDeletedGalleryRetiresTheSamePagesAsAPause() async throws {
        let large = SessionGallery(
            gid: "210240",
            title: "Deleted",
            pageCount: 10,
            completedPageCount: 6
        )
        let small = SessionGallery(gid: "210241", title: "Surviving", pageCount: 4)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        let openingPair = try firstPushedPair(spy.progressUpdates)
        #expect(openingPair.completedUnitCount == 6)
        #expect(openingPair.totalUnitCount == 14)
        #expect(openingPair.subtitle == "6 / 14 pages · 2 galleries")

        try await fixture.manager.delete(gid: large.gid).get()

        let deletedPair = try lastPushedPair(spy.progressUpdates)
        #expect(deletedPair.completedUnitCount == 6)
        #expect(deletedPair.totalUnitCount == 10)
        #expect(deletedPair.subtitle == "6 / 10 pages · 1 gallery")
        #expect(deletedPair == Self.departedPair)
        expectTheCompletedSeriesNeverRewinds(spy.progressUpdates)
        #expect(deletedPair.completedUnitCount < deletedPair.totalUnitCount)
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionLedgerTests {
    /// Patches one gallery's record to an all-hashed, complete manifest through the index seam a
    /// page flush writes through. The caller settles it afterwards, which is the queue-store
    /// removal that actually makes it leave the schedulable set.
    func completeManifest(
        of gallery: SessionGallery,
        in fixture: SessionFixture
    ) async {
        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
            ),
            manifest: manifest(
                for: SessionGallery(
                    gid: gallery.gid,
                    title: gallery.title,
                    pageCount: gallery.pageCount,
                    completedPageCount: gallery.pageCount
                )
            )
        )
    }

    /// Every push but the last is strictly below its own total, and the last is exactly equal.
    ///
    /// Written over the recorded list rather than as four hand-written comparisons, so a fifth push
    /// appearing later cannot slip past it. The final pair being exactly `20 / 20` rather than
    /// `20 / 21` is also this suite's half of the clamp-ordering canary: if the retired total is
    /// ever added to a denominator `displayPageCount` has already floored at one page, every drain
    /// comes out one page high. That is a wrong operand in the push, never a wrong expectation
    /// here.
    func expectTheFractionReachesOneOnlyAtTheDrain(
        _ updates: [BackgroundProcessingClientSpy.ProgressUpdate]
    ) throws {
        for update in updates.dropLast() {
            #expect(update.completedUnitCount < update.totalUnitCount)
        }
        let drain = try #require(updates.last)
        #expect(drain.completedUnitCount == drain.totalUnitCount)
    }

    /// The numerator never goes backwards, whatever else moved.
    ///
    /// Written over adjacent pairs rather than as a comparison of the first and last update: a
    /// rewind that is later recovered is still a rewind, and it is exactly what the scheduler reads
    /// as a task losing ground.
    func expectTheCompletedSeriesNeverRewinds(
        _ updates: [BackgroundProcessingClientSpy.ProgressUpdate]
    ) {
        for (earlier, later) in zip(updates, updates.dropFirst()) {
            #expect(earlier.completedUnitCount <= later.completedUnitCount)
        }
    }

    func firstPushedPair(
        _ updates: [BackgroundProcessingClientSpy.ProgressUpdate]
    ) throws -> PushedPair {
        try pushedPair(#require(updates.first))
    }

    func lastPushedPair(
        _ updates: [BackgroundProcessingClientSpy.ProgressUpdate]
    ) throws -> PushedPair {
        try pushedPair(#require(updates.last))
    }

    func pushedPair(
        _ update: BackgroundProcessingClientSpy.ProgressUpdate
    ) -> PushedPair {
        PushedPair(
            completedUnitCount: update.completedUnitCount,
            totalUnitCount: update.totalUnitCount,
            subtitle: update.subtitle
        )
    }
}
