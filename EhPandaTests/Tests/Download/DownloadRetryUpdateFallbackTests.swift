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
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, queueingManager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let fallbackResult = try await fetchUpdateFallbackPayload(
            manager: queueingManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex
        )
        let pageCount = fallbackResult.pageCount
        let oldCount = pageCount - 5

        try writeFinalManifest(
            storage: storage,
            gid: gid,
            pageCount: oldCount
        )
        await queueingManager.reloadDownloadIndex()
        await queueingManager.testingSetUpdatedGalleryIDs([gid])
        let queuedCandidate = await queueingManager.fetchDownload(gid: gid)
        #expect(queuedCandidate?.hasUpdate == true)

        let blockerTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 5_000_000_000) }
        await queueingManager.testingInstallActiveTask(gid: "blocker", task: blockerTask)
        defer { blockerTask.cancel() }

        let retryResult = await queueingManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = retryResult else {
            Issue.record("retryPages should succeed, got \(retryResult)")
            return
        }

        let queued = await queueingManager.fetchDownload(gid: gid)
        #expect(queued?.displayStatus == .queued)
        #expect(queued?.badge.status == .queued)
        #expect(queued?.lastError == nil)
    }

    @Test
    func testRetryPagesNormalizesImmediateUpdateWhenGalleryHasUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, immediateManager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let updateResult = try await fetchUpdateFallbackPayload(
            manager: immediateManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex
        )
        let pageCount = updateResult.pageCount

        try setupImmediateUpdateTestState(
            storage: storage,
            context: DownloadPageContext(gid: gid, pageIndex: pageIndex, pageCount: pageCount)
        )
        await immediateManager.reloadDownloadIndex()
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

        let resumedDownload = await immediateManager.fetchDownload(gid: gid)
        #expect(resumedDownload?.displayStatus == .active)
        #expect(resumedDownload?.lastError == nil)
    }
}

// MARK: - Update Fallback Payload Result

private struct UpdateFallbackPayloadResult {
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
        manager: DownloadCoordinator, sessionID: String, gid: String,
        pageIndex: Int
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
            pageCount: 156, completedPageCount: 155
        )
        let fetchedPayload = try await manager.fetchLatestPayload(
            for: scaffoldDownload, mode: .update, options: .init(), pageSelection: nil
        )
        let pageCount = fetchedPayload.galleryDetail.pageCount
        #expect(pageCount > pageIndex)
        #expect(pageCount > 5)
        return UpdateFallbackPayloadResult(pageCount: pageCount)
    }

    func setupImmediateUpdateTestState(
        storage: DownloadStore,
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
        storage: DownloadStore,
        gid: String,
        pageCount: Int
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Pause Race")
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
            remoteCoverURL: manifest.remoteCoverURL,
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
