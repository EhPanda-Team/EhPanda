//
//  DownloadProcessTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadProcessTests: DownloadFeatureTestCase {
    @Test
    func testFailurePersistenceCompletesBeforeRescheduling() async throws {
        let sessionID = UUID().uuidString
        let gid = "100010"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let persistenceGate = FailurePersistenceGate()
        let scheduledRecorder = ScheduledGalleryRecorder()
        let taskRunner = DownloadTaskRunner(
            recordScheduledGallery: { gid in
                scheduledRecorder.record(gid)
            },
            beforeFailurePersistence: {
                await persistenceGate.waitAtGate()
            }
        )
        let (storage, manager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL,
            sessionID: sessionID,
            taskRunner: taskRunner
        )
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        try writeProcessManifestFolder(
            storage: storage,
            gid: gid,
            title: "Queued Failure",
            pageCount: 2
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        let completionProbe = ProcessCompletionProbe()
        let processTask = Task {
            await manager.processDownload(gid: gid)
            await completionProbe.finish()
        }

        await persistenceGate.waitForArrival()
        let completedBeforePersistence = await completionProbe
            .isFinished()
        let scheduledBeforePersistence = scheduledRecorder.snapshot()
        #expect(completedBeforePersistence == false)
        #expect(scheduledBeforePersistence.isEmpty)

        await persistenceGate.release()
        await processTask.value

        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.displayStatus == .error)
        #expect(stored?.lastError?.code == .networkingFailed)

        await manager.scheduleNextIfNeeded()
        let scheduledAfterFailure = scheduledRecorder.snapshot()
        #expect(scheduledAfterFailure.isEmpty)
    }

    @Test
    func testProcessDownloadClearsStalePageSelectionWhenLatestPayloadRevealsUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 401)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, manager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let updatedPageCount = try await fetchAndInstallStub(
            manager: manager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex
        )
        let oldPageCount = updatedPageCount - 5

        let staleFolderURL = try prepareStaleExistingFolder(
            storage: storage, gid: gid, pageIndex: pageIndex,
            oldPageCount: oldPageCount
        )
        await manager.reloadDownloadIndex()
        let beforeProcess = await manager.fetchDownload(gid: gid)
        #expect(beforeProcess?.hasUpdate ?? true == false)

        await manager.processDownload(gid: gid)

        try await verifyCompletedProcess(
            manager: manager, storage: storage,
            context: ProcessVerificationContext(
                gid: gid,
                updatedPageCount: updatedPageCount,
                staleFolderURL: staleFolderURL
            )
        )
    }

    @Test
    func testProcessDownloadUsesLiveOptionsWhenQueuedDownloadStarts() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 403)
        let latestOptions = DownloadRequestOptions(
            threadLimit: 3,
            allowCellular: false,
            autoRetryFailedPages: false
        )
        let optionsBox = UncheckedBox(DownloadRequestOptions(allowCellular: true))
        let detailAllowsCellular = UncheckedBox<Bool?>(nil)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, manager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL,
            sessionID: sessionID,
            downloadOptionsProvider: { optionsBox.value }
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let detailHTML = try fixtureData(resource: "GalleryDetail", pathExtension: "html")
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.path.contains("/g/\(gid)/token") {
                detailAllowsCellular.value = request.allowsCellularAccess
                return (
                    try #require(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "text/html; charset=utf-8"]
                    )),
                    detailHTML
                )
            }
            throw URLError(.notConnectedToInternet)
        }

        try writeProcessManifestFolder(
            storage: storage,
            gid: gid,
            title: "Queued Options",
            pageCount: 2
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        optionsBox.value = latestOptions
        await manager.processDownload(gid: gid)

        #expect(detailAllowsCellular.value == false)
    }
}

private actor FailurePersistenceGate {
    private var didArrive = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitAtGate() async {
        didArrive = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitForArrival() async {
        guard !didArrive else { return }
        await withCheckedContinuation { continuation in
            arrivalContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private actor ProcessCompletionProbe {
    private var finished = false

    func finish() {
        finished = true
    }

    func isFinished() -> Bool {
        finished
    }
}

private struct ProcessVerificationContext {
    let gid: String
    let updatedPageCount: Int
    let staleFolderURL: URL
}

private extension DownloadProcessTests {
    func writeProcessManifestFolder(
        storage: DownloadStore,
        gid: String,
        title: String,
        pageCount: Int
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: title, pageCount: pageCount),
            folderURL: folderURL
        )
    }

    func fetchAndInstallStub(
        manager: DownloadCoordinator, sessionID: String, gid: String,
        pageIndex: Int
    ) async throws -> Int {
        let stubContent = StubHandlerContent(
            detailHTML: try fixtureData(resource: "GalleryDetail", pathExtension: "html"),
            mpvHTML: try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html"),
            metadataResponse: try makeMetadataResponseData(gid: gid)
        )
        var allowedImageURLs = Set<String>()
        installDownloadStubHandler(
            sessionID: sessionID, gid: gid, pageIndex: pageIndex,
            content: stubContent, allowedImageURLs: allowedImageURLs
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155
        )
        let latestPayload = try await manager.fetchLatestPayload(
            for: scaffoldDownload, mode: .redownload, options: .init(), pageSelection: [pageIndex]
        )
        if let coverURL = latestPayload.galleryDetail.coverURL ?? latestPayload.gallery.coverURL {
            allowedImageURLs.insert(coverURL.absoluteString)
            installDownloadStubHandler(
                sessionID: sessionID, gid: gid, pageIndex: pageIndex,
                content: stubContent, allowedImageURLs: allowedImageURLs
            )
        }
        let updatedPageCount = latestPayload.galleryDetail.pageCount
        #expect(updatedPageCount > pageIndex)
        #expect(updatedPageCount > 5)
        return updatedPageCount
    }

    func prepareStaleExistingFolder(
        storage: DownloadStore, gid: String, pageIndex: Int,
        oldPageCount: Int
    ) throws -> URL {
        let staleManifest = try sampleManifest(
            gid: gid, title: "Pause Race",
            pageCount: oldPageCount
        )
        let folderURL = storage.folderURL(relativePath: "Folder/\(gid) - Pause Race")
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(staleManifest, folderURL: folderURL)
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent("123_token_cover.jpg"),
            options: .atomic
        )
        try Data([UInt8(pageIndex % 255)]).write(
            to: folderURL.appendingPathComponent("\(gid)_token_\(pageIndex).jpg"),
            options: .atomic
        )
        return folderURL
    }

    func verifyCompletedProcess(
        manager: DownloadCoordinator,
        storage: DownloadStore,
        context: ProcessVerificationContext
    ) async throws {
        let completedDownload = await manager.fetchDownload(gid: context.gid)
        let unwrapped = try #require(completedDownload)
        #expect(unwrapped.displayStatus == .completed)
        #expect(unwrapped.pageCount == context.updatedPageCount)
        #expect(unwrapped.completedPageCount == context.updatedPageCount)

        let completedFolderURL = unwrapped.folderURL
        let manifest = try storage.readManifest(folderURL: completedFolderURL)
        #expect(manifest.pageCount == context.updatedPageCount)
        #expect(manifest.pages.count == context.updatedPageCount)
        #expect(
            FileManager.default.fileExists(
                atPath: completedFolderURL.appendingPathComponent("\(context.gid)_token_1.jpg").path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: completedFolderURL.appendingPathComponent("123_token_1.jpg").path
            ) == false
        )

        #expect(FileManager.default.fileExists(atPath: context.staleFolderURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: completedFolderURL.path))
    }
}
