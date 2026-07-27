import DownloadClient
import Foundation
import Testing

struct DownloadBackgroundProcessingTests: DownloadFeatureTestCase {
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

    @Test
    func testRunQueueUntilIdleDrainsAllQueuedItems() async throws {
        let sessionID = UUID().uuidString
        let gids = ["210011", "210012", "210013"]
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let (storage, manager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL,
            sessionID: sessionID
        )
        // Every request fails, so each scheduled download settles to .error and leaves
        // the queue — letting the drain converge without a live network.
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        for gid in gids {
            try writeQueuedManifest(storage: storage, gid: gid, title: "Queued \(gid)")
        }
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs(gids)
        #expect(await manager.hasPendingWork())

        await manager.runQueueUntilIdle()

        #expect(!(await manager.hasPendingWork()))
        for gid in gids {
            #expect(await manager.fetchDownload(gid: gid)?.displayStatus == .error)
        }
    }

    @Test
    func testRunQueueUntilIdleReturnsPromptlyOnCancellation() async throws {
        let gid = "210021"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskRunner = DownloadTaskRunner(
            runScheduledDownload: { _, _ in
                while !Task.isCancelled {
                    await sleepIgnoringCancellation(for: .milliseconds(10))
                }
                return .skippedOperation
            }
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            taskRunner: taskRunner
        )

        try writeQueuedManifest(storage: storage, gid: gid, title: "Blocking")
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        let drainTask = Task { await manager.runQueueUntilIdle() }
        try await waitUntil { await manager.testingHasActiveTask() }
        drainTask.cancel()

        // Without the cancellation handler the drain would block on the never-finishing
        // transfer; cancelling it must cancel the active task and return.
        _ = try await waitForTaskValue(
            drainTask,
            timeout: .seconds(2),
            description: "runQueueUntilIdle cancellation"
        )
    }
}

// MARK: - Helpers

private extension DownloadBackgroundProcessingTests {
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

    // The poll returns the moment the condition holds, so the deadline costs nothing on a healthy
    // run and only bounds a genuine hang. One second did not survive CI, where the whole target's
    // suites run in parallel and a task can sit unscheduled far longer than the work itself takes.
    func waitUntil(
        timeout: Duration = .seconds(10),
        _ condition: @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while await !condition(), clock.now < deadline {
            await sleepIgnoringCancellation(for: .milliseconds(10))
        }
        try #require(await condition(), "Timed out waiting for condition.")
    }
}
