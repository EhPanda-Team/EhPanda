//
//  DownloadClient+Scheduling.swift
//  EhPanda
//

import Foundation

// MARK: - Observer Management & Scheduling
extension DownloadCoordinator {
    func notifyObservers() async {
        let downloads = await indexedDownloads()
        await observerHub.notify(downloads)
    }

    func scheduleNextIfNeeded() async {
        let queuedGIDs = queueStore.gids
        let downloads = queuedGIDs.isEmpty
            ? await indexedDownloads()
            : await indexedDownloads(gids: queuedGIDs)
        await taskRunner.beforeActiveTaskCheck()
        guard activeTask == nil else {
            await reconcileActiveDownloadState()
            return
        }
        let nextDownload = queuedGIDs.isEmpty
            ? nextUnqueuedSchedulableDownload(from: downloads)
            : nextQueuedDownload(
                orderedGIDs: queuedGIDs,
                downloads: downloads
            )
        guard let nextDownload else { return }

        await taskRunner.recordScheduledGallery(nextDownload.gid)
        activeTaskGeneration += 1
        let generation = activeTaskGeneration
        activeGalleryID = nextDownload.gid
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.processScheduledDownload(
                gid: nextDownload.gid,
                generation: generation
            )
        }
    }

    private func processScheduledDownload(
        gid: String,
        generation: Int
    ) async {
        let result = await taskRunner.runScheduledDownload(gid) {
            await self.processDownload(gid: gid, generation: generation)
        }
        guard result == .skippedOperation else { return }
        finishActiveTaskIfOwned(
            gid: gid,
            generation: generation,
            schedulesNext: false
        )
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

    private func nextUnqueuedSchedulableDownload(
        from downloads: [DownloadedGallery]
    ) -> DownloadedGallery? {
        // Some transient actor state, such as an interrupted active download or
        // selected page retry, can be schedulable before it is reflected in the
        // persisted queue.
        downloads
            .filter(isSchedulableDownload)
            .sorted { lhs, rhs in
                let lhsIsDownloading = lhs.displayStatus == .active
                let rhsIsDownloading = rhs.displayStatus == .active
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
        if download.displayStatus == .active || download.isQueuedWorkItem {
            return true
        }

        guard download.displayStatus == .inactive, download.isIncomplete else {
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
        await notifyObservers()
        guard scheduleNext else { return }
        await scheduleNextIfNeeded()
    }
}

// MARK: - Pause & Resume
extension DownloadCoordinator {
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
            guard [.queued, .active]
                    .contains(currentDownload.displayStatus)
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
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
        await backgroundTaskStore.removeAll(for: gid)
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
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
        await backgroundTaskStore.removeAll(for: gid)
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

        clearDownloadQueueIntent(gid: download.gid)
        await queueStore.remove(download.gid)
        await notifyObservers()
        return .success(())
    }

    func resume(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        clearDownloadFailureState(gid: gid)
        queuedModes[gid] = resumeMode(for: download)
        queuedPageSelections[gid] = nil
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

}
