import DownloadClient
import Foundation
import Testing

/// Covers the coordinator's schedulable-work predicate against real queue state, so the
/// predicate cannot silently drift from what the scheduler treats as schedulable.
struct DownloadPendingWorkTests: DownloadFeatureTestCase {
    @Test
    func testHasPendingWorkReflectsQueueState() async throws {
        let gid = "210001"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        await manager.reloadDownloadIndex()
        #expect(!(await manager.hasPendingWork()))

        try writeQueuedManifest(storage: storage, gid: gid, title: "Queued")
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])
        #expect(await manager.hasPendingWork())
    }

    /// The shared schedulable read's active-gallery union (WR-01, landed in plan 15-26), covered at
    /// the pending-work seam for the first time.
    ///
    /// `schedulableDownloads()` is shared by three callers — this gate, the continued-session card's
    /// `schedulableSnapshot()`, and the expiration sweep `pauseAllSchedulable(expiring:)` — and
    /// **the scheduler is not one of them (G-15-24)**: `scheduleNextIfNeededCore` reads
    /// `queueStore.gids` and then `indexedDownloads()` or `indexedDownloads(gids:)` for itself, and
    /// reaches `isSchedulableDownload` through `nextQueuedDownload` /
    /// `nextUnqueuedSchedulableDownload`. The two share the PREDICATE, not the read scope, so the
    /// union covered here is a difference between the two reads — and this case pins it where a
    /// consumer actually asks the question, not at the scheduler.
    ///
    /// The staging is the production state the union exists for: the running gallery is absent from
    /// a persisted queue that is not empty, so the queue-scoped read has to widen to see it. No task
    /// is installed, so `hasPendingWork`'s `activeTask` short-circuit cannot answer and the question
    /// really does reach `schedulableDownloads()`.
    ///
    /// The queued remainder is a real record held by a live operation's scheduling block, which is
    /// what makes it unschedulable — a queued record is otherwise schedulable on its own, since
    /// `displayStatus` reports `.queued` for anything the queue store holds and `shouldSchedule`
    /// accepts a queued work item whatever its pages say.
    ///
    /// Falsifiability is structural: revert the union and the scoped read fetches the queued
    /// remainder alone, so the first expectation reads false. The control expectation is what proves
    /// the staging cannot pass vacuously — with the active gallery cleared, that same non-empty queue
    /// contributes nothing, so the union is the only reason the first expectation held.
    @Test
    func testHasPendingWorkSeesAnActiveGalleryThePersistedQueueLagsBehind() async throws {
        let activeGID = "210401"
        let queuedGID = "210402"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        try writeQueuedManifest(storage: storage, gid: activeGID, title: "Running")
        try writeQueuedManifest(storage: storage, gid: queuedGID, title: "Held")
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([queuedGID])
        await manager.testingBlockScheduling(gid: queuedGID)
        await manager.testingSetActiveGalleryID(activeGID)

        #expect(await manager.hasPendingWork())

        await manager.testingSetActiveGalleryID(nil)
        #expect(!(await manager.hasPendingWork()))
    }
}

// MARK: - Helpers

private extension DownloadPendingWorkTests {
    func writeQueuedManifest(
        storage: DownloadStore,
        gid: String,
        title: String
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: title),
            folderURL: folderURL
        )
    }
}
