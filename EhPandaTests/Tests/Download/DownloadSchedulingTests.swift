//
//  DownloadSchedulingTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

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
        try await waitForActiveGalleryID(manager, toEqual: nil)

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

    func waitForActiveGalleryID(
        _ manager: DownloadCoordinator,
        toEqual expected: String?,
        timeout: Duration = .seconds(1)
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while await manager.testingActiveGalleryID() != expected,
              clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        try #require(
            await manager.testingActiveGalleryID() == expected,
            "Timed out waiting for activeGalleryID to become \(String(describing: expected))."
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
    private var secondStarted = false
    private var firstArrivalContinuation: CheckedContinuation<Void, Never>?
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
        await withCheckedContinuation { continuation in
            releaseFirstContinuation = continuation
        }
    }

    private func startSecond() {
        secondStarted = true
        secondStartContinuation?.resume()
        secondStartContinuation = nil
    }
}
