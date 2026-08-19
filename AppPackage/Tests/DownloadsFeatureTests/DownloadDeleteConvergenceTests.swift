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
        let fence = sampleDownload(
            gid: "fence-\(UUID().uuidString)",
            title: "Fence",
            status: .completed
        )
        let observerTask = collectSnapshots(from: downloads, untilFence: fence.gid)

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
        // The fence, not a clock: `delete` awaits `notifyObservers()` on every exit, so once it has
        // returned its notification is either buffered or will never come — see
        // `collectSnapshots(from:untilFence:)` for why that admits a sentinel and why the
        // ten-second bound that stood here (15-21, 15-64) is retired at this site. The fence
        // measures the fact the clock could not.
        await fixture.manager.observerHub.notify([fence])
        let emissions = await observerTask.value

        #expect(throws: AppError.notFound) {
            try result.get()
        }
        #expect(scheduledGalleryRecorder.snapshot() == [secondGallery.gid])
        // A sequence pin, not a count pin: the scheduling tail spawns a `finishActiveTaskIfOwned`
        // notify asynchronously, so how many further converged emissions land before the fence is
        // scheduling's business. The production guarantee is that the converged index is published,
        // first, and that nothing afterwards resurrects the deleted record.
        //
        // Membership rather than intra-snapshot order: the published index orders by modification
        // date, which is not what this detector is about and which the failing-removal paths
        // reshuffle on their own.
        let emittedGIDs = emissions.map({ Set($0.map(\.gid)) })
        #expect(emissions.count >= 2)
        #expect(emittedGIDs.first == [firstGallery.gid, secondGallery.gid])
        #expect(emittedGIDs.dropFirst().first == [secondGallery.gid])
        #expect(emittedGIDs.dropFirst().allSatisfy({ $0 == [secondGallery.gid] }))
        #expect(await fixture.manager.testingHasContinuedSession())
        #expect(clientSpy.finishRecords.isEmpty)
    }
}
