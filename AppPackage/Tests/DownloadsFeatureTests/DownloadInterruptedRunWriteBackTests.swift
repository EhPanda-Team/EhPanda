import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// G-20-09-1: a whole-gallery repair stopped part-way must leave its record reading the work it
/// actually did, not the ceiling it claimed before the run began.
///
/// The staging is the wholesale-refusal family. A record claims every page while none of its files
/// is on disk, so the preparation's reconciliation refuses to blank the whole manifest on one scan
/// (G-15-2G) and the record goes on reading N-of-N for the entire re-download; the run's own
/// measurement is what the row shows while it stands (D-SSOT-10). The flush path only ever ASSIGNS
/// hashes, so nothing during the run can lower that claim either. Before the fix the run's exit
/// retired the measurement and left the record as it was, so a paused repair with three of six pages
/// on disk read "Downloaded 6 of 6", with Resume disabled because the record looked finished — the
/// device finding on the owner's test iPhone (owner msg 2893).
///
/// **Every stop goes through production.** The run is a REAL scheduled run: the injected runner parks
/// until the pause cancels it and then invokes the operation it was handed, which is the scheduler's
/// own `processDownload(gid:generation:)` at the stamped generation, so the exit under test is the
/// run's real `defer`. The measurement is announced by `prepareWorkingSeedAnnouncingProgress`, pages
/// land through the production flush, and the stop is the product's own pause or the D-11
/// expiration's bulk pause.
@Suite
struct DownloadInterruptedRunWriteBackTests: DownloadFeatureTestCase {
    /// The reported defect, through the in-app Pause.
    @Test
    func testAPausedWholeGalleryRepairReadsTheWorkItActuallyDid() async throws {
        let gallery = SessionGallery(
            gid: "200901-a",
            title: "Paused Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let control = BlockingRunnerControl()
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeParkedRepairFixture(
            gallery: gallery,
            client: .noop,
            control: control,
            stubSessionID: stubSessionID
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager
        try await startRepairAndLandPages([1, 2, 3], of: gallery, in: fixture, control: control)

        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectThePausedRecordReads(landedPages: [1, 2, 3], of: gallery, manager: manager)
    }

    /// The same defect through the continued-processing card's cancel, which the system reports as
    /// an expiration: D-11's bulk pause reaches `commitPause` exactly as the in-app Pause does, and
    /// the device run showed the two leaving the same stale row.
    @Test
    func testAnExpirationPausedWholeGalleryRepairReadsTheWorkItActuallyDid() async throws {
        let gallery = SessionGallery(
            gid: "200901-b",
            title: "Expired Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeParkedRepairFixture(
            gallery: gallery,
            client: spy.client,
            control: control,
            stubSessionID: stubSessionID
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager
        try await startRepairAndLandPages([1, 2, 3], of: gallery, in: fixture, control: control)
        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())

        await manager.testingPauseAllSchedulable(expiring: sessionID)
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectThePausedRecordReads(landedPages: [1, 2, 3], of: gallery, manager: manager)
    }

    /// K0-a: a repair stopped after its measurement was announced but before ANY page landed reads
    /// Paused 0 of N with Resume, not the whole-gallery claim it started from (product lead, EhPanda
    /// msg 2901).
    ///
    /// With nothing on disk every claimed page is a positive absence, so the all-or-nothing guard
    /// alone would refuse here exactly as it refused at the preparation. What licenses the blanking is
    /// the corroboration: the run's own preparation scan already found every one of these pages
    /// positively absent (it owes them and inherits none of them), and the exit's fresh scan agrees.
    /// Two successful scans are not the single transient scan G-15-2G guards against, and the
    /// validation and preparation callers are untouched.
    @Test
    func testARepairPausedBeforeAnyPageLandedReadsZeroOfN() async throws {
        let gallery = SessionGallery(
            gid: "200901-c",
            title: "Unstarted Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let control = BlockingRunnerControl()
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeParkedRepairFixture(
            gallery: gallery,
            client: .noop,
            control: control,
            stubSessionID: stubSessionID
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager
        try await startRepairAndLandPages([], of: gallery, in: fixture, control: control)

        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectThePausedRecordReads(landedPages: [], of: gallery, manager: manager)
    }

    /// K0-a through the card's cancel: the expiration's bulk pause reaches the same exit.
    @Test
    func testAnExpirationPausedRepairBeforeAnyPageLandedReadsZeroOfN() async throws {
        let gallery = SessionGallery(
            gid: "200901-d",
            title: "Unstarted Expired Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeParkedRepairFixture(
            gallery: gallery,
            client: spy.client,
            control: control,
            stubSessionID: stubSessionID
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager
        try await startRepairAndLandPages([], of: gallery, in: fixture, control: control)
        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())

        await manager.testingPauseAllSchedulable(expiring: sessionID)
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectThePausedRecordReads(landedPages: [], of: gallery, manager: manager)
    }

    /// A repair stopped before its measurement was announced (K0-b, the payload-fetch window) has no
    /// scan of its own to corroborate anything, so WITHOUT Verify's evidence the record keeps its
    /// pre-repair claim. One fresh scan alone is never authority to blank a whole gallery (G-15-2G).
    /// With Verify's evidence the stop corroborates it instead: `DownloadWholesaleAbsenceTests`.
    @Test
    func testARepairPausedBeforeItsAnnouncementKeepsItsRecord() async throws {
        let gallery = SessionGallery(
            gid: "200901-e",
            title: "Unannounced Repair",
            pageCount: 6,
            completedPageCount: 6
        )
        let control = BlockingRunnerControl()
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeParkedRepairFixture(
            gallery: gallery,
            client: .noop,
            control: control,
            stubSessionID: stubSessionID
        )
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }
        let manager = fixture.manager
        let staged = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)
        await manager.scheduleNextIfNeeded()
        await control.started()
        #expect(await manager.testingActiveGalleryID() == gallery.gid)

        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        let paused = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(paused.runProgress == nil)
        #expect(paused.completedPageCount == 6)
        #expect(paused.manifest.pages.values.allSatisfy({ !$0.isEmpty }))
        #expect(await manager.resumeMode(for: paused) == .repair)
    }
}

// MARK: - Helpers

private extension DownloadInterruptedRunWriteBackTests {
    /// A complete-claiming record with no page file on disk, queued, behind a runner that parks
    /// until it is cancelled and then runs the real operation it was handed.
    ///
    /// The runner deliberately does NOT return `.skippedOperation`: the run's exit is the subject, and
    /// only the operation reaches `processDownload`'s `defer`. Run after the cancellation, the
    /// operation's first live request fails at once, so the stub only guarantees that nothing reaches
    /// the network.
    func makeParkedRepairFixture(
        gallery: SessionGallery,
        client: BackgroundProcessingClient,
        control: BlockingRunnerControl,
        stubSessionID: String
    ) async throws -> SessionFixture {
        try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [gallery.gid],
            client: client,
            taskRunner: DownloadTaskRunner(
                runScheduledDownload: { _, operation in
                    await withTaskCancellationHandler {
                        await control.park()
                    } onCancel: {
                        control.recordCancellation()
                        control.release()
                    }
                    await operation()
                    return .ranOperation
                }
            ),
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
    }

    /// An offline stub for the run's detail request; the caller removes it when the case ends.
    func makeOfflineStub() -> String {
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        return stubSessionID
    }

    /// Schedules the repair, announces its measurement and lands `indices` through the production
    /// flush, asserting on the way that the record really claimed every page throughout — the
    /// non-vacuity a three-of-six outcome needs, since otherwise the record could have read three
    /// before the stop did anything.
    func startRepairAndLandPages(
        _ indices: [Int],
        of gallery: SessionGallery,
        in fixture: SessionFixture,
        control: BlockingRunnerControl
    ) async throws {
        let manager = fixture.manager
        let staged = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        await manager.scheduleNextIfNeeded()
        await control.started()
        #expect(await manager.testingActiveGalleryID() == gallery.gid)

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: gallery),
            folderURL: folderURL
        )
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])
        // The refusal refused: one scan found no file at all, so nothing was blanked.
        #expect(await manager.fetchDownload(gid: gallery.gid)?.completedPageCount == 6)

        guard !indices.isEmpty else { return }
        try writePageFiles(for: gallery, in: fixture, indices: indices)
        var pendingResolvedPages = pageResults(for: gallery, in: fixture, indices: indices)
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: gallery.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        let midRun = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(midRun.runProgress?.creditedPageIndices == Set(indices))
        // The record cannot follow the run upward: it claimed every page before any landed.
        #expect(midRun.completedPageCount == 6)
    }

    /// What a stopped repair of a six-page gallery with `landedPages` on disk must read, live and
    /// after a reload from disk: Paused k of 6 with Resume.
    func expectThePausedRecordReads(
        landedPages: [Int],
        of gallery: SessionGallery,
        manager: DownloadCoordinator
    ) async throws {
        let landedCount = landedPages.count
        let paused = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(paused.runProgress == nil)
        #expect(paused.completedPageCount == landedCount)
        #expect(paused.isIncomplete)
        #expect(paused.displayStatus == .inactive)
        #expect(paused.canTogglePause)
        #expect(
            paused.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: landedCount, pageCount: 6)
            )
        )
        #expect(await manager.resumeMode(for: paused) == .repair)
        // Only the absences were blanked: the landed pages keep their recorded hashes.
        #expect(paused.manifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == landedPages)

        // Persisted rather than held in memory: a cold reload reads the same record off disk.
        await manager.reloadDownloadIndex()
        let reloaded = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(reloaded.completedPageCount == landedCount)
        #expect(reloaded.isIncomplete)
        #expect(reloaded.displayStatus == .inactive)
    }
}
