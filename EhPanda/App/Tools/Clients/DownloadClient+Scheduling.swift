//
//  DownloadClient+Scheduling.swift
//  EhPanda
//

import Foundation

// MARK: - Observer Management & Scheduling
extension DownloadManager {
    func addObserver(
        id: UUID,
        continuation: AsyncStream<[DownloadedGallery]>.Continuation
    ) async {
        observers[id] = continuation
        let downloads = await fetchDownloads()
        lastObservedDownloads = downloads
        continuation.yield(downloads)
    }

    func removeObserver(id: UUID) {
        observers[id] = nil
    }

    func notifyObservers() async {
        let downloads = await fetchDownloads()
        guard downloads != lastObservedDownloads else { return }
        lastObservedDownloads = downloads
        observers.values.forEach { $0.yield(downloads) }
    }

    func scheduleNextIfNeeded() async {
        let queuedGIDs = queueStore.gids
        let downloads = queuedGIDs.isEmpty
            ? await fetchDownloadsFromStore()
            : await fetchDownloadsFromStore(gids: queuedGIDs)
        guard activeTask == nil else {
            await reconcileActiveDownloadState()
            return
        }
        let nextDownload = queuedGIDs.isEmpty
            ? nextLegacyScheduledDownload(from: downloads)
            : nextQueuedDownload(
                orderedGIDs: queuedGIDs,
                downloads: downloads
            )
        guard let nextDownload else { return }

#if DEBUG
        testingScheduledGalleryIDHistory.append(nextDownload.gid)
#endif
        activeGalleryID = nextDownload.gid
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.processScheduledDownload(gid: nextDownload.gid)
        }
    }

    private func processScheduledDownload(gid: String) async {
#if DEBUG
        if let testingScheduledProcessHook {
            defer {
                activeTask = nil
                activeGalleryID = nil
            }
            await testingScheduledProcessHook(gid)
            return
        }
#endif
        await processDownload(gid: gid)
    }

    private func nextQueuedDownload(
        orderedGIDs: [String],
        downloads: [DownloadedGallery]
    ) -> DownloadedGallery? {
        let downloadsByGID = Dictionary(
            uniqueKeysWithValues: downloads.map { ($0.gid, $0) }
        )
        return orderedGIDs
            .compactMap { downloadsByGID[$0] }
            .first { isSchedulableDownload($0) }
    }

    private func nextLegacyScheduledDownload(
        from downloads: [DownloadedGallery]
    ) -> DownloadedGallery? {
        downloads
            .filter(isSchedulableDownload)
            .sorted { lhs, rhs in
                let lhsIsDownloading = lhs.status == .downloading
                let rhsIsDownloading = rhs.status == .downloading
                if lhsIsDownloading != rhsIsDownloading {
                    return lhsIsDownloading
                }
                return (lhs.lastDownloadedAt ?? .distantPast)
                    < (rhs.lastDownloadedAt ?? .distantPast)
            }
            .first
    }

    private func isSchedulableDownload(
        _ download: DownloadedGallery
    ) -> Bool {
        !schedulingBlockedGalleryIDs.contains(download.gid)
            && shouldSchedule(download: download)
    }

    func shouldSchedule(download: DownloadedGallery) -> Bool {
        if download.status == .downloading || download.isQueuedWorkItem {
            return true
        }

        guard download.status == .partial else {
            return false
        }

        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: download.gid)
        guard let resumeState = try? storage
                .readResumeState(folderURL: temporaryFolderURL),
              let pageSelection = resumeState.pageSelection
        else {
            return false
        }
        return !pageSelection.isEmpty
    }

    func syncDownloadsState(scheduleNext: Bool) async {
        let downloads = await fetchDownloadsFromStore()
        await normalizeNeedsAttentionDownloads(downloads)
        await normalizeInterruptedDownloads(downloads)

        let normalizedDownloads = await fetchDownloadsFromStore()
        do {
            try storage.ensureRootDirectory()
            try storage.cleanupTemporaryFolders(
                preservingGIDs: Set(
                    normalizedDownloads.compactMap { download in
                        download.shouldPreserveTemporaryWorkingSet
                            ? download.gid
                            : nil
                    }
                )
            )
        } catch {
            Logger.error(error)
        }
        await reconcileActiveDownloadState()
        await validateDownloads()
        await notifyObservers()
        guard scheduleNext else { return }
        await scheduleNextIfNeeded()
    }
}

