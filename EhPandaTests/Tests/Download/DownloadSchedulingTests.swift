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

        let storage = DownloadFileStorage(
            rootURL: rootURL,
            fileManager: .default
        )
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )
        await manager.testingSetScheduledProcessHook { _ in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

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

        let gate = ScheduleFetchGate()
        await manager.testingSetFetchDownloadsFromStoreHook {
            await gate.waitAtGate()
        }

        async let firstSchedule: Void =
            manager.testingScheduleNextIfNeeded()
        async let secondSchedule: Void =
            manager.testingScheduleNextIfNeeded()

        await gate.waitForBothArrivals()
        await gate.releaseAll()
        _ = await (firstSchedule, secondSchedule)
        await manager.testingSetFetchDownloadsFromStoreHook(nil)

        let scheduledGalleryIDs = await manager
            .testingScheduledGalleryIDs()
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
}

private actor ScheduleFetchGate {
    private var arrivalCount = 0
    private var bothArrivedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuations = [CheckedContinuation<Void, Never>]()

    func waitAtGate() async {
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
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }
}
