import Foundation
import Synchronization
import UIKit
import Testing
import DownloadClient
@testable import AppFeature

@Suite
struct DownloadBackgroundAssertionTests: DownloadFeatureTestCase {
    @Test
    func testBeginsAssertionWhenWorkScheduled() async throws {
        let gid = "200001"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()

        #expect(context.spy.beginCount == 1)
        #expect(context.spy.endCount == 0)
        #expect(await context.manager.testingHasBackgroundAssertion())

        _ = await context.manager.pause(gid: gid)
    }

    @Test
    func testEndsAssertionWhenQueueDrainsViaPause() async throws {
        let gid = "200002"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()
        #expect(context.spy.beginCount == 1)

        guard case .success = await context.manager.pause(gid: gid) else {
            Issue.record("Pause should succeed for the active test download.")
            return
        }

        // Regression: the queue draining to empty must release the assertion, even
        // though `pause` nulls `activeTask` directly instead of via the finish path.
        #expect(context.spy.beginCount == 1)
        #expect(context.spy.endCount == 1)
        #expect(!(await context.manager.testingHasBackgroundAssertion()))
    }

    @Test
    func testRepeatedSchedulingBeginsAssertionOnce() async throws {
        let gid = "200003"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()
        await context.manager.scheduleNextIfNeeded()

        #expect(context.spy.beginCount == 1)
        #expect(context.spy.endCount == 0)

        _ = await context.manager.pause(gid: gid)
    }

    @Test
    func testExpirationHandlerReleasesAssertion() async throws {
        let gid = "200004"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()
        #expect(await context.manager.testingHasBackgroundAssertion())

        context.spy.fireExpiration()

        // The expiration handler releases the assertion on a detached task that nils the
        // token *before* awaiting the MainActor `end` hop. Wait on `endCount` (the later
        // of the two) rather than the token so the assertion below can't observe the
        // in-between window where the token is already nil but `end` hasn't run yet.
        try await waitUntil {
            context.spy.endCount == 1
        }
        #expect(context.spy.beginCount == 1)
        #expect(!(await context.manager.testingHasBackgroundAssertion()))

        _ = await context.manager.pause(gid: gid)
    }

    @Test
    func testDeleteOfLastActiveDownloadReleasesAssertion() async throws {
        let gid = "200005"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()
        #expect(context.spy.beginCount == 1)

        guard case .success = await context.manager.delete(gid: gid) else {
            Issue.record("Delete should succeed for the active test download.")
            return
        }

        #expect(context.spy.endCount == 1)
        #expect(!(await context.manager.testingHasBackgroundAssertion()))
    }

    @Test
    func testDeleteFolderOfLastActiveDownloadReleasesAssertion() async throws {
        let gid = "200006"
        let context = try await makeBlockingCoordinator(gid: gid, title: "Queued")
        defer { try? FileManager.default.removeItem(at: context.rootURL) }

        await context.manager.scheduleNextIfNeeded()
        #expect(context.spy.beginCount == 1)

        guard case .success = await context.manager.deleteFolder(name: "Folder") else {
            Issue.record("Delete folder should succeed for the active test download.")
            return
        }

        #expect(context.spy.endCount == 1)
        #expect(!(await context.manager.testingHasBackgroundAssertion()))
    }
}

// MARK: - Helpers

private extension DownloadBackgroundAssertionTests {
    struct BlockingCoordinatorContext {
        let manager: DownloadCoordinator
        let storage: DownloadStore
        let spy: BackgroundTaskClientSpy
        let rootURL: URL
    }

    /// Builds a coordinator whose single queued download blocks forever once scheduled,
    /// so `activeTask` stays installed and the assertion lifecycle can be observed.
    func makeBlockingCoordinator(
        gid: String,
        title: String
    ) async throws -> BlockingCoordinatorContext {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let spy = BackgroundTaskClientSpy()
        let taskRunner = DownloadTaskRunner(
            runScheduledDownload: { _, _ in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(10))
                }
                return .skippedOperation
            }
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskClient: spy.client,
            taskRunner: taskRunner
        )

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
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])
        return BlockingCoordinatorContext(
            manager: manager,
            storage: storage,
            spy: spy,
            rootURL: rootURL
        )
    }

    func waitUntil(
        timeout: Duration = .seconds(1),
        _ condition: @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while await !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        try #require(await condition(), "Timed out waiting for condition.")
    }
}

// MARK: - Spy

final class BackgroundTaskClientSpy: Sendable {
    private struct State {
        var beginCount = 0
        var endCount = 0
        var expirationHandler: (@Sendable () -> Void)?
    }
    private let state = Mutex(State())

    var beginCount: Int { state.withLock { $0.beginCount } }
    var endCount: Int { state.withLock { $0.endCount } }

    func fireExpiration() {
        let handler = state.withLock { $0.expirationHandler }
        handler?()
    }

    var client: BackgroundTaskClient {
        BackgroundTaskClient(
            begin: { handler in
                self.state.withLock {
                    $0.beginCount += 1
                    $0.expirationHandler = handler
                }
                return UIBackgroundTaskIdentifier(rawValue: 1)
            },
            end: { _ in
                self.state.withLock { $0.endCount += 1 }
            }
        )
    }
}
