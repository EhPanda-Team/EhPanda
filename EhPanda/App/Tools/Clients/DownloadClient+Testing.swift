//
//  DownloadClient+Testing.swift
//  EhPanda
//

import Foundation

#if DEBUG
extension DownloadManager {
    func testingInstallActiveTask(
        gid: String,
        task: Task<Void, Never>
    ) {
        activeGalleryID = gid
        activeTask = task
    }

    func testingScheduleNextIfNeeded() async {
        await scheduleNextIfNeeded()
    }

    func testingSetFetchDownloadsFromStoreHook(
        _ hook: (@Sendable () async -> Void)?
    ) {
        testingFetchDownloadsFromStoreHook = hook
    }

    func testingSetPersistFailureHook(
        _ hook: (@Sendable () async -> Void)?
    ) {
        testingPersistFailureHook = hook
    }

    func testingScheduledGalleryIDs() -> [String] {
        testingScheduledGalleryIDHistory
    }

    func testingHasActiveTask() -> Bool {
        activeTask != nil
    }

    func testingFetchDownload(
        gid: String
    ) async -> DownloadedGallery? {
        await fetchDownload(gid: gid)
    }

    func testingActiveGalleryID() -> String? {
        activeGalleryID
    }

    func testingRestoreCachedPages(
        payload: DownloadRequestPayload
    ) async throws -> Int {
        try storage.ensureRootDirectory()
        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: payload.gallery.gid)
        try? fileManager().removeItem(at: temporaryFolderURL)
        try createDirectory(at: temporaryFolderURL)
        try createDirectory(
            at: temporaryFolderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages,
                isDirectory: true
            )
        )

        let downloadContext = PageDownloadContext(
            payload: payload,
            source: nil,
            temporaryFolderURL: temporaryFolderURL,
            storedGalleryImageState:
                await fetchCachedGalleryImageState(
                    gid: payload.gallery.gid
                )
        )
        let batchResult = try await downloadPages(
            context: downloadContext,
            pendingPageIndices: pendingPageIndices(
                payload: payload,
                folderURL: temporaryFolderURL,
                existingPageRelativePaths: [:]
            ),
            existingManifest: nil,
            existingPageRelativePaths: [:]
        )
        return batchResult.pages.count
    }

    func testingFetchLatestPayload(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        pageSelection: [Int]? = nil
    ) async throws -> FetchLatestPayloadResult {
        try await fetchLatestPayload(
            for: download,
            mode: mode,
            pageSelection: pageSelection
        )
    }

    func testingPrepareWorkingSeed(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        versionSignature: String
    ) throws -> PrepareWorkingSeedResult {
        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: payload.gallery.gid)
        try? fileManager().removeItem(at: temporaryFolderURL)
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            temporaryFolderURL: temporaryFolderURL,
            versionSignature: versionSignature
        )
        return PrepareWorkingSeedResult(
            folderURL: workingSeed.folderURL,
            manifest: workingSeed.manifest,
            existingPages: workingSeed.existingPages,
            coverRelativePath: workingSeed.coverRelativePath
        )
    }

    func testingProcessDownload(gid: String) async {
        await processDownload(gid: gid)
    }

    func testingDetectResponseError(
        fileURL: URL,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: requestURL
        )
    }

    func testingDetectResponseError(
        data: Data,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        detectResponseError(
            data: data,
            response: response,
            requestURL: requestURL
        )
    }
}
#endif
