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

    func testingSetScheduledProcessHook(
        _ hook: (@Sendable (String) async -> Void)?
    ) {
        testingScheduledProcessHook = hook
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
