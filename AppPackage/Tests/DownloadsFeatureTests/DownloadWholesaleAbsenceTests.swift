import AppModels
import BackgroundProcessingClient
import Clocks
import DownloadClient
import Foundation
import Testing

/// B1 (product lead, EhPanda msg 2903): a whole-gallery repair stopped before its run ever scanned
/// the folder reads Paused 0 of N with Resume, not "Downloaded N of N".
///
/// Two stops have no run evidence of their own: a pause during the payload fetch, before the run's
/// measurement is announced (K0-b), and a pause while the repair is still queued behind another
/// gallery (K0-c), which reaches `commitPause` without any run exiting. What licenses dropping the
/// record there is two independent fresh scans agreeing: Verify Images' full scan found every
/// claimed page positively absent, and the stop takes its own fresh scan that finds the same.
///
/// **The safety rule, stated once.** The record drops only when BOTH scans find EVERY claimed page
/// positively absent. Validation alone still never blanks a whole gallery (G-15-2G), and the
/// evidence is dropped by everything that makes it stale: a delete, a redownload, a folder move, a
/// completion, a file reappearing, and a relaunch (it is held in memory only).
@Suite
struct DownloadWholesaleAbsenceTests: DownloadFeatureTestCase {
    /// K0-b through the in-app Pause: the run is parked before its preparation, so it never scans.
    @Test
    func testARepairPausedDuringItsPayloadFetchReadsZeroOfN() async throws {
        let gallery = SessionGallery(gid: "200902-a", title: "Fetch Pause", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await startTheRepairAndPark(gallery: gallery, harness: harness)

        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectPausedZeroOfSix(gallery: gallery, manager: manager)
        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// K0-b through the card's cancel: the expiration's bulk pause reaches the same `commitPause`.
    @Test
    func testAnExpirationDuringThePayloadFetchReadsZeroOfN() async throws {
        let gallery = SessionGallery(gid: "200902-b", title: "Fetch Expiry", pageCount: 6, completedPageCount: 6)
        let spy = BackgroundProcessingClientSpy()
        let harness = try await makeHarness(galleries: [gallery], client: spy.client)
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await startTheRepairAndPark(gallery: gallery, harness: harness)
        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())

        await manager.testingPauseAllSchedulable(expiring: sessionID)
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectPausedZeroOfSix(gallery: gallery, manager: manager)
    }

    /// K0-c: the repair is queued behind another gallery's run and paused there through `pause(gid:)`,
    /// the route the card's cancel and the system's expiry take for every schedulable gallery. No run
    /// exits, so only `commitPause` can act.
    @Test
    func testARepairPausedWhileQueuedBehindAnotherGalleryReadsZeroOfN() async throws {
        let other = SessionGallery(gid: "200902-c-other", title: "Running Ahead", pageCount: 6)
        let gallery = SessionGallery(gid: "200902-c", title: "Queued Pause", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [other, gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        await manager.testingSetQueuedGalleryIDs([other.gid])
        await manager.scheduleNextIfNeeded()
        await harness.control.started()
        #expect(await manager.testingActiveGalleryID() == other.gid)

        try await manager.retryPages(gid: gallery.gid, pageIndices: Array(1...6)).get()
        #expect(await manager.fetchDownload(gid: gallery.gid)?.displayStatus == .queued)

        try await manager.pause(gid: gallery.gid).get()

        try await expectPausedZeroOfSix(gallery: gallery, manager: manager)
        // The gallery ahead is untouched by the queued gallery's pause.
        #expect(await manager.testingActiveGalleryID() == other.gid)
    }

    /// K0-c through the in-app Pause, which is `togglePause`. A queued repair does not reach
    /// `commitPause` from there: its queued work item is cancelled (`cancelQueuedWorkItem`), and the
    /// gallery falls back to its record. The owner's test iPhone read "Downloaded 112 of 112" on
    /// exactly this route while the `pause(gid:)` case above was green.
    @Test
    func testARepairPausedInAppWhileQueuedBehindAnotherGalleryReadsZeroOfN() async throws {
        let other = SessionGallery(gid: "200902-c2-other", title: "Running Ahead", pageCount: 6)
        let gallery = SessionGallery(gid: "200902-c2", title: "Queued Toggle", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [other, gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        await manager.testingSetQueuedGalleryIDs([other.gid])
        await manager.scheduleNextIfNeeded()
        await harness.control.started()
        try await manager.retryPages(gid: gallery.gid, pageIndices: Array(1...6)).get()
        #expect(await manager.fetchDownload(gid: gallery.gid)?.displayStatus == .queued)

        try await manager.togglePause(gid: gallery.gid).get()

        try await expectPausedZeroOfSix(gallery: gallery, manager: manager)
        #expect(await manager.testingActiveGalleryID() == other.gid)
        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// Validation alone never blanks: Verify Images over a gallery with every page gone keeps the
    /// record's claim, however often it runs, until a stop corroborates it.
    @Test
    func testVerifyAloneNeverBlanksAWholeGallery() async throws {
        let gallery = SessionGallery(gid: "200902-d", title: "Verify Only", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)

        await manager.reloadDownloadIndex()
        #expect(await manager.fetchDownload(gid: gallery.gid)?.completedPageCount == 6)
    }

    /// A stop without Verify's scan has nothing to corroborate: the record keeps its claim.
    @Test
    func testAStopWithoutVerifyKeepsTheRecord() async throws {
        let gallery = SessionGallery(gid: "200902-e", title: "No Verify", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await startTheRepairAndPark(gallery: gallery, harness: harness)
        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectTheRecordKeptItsClaim(gallery: gallery, manager: manager)
    }

    /// A file reappearing between Verify and the stop: the stop's scan no longer finds EVERY claimed
    /// page absent, so nothing is blanked and the evidence is gone.
    @Test
    func testAFileReappearingBeforeTheStopKeepsTheRecordAndDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-f", title: "Reappeared", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try writePageFiles(for: gallery, in: harness.fixture, indices: [2])
        try await startTheRepairAndPark(gallery: gallery, harness: harness)
        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        try await expectTheRecordKeptItsClaim(gallery: gallery, manager: manager)
        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// A delete drops the evidence.
    @Test
    func testADeleteDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-g", title: "Deleted", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await manager.delete(gid: gallery.gid).get()

        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// A redownload drops the evidence: the run starts from a fresh folder and manifest.
    @Test
    func testARedownloadDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-h", title: "Redownloaded", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await manager.retry(gid: gallery.gid, mode: .redownload).get()

        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// A folder move drops the evidence, and a stop after it keeps the record.
    @Test
    func testAFolderMoveDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-i", title: "Moved", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        try await manager.moveDownload(gid: gallery.gid, toFolderName: "Elsewhere").get()
        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)

        try await startTheRepairAndPark(gallery: gallery, harness: harness)
        try await manager.pause(gid: gallery.gid).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        try await expectTheRecordKeptItsClaim(gallery: gallery, manager: manager)
    }

    /// A completion drops the evidence.
    @Test
    func testACompletionDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-j", title: "Completed", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }
        let manager = harness.fixture.manager

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: manager)
        await manager.settleCompletedDownload(gid: gallery.gid)

        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)
    }

    /// A relaunch drops the evidence: it lives in memory only, so a fresh coordinator over the same
    /// disk has none, and its stop keeps the record.
    @Test
    func testARelaunchDropsTheEvidence() async throws {
        let gallery = SessionGallery(gid: "200902-k", title: "Relaunched", pageCount: 6, completedPageCount: 6)
        let harness = try await makeHarness(galleries: [gallery])
        defer { tearDown(harness) }

        try await verifyFindsEveryPageMissingWithoutBlanking(gallery: gallery, manager: harness.fixture.manager)

        let relaunched = DownloadCoordinator(
            storage: harness.fixture.storage,
            urlSession: makeStubbedURLSession(stubSessionID: harness.stubSessionID),
            backgroundProcessingClient: .noop,
            taskRunner: harness.taskRunner,
            now: { Date() },
            clock: TestClock()
        )
        await relaunched.reloadDownloadIndex()
        #expect(await relaunched.testingHasWholesaleAbsenceEvidence(gid: gallery.gid) == false)

        try await relaunched.retryPages(gid: gallery.gid, pageIndices: Array(1...6)).get()
        await harness.control.started()
        try await relaunched.pause(gid: gallery.gid).get()
        try await waitUntil {
            await relaunched.testingHasActiveTask() == false
        }
        try await expectTheRecordKeptItsClaim(gallery: gallery, manager: relaunched)
    }
}

// MARK: - Helpers

private struct Harness {
    let fixture: SessionFixture
    let control: BlockingRunnerControl
    let taskRunner: DownloadTaskRunner
    let stubSessionID: String

}

private extension DownloadWholesaleAbsenceTests {
    func tearDown(_ harness: Harness) {
        harness.control.release()
        SharedSessionStubURLProtocol.removeHandler(for: harness.stubSessionID)
        removeTemporaryItem(at: harness.fixture.rootURL)
    }

    /// Complete-claiming records with no page file on disk, nothing queued, behind a runner that
    /// parks until it is cancelled and then runs the real operation it was handed, offline.
    func makeHarness(
        galleries: [SessionGallery],
        client: BackgroundProcessingClient = .noop
    ) async throws -> Harness {
        let control = BlockingRunnerControl()
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        let taskRunner = DownloadTaskRunner(
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
        )
        let fixture = try await makeQueuedCoordinator(
            galleries: galleries,
            queuedGIDs: [],
            client: client,
            taskRunner: taskRunner,
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        return Harness(
            fixture: fixture,
            control: control,
            taskRunner: taskRunner,
            stubSessionID: stubSessionID
        )
    }

    /// Verify Images over a gallery whose every page file is gone: the verdict is missing files,
    /// the record keeps its whole claim (G-15-2G), and the evidence is recorded.
    func verifyFindsEveryPageMissingWithoutBlanking(
        gallery: SessionGallery,
        manager: DownloadCoordinator
    ) async throws {
        let verdict = await manager.verifyImages(gid: gallery.gid)
        guard case .missingFiles = verdict else {
            Issue.record("Expected a missing-files verdict, got \(String(describing: verdict))")
            return
        }
        let verified = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(verified.completedPageCount == 6)
        #expect(verified.displayStatus == .error)
        #expect(await manager.testingHasWholesaleAbsenceEvidence(gid: gallery.gid))
    }

    /// Retry Pages, as the inspector issues it, and the run parks before its payload fetch.
    func startTheRepairAndPark(gallery: SessionGallery, harness: Harness) async throws {
        let manager = harness.fixture.manager
        try await manager.retryPages(gid: gallery.gid, pageIndices: Array(1...6)).get()
        await harness.control.started()
        #expect(await manager.testingActiveGalleryID() == gallery.gid)
        #expect(await manager.fetchDownload(gid: gallery.gid)?.runProgress == nil)
    }

    func expectPausedZeroOfSix(
        gallery: SessionGallery,
        manager: DownloadCoordinator
    ) async throws {
        let paused = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(paused.completedPageCount == 0)
        #expect(paused.isIncomplete)
        #expect(paused.displayStatus == .inactive)
        #expect(paused.canTogglePause)
        #expect(
            paused.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 0, pageCount: 6)
            )
        )
        #expect(await manager.resumeMode(for: paused) == .repair)
        #expect(paused.manifest.pages.values.allSatisfy({ $0.isEmpty }))

        await manager.reloadDownloadIndex()
        let reloaded = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(reloaded.completedPageCount == 0)
        #expect(reloaded.displayStatus == .inactive)
    }

    func expectTheRecordKeptItsClaim(
        gallery: SessionGallery,
        manager: DownloadCoordinator
    ) async throws {
        let paused = try #require(await manager.fetchDownload(gid: gallery.gid))
        #expect(paused.completedPageCount == 6)
        #expect(paused.manifest.pages.values.allSatisfy({ !$0.isEmpty }))
    }
}
