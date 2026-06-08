//
//  DownloadRetryUpdateFallbackTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadRetryUpdateFallbackTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesFullUpdateWhenGalleryHasUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, queueingManager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let fallbackResult = try await fetchUpdateFallbackPayload(
            manager: queueingManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        let pageCount = fallbackResult.pageCount
        let oldCount = pageCount - 5

        try writeFinalManifest(
            storage: storage,
            gid: gid,
            pageCount: oldCount
        )
        await queueingManager.testingSetUpdatedGalleryIDs([gid])
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
        #expect(queued?.status == .queued)
        #expect(queued?.badge == .queued)
        #expect(queued?.pendingOperation == nil)
        #expect(queued?.lastError == nil)
    }

    @Test
    func testRetryPagesNormalizesImmediateUpdateWhenGalleryHasUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let oldVersionSignature = chainVersionSignature(gid: gid, token: "token")
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, immediateManager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let updateResult = try await fetchUpdateFallbackPayload(
            manager: immediateManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex, oldVersionSignature: oldVersionSignature
        )
        let pageCount = updateResult.pageCount

        try setupImmediateUpdateTestState(
            storage: storage,
            context: DownloadPageContext(gid: gid, pageIndex: pageIndex, pageCount: pageCount)
        )
        await immediateManager.testingSetUpdatedGalleryIDs([gid])

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
        let fetchedPayload = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .update
        )
        let pageCount = fetchedPayload.galleryDetail.pageCount
        #expect(pageCount > pageIndex)
        #expect(pageCount > 5)
        return UpdateFallbackPayloadResult(
            versionSignature: chainVersionSignature(gid: gid, token: "updated-key"),
            pageCount: pageCount
        )
    }

    func setupImmediateUpdateTestState(
        storage: DownloadFileStorage,
        context: DownloadPageContext
    ) throws {
        let oldCount = context.pageCount - 5
        try writeFinalManifest(
            storage: storage,
            gid: context.gid,
            pageCount: oldCount
        )
    }

    func writeFinalManifest(
        storage: DownloadFileStorage,
        gid: String,
        pageCount: Int
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] Pause Race")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            completeManifest(gid: gid, title: "Pause Race", pageCount: pageCount),
            folderURL: folderURL
        )
    }

    func completeManifest(
        gid: String,
        title: String,
        pageCount: Int
    ) throws -> DownloadManifest {
        let manifest = try sampleManifest(
            gid: gid,
            title: title,
            pageCount: pageCount
        )
        return DownloadManifest(
            gid: manifest.gid,
            host: manifest.host,
            token: manifest.token,
            title: manifest.title,
            jpnTitle: manifest.jpnTitle,
            category: manifest.category,
            language: manifest.language,
            uploader: manifest.uploader,
            tags: manifest.tags,
            postedDate: manifest.postedDate,
            rating: manifest.rating,
            pages: Dictionary(
                uniqueKeysWithValues:
                    manifest.pages.keys.sorted().map { ($0, "sha256:\($0)") }
            )
        )
    }
}
