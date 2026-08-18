import BackgroundProcessingClient
import Clocks
import DownloadClient
import Foundation
import Testing

/// The coordinator-owned heartbeat that re-pushes a live session's current pair (G-15-2D).
///
/// **What it is for.** Progress reaches the card only when a page lands, and the shipped worker
/// count is one — so a single slow page freezes the numerator for as long as that page takes, and
/// the scheduler force-expires the tasks reporting the least progress. Re-pushing the same pair
/// every ten seconds says "still working" without inventing progress.
///
/// Every case drives an injected `TestClock`, so nothing here sleeps. The two NEGATIVE cases prove
/// the heartbeat is live FIRST — by making it fire once — and only then remove its reason to beat:
/// a negative assertion over a clock whose sleeper was never registered would pass vacuously.
@Suite
struct DownloadContinuedSessionHeartbeatTests: DownloadFeatureTestCase {
    @Test
    func heartbeatRePushesTheCurrentPairWhileTheSessionIsLive() async throws {
        let gallery = SessionGallery(gid: "230010", title: "Heartbeat", pageCount: 6, completedPageCount: 2)
        let spy = BackgroundProcessingClientSpy()
        let clock = TestClock()
        let fixture = try await makeClockedFixture(gallery: gallery, client: spy.client, clock: clock)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        let seeded = try #require(spy.progressUpdates.last)

        try await beat(clock, until: { spy.progressUpdates.count > 1 })

        let beaten = try #require(spy.progressUpdates.last)
        // The SAME pair, re-issued: a heartbeat reports liveness, never progress.
        #expect(beaten.completedUnitCount == seeded.completedUnitCount)
        #expect(beaten.totalUnitCount == seeded.totalUnitCount)
        #expect(beaten.subtitle == seeded.subtitle)

        _ = await fixture.manager.pause(gid: gallery.gid)
    }

    @Test
    func heartbeatStopsWhenTheSessionEnds() async throws {
        let gallery = SessionGallery(gid: "230020", title: "Heartbeat", pageCount: 6, completedPageCount: 2)
        let spy = BackgroundProcessingClientSpy()
        let clock = TestClock()
        let fixture = try await makeClockedFixture(gallery: gallery, client: spy.client, clock: clock)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        try await beat(clock, until: { spy.progressUpdates.isEmpty == false })

        let sessionTask = try #require(await fixture.manager.testingContinuedSessionTask())
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish after expiration"
        )
        let settled = spy.progressUpdates.count

        await advance(clock, by: .seconds(10), times: 3)

        #expect(spy.progressUpdates.count == settled)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }

    /// The beat is gated on the queue having pending work, so a session that is live but has
    /// nothing left to do reports nothing — and stays live, because ending it is a drain's job.
    ///
    /// The queue is emptied WITHOUT driving a convergence on purpose: a convergence over an empty
    /// queue drains and completes the session, which is a different case entirely.
    @Test
    func heartbeatIsIdleWithoutPendingWork() async throws {
        let gallery = SessionGallery(gid: "230030", title: "Heartbeat", pageCount: 6, completedPageCount: 2)
        let spy = BackgroundProcessingClientSpy()
        let clock = TestClock()
        let fixture = try await makeClockedFixture(gallery: gallery, client: spy.client, clock: clock)
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        try await beat(clock, until: { spy.progressUpdates.isEmpty == false })
        let beforeIdle = spy.progressUpdates.count

        await fixture.manager.testingSetQueuedGalleryIDs([])
        await advance(clock, by: .seconds(10), times: 3)

        #expect(spy.progressUpdates.count == beforeIdle)
        #expect(await fixture.manager.testingHasContinuedSession())
    }
}

// MARK: - Fixture

private extension DownloadContinuedSessionHeartbeatTests {
    /// One queued gallery on disk, over an injected clock and a constant environment probe.
    ///
    /// Built here rather than through the shared queued-coordinator helper because that helper
    /// exposes no clock seam, and because the shared helpers file sits against its `file_length`
    /// gate. The environment probe is a constant so the session's start line cannot depend on the
    /// host's real network or thermal state.
    func makeClockedFixture(
        gallery: SessionGallery,
        client: BackgroundProcessingClient,
        clock: any Clock<Duration>
    ) async throws -> SessionFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundProcessingClient: client,
            clock: clock,
            environmentProbe: .constant(
                DownloadEnvironmentSnapshot(
                    network: .wifi,
                    isLowPowerModeEnabled: false,
                    thermalState: .nominal
                )
            )
        )

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try storage.writeManifest(manifest(for: gallery), folderURL: folderURL)
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gallery.gid])
        return SessionFixture(manager: manager, storage: storage, rootURL: rootURL)
    }

    /// Advances the clock until `condition` holds.
    ///
    /// Advancing repeatedly rather than once is what removes the race between this case and the
    /// heartbeat task registering its sleeper: an advance that finds no sleeper is a no-op, and the
    /// next one lands. It returns the moment the condition holds, so a healthy run costs nothing.
    func beat(_ clock: TestClock<Duration>, until condition: @escaping @Sendable () -> Bool) async throws {
        try await waitUntil {
            await clock.advance(by: .seconds(10))
            return condition()
        }
    }

    /// Advances the clock a fixed number of times, for the NEGATIVE cases: they must state how far
    /// the clock moved rather than poll for something that must never happen.
    func advance(_ clock: TestClock<Duration>, by duration: Duration, times: Int) async {
        for _ in 0..<times {
            await clock.advance(by: duration)
            await Task.yield()
        }
    }
}
