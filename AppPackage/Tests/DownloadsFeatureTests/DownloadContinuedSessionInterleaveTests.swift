import AppModels
import BackgroundProcessingClient
import CustomDump
import DownloadClient
import Foundation
import Testing

/// Pins the suspension window where expiration settlement and a newer user action interleave.
///
/// An expiration settling across its own suspensions must not erase an action that arrived inside
/// that window. The file also pins the drain-versus-mobilization window: work landing inside the
/// drain's own terminal push must not be torn down by the drain that was decided before it. These
/// cases live outside the coordinator suite because that file sits against the project's hard
/// file-length boundary.
@Suite
struct DownloadContinuedSessionInterleaveTests: DownloadFeatureTestCase {
    /// CR-03 / WR-01 replacement: start, expire, hold the resulting pause after cancellation,
    /// retry inside that hold, release, and verify the retry both survives and mobilizes the queue.
    /// Before the generation guard, the stale settled write cleared the fresh intent and left a
    /// successful tap with neither running work nor the continued-processing session it requested.
    @Test
    func testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue() async throws {
        let gid = "210190"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeBlockingCoordinator(
            gid: gid,
            title: "Expiration interleave",
            backgroundProcessingClient: spy.client,
            releasesOnCancellation: false
        )
        defer { removeTemporaryItem(at: context.rootURL) }
        defer { context.control.release() }
        let queueStore = DownloadQueueStore(fileURL: context.storage.queueURL())

        await context.manager.testingEnsureContinuedSession()
        let sessionTask = try #require(await context.manager.testingContinuedSessionTask())
        #expect(spy.startCount == 1)

        try await context.manager.resume(gid: gid).get()
        await context.control.started()

        // Expire through the seam so the spy releases the same live-session identity the real
        // store releases before delivering its terminal event. Injecting the event directly would
        // describe an impossible client contract while leaving the predecessor artificially held.
        spy.expire()
        await context.control.cancellationObserved()

        try await context.manager.retry(gid: gid, mode: .initial).get()
        #expect(spy.startCount == 1)

        context.control.release()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "expiration settlement after the interleaved retry"
        )

        #expect(queueStore.contains(gid))
        #expect(await context.manager.queuedModes[gid] == .initial)
        #expect(spy.startCount == 2)
        #expect(await context.manager.testingHasContinuedSession())
        let mostRecentStartID = try #require(spy.startSessionIDs.last)
        #expect(
            spy.finishRecords.contains(where: { $0.sessionID == mostRecentStartID }) == false
        )
    }

    /// Keeps the generation guard scoped to expiration ownership: a user pause does not yield to
    /// an action that arrives while its cancellation is suspended. Widening the guard to every
    /// pause would reverse last-writer-wins behavior and make an explicit pause unreliable.
    @Test
    func testAUserPauseIsNeverAbandonedByAnInterleavingRetry() async throws {
        let gid = "210191"
        let context = try await makeBlockingCoordinator(
            gid: gid,
            title: "User pause interleave",
            releasesOnCancellation: false
        )
        defer { removeTemporaryItem(at: context.rootURL) }
        defer { context.control.release() }
        let queueStore = DownloadQueueStore(fileURL: context.storage.queueURL())

        try await context.manager.resume(gid: gid).get()
        await context.control.started()

        let pause = Task { @concurrent in
            await context.manager.pause(gid: gid)
        }
        await context.control.cancellationObserved()

        try await context.manager.retry(gid: gid, mode: .initial).get()
        #expect(queueStore.contains(gid))
        #expect(await context.manager.queuedModes[gid] == .initial)

        context.control.release()
        try await pause.value.get()

        #expect(queueStore.contains(gid) == false)
        #expect(await context.manager.queuedModes[gid] == nil)
    }

    /// G-15-3 / D-G3-01: a queue-mobilizing action landing inside the drain's terminal push leaves
    /// the session alive.
    ///
    /// The push crosses the client seam's main-actor hop, so the drain decision taken before it is
    /// stale by the time it resumes. The retry staged inside that window folds into this session —
    /// its own `ensureContinuedSession` is inert while the liveness flag is set — so a drain that
    /// completed on its pre-push observation would surrender coverage with no path to get it back
    /// before the next qualifying tap (D-03: no fallback tier).
    ///
    /// The race is reached through `pause`'s own convergence rather than a directly-invoked push,
    /// so what is pinned here is the production drain, not a hand-built approximation of it.
    @Test
    func testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain() async throws {
        let drainingGID = "210192"
        let mobilizedGID = "210193"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: drainingGID, title: "Draining", pageCount: 5, completedPageCount: 1),
                .init(gid: mobilizedGID, title: "Mobilized", pageCount: 4)
            ],
            queuedGIDs: [drainingGID],
            client: spy.client,
            // Inert, so the mid-race schedule of the mobilized gallery installs an active task
            // without performing a download underneath the assertions.
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        _ = try #require(await fixture.manager.testingContinuedSessionID())
        #expect(spy.startCount == 1)

        let gate = spy.armProgressGate()
        defer { gate.release() }
        // Pausing the only queued gallery empties the queue and converges on the scheduling tail,
        // whose drain branch parks its terminal push on the armed gate.
        let drainingPause = Task { @concurrent in
            await fixture.manager.pause(gid: drainingGID)
        }
        await gate.entered()

        // Mid-hop: the coordinator's actor is free while the push is parked at the seam, so this
        // whole retry runs inside the drain's one suspension.
        try await fixture.manager.retry(gid: mobilizedGID, mode: .initial).get()
        // The retry pushes once through its own convergence, and the inert runner's completion
        // tail converges again; both land before the release so the pinned order below is settled
        // rather than raced.
        try await waitUntil { spy.progressUpdates.count == 2 }

        gate.release()
        _ = await drainingPause.value

        #expect(spy.finishRecords.isEmpty)
        #expect(await fixture.manager.testingHasContinuedSession())
        #expect(spy.startCount == 1)
        #expect(spy.rejectedProgressUpdates.isEmpty)

        // No zombie: the surviving session still completes when the queue genuinely drains.
        _ = await fixture.manager.pause(gid: mobilizedGID)
        #expect(spy.finishSuccesses == [true])
        #expect(await fixture.manager.testingHasContinuedSession() == false)
        expectNoDifference(
            spy.progressUpdates.map(\.subtitle),
            [
                // The mobilized gallery joins: its four pages plus the drained gallery's one
                // retired page.
                "1 / 5 pages · 1 gallery",
                "1 / 5 pages · 1 gallery",
                // The released parked push, whose arguments were computed at the drain — the
                // terminal-shaped transient D-G3-01 accepts rather than removes.
                "1 / 1 page · 0 galleries",
                // The genuine drain, which retires the mobilized gallery at zero finished pages.
                "1 / 1 page · 0 galleries"
            ]
        )
    }
}
