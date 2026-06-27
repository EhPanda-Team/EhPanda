import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadBackgroundProcessingTests: DownloadFeatureTestCase {
    @Test
    func testHasPendingWorkReflectsQueueState() async throws {
        let gid = "210001"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
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
        defer { try? FileManager.default.removeItem(at: rootURL) }

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
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
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

    @MainActor
    @Test
    func testBackgroundSchedulesProcessingWhenWorkPending() async {
        let scheduleCount = UncheckedBox(0)
        let store = makeBackgroundStore(hasPendingWork: true, scheduleCount: scheduleCount)

        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
        }
        await store.finish()

        #expect(scheduleCount.value == 1)
    }

    @MainActor
    @Test
    func testBackgroundSkipsSchedulingWhenIdle() async {
        let scheduleCount = UncheckedBox(0)
        let store = makeBackgroundStore(hasPendingWork: false, scheduleCount: scheduleCount)

        await store.send(.onScenePhaseChange(.background)) {
            $0.scenePhase = .background
            $0.hasEnteredBackground = true
        }
        await store.finish()

        #expect(scheduleCount.value == 0)
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

    @MainActor
    func makeBackgroundStore(
        hasPendingWork: Bool,
        scheduleCount: UncheckedBox<Int>
    ) -> TestStoreOf<AppReducer> {
        var initialState = AppReducer.State()
        initialState.settingState.hasLoadedInitialSetting = true
        let store = TestStore(
            initialState: initialState,
            reducer: AppReducer.init,
            withDependencies: {
                $0.appLaunchAutomationClient = .none
                $0.cookieClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.hasPendingWork = { hasPendingWork }
                $0.backgroundProcessingClient = BackgroundProcessingClient(
                    register: { _ in },
                    schedule: {
                        scheduleCount.value += 1
                    },
                    cancel: {}
                )
            }
        )
        store.exhaustivity = .off
        return store
    }
}
