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

    func testingSetQueuedGalleryIDs(_ gids: [String]) async {
        await queueStore.removeAll()
        for gid in gids {
            await queueStore.enqueue(gid)
        }
    }

    func testingSetDownloadError(
        _ failure: DownloadFailure?,
        gid: String
    ) {
        downloadErrors[gid] = failure
    }

    func testingSetUpdatedGalleryIDs(_ gids: Set<String>) {
        updatedGalleryIDs = gids
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
        try? fileManager.operate {
            try $0.removeItem(at: temporaryFolderURL)
        }
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
        let folderURL = storage.folderURL(
            relativePath: folderRelativePath(for: payload)
        )
        try? fileManager.operate {
            try $0.removeItem(at: folderURL)
        }
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL,
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
