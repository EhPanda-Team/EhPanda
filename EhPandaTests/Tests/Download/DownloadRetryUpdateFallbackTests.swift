//
//  DownloadRetryUpdateFallbackTests.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadRetryUpdateFallbackTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesFullUpdateWhenGalleryHasUpdate() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, queueingManager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID, persistenceContainer: container
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let fallbackResult = try await fetchUpdateFallbackPayload(
            manager: queueingManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        let updatedVersionSignature = fallbackResult.versionSignature
        let pageCount = fallbackResult.pageCount
        let oldCount = pageCount - 5
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)

        try insertPersistedDownload(
            in: container, gid: gid, status: .updateAvailable,
            completedPageCount: oldCount - 1, pageCount: oldCount,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: updatedVersionSignature
        )
        let queuedCandidate = await queueingManager.testingFetchDownload(gid: gid)
        #expect(queuedCandidate?.hasUpdate == true)

        let blockerTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 5_000_000_000) }
        await queueingManager.testingInstallActiveTask(gid: "blocker", task: blockerTask)
        defer { blockerTask.cancel() }

        let retryResult = await queueingManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = retryResult else {
            Issue.record("retryPages should succeed, got \(retryResult)")
            return
        }

        let queued = await queueingManager.testingFetchDownload(gid: gid)
        #expect(queued?.status == .updateAvailable)
        #expect(queued?.pendingOperation == .update)
        #expect(queued?.lastError == nil)
        if FileManager.default.fileExists(atPath: temporaryFolderURL.path) {
            let queuedResumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
            #expect(queuedResumeState.mode == .update)
            #expect(queuedResumeState.pageSelection == nil)
        }
    }

    @Test
    func testRetryPagesNormalizesImmediateUpdateWhenGalleryHasUpdate() async throws {
        let container = try makeInMemoryContainer()
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, immediateManager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID, persistenceContainer: container
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let updateResult = try await fetchUpdateFallbackPayload(
            manager: immediateManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        let updatedVersionSignature = updateResult.versionSignature
        let pageCount = updateResult.pageCount

        try setupImmediateUpdateTestState(
            container: container, storage: storage,
            context: DownloadPageContext(gid: gid, pageIndex: pageIndex, pageCount: pageCount),
            signatures: VersionSignaturePair(old: oldVersionSignature, updated: updatedVersionSignature)
        )

        let immediateBlockerTask = Task<Void, Never> {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
        await immediateManager.testingInstallActiveTask(gid: gid, task: immediateBlockerTask)
        defer { immediateBlockerTask.cancel() }

        let result = await immediateManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = result else {
            Issue.record("Immediate retryPages should succeed, got \(result)")
            return
        }

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let resumedState = try storage.readResumeState(folderURL: temporaryFolderURL)
        #expect(resumedState.mode == .update)
        #expect(resumedState.versionSignature == updatedVersionSignature)
        #expect(resumedState.pageCount == pageCount)
        #expect(resumedState.pageSelection == nil)
        let resumedDownload = await immediateManager.testingFetchDownload(gid: gid)
        #expect(resumedDownload?.status == .downloading)
        #expect(resumedDownload?.pendingOperation == nil)
        #expect(resumedDownload?.lastError == nil)
    }
}

// MARK: - Update Fallback Payload Result

private struct UpdateFallbackPayloadResult {
    let versionSignature: String
    let pageCount: Int
}

// MARK: - Version Signature Pair

private struct VersionSignaturePair {
    let old: String
    let updated: String
}

// MARK: - Download Page Context

private struct DownloadPageContext {
    let gid: String
    let pageIndex: Int
    let pageCount: Int
}

// MARK: - Setup Helpers

private extension DownloadRetryUpdateFallbackTests {
    func fetchUpdateFallbackPayload(
        manager: DownloadManager, sessionID: String, gid: String,
        pageIndex: Int, oldVersionSignature: String
    ) async throws -> UpdateFallbackPayloadResult {
        let stubContent = StubHandlerContent(
            detailHTML: try fixtureData(resource: "GalleryDetail", pathExtension: "html"),
            mpvHTML: try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html"),
            metadataResponse: try makeMetadataResponseData(gid: gid)
        )
        installDownloadStubHandler(
            sessionID: sessionID, gid: gid, pageIndex: pageIndex, content: stubContent
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155,
            remoteVersionSignature: oldVersionSignature,
            latestRemoteVersionSignature: ""
        )
        let fetchResult = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .update
        )
        let pageCount = fetchResult.payload.galleryDetail.pageCount
        #expect(pageCount > pageIndex)
        #expect(pageCount > 5)
        return UpdateFallbackPayloadResult(
            versionSignature: fetchResult.versionSignature, pageCount: pageCount
        )
    }

    func setupImmediateUpdateTestState(
        container: NSPersistentContainer, storage: DownloadFileStorage,
        context: DownloadPageContext, signatures: VersionSignaturePair
    ) throws {
        let oldCount = context.pageCount - 5
        let manifest = try sampleManifest(
            gid: context.gid, title: "Pause Race",
            pageCount: context.pageCount, versionSignature: signatures.updated
        )
        try writeTemporaryManifestAndPages(
            storage: storage, gid: context.gid, manifest: manifest,
            pageCount: context.pageCount, omittingPage: context.pageIndex,
            versionSignature: signatures.updated,
            mode: .update, pageSelection: [context.pageIndex]
        )
        try insertPersistedDownload(
            in: container, gid: context.gid, status: .updateAvailable,
            completedPageCount: oldCount - 1, pageCount: oldCount,
            remoteVersionSignature: signatures.old,
            latestRemoteVersionSignature: signatures.updated
        )
    }
}
