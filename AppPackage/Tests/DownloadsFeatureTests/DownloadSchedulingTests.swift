import Foundation
import AppModels
import Testing
import DownloadClient
@testable import AppFeature

@Suite
struct DownloadSchedulingTests: DownloadFeatureTestCase {
    @Test
    func testConcurrentSchedulingCreatesOnlyOneActiveTask() async throws {
        let gid = "100001"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(
            rootURL: rootURL,
            fileManager: .default
        )
        let gate = ScheduleFetchGate()
        let scheduledRecorder = ScheduledGalleryRecorder()
        let taskRunner = DownloadTaskRunner(
            beforeActiveTaskCheck: {
                await gate.waitAtGate()
            },
            recordScheduledGallery: { gid in
                scheduledRecorder.record(gid)
            },
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

        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Queued")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            DownloadManifest(
                gid: gid,
                host: .ehentai,
                token: "token",
                title: "Queued",
                jpnTitle: nil,
                category: .doujinshi,
                language: .japanese,
                remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: [1: ""]
            ),
            folderURL: folderURL
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        async let firstSchedule: Void =
            manager.scheduleNextIfNeeded()
        async let secondSchedule: Void =
            manager.scheduleNextIfNeeded()

        await gate.waitForBothArrivals()
        await gate.releaseAll()
        _ = await (firstSchedule, secondSchedule)

        let scheduledGalleryIDs = scheduledRecorder.snapshot()
        let hasActiveTask = await manager.testingHasActiveTask()
        let activeGalleryID = await manager.testingActiveGalleryID()
        #expect(scheduledGalleryIDs.count == 1)
        #expect(hasActiveTask)
        #expect(scheduledGalleryIDs.first == activeGalleryID)

        guard case .success = await manager.pause(gid: gid) else {
            Issue.record("Pause should succeed for the active test download.")
            return
        }
    }

    @Test
    func testCancelledProcessCleanupDoesNotClearNewerActiveTask() async throws {
        let firstGID = "100011"
        let secondGID = "100012"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(
            rootURL: rootURL,
            fileManager: .default
        )
        let gate = ScheduledProcessCleanupGate(firstGID: firstGID)
        let taskRunner = DownloadTaskRunner(
            runScheduledDownload: { gid, _ in
                await gate.run(gid: gid)
                return .skippedOperation
            }
        )
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            taskRunner: taskRunner
        )

        try writeQueuedManifest(storage: storage, gid: firstGID, title: "First")
        try writeQueuedManifest(storage: storage, gid: secondGID, title: "Second")
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([firstGID, secondGID])

        await manager.scheduleNextIfNeeded()
        await gate.waitForFirstArrival()

        let pauseTask = Task {
            await manager.pause(gid: firstGID)
        }
        // Pause cancels the first task and clears the active slot synchronously
        // before suspending on the cancelled task's completion. Awaiting that
        // cancellation event (instead of polling activeGalleryID against a
        // wall-clock deadline) lets actor mutual exclusion guarantee the slot is
        // already clear by the time the next scheduleNextIfNeeded() runs.
        await gate.waitForFirstCancellation()

        await manager.scheduleNextIfNeeded()
        await gate.waitForSecondStart()
        await gate.releaseFirst()

        guard case .success = await pauseTask.value else {
            Issue.record("Pause should succeed for the canceled first download.")
            return
        }

        let activeGalleryID = await manager.testingActiveGalleryID()
        let hasActiveTask = await manager.testingHasActiveTask()
        #expect(activeGalleryID == secondGID)
        #expect(hasActiveTask)

        guard case .success = await manager.pause(gid: secondGID) else {
            Issue.record("Cleanup pause should succeed for the second download.")
            return
        }
    }
}

private extension DownloadSchedulingTests {
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

private actor ScheduleFetchGate {
    private var arrivalCount = 0
    private var isReleased = false
    private var bothArrivedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuations = [CheckedContinuation<Void, Never>]()

    func waitAtGate() async {
        guard !isReleased else { return }
        arrivalCount += 1
        if arrivalCount == 2 {
            bothArrivedContinuation?.resume()
            bothArrivedContinuation = nil
        }
        await withCheckedContinuation { continuation in
            releaseContinuations.append(continuation)
        }
    }

    func waitForBothArrivals() async {
        guard arrivalCount < 2 else { return }
        await withCheckedContinuation { continuation in
            bothArrivedContinuation = continuation
        }
    }

    func releaseAll() {
        isReleased = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}

private actor ScheduledProcessCleanupGate {
    private let firstGID: String
    private var firstArrived = false
    private var firstCancelled = false
    private var secondStarted = false
    private var firstArrivalContinuation: CheckedContinuation<Void, Never>?
    private var firstCancellationContinuation: CheckedContinuation<Void, Never>?
    private var secondStartContinuation: CheckedContinuation<Void, Never>?
    private var releaseFirstContinuation: CheckedContinuation<Void, Never>?

    init(firstGID: String) {
        self.firstGID = firstGID
    }

    func run(gid: String) async {
        if gid == firstGID {
            await waitForRelease()
        } else {
            startSecond()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    func waitForFirstArrival() async {
        guard !firstArrived else { return }
        await withCheckedContinuation { continuation in
            firstArrivalContinuation = continuation
        }
    }

    func waitForFirstCancellation() async {
        guard !firstCancelled else { return }
        await withCheckedContinuation { continuation in
            firstCancellationContinuation = continuation
        }
    }

    func waitForSecondStart() async {
        guard !secondStarted else { return }
        await withCheckedContinuation { continuation in
            secondStartContinuation = continuation
        }
    }

    func releaseFirst() {
        releaseFirstContinuation?.resume()
        releaseFirstContinuation = nil
    }

    private func waitForRelease() async {
        firstArrived = true
        firstArrivalContinuation?.resume()
        firstArrivalContinuation = nil
        // Stay parked past cancellation: the first task's cleanup must fire only
        // after the second task becomes active. The cancellation handler merely
        // reports that pause() has cancelled this task, which is the point at
        // which it has cleared the active slot.
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                releaseFirstContinuation = continuation
            }
        } onCancel: {
            Task { await self.markFirstCancelled() }
        }
    }

    private func markFirstCancelled() {
        guard !firstCancelled else { return }
        firstCancelled = true
        firstCancellationContinuation?.resume()
        firstCancellationContinuation = nil
    }

    private func startSecond() {
        secondStarted = true
        secondStartContinuation?.resume()
        secondStartContinuation = nil
    }
}
