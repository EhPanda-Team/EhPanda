import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The multi-gallery half of the continued session's arithmetic: what the card reports as galleries
/// finish one after another and the queue drains.
///
/// A new file rather than more cases in `DownloadContinuedSessionTests.swift` for a concrete
/// reason: that file already sits past 900 lines against a `file_length` limit of 1000 at error
/// severity, so the coverage this gap needs does not fit there.
///
/// Every case stages a completion the way the product does — patch the gallery's record to a
/// complete manifest through the same index seam a page flush uses, then call
/// `settleCompletedDownload(gid:)`, which is what removes it from the queue store — and pushes
/// progress explicitly between steps, so the recorded update list is a fact about the arithmetic
/// rather than about scheduling timing.
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

    func lastPushedPair(
        _ updates: [BackgroundProcessingClientSpy.ProgressUpdate]
    ) throws -> PushedPair {
        let update = try #require(updates.last)
        return PushedPair(
            completedUnitCount: update.completedUnitCount,
            totalUnitCount: update.totalUnitCount,
            subtitle: update.subtitle
        )
    }
}
