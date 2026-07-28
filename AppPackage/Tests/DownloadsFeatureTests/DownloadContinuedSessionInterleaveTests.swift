import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// Pins the suspension window where expiration settlement and a newer user action interleave.
///
/// An expiration settling across its own suspensions must not erase an action that arrived inside
/// that window. These cases live outside the coordinator suite because that file sits against the
/// project's hard file-length boundary.
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

        await context.manager.ensureContinuedSession()
        let expiringSessionID = try #require(
            await context.manager.testingContinuedSessionID()
        )
        #expect(spy.startCount == 1)

        try await context.manager.resume(gid: gid).get()
        await context.control.started()

        let expiration = Task { @concurrent in
            await context.manager.handleContinuedSessionEvent(
                .expired,
                sessionID: expiringSessionID
            )
        }
        await context.control.cancellationObserved()

        try await context.manager.retry(gid: gid, mode: .initial).get()
        #expect(spy.startCount == 1)

        context.control.release()
        await expiration.value

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
}
