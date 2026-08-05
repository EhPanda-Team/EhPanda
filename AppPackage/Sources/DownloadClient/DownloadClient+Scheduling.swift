import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// Binds an expiration-owned pause to both the session that requested it and the gallery intent
/// that was current at that decision. The session alone cannot distinguish a still-live owner from
/// a gallery that a newer user action has already moved forward.
struct ExpirationPauseOwnership {
    let sessionID: UUID
    let queueIntentGeneration: Int
}

private enum PauseCommitOutcome {
    case settled(Result<Void, AppError>)
    case superseded
}

// MARK: - Observer Management & Scheduling
extension DownloadCoordinator {
    public func notifyObservers() async {
        let downloads = await indexedDownloads()
        await observerHub.notify(downloads)
    }

    public func scheduleNextIfNeeded() async {
        // Deliberately a forwarder: every queue mutation converges here, so this tail is
        // the one place a reconcile sees every exit path of the core (both its early-return
        // guards and its happy path). That is what keeps a live session matched to queue
        // state, and what stops one being left running after the last active download is
        // paused or deleted — those paths null the active task directly, but they still
        // reschedule afterwards, so they arrive here too.
        await scheduleNextIfNeededCore()
        await reconcileContinuedSession()
    }

    private func scheduleNextIfNeededCore() async {
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
            uniqueKeysWithValues: downloads.map({ ($0.gid, $0) })
        )
        return orderedGIDs
            .compactMap({ downloadsByGID[$0] })
            .first(where: { isSchedulableDownload($0) })
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
                return (lhs.lastDownloadedDate ?? .distantPast)
                    < (rhs.lastDownloadedDate ?? .distantPast)
            }
            .first
    }

    /// Internal rather than private so the continued-processing session selects the very same
    /// gallery set the scheduler does. A second, divergent predicate is the bug this avoids.
    func isSchedulableDownload(
        _ download: DownloadedGallery
    ) -> Bool {
        schedulingBlockedGalleryCounts[download.gid] == nil
            && shouldSchedule(download: download)
    }

    public func shouldSchedule(download: DownloadedGallery) -> Bool {
        if download.displayStatus == .active || download.isQueuedWorkItem {
            return true
        }

        guard download.displayStatus == .inactive, download.isIncomplete else {
            return false
        }

        return queuedPageSelections[download.gid]?.isEmpty == false
    }

    public func syncDownloadsState(scheduleNext: Bool) async {
        let downloads = await fetchDownloadsFromStore()
        await normalizeNeedsAttentionDownloads(downloads)
        await normalizeInterruptedDownloads(downloads)

        do {
            try storage.ensureRootDirectory()
        } catch {
            // Hash-masked identifiers remain correlatable without disclosure. Errors are private
            // because gallery-folder paths embed titles even when the log statement does not.
            logger.error("\(error, privacy: .private)")
        }
        await reconcileActiveDownloadState()
        await notifyObservers()
        guard scheduleNext else { return }
        await scheduleNextIfNeeded()
    }
}

// MARK: - Pause & Resume
extension DownloadCoordinator {
    public func pause(gid: String) async -> Result<Void, AppError> {
        await pause(gid: gid, expiration: nil)
    }

    func pause(
        gid: String,
        expiration: ExpirationPauseOwnership?
    ) async -> Result<Void, AppError> {
        switch await commitPause(gid: gid, expiration: expiration) {
        case .settled(let result):
            return result
        case .superseded:
            logger.notice(
                """
                Expiration pause abandoned after newer intent, \
                gid: \(gid, privacy: .private(mask: .hash)).
                """
            )
            // A queue-mobilizing user action reached this gallery while the expiration held its
            // scheduling block. This is that action's deferred convergence, not a background
            // session start: once the block is gone, notify and scheduling make the gallery
            // runnable, and the scheduler's own foreground validation makes a late ensure inert
            // if the action no longer qualifies. This is the one-frame-up
            // ACTIVE-OWNERSHIP CONVERGENCE path for the ownership cleared inside `commitPause`.
            await notifyObservers()
            await scheduleNextIfNeeded()
            await ensureContinuedSession()
            return .success(())
        }
    }

