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

        return queuedPageSelections[download.gid]?.isEmpty == false
    }

    func syncDownloadsState(scheduleNext: Bool) async {
        let downloads = await fetchDownloadsFromStore()
        await normalizeNeedsAttentionDownloads(downloads)
        await normalizeInterruptedDownloads(downloads)

        do {
            try storage.ensureRootDirectory()
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
        validationErrors[gid] = nil
        queuedModes[gid] = nil
        queuedPageSelections[gid] = nil
        await queueStore.remove(gid)
        _ = await reloadDownloadIndex()
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
        validationErrors[gid] = nil
        queuedModes[gid] = nil
        queuedPageSelections[gid] = nil
        await queueStore.remove(gid)
        _ = await reloadDownloadIndex()
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

        queuedModes[download.gid] = nil
        queuedPageSelections[download.gid] = nil
        await queueStore.remove(download.gid)
        await notifyObservers()
        return .success(())
    }

    func resume(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        downloadErrors[gid] = nil
        validationErrors[gid] = nil
        queuedModes[gid] = resumeMode(for: download)
        queuedPageSelections[gid] = nil
        await queueStore.enqueue(gid)
        _ = await reloadDownloadIndex()
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

}
