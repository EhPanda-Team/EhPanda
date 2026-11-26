import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing
import TestingSupport

/// B-1 and B-2 (261117-tyj, owner decisions): a gallery the user deletes, singly or by deleting the
/// folder that holds it, leaves the continued session entirely. Its pages leave both X and Y, it
/// stops counting toward N whatever state it was in, and the numerator's monotonic floor gives back
/// exactly what the session counted for it, so later real work is not absorbed. Every other
/// departure keeps D-G2-01's retirement, which `DownloadContinuedSessionLedgerTests` pins.
///
/// Every case runs one fixture of two galleries, a 10-page `large` with 6 finished and a 4-page
/// `small` with none, so the opening card reads "6 of 14 pages in 2 galleries". Deletions are driven
/// through the coordinator's own `delete(gid:)` and `deleteFolder(name:)`, and the arithmetic is
/// asserted per regime: the pushes recorded before the deletion must never lose ground, the pair the
/// deletion leaves is asserted exactly (the one deliberate step back, which the series helper is not
/// meant to excuse), and later work on the survivor must then raise it. Absorption by a floor that
/// still counted the deleted pages is the failure the last step catches: it would read the deleted
/// gallery's six pages as `small`'s own progress until the survivor climbed back over them.
@Suite(.isolatedAppStorage)
struct DownloadContinuedSessionDeletionTests: DownloadFeatureTestCase {
    private static let large = SessionGallery(
        gid: "210500",
        title: "Large",
        pageCount: 10,
        completedPageCount: 6
    )
    private static let small = SessionGallery(gid: "210501", title: "Small", pageCount: 4)

    /// What the card owes once `large` is gone: only the survivor's pages and the survivor.
    private static let survivorOnlyPair = PushedPair(
        completedUnitCount: 0,
        totalUnitCount: 4,
        subtitle: "0 of 4 pages in 1 gallery"
    )

    /// The terminal pair of a session whose last gallery was deleted: the empty-denominator display
    /// clamp (`displayPageCount` floors at one page), with no gallery named.
    private static let drainedPair = PushedPair(
        completedUnitCount: 0,
        totalUnitCount: 1,
        subtitle: "0 of 1 page in 0 galleries"
    )

    /// How `large` left the queue before the user deleted it.
    enum PriorDeparture: CaseIterable {
        case paused
        case completed
    }

