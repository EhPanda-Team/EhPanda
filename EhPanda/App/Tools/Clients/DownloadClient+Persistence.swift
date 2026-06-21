//
//  DownloadClient+Persistence.swift
//  EhPanda
//

import Foundation

// MARK: - Disk Index
extension DownloadCoordinator {
    @discardableResult
    func reloadDownloadIndex() async -> [DownloadedGallery] {
        do {
            let scanResult = try storage.scanDownloads()
            downloadIndex = deduplicatedDownloadIndex(from: scanResult.records)
            userFolders = scanResult.userFolders
            hasLoadedIndex = true
            return await downloads(from: scanResult.records)
        } catch {
            Logger.error(error)
            downloadIndex = [:]
            userFolders = []
            hasLoadedIndex = true
            return []
        }
    }

    /// The filesystem is the durable source of truth, but this actor's index is the read authority
    /// between explicit sync points. Hot lookups must not walk download folders; app launch,
    /// foreground return, pull-to-refresh, and targeted surprise repair are the scan boundaries.
    func indexedDownload(gid: String) async -> DownloadedGallery? {
        guard hasLoadedIndex else { return nil }
        guard let record = downloadIndex[gid] else { return nil }
        return downloadedGallery(from: record)
    }

    func indexedDownloads() async -> [DownloadedGallery] {
        guard hasLoadedIndex else { return [] }
        return await downloads(from: Array(downloadIndex.values))
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

    func indexedDownloads(gids: [String]) async -> [DownloadedGallery] {
        guard hasLoadedIndex else { return [] }
        let gidSet = Set(gids)
        return await downloads(
            from: downloadIndex.values.filter { gidSet.contains($0.manifest.gid) }
        )
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
            folderName: record.parentFolderName,
            localCoverURL: record.localCoverURL,
            localPageURLs: record.localPageURLs,
            modificationDate: record.modificationDate,
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
            return lhs.displayStatus.sortPriority < rhs.displayStatus.sortPriority
        }
        return (lhs.lastDownloadedDate ?? .distantPast)
            > (rhs.lastDownloadedDate ?? .distantPast)
    }
}

private extension DownloadFolderRecord {
    var displayDate: Date {
        modificationDate ?? .distantPast
    }
}

// MARK: - Store Operations
extension DownloadCoordinator {
    func fetchDownload(
        gid: String
    ) async -> DownloadedGallery? {
        return await indexedDownload(gid: gid)
    }

    func fetchDownloadsFromStore() async -> [DownloadedGallery] {
        return await reloadDownloadIndex()
    }

    @discardableResult
    func reloadDownloadRecord(gid: String, token: String) async -> DownloadedGallery? {
        let records = storage.galleryFolderRecords(gid: gid, token: token)
        guard let record = deduplicatedDownloadIndex(from: records).values.first else {
            downloadIndex[gid] = nil
            return nil
        }
        downloadIndex[gid] = record
        if !userFolders.contains(record.parentFolderName) {
            userFolders.append(record.parentFolderName)
            userFolders.sort {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        }
        return await indexedDownload(gid: gid)
    }
}

// MARK: - Persist Failure & Progress
extension DownloadCoordinator {
    func persistFailure(
        error: AppError,
        context: FailureContext
    ) async {
        await taskRunner.beforeFailurePersistence()
        await settleDownloadFailure(gid: context.gid, error: error)
    }

    /// Surfaces a download-level failure and clears its queue intent so it does not
    /// auto-resume. Shared by the foreground `persistFailure` and the background/orphan
    /// fatal-error paths so a fatal 509/auth/ban settles identically either way.
    func settleDownloadFailure(gid: String, error: AppError) async {
        downloadErrors[gid] = DownloadFailure(error: error)
        clearDownloadQueueIntent(gid: gid)
        await queueStore.remove(gid)
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
        let manifest = try storage.refreshManifestPageFileHashes(
            folderURL: folderURL,
            pageRelativePaths: pageRelativePaths
        )
        updateDownloadIndex(folderURL: folderURL, manifest: manifest)
    }

    func updateDownloadIndex(folderURL: URL, manifest: DownloadManifest) {
        downloadIndex[manifest.gid] = storage.galleryFolderRecord(
            folderURL: folderURL,
            manifest: manifest,
            parentFolderName: storage.parentFolderName(forFolderURL: folderURL) ?? ""
        )
    }
}
