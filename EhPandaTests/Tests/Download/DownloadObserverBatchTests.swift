//
//  DownloadObserverBatchTests.swift
//  EhPandaTests
//

import Foundation
import ComposableArchitecture
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadObserverBatchTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorClearsInspectionWhenObservedDownloadDisappears() async {
        let download = sampleDownload(
            gid: "9988",
            title: "Observed Archive",
            status: .completed
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.yield([download])
                        continuation.yield([])
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [download] }
                $0.downloadClient.fetchDownload = { gid in gid == download.gid ? download : nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadInspection = { _ in inspection }
            }
        )
        store.exhaustivity = .off

        await store.send(.observeDownloads)
        await store.receive(\.observeDownloadsDone, [download])
        await store.receive(\.observeDownloadsDone, []) {
            $0.inspection = nil
            $0.stableInspection = nil
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush() async throws {
        let pageCount = 20
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        // Warm the (empty) index before seeding so the gallery surfaces only
        // through flush updates, mirroring an active download whose folder is
        // patched into the index rather than re-scanned per progress tick.
        await manager.reloadDownloadIndex()

        let folderRelativePath = "Folder/\(gid) - Progress Flush"
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(
                gid: gid,
                title: "Progress Flush",
                pageCount: pageCount
            ),
            folderURL: folderURL
        )

        let observationStream = await manager.observeDownloads()
        let emissionTask = Task<Int, Never> {
            var emissionCount = 0
            for await downloads in observationStream {
                guard let relevantDownload = downloads.first(where: { $0.gid == gid }) else { continue }
                emissionCount += 1
                if relevantDownload.completedPageCount == pageCount { break }
            }
            return emissionCount
        }

        var pendingResolvedPages = [DownloadCoordinator.PageResult]()
        var lastFlushDate = Date.distantPast
        for index in 1...pageCount {
            let relativePath = storage.makePageRelativePath(
                gid: gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            try Data([UInt8(index)]).write(
                to: folderURL.appendingPathComponent(relativePath),
                options: .atomic
            )
            pendingResolvedPages.append(
                .init(index: index, relativePath: relativePath, imageURL: nil)
            )
            try await manager.flushDownloadProgress(
                context: .init(gid: gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: false
            )
        }
        try await manager.flushDownloadProgress(
            context: .init(gid: gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )

        let emissionCount = try await waitForTaskValue(
            emissionTask,
            timeout: .seconds(2),
            description: "observer updates for progress flush"
        )
        let stored = await manager.fetchDownload(gid: gid)

        #expect(stored?.completedPageCount == pageCount)
        #expect(emissionCount < pageCount)
        #expect(emissionCount <= 2 + Int(ceil(Double(pageCount) / 8.0)))
    }

    @Test
    func testObserverHubBroadcastIsNotSuppressedByLateObserverInitialSnapshot() async throws {
        let hub = DownloadObserverHub()
        let initialDownload = sampleDownload(
            gid: "observer-race",
            title: "Observer Race",
            status: .queued,
            completedPageCount: 0
        )
        let updatedDownload = sampleDownload(
            gid: initialDownload.gid,
            title: initialDownload.title,
            status: .completed,
            completedPageCount: initialDownload.pageCount
        )

        await hub.notify([initialDownload])
        let existingSnapshot = [initialDownload]
        let existingObserverStream = await hub.observe { existingSnapshot }
        let existingObserverTask = collectEmissions(
            from: existingObserverStream,
            count: 2
        )

        let lateSnapshot = [updatedDownload]
        let lateObserverStream = await hub.observe { lateSnapshot }
        let lateObserverTask = collectEmissions(
            from: lateObserverStream,
            count: 1
        )
        let lateObserverEmissions = try await waitForTaskValue(
            lateObserverTask,
            timeout: .seconds(1),
            description: "late observer initial snapshot"
        )
        #expect(lateObserverEmissions == [[updatedDownload]])

        await hub.notify([updatedDownload])

        let existingObserverEmissions = try await waitForTaskValue(
            existingObserverTask,
            timeout: .seconds(1),
            description: "existing observer update after late observer registration"
        )
        #expect(existingObserverEmissions == [[initialDownload], [updatedDownload]])
    }

    @Test
    func testObserverHubRegistersObserverBeforeReturningStream() async {
        let hub = DownloadObserverHub()
        let initialDownload = sampleDownload(
            gid: "observer-registration",
            title: "Observer Registration",
            status: .completed
        )
        let registrationSnapshot = [initialDownload]
        let stream = await hub.observe { registrationSnapshot }
        let observerTask = collectEmissions(from: stream, count: 1)

        let emissions = await observerTask.value
        #expect(emissions == [[initialDownload]])
    }

    @Test
    func testObserveDeliversNotifyArrivingDuringSnapshotResolution() async throws {
        let hub = DownloadObserverHub()
        let initialDownload = sampleDownload(
            gid: "observer-window",
            title: "Observer Window",
            status: .queued,
            completedPageCount: 0
        )
        let updatedDownload = sampleDownload(
            gid: initialDownload.gid,
            title: initialDownload.title,
            status: .completed,
            completedPageCount: initialDownload.pageCount
        )

        // The provider notifies the hub mid-resolution, reproducing a state change
        // landing in the capture->register window. The observer must receive the
        // notify value, not the stale snapshot captured before it.
        let stream = await hub.observe {
            await hub.notify([updatedDownload])
            return [initialDownload]
        }
        let observerTask = collectEmissions(from: stream, count: 1)

        let emissions = try await waitForTaskValue(
            observerTask,
            timeout: .seconds(1),
            description: "observer notify during snapshot resolution"
        )
        #expect(emissions == [[updatedDownload]])
    }
}

private func collectEmissions(
    from stream: AsyncStream<[DownloadedGallery]>,
    count: Int
) -> Task<[[DownloadedGallery]], Never> {
    Task {
        var emissions = [[DownloadedGallery]]()
        for await downloads in stream {
            emissions.append(downloads)
            if emissions.count == count {
                break
            }
        }
        return emissions
    }
}