    /// The core rule, at the state the owner reported: a deleted gallery that had finished pages
    /// leaves X, Y and N, and the floor gives its six pages back.
    ///
    /// `6 of 6 pages in 1 gallery` is the absorbed reading this case exists to refuse: the ledger
    /// keeps the deleted gallery's six pages in both X and Y and the floor keeps them counted, so a
    /// survivor at two of four reads as six of six.
    @Test
    func testDeletingAGalleryWithFinishedPagesTakesItOutOfXYAndN() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try firstPushedPair(spy.progressUpdates).subtitle == "6 of 14 pages in 2 galleries")
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)

        try await manager.delete(gid: large.gid).get()

        #expect(try lastPushedPair(spy.progressUpdates) == Self.survivorOnlyPair)

        await patchManifest(of: small, completedPageCount: 2, in: fixture)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "2 of 4 pages in 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// A gallery that had already left the live set by another route is withdrawn from the ledger
    /// instead of from the live observation: paused, it is retired with its six pages, and completed
    /// and settled it is retired whole. Deleting either leaves the same survivor-only card.
    @Test(arguments: PriorDeparture.allCases)
    func testDeletingARetiredGalleryRemovesItsLedgerEntry(prior: PriorDeparture) async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        switch prior {
        case .paused:
            try await manager.pause(gid: large.gid).get()
            #expect(try lastPushedPair(spy.progressUpdates).subtitle == "6 of 10 pages in 2 galleries")
        case .completed:
            await completeManifest(of: large, in: fixture)
            await manager.settleCompletedDownload(gid: large.gid)
            await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
            #expect(try lastPushedPair(spy.progressUpdates).subtitle == "10 of 14 pages in 2 galleries")
        }
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)

        try await manager.delete(gid: large.gid).get()

        #expect(try lastPushedPair(spy.progressUpdates) == Self.survivorOnlyPair)

        await patchManifest(of: small, completedPageCount: 2, in: fixture)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "2 of 4 pages in 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// Deleting the only gallery drains the session. The terminal pair is the empty-denominator
    /// display clamp's (`displayPageCount` floors at one page), the same drain behavior as any
    /// emptied queue, with no gallery named and nothing rejected.
    @Test
    func testDeletingTheOnlyGalleryDrainsTheSessionAtZeroGalleries() async throws {
        let only = Self.large
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [only],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try firstPushedPair(spy.progressUpdates).subtitle == "6 of 10 pages in 1 gallery")
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)

        try await manager.delete(gid: only.gid).get()

        #expect(try lastPushedPair(spy.progressUpdates) == Self.drainedPair)
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// The deletion cancels the gallery's own run: a parked run the coordinator observed through a
    /// push, released by its cancellation. It leaves X, Y and N like any other, and the survivor's
    /// later work is not absorbed.
    @Test
    func testDeletingTheActiveGalleryLeavesTheSession() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
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
        #expect(await manager.testingActiveGalleryID() == large.gid)

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "6 of 14 pages in 2 galleries")
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)

        try await manager.delete(gid: large.gid).get()
        await control.cancellationObserved()

        #expect(try lastPushedPair(spy.progressUpdates) == Self.survivorOnlyPair)

        await patchManifest(of: small, completedPageCount: 2, in: fixture)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "2 of 4 pages in 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// B-3: a deletion landing inside the session start's client hop. The start gate parks the
    /// client start, the deletion runs to completion inside it, and the start is released
    /// afterwards. The submission still reads the opening snapshot (it was fixed before the hop),
    /// and the first push after it already leaves the deleted gallery out.
    ///
    /// This is the case that fails when the seed follows the hop instead of preceding it: the
    /// deletion then finds nothing to withdraw, and the post-hop seed re-installs the deleted
    /// gallery from the stale snapshot, so the next reconcile retires its six pages back into X, Y
    /// and N.
    @Test
    func testADeletionInsideTheClientStartHopLeavesTheSession() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        let gate = spy.armStartGate()
        defer { gate.release() }
        let sessionStart = Task { await manager.testingEnsureContinuedSession() }
        await gate.entered()

        try await manager.delete(gid: large.gid).get()

        gate.release()
        await sessionStart.value
        #expect(spy.startSubtitles == ["6 of 14 pages in 2 galleries"])

        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates) == Self.survivorOnlyPair)

        await patchManifest(of: small, completedPageCount: 2, in: fixture)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "2 of 4 pages in 1 gallery")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// A deleted gid downloaded again in the same session counts only its new work: the
    /// predecessor's observation is gone and its generation stamp cannot credit the successor
    /// (every queue-mobilizing entrance advances the intent generation, CR-02).
    @Test
    func testARejoiningDeletedGalleryCountsOnlyItsNewWork() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        try await manager.delete(gid: large.gid).get()
        #expect(try lastPushedPair(spy.progressUpdates) == Self.survivorOnlyPair)

        try await manager.enqueue(payload: makeStartPayload(for: large, mode: .redownload)).get()
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "0 of 14 pages in 2 galleries")

        await patchManifest(
            of: SessionGallery(gid: large.gid, title: large.title, pageCount: large.pageCount),
            completedPageCount: 3,
            in: fixture
        )
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "3 of 14 pages in 2 galleries")
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    /// B-2: deleting the folder that holds both galleries is a user deletion too. Each gallery it
    /// removes leaves the session, so the session drains at zero galleries instead of retiring
    /// `large`'s six pages into a card that names it.
    @Test
    func testDeletingAFolderTakesEveryGalleryInItOutOfTheSession() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try firstPushedPair(spy.progressUpdates).subtitle == "6 of 14 pages in 2 galleries")
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)

        try await manager.deleteFolder(name: "Folder").get()

        #expect(try lastPushedPair(spy.progressUpdates) == Self.drainedPair)
        #expect(spy.finishSuccesses == [true])
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }
}
