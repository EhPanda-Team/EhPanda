//
//  DownloadClient+Persistence.swift
//  EhPanda
//

import Foundation

// MARK: - Disk Index
extension DownloadManager {
    @discardableResult
    func reloadDownloadIndex() async -> [DownloadedGallery] {
        do {
            let records = try storage.scanDownloadFolders()
            downloadIndex = deduplicatedDownloadIndex(from: records)
            return await downloads(from: records)
        } catch {
            Logger.error(error)
            downloadIndex = [:]
            return []
        }
    }

    func indexedDownload(gid: String) async -> DownloadedGallery? {
        guard let record = downloadIndex[gid] else { return nil }
        return downloadedGallery(from: record)
    }

    func indexedDownloads() async -> [DownloadedGallery] {
        await downloads(from: Array(downloadIndex.values))
    }

    private func downloads(
        from records: [DownloadFolderRecord]
    ) async -> [DownloadedGallery] {
        return deduplicatedDownloadIndex(from: records).values
            .map {
                downloadedGallery(from: $0)
            }
            .sorted(by: sortDownloadsByDisplayStatus)
    }

    private func deduplicatedDownloadIndex(
        from records: [DownloadFolderRecord]
    ) -> [String: DownloadFolderRecord] {
        records.reduce(into: [:]) { index, record in
            let gid = record.manifest.gid
            guard let currentRecord = index[gid] else {
                index[gid] = record
                return
            }
            if record.displayDate > currentRecord.displayDate {
                index[gid] = record
            }
        }
    }

    private func downloadedGallery(
        from record: DownloadFolderRecord
    ) -> DownloadedGallery {
        let gid = record.manifest.gid
        return DownloadedGallery(
            manifest: record.manifest,
            folderURL: record.folderURL,
            modifiedAt: record.modifiedAt,
            displayStatus: displayStatus(for: record),
            lastError: validationErrors[gid] ?? downloadErrors[gid]
        )
    }

    private func displayStatus(
        for record: DownloadFolderRecord
    ) -> DownloadDisplayStatus {
        let gid = record.manifest.gid
        if validationErrors[gid] != nil {
            return .error
        }
        if activeGalleryID == gid {
            return .active
        }
        if queueStore.contains(gid) {
            return .queued
        }
        if record.manifest.isComplete,
           updatedGalleryIDs.contains(gid) {
            return .updateAvailable
        }
        if record.manifest.isComplete {
            return .completed
        }
        if downloadErrors[gid] != nil {
            return .error
        }
        return .inactive
    }

    private func sortDownloadsByDisplayStatus(
        _ lhs: DownloadedGallery,
        _ rhs: DownloadedGallery
    ) -> Bool {
        if lhs.displayStatus != rhs.displayStatus {
            return lhs.displayStatus.rawValue < rhs.displayStatus.rawValue
        }
        return (lhs.lastDownloadedAt ?? .distantPast)
            > (rhs.lastDownloadedAt ?? .distantPast)
    }
}

private extension DownloadFolderRecord {
    var displayDate: Date {
        modifiedAt ?? .distantPast
    }
}

// MARK: - Store Operations
extension DownloadManager {
    func fetchDownload(
        gid: String
    ) async -> DownloadedGallery? {
        _ = await reloadDownloadIndex()
        return await indexedDownload(gid: gid)
    }

    func fetchDownloadsFromStore() async -> [DownloadedGallery] {
#if DEBUG
        if let testingFetchDownloadsFromStoreHook {
            await testingFetchDownloadsFromStoreHook()
        }
#endif
        return await reloadDownloadIndex()
    }

    func fetchDownloadsFromStore(
        gids: [String]
    ) async -> [DownloadedGallery] {
#if DEBUG
        if let testingFetchDownloadsFromStoreHook {
            await testingFetchDownloadsFromStoreHook()
        }
#endif
        let gidSet = Set(gids)
        return await reloadDownloadIndex()
            .filter { gidSet.contains($0.gid) }
    }
}

// MARK: - Persist Failure & Progress
extension DownloadManager {
    func persistFailure(
        error: AppError,
        context: FailureContext
    ) async {
#if DEBUG
        if let testingPersistFailureHook {
            await testingPersistFailureHook()
        }
#endif
        downloadErrors[context.gid] = DownloadFailure(error: error)
        queuedModes[context.gid] = nil
        queuedPageSelections[context.gid] = nil
        await queueStore.remove(context.gid)
        _ = await reloadDownloadIndex()
    }

    func flushDownloadProgress(
        context: ProgressFlushContext,
        pendingResolvedPages: inout [PageResult],
        lastFlushDate: inout Date,
        force: Bool
    ) async throws {
        let shouldFlush = force
            || pendingResolvedPages.count
            >= Self.progressFlushPageInterval
            || Date().timeIntervalSince(lastFlushDate)
            >= Self.progressFlushMinimumInterval
        guard shouldFlush else { return }

        let resolvedPages = pendingResolvedPages
        try flushManifestPageProgress(
            folderURL: context.folderURL,
            pages: resolvedPages
        )
        pendingResolvedPages
            .removeAll(keepingCapacity: true)
        lastFlushDate = Date()
        await notifyObservers()
    }

    func flushManifestPageProgress(
        folderURL: URL,
        pages: [PageResult]
    ) throws {
        guard !pages.isEmpty else { return }
        let manifestURL = folderURL
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
        guard fileManager.operate({
            $0.fileExists(atPath: manifestURL.path)
        }) else {
            return
        }
        let pageRelativePaths = pages.reduce(into: [Int: String]()) { result, page in
            result[page.index] = page.relativePath
        }
        try storage.refreshManifestPageFileHashes(
            folderURL: folderURL,
            pageRelativePaths: pageRelativePaths
        )
    }

}
