//
//  DownloadRetryMinimalSourceTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadRetryMinimalSourceTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesUsesMinimalSourceResolutionAndSkipsWhenNoPendingPages() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 200)
        let pageIndex = 40
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let (storage, manager) = makeStubbedDownloadManager(
            rootURL: rootURL, sessionID: sessionID
        )
        let setup = try await setupMinimalSourceTest(
            manager: manager, sessionID: sessionID, gid: gid, pageIndex: pageIndex
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let manifest = try sampleManifest(
            gid: gid, title: "Pause Race",
            pageCount: setup.pageCount
        )
        try writeFinalManifest(
            storage: storage,
            gid: gid,
            manifest: manifest,
            missingPageIndex: pageIndex
        )
        await manager.testingSetDownloadError(
            .init(code: .fileOperationFailed, message: "Page \(pageIndex) is missing."),
            gid: gid
        )
        let blocker = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(60))
        }
        defer { blocker.cancel() }
        await manager.testingInstallActiveTask(gid: "busy", task: blocker)
        guard case .success = await manager.retryPages(gid: gid, pageIndices: [pageIndex]) else {
            Issue.record("retryPages should queue the selected page.")
            return
        }
        await manager.testingProcessDownload(gid: gid)

        let firstRunSnapshot = setup.recorder.snapshot()
        #expect(
            firstRunSnapshot.previewPageNumbers == [0],
            "\(firstRunSnapshot)"
        )

        setup.recorder.reset()
        try await assertRetrySkipsCompletedSelection(
            .init(
                storage: storage,
                manager: manager,
                gid: gid,
                pageIndex: pageIndex,
                setup: setup,
                manifest: manifest
            )
        )
    }
}

// MARK: - Minimal Source Test Result

private struct MinimalSourceTestResult {
    let recorder: RequestRecorder
    let pageCount: Int
}

private struct MinimalSourceRetrySkipContext {
    let storage: DownloadFileStorage
    let manager: DownloadManager
    let gid: String
    let pageIndex: Int
    let setup: MinimalSourceTestResult
    let manifest: DownloadManifest
}

// MARK: - Setup Helpers

private extension DownloadRetryMinimalSourceTests {
    func assertRetrySkipsCompletedSelection(
        _ context: MinimalSourceRetrySkipContext
    ) async throws {
        let blocker = Task<Void, Never> {
            try? await Task.sleep(for: .seconds(60))
        }
        defer { blocker.cancel() }
        await context.manager.testingInstallActiveTask(gid: "busy", task: blocker)
        guard case .success = await context.manager.retryPages(
            gid: context.gid,
            pageIndices: [context.pageIndex]
        ) else {
            Issue.record("retryPages should queue the selected page.")
            return
        }
        await context.manager.testingProcessDownload(gid: context.gid)
        let snapshot = context.setup.recorder.snapshot()
        #expect(snapshot.previewPageNumbers.isEmpty, "\(snapshot)")
        #expect(snapshot.mpvRequests == 0)
        #expect(snapshot.imageDispatchRequests == 0)
    }

    func writeFinalManifest(
        storage: DownloadFileStorage,
        gid: String,
        manifest: DownloadManifest,
        missingPageIndex: Int
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Pause Race")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try Data([0x00]).write(
            to: folderURL.appendingPathComponent("\(gid)_token_cover.jpg"),
            options: .atomic
        )
        for index in manifest.pages.keys where index != missingPageIndex {
            try Data([UInt8(index % 255)]).write(
                to: folderURL.appendingPathComponent("\(gid)_token_\(index).jpg"),
                options: .atomic
            )
        }
        try storage.writeManifest(manifest, folderURL: folderURL)
    }

    func setupMinimalSourceTest(
        manager: DownloadManager, sessionID: String, gid: String, pageIndex: Int
    ) async throws -> MinimalSourceTestResult {
        let recorder = RequestRecorder()
        let stubContent = StubHandlerContent(
            detailHTML: try fixtureData(resource: "GalleryDetail", pathExtension: "html"),
            mpvHTML: try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html"),
            metadataResponse: try makeMetadataResponseData(gid: gid)
        )
        installDownloadStubHandler(
            sessionID: sessionID, gid: gid, pageIndex: pageIndex,
            content: stubContent, recorder: recorder
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155
        )
        let fetchedPayload = try await manager.testingFetchLatestPayload(
            for: scaffoldDownload, mode: .redownload, pageSelection: [pageIndex]
        )
        recorder.reset()
        return MinimalSourceTestResult(
            recorder: recorder,
            pageCount: fetchedPayload.galleryDetail.pageCount
        )
    }
}
