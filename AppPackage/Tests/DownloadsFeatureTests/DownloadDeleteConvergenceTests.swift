import AppModels
import DownloadClient
import Foundation
import Testing

/// Pins the delete-path convergence contract when an indexed download record has vanished.
@Suite
struct DownloadDeleteConvergenceTests: DownloadFeatureTestCase {
    /// CR-04: a last-item record that disappears between indexing and deletion must still close
    /// the continued session. Before the convergence fix, the not-found branch returned before
    /// reconciling session liveness.
    @Test
    func testDeletingAVanishedLastRecordCompletesTheSession() async throws {
        let gallery = SessionGallery(
            gid: "vanished-last",
            title: "Vanished Last",
            pageCount: 2
        )
        let clientSpy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            client: clientSpy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let clientSessionID = try #require(clientSpy.startSessionIDs.first)
        #expect(await fixture.manager.testingHasContinuedSession())

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        try FileManager.default.removeItem(at: folderURL)
        #expect(
            await fixture.manager.reloadDownloadRecord(gid: gallery.gid, token: "token") == nil
        )

        let result = await fixture.manager.delete(gid: gallery.gid)

        #expect(throws: AppError.notFound) {
            try result.get()
        }
        #expect(
            clientSpy.finishRecords == [
                .init(sessionID: clientSessionID, success: true)
            ]
        )
        #expect(await fixture.manager.testingHasContinuedSession() == false)
    }

    /// CR-04: deleting a vanished queued record must publish the converged index and immediately
    /// schedule the next gallery. Before the convergence fix, observers received no second
    /// emission and the remaining gallery stayed stranded.
    @Test
    func testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving() async throws {
        let firstGallery = SessionGallery(
            gid: "vanished-first",
            title: "Vanished First",
            pageCount: 2
        )
        let secondGallery = SessionGallery(
            gid: "scheduled-second",
            title: "Scheduled Second",
            pageCount: 2
        )
        let clientSpy = BackgroundProcessingClientSpy()
        let scheduledGalleryRecorder = ScheduledGalleryRecorder()
        let taskRunner = DownloadTaskRunner(
            recordScheduledGallery: { gid in
                scheduledGalleryRecorder.record(gid)
            },
            runScheduledDownload: { _, _ in
                .skippedOperation
            }
        )
        let fixture = try await makeQueuedCoordinator(
            galleries: [firstGallery, secondGallery],
            client: clientSpy.client,
            taskRunner: taskRunner
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        #expect(await fixture.manager.testingHasContinuedSession())

        let downloads = await fixture.manager.observeDownloads()
        let observerTask = Task { () -> [[DownloadedGallery]] in
            var emissions = [[DownloadedGallery]]()
            for await downloadSnapshot in downloads {
                emissions.append(downloadSnapshot)
                if emissions.count == 2 {
                    return emissions
                }
            }
            return emissions
        }
        defer { observerTask.cancel() }

        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(firstGallery.gid)_token] \(firstGallery.title)"
        )
        try FileManager.default.removeItem(at: folderURL)
        #expect(
            await fixture.manager.reloadDownloadRecord(
                gid: firstGallery.gid,
                token: "token"
            ) == nil
        )

        let result = await fixture.manager.delete(gid: firstGallery.gid)
        // This awaits the collector's value rather than polling a predicate. The deadline only
        // turns the pre-fix missing notification into a named failure instead of a hung suite.
        //
        // IN-01 asks for a one-second budget here, on the reading that a detector's bound is its
        // failure budget rather than scheduling headroom. The bound is declined, and this is the
        // one place that argument lives — the sibling detector in `DownloadOwnershipConvergence
        // Tests` refers here rather than restating it, so the decision has a single owner exactly
        // as the number does. What the wait actually measures is wall time, and wall time cannot
        // tell a notification that never arrives from a collector the parallel suite has not
        // scheduled. The short bound was not hypothetical: it stood at this very call site, and
        // 15-21 recorded THIS case timing out with 13.2 seconds of wall time under contention
        // (`deferred-items.md`), after which 15-64 removed the one-second argument from five sites
        // because three sibling observer cases failed the same way. A bound below the observed
        // scheduling delay therefore buys nine seconds on a red run by making every green run a
        // coin flip — and a flaky detector is how a real regression gets re-run until it passes.
        // The shared ten-second default stands, deliberately rather than by inheritance.
        let emissions = try await waitForTaskValue(
            observerTask,
            description: "the vanished-record deletion observer emission"
        )

        #expect(throws: AppError.notFound) {
            try result.get()
        }
        #expect(scheduledGalleryRecorder.snapshot() == [secondGallery.gid])
        #expect(emissions.count == 2)
        #expect(emissions[1].map(\.gid) == [secondGallery.gid])
        #expect(await fixture.manager.testingHasContinuedSession())
        #expect(clientSpy.finishRecords.isEmpty)
    }
}