// MARK: - Pause & Resume
extension DownloadManager {
    func pause(gid: String) async -> Result<Void, AppError> {
        do {
            schedulingBlockedGalleryIDs.insert(gid)
            defer {
                schedulingBlockedGalleryIDs.remove(gid)
            }
            guard let currentDownload = await fetchDownload(gid: gid)
            else {
                return .failure(.notFound)
            }
            guard [.queued, .downloading]
                    .contains(currentDownload.status)
            else {
                await notifyObservers()
                await scheduleNextIfNeeded()
                return .success(())
            }
            let taskToCancel = try await writeInitialPauseRecord(
                gid: gid,
                download: currentDownload
            )
            await taskToCancel?.value
            try await writeSettledPauseRecord(
                gid: gid,
                download: currentDownload
            )
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    private func writeInitialPauseRecord(
        gid: String,
        download: DownloadedGallery
    ) async throws -> Task<Void, Never>? {
        downloadErrors[gid] = nil
        await queueStore.remove(gid)
        let initialCount = max(
            download.completedPageCount,
            temporaryCompletedPageCount(
                gid: gid,
                expectedPageCount: max(download.pageCount, 1)
            )
        )
        try await updateDownloadRecord(
            gid: gid,
            createIfMissing: false
        ) { record in
            record.status = DownloadStatus.paused.rawValue
            record.completedPageCount = Int64(initialCount)
            record.lastError = nil
            record.lastDownloadedAt = .now
        }
        await notifyObservers()
        if activeGalleryID == gid {
            let task = activeTask
            activeTask?.cancel()
            activeTask = nil
            activeGalleryID = nil
            return task
        }
        return nil
    }

    private func writeSettledPauseRecord(
        gid: String,
        download: DownloadedGallery
    ) async throws {
        downloadErrors[gid] = nil
        await queueStore.remove(gid)
        let settledCount = max(
            download.completedPageCount,
            temporaryCompletedPageCount(
                gid: gid,
                expectedPageCount: max(download.pageCount, 1)
            )
        )
        try await updateDownloadRecord(
            gid: gid,
            createIfMissing: false
        ) { record in
            record.status = DownloadStatus.paused.rawValue
            record.completedPageCount = Int64(settledCount)
            record.lastError = nil
            record.lastDownloadedAt = .now
        }
    }

    func cancelQueuedWorkItem(
        _ download: DownloadedGallery,
        mode: DownloadStartMode
    ) async -> Result<Void, AppError> {
        switch mode {
        case .initial:
            return await pause(gid: download.gid)
        case .redownload, .update, .repair:
            break
        }

        let restoredStatus = download.status
        let restoredCompletedPageCount =
            validatedCompletedPageCount(download)
        do {
            try await updateDownloadRecord(
                gid: download.gid,
                createIfMissing: false
            ) { record in
                record.status = restoredStatus.rawValue
                record.completedPageCount =
                    Int64(restoredCompletedPageCount)
                record.lastDownloadedAt = .now
                record.pendingOperation = nil
            }
            await notifyObservers()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    func resume(gid: String) async -> Result<Void, AppError> {
        guard await fetchDownload(gid: gid) != nil else {
            return .failure(.notFound)
        }

        do {
            downloadErrors[gid] = nil
            await queueStore.enqueue(gid)
            let indexedDownloads = await reloadDownloadIndex()
            if indexedDownloads.contains(where: { $0.gid == gid }) {
                await notifyObservers()
                await scheduleNextIfNeeded()
                return .success(())
            }
            let resumedStatus: DownloadStatus =
                activeTask == nil ? .downloading : .queued
            try await updateDownloadRecord(
                gid: gid,
                createIfMissing: false
            ) { record in
                record.status = resumedStatus.rawValue
                record.lastError = nil
                record.lastDownloadedAt = .now
                record.pendingOperation = nil
            }
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    func sortDownloads(
        _ downloads: [DownloadedGallery]
    ) -> [DownloadedGallery] {
        downloads.sorted { lhs, rhs in
            let lhsPriority = lhs.sortPriority
            let rhsPriority = rhs.sortPriority
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return (lhs.lastDownloadedAt ?? .distantPast)
                > (rhs.lastDownloadedAt ?? .distantPast)
        }
    }
}
