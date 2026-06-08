//
//  DownloadProcessTests.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadProcessTests: DownloadFeatureTestCase {
    @Test
    func testFailurePersistenceCompletesBeforeRescheduling() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString
        let gid = "100010"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (_, manager) = makeStubbedDownloadManager(
            rootURL: rootURL,
            sessionID: sessionID,
            persistenceContainer: container
        )
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .queued,
            completedPageCount: 0,
            pageCount: 2
        )

        let persistenceGate = FailurePersistenceGate()
        await manager.testingSetPersistFailureHook {
            await persistenceGate.waitAtGate()
        }

        let completionProbe = ProcessCompletionProbe()
        let processTask = Task {
            await manager.testingProcessDownload(gid: gid)
            await completionProbe.finish()
        }

        await persistenceGate.waitForArrival()
        let completedBeforePersistence = await completionProbe
            .isFinished()
        let scheduledBeforePersistence = await manager
            .testingScheduledGalleryIDs()
        #expect(completedBeforePersistence == false)
        #expect(scheduledBeforePersistence.isEmpty)

        await persistenceGate.release()
        await processTask.value
        await manager.testingSetPersistFailureHook(nil)

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .partial)
        #expect(stored?.lastError?.code == .networkingFailed)

        await manager.testingScheduleNextIfNeeded()
        let scheduledAfterFailure = await manager
            .testingScheduledGalleryIDs()
        #expect(scheduledAfterFailure.isEmpty)
    }

    @Test
    func testProcessDownloadClearsStalePageSelectionWhenLatestPayloadRevealsUpdate() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 401)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, manager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID, persistenceContainer: container
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let (updatedPageCount, updatedVersionSignature) = try await fetchAndInstallStub(
            manager: manager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        let oldPageCount = updatedPageCount - 5

        try insertPersistedDownload(
            in: container, gid: gid, status: .partial,
            completedPageCount: oldPageCount - 1, pageCount: oldPageCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        let beforeProcess = await manager.testingFetchDownload(gid: gid)
        #expect(beforeProcess?.hasUpdate ?? true == false)

        let staleFolderURL = try prepareStaleExistingFolder(
            storage: storage, gid: gid, pageIndex: pageIndex,
            oldPageCount: oldPageCount, oldVersionSignature: oldVersionSignature
        )

        await manager.testingProcessDownload(gid: gid)

        try await verifyCompletedProcess(
            manager: manager, storage: storage,
            context: ProcessVerificationContext(
                gid: gid,
                updatedPageCount: updatedPageCount,
                updatedVersionSignature: updatedVersionSignature,
                staleFolderURL: staleFolderURL
            )
        )
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
    let updatedVersionSignature: String
    let staleFolderURL: URL
}

private extension DownloadProcessTests {
    func fetchAndInstallStub(
        manager: DownloadManager, sessionID: String, gid: String,
        pageIndex: Int, oldVersionSignature: String
    ) async throws -> (Int, String) {
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
            pageCount: 156, completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: oldVersionSignature
        )
        let fetchResult = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .redownload, pageSelection: [pageIndex]
        )
        let latestPayload = fetchResult.payload
        let updatedVersionSignature = fetchResult.versionSignature
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
        return (updatedPageCount, updatedVersionSignature)
    }

    func prepareStaleExistingFolder(
        storage: DownloadFileStorage, gid: String, pageIndex: Int,
        oldPageCount: Int, oldVersionSignature: String
    ) throws -> URL {
        let staleManifest = try sampleManifest(
            gid: gid, title: "Pause Race",
            pageCount: oldPageCount, versionSignature: oldVersionSignature
        )
        let folderURL = storage.folderURL(relativePath: "\(gid) - Pause Race")
        try? FileManager.default.removeItem(at: folderURL)
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages, isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try storage.writeManifest(staleManifest, folderURL: folderURL)
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([UInt8(pageIndex % 255)]).write(
            to: folderURL.appendingPathComponent(
                "pages/\(String(format: "%04d", pageIndex)).jpg"
            ),
            options: .atomic
        )
        try storage.writeResumeState(
            .init(
                mode: .redownload,
                versionSignature: oldVersionSignature,
                pageCount: oldPageCount,
                downloadOptions: .init(),
                pageSelection: [pageIndex]
            ),
            folderURL: folderURL
        )
        return folderURL
    }

    func verifyCompletedProcess(
        manager: DownloadManager,
        storage: DownloadFileStorage,
        context: ProcessVerificationContext
    ) async throws {
        let completedDownload = await manager.testingFetchDownload(gid: context.gid)
        let unwrapped = try #require(completedDownload)
        #expect(unwrapped.status == .completed)
        #expect(unwrapped.pageCount == context.updatedPageCount)
        #expect(unwrapped.completedPageCount == context.updatedPageCount)

        let completedFolderURL = storage.folderURL(relativePath: unwrapped.folderRelativePath)
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
                atPath: completedFolderURL.appendingPathComponent("pages/0001.jpg").path
            ) == false
        )

        let resumeState = try storage.readResumeState(folderURL: completedFolderURL)
        #expect(resumeState.versionSignature == context.updatedVersionSignature)
        #expect(resumeState.pageCount == context.updatedPageCount)
        #expect(resumeState.pageSelection == nil)
        #expect(FileManager.default.fileExists(atPath: context.staleFolderURL.path) == false)
        #expect(
            FileManager.default.fileExists(
                atPath: storage.temporaryFolderURL(gid: context.gid).path
            ) == false
        )
    }
}
