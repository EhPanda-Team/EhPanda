import AppModels
import BackgroundProcessingClient
@testable import DownloadClient
import Foundation
import Testing
import TestingSupport

/// B-1: Download Now interrupts the active gallery and starts the selected one at once. The interrupted gallery is
/// not paused and does not leave the queue: it waits directly after the selected one, with the pages it saved and
/// its manifest exactly as its own run left them, and no failure recorded (the manifest-SSOT invariant, the
/// folder-deletion invariant). Nothing is deleted, and the queue converges through the coordinator's one
/// convergence point.
@Suite(.isolatedAppStorage)
struct DownloadQueueInterruptTests: DownloadFeatureTestCase {
    struct ModeCase: Sendable, CustomTestStringConvertible {
        let stagedMode: DownloadStartMode
        let prepared: Bool
        let expectedMode: DownloadStartMode

        var testDescription: String { "\(stagedMode) prepared \(prepared) → \(expectedMode)" }
    }

    @Test
    func testDownloadNowInterruptsTheActiveGalleryAndQueuesItNext() async throws {
        let active = SessionGallery(gid: "261123300", title: "Active", pageCount: 4)
        let first = SessionGallery(gid: "261123301", title: "First", pageCount: 4)
        let second = SessionGallery(gid: "261123302", title: "Second", pageCount: 4)
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, first, second],
            queuedGIDs: [active, first, second].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        let before = try #require(await manager.fetchDownload(gid: active.gid))
        let intentBefore = await manager.queueIntentSnapshot(gid: active.gid, backgroundSessionStartCount: 0)

        try await manager.performQueueOperation(gid: second.gid, operation: .downloadNow).get()

