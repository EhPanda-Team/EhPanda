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

        let store = TestStore(initialState: initialState) {
            DownloadInspectorReducer()
        } withDependencies: {
            $0.downloadClient = .init(
                observeDownloads: {
                    AsyncStream { continuation in
                        continuation.yield([download])
                        continuation.yield([])
                        continuation.finish()
                    }
                },
                fetchDownloads: { [download] },
                fetchDownload: { gid in gid == download.gid ? download : nil },
                refreshDownloads: {},
                resumeQueue: {},
                badges: { _ in [:] },
                updateRemoteSignature: { _, _ in .none },
                enqueue: { _ in .success(()) },
                togglePause: { _ in .success(()) },
                retry: { _, _ in .success(()) },
                delete: { _ in .success(()) },
                loadManifest: { _ in .failure(.notFound) },
                loadInspection: { _ in .success(inspection) }
            )
        }
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
    func testDownloadManagerBatchesObserverUpdatesDuringProgressFlush() async throws {
        let container = try makeInMemoryContainer()
        let pageCount = 20
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 104)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)

        let folderRelativePath = "\(gid) - Progress Flush"
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
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

        var pendingResolvedPages = [DownloadManager.PageResult]()
        var lastFlushDate = Date.distantPast
        for index in 1...pageCount {
            let relativePath = "pages/\(String(format: "%04d", index)).jpg"
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
                completedCount: index,
                lastFlushDate: &lastFlushDate,
                force: false
            )
        }
        try await manager.flushDownloadProgress(
            context: .init(gid: gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            completedCount: pageCount,
            lastFlushDate: &lastFlushDate,
            force: true
        )

        let emissionCount = try await waitForTaskValue(
            emissionTask,
            timeout: .seconds(2),
            description: "observer updates for progress flush"
        )
        let stored = await manager.testingFetchDownload(gid: gid)

        #expect(stored?.completedPageCount == pageCount)
        #expect(emissionCount < pageCount)
        #expect(emissionCount <= 2 + Int(ceil(Double(pageCount) / 8.0)))
    }
}