    private func commitPause(
        gid: String,
        expiration: ExpirationPauseOwnership?
    ) async -> PauseCommitOutcome {
        do {
            blockScheduling(gid: gid)
            guard let currentDownload = await fetchDownload(gid: gid)
            else {
                // ACTIVE-OWNERSHIP CONVERGENCE, swept for G-15-8. The former function-scoped
                // `defer` made this the one `.settled` exit that converged nowhere: a pause of a
                // record that vanished across the read above returned while its gid was still
                // hidden from `schedulableDownloads()`, and nothing rescheduled afterwards. The
                // release comes first on every exit below for the same reason — converging while
                // the affected gallery is still blocked makes the scheduler skip it silently.
                releaseScheduling(gid: gid)
                await notifyObservers()
                await scheduleNextIfNeeded()
                return .settled(.failure(.notFound))
            }
            guard ownsExpirationPause(expiration, gid: gid) else {
                // The one-frame-up convergence: `pause(gid:expiration:)` notifies, schedules and
                // re-ensures on every `.superseded` value it receives, after this release lands.
                releaseScheduling(gid: gid)
                return .superseded
            }
            guard [.queued, .active]
                    .contains(currentDownload.displayStatus)
            else {
                releaseScheduling(gid: gid)
                await notifyObservers()
                await scheduleNextIfNeeded()
                return .settled(.success(()))
            }
            // The ownership checks guard the far side of both real suspensions: the indexed
            // record read above and the unbounded active-task wait below. A user action landing
            // inside `writeInitialPauseRecord`'s queue-store hop remains last-writer-wins; that
            // single actor hop is the accepted residual, rather than false transactional
            // atomicity across the persisted queue.
            let taskToCancel = try await writeInitialPauseRecord(
                gid: gid,
                download: currentDownload
            )
            await taskToCancel?.value
            guard ownsExpirationPause(expiration, gid: gid) else {
                releaseScheduling(gid: gid)
                return .superseded
            }
            try await writeSettledPauseRecord(
                gid: gid,
                download: currentDownload
            )
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            logger.notice("Download paused, gid: \(gid, privacy: .private(mask: .hash)).")
            return .settled(.success(()))
        } catch let error as AppError {
            // Both catches are reachable only from the two record writes above, which sit past the
            // block and ahead of every release, so this is that path's single release.
            releaseScheduling(gid: gid)
            // Convergence is intentionally unconditional, including expiration-owned pauses:
            // surrounding exits already converge during expiration, the failed pause's gallery is
            // precisely the work that must not be stranded, and scheduling does not start a new
            // continued-processing session. Gating this on `expiration == nil` would violate
            // ACTIVE-OWNERSHIP CONVERGENCE on the expiration path.
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .settled(.failure(error))
        } catch {
            logger.error("\(error, privacy: .private)")
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .settled(.failure(.unknown))
        }
    }

    private func ownsExpirationPause(
        _ expiration: ExpirationPauseOwnership?,
        gid: String
    ) -> Bool {
        guard let expiration else { return true }
        return (continuedSessionID == nil || continuedSessionID == expiration.sessionID)
            && queueIntentGeneration(for: gid) == expiration.queueIntentGeneration
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

    public func cancelQueuedWorkItem(
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
        // This removal can take the last schedulable item out of the queue, and only the
        // convergence point's tail can then complete a live session. The `.initial` branch above
        // reaches it through `pause`, which converges on its own.
        await scheduleNextIfNeeded()
        return .success(())
    }

    public func resume(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        advanceQueueIntentGeneration(for: gid)
        clearDownloadFailureState(gid: gid)
        queuedModes[gid] = resumeMode(for: download)
        queuedPageSelections[gid] = nil
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        logger.notice("Download resumed, gid: \(gid, privacy: .private(mask: .hash)).")
        return .success(())
    }

}