        #expect(await manager.testingActiveGalleryID() == second.gid)
        #expect(await waitingGIDs(in: manager) == [active, first].map(\.gid))
        let after = try #require(await manager.fetchDownload(gid: active.gid))
        #expect(after.queuePlace == DownloadQueuePlace(position: 1, waitingCount: 2))
        #expect(after.displayStatus == .queued)
        #expect(gate.scheduledGIDs == [active, second].map(\.gid))
        #expect(gate.cancelledRunCount == 1)
        #expect(await manager.queueIntentSnapshot(gid: active.gid, backgroundSessionStartCount: 0) == intentBefore)
        #expect(after.manifest == before.manifest)
        #expect(after.runProgress == nil)
    }

    @Test
    func testAnInterruptedRunKeepsTheWorkItDidAndRecordsNoFailure() async throws {
        let active = SessionGallery(gid: "261123310", title: "Active", pageCount: 6)
        let selected = SessionGallery(gid: "261123311", title: "Selected", pageCount: 4)
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let gate = QueueRunGate(runsOperationAfterCancellation: true)
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, selected],
            queuedGIDs: [active, selected].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner,
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        let folderURL = galleryFolderURL(for: active, in: fixture)
        let preparedRun = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: active),
            folderURL: folderURL
        )
        #expect(preparedRun.pendingPageIndices == [1, 2, 3, 4, 5, 6])
        try writePageFiles(for: active, in: fixture, indices: [1, 2, 3])
        var pendingResolvedPages = pageResults(for: active, in: fixture, indices: [1, 2, 3])
        var lastFlushDate = Date.distantPast
        try await manager.flushDownloadProgress(
            context: .init(gid: active.gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        let midRun = try #require(await manager.fetchDownload(gid: active.gid))
        #expect(midRun.completedPageCount == 3)
        #expect(midRun.runProgress?.creditedPageIndices == [1, 2, 3])

        try await manager.performQueueOperation(gid: selected.gid, operation: .downloadNow).get()

        let interrupted = try #require(await manager.fetchDownload(gid: active.gid))
        #expect(interrupted.runProgress == nil)
        #expect(interrupted.completedPageCount == 3)
        #expect(interrupted.manifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == [1, 2, 3])
        #expect(interrupted.displayStatus == .queued)
        #expect(interrupted.queuePlace == DownloadQueuePlace(position: 1, waitingCount: 1))
        let intent = await manager.queueIntentSnapshot(gid: active.gid, backgroundSessionStartCount: 0)
        #expect(intent.isQueued)
        #expect(intent.downloadError == nil)
        #expect(intent.verificationError == nil)
        #expect(intent.failedPageIndices.isEmpty)
        for index in [1, 2, 3] {
            let pagePath = fixture.storage.makePageRelativePath(
                gid: active.gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            let pageURL = folderURL.appending(path: pagePath)
            #expect(FileManager.default.fileExists(atPath: pageURL.path(percentEncoded: false)))
        }
        await manager.reloadDownloadIndex()
        let reloaded = try #require(await manager.fetchDownload(gid: active.gid))
        #expect(reloaded.completedPageCount == 3)
        #expect(reloaded.manifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() == [1, 2, 3])
        #expect(await manager.testingActiveGalleryID() == selected.gid)
    }

    private static let large = SessionGallery(gid: "261123320", title: "Large", pageCount: 10, completedPageCount: 6)
    private static let small = SessionGallery(gid: "261123321", title: "Small", pageCount: 4)

    @Test
    func testDownloadNowKeepsTheContinuedSessionCountingBothGalleries() async throws {
        let (large, small) = (Self.large, Self.small)
        let spy = BackgroundProcessingClientSpy()
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [large, small],
            queuedGIDs: [large, small].map(\.gid),
            client: spy.client,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        await manager.testingEnsureContinuedSession()
        let sessionID = try #require(await manager.testingContinuedSessionID())
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try firstPushedPair(spy.progressUpdates).subtitle == "6 of 14 pages in 2 galleries")

        try await manager.performQueueOperation(gid: small.gid, operation: .downloadNow).get()
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "6 of 14 pages in 2 galleries")

        await patchManifest(of: small, completedPageCount: 2, in: fixture)
        await manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        #expect(try lastPushedPair(spy.progressUpdates).subtitle == "8 of 14 pages in 2 galleries")
        expectTheCompletedSeriesNeverLosesGround(spy.progressUpdates)
        #expect(spy.rejectedProgressUpdates.isEmpty)
    }

    @Test(arguments: [
        ModeCase(stagedMode: .redownload, prepared: true, expectedMode: .repair),
        ModeCase(stagedMode: .update, prepared: true, expectedMode: .repair),
        ModeCase(stagedMode: .redownload, prepared: false, expectedMode: .redownload),
        ModeCase(stagedMode: .initial, prepared: true, expectedMode: .initial),
        ModeCase(stagedMode: .repair, prepared: true, expectedMode: .repair)
    ])
    func testAnInterruptedRunThatReplacedItsFolderContinuesAsARepair(_ modeCase: ModeCase) async throws {
        let active = SessionGallery(gid: "261123330", title: "Active", pageCount: 6, completedPageCount: 6)
        let selected = SessionGallery(gid: "261123331", title: "Selected", pageCount: 4)
        let stubSessionID = makeOfflineStub()
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let gate = QueueRunGate(runsOperationAfterCancellation: true)
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, selected],
            queuedGIDs: [active, selected].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner,
            urlSession: makeStubbedURLSession(stubSessionID: stubSessionID)
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        await manager.stageQueuedMode(modeCase.stagedMode, gid: active.gid)
        if modeCase.prepared {
            _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
                payload: makeStartPayload(for: active, mode: .redownload),
                folderURL: galleryFolderURL(for: active, in: fixture)
            )
        }

        try await manager.performQueueOperation(gid: selected.gid, operation: .downloadNow).get()

        let intent = await manager.queueIntentSnapshot(gid: active.gid, backgroundSessionStartCount: 0)
        #expect(intent.queuedMode == modeCase.expectedMode)
        #expect(intent.isQueued)
    }

    @Test
    func testDownloadNowOnAPausedItemResumesItAndStartsItFirst() async throws {
        let active = SessionGallery(gid: "261123340", title: "Active", pageCount: 4)
        let first = SessionGallery(gid: "261123341", title: "First", pageCount: 4)
        let second = SessionGallery(gid: "261123342", title: "Second", pageCount: 4)
        let paused = SessionGallery(gid: "261123343", title: "Paused", pageCount: 4, completedPageCount: 1)
        let spy = BackgroundProcessingClientSpy()
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, first, second, paused],
            queuedGIDs: [active, first, second].map(\.gid),
            client: spy.client,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()

        try await manager.performQueueOperation(gid: paused.gid, operation: .downloadNow).get()

        #expect(await manager.testingActiveGalleryID() == paused.gid)
        #expect(await waitingGIDs(in: manager) == [active, first, second].map(\.gid))
        #expect(gate.scheduledGIDs == [active, paused].map(\.gid))
        #expect(gate.cancelledRunCount == 1)
        let intent = await manager.queueIntentSnapshot(
            gid: paused.gid,
            backgroundSessionStartCount: spy.startCount
        )
        #expect(intent.hasContinuedSession)
    }

    @Test
    func testDownloadNowWithNothingActiveStartsTheItemFirst() async throws {
        let first = SessionGallery(gid: "261123350", title: "First", pageCount: 4)
        let second = SessionGallery(gid: "261123351", title: "Second", pageCount: 4)
        let third = SessionGallery(gid: "261123352", title: "Third", pageCount: 4)
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [first, second, third],
            queuedGIDs: [first, second, third].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }

        try await manager.performQueueOperation(gid: third.gid, operation: .downloadNow).get()

        #expect(await manager.testingActiveGalleryID() == third.gid)
        #expect(await waitingGIDs(in: manager) == [first, second].map(\.gid))
        #expect(gate.scheduledGIDs == [third.gid])
        #expect(gate.cancelledRunCount == 0)
    }

    // MARK: Interleavings while the interrupted run is still unwinding

    /// Stages A's cancelled run held, starts Download Now on `selected` and returns once the interrupt is waiting
    /// on that run, so the case can act inside the wait.
    private func startHeldInterrupt(
        selected: SessionGallery,
        manager: DownloadCoordinator,
        gate: QueueRunGate
    ) async throws -> Task<Result<Void, AppError>, Never> {
        gate.holdCancelledRuns()
        let firstCall = Task {
            await manager.performQueueOperation(gid: selected.gid, operation: .downloadNow)
        }
        try await waitUntil {
            gate.cancelledRunCount == 1
        }
        return firstCall
    }

    @Test
    func testASecondDownloadNowDuringTheInterruptWins() async throws {
        let active = SessionGallery(gid: "261123360", title: "Active", pageCount: 4)
        let first = SessionGallery(gid: "261123361", title: "First", pageCount: 4)
        let second = SessionGallery(gid: "261123362", title: "Second", pageCount: 4)
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, first, second],
            queuedGIDs: [active, first, second].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        let firstCall = try await startHeldInterrupt(selected: first, manager: manager, gate: gate)

        try await manager.performQueueOperation(gid: second.gid, operation: .downloadNow).get()
        gate.releaseCancelledRuns()
        try await firstCall.value.get()

        #expect(await manager.testingActiveGalleryID() == second.gid)
        #expect(await waitingGIDs(in: manager) == [first, active].map(\.gid))
        #expect(gate.scheduledGIDs == [active, second].map(\.gid))
    }

    @Test
    func testPausingTheInterruptedGalleryDuringTheInterruptKeepsItPaused() async throws {
        let active = SessionGallery(gid: "261123370", title: "Active", pageCount: 4)
        let selected = SessionGallery(gid: "261123371", title: "Selected", pageCount: 4)
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, selected],
            queuedGIDs: [active, selected].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        let firstCall = try await startHeldInterrupt(selected: selected, manager: manager, gate: gate)

        try await manager.pause(gid: active.gid).get()
        gate.releaseCancelledRuns()
        try await firstCall.value.get()

        #expect(await manager.testingActiveGalleryID() == selected.gid)
        let paused = try #require(await manager.fetchDownload(gid: active.gid))
        #expect(paused.displayStatus == .inactive)
        let intent = await manager.queueIntentSnapshot(gid: active.gid, backgroundSessionStartCount: 0)
        #expect(!intent.isQueued)
        #expect(intent.queuedMode == nil)
        #expect(intent.downloadError == nil)
        #expect(gate.scheduledGIDs == [active, selected].map(\.gid))
    }

    @Test
    func testDeletingTheSelectedGalleryDuringTheInterruptRestartsTheInterruptedOne() async throws {
        let active = SessionGallery(gid: "261123380", title: "Active", pageCount: 4)
        let selected = SessionGallery(gid: "261123381", title: "Selected", pageCount: 4)
        let gate = QueueRunGate()
        let fixture = try await makeQueuedCoordinator(
            galleries: [active, selected],
            queuedGIDs: [active, selected].map(\.gid),
            client: .noop,
            taskRunner: gate.taskRunner
        )
        let manager = fixture.manager
        defer {
            gate.stop()
            removeTemporaryItem(at: fixture.rootURL)
        }
        await manager.scheduleNextIfNeeded()
        let firstCall = try await startHeldInterrupt(selected: selected, manager: manager, gate: gate)

        try await manager.delete(gid: selected.gid).get()
        gate.releaseCancelledRuns()
        try await firstCall.value.get()

        #expect(await manager.testingActiveGalleryID() == active.gid)
        #expect(await manager.fetchDownload(gid: selected.gid) == nil)
        #expect(gate.scheduledGIDs == [active, active].map(\.gid))
        #expect(gate.cancelledRunCount == 1)
    }
}
