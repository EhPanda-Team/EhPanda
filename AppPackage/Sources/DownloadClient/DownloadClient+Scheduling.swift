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
            // session start. This is the one-frame-up ACTIVE-OWNERSHIP CONVERGENCE path for the
            // ownership cleared inside `commitPause`.
            //
            // **The trailing ensure is stated on what the coordinator can observe (WR-09).** The
            // former argument here — "the scheduler's own foreground validation makes a late ensure
            // inert" — named behavior no code on this side can check, and a second claim, that the
            // session-liveness guard would stop the call anyway, is false: the `.expired` handler
            // calls `markContinuedSessionEnded` BEFORE `pauseAllSchedulable`
            // (`+ContinuedSession.swift`), so by the time an expiration pause reaches this arm the
            // liveness flag is already down. The observable bound is `ownsExpirationPause`, whose
            // two failure branches are the only ways to arrive here:
            //
            // 1. **The gid's queue-intent generation advanced.** Only a queue-mobilizing user
            //    action advances it, and every such action does call `ensureContinuedSession()` —
            //    but that call can legitimately have done nothing, because THIS pause still held
            //    the gallery's scheduling block when it ran: `isSchedulableDownload` rejects a
            //    blocked gid, so `hasPendingWork()` answered false and the action's own ensure
            //    returned at its first guard. `releaseScheduling` ran just above, so this line is
            //    the first moment the mobilized gallery is visible to that same predicate. Dropping
            //    the call leaves a successful tap with running work and no session — half of the
            //    defect `testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` pins,
            //    which fails on exactly `spy.startCount` and `testingHasContinuedSession()` without
            //    it.
            // 2. **A live successor session exists** (a non-`nil` session id that is not the
            //    expiring one), minted by a qualifying tap that owned its own ensure. Here the call
            //    is inert for a reason this side can check rather than infer: `hasLiveContinuedSession`
            //    is true, which is `ensureContinuedSession()`'s own first guard.
            //
            // So the call starts a session on exactly the branch that would otherwise have none,
            // and returns at a locally observable guard on the branch that already has one.
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
        // This path is non-throwing end to end, and deliberately so: no member reached from here
        // can fail, so every exit below is a real exit and each one releases the scheduling block
        // before it converges. A future addition that does throw stops compiling until it is given
        // its own `catch`, which forces that release-then-converge decision to be made explicitly
        // instead of letting a standing arm absorb it unexamined.
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
        let taskToCancel = await writeInitialPauseRecord(gid: gid)
        await taskToCancel?.value
        guard ownsExpirationPause(expiration, gid: gid) else {
            releaseScheduling(gid: gid)
            return .superseded
        }
        await writeSettledPauseRecord(gid: gid)
        releaseScheduling(gid: gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        logger.notice("Download paused, gid: \(gid, privacy: .private(mask: .hash)).")
        return .settled(.success(()))
    }

    private func ownsExpirationPause(
        _ expiration: ExpirationPauseOwnership?,
        gid: String
    ) -> Bool {
        guard let expiration else { return true }
        return (continuedSessionID == nil || continuedSessionID == expiration.sessionID)
            && queueIntentGeneration(for: gid) == expiration.queueIntentGeneration
    }

    /// Writes the pause's record and hands back the run task the caller must await before the
    /// pause settles.
    ///
    /// This is the *first* of the pause's two identical record writes, and the pair is deliberate:
    /// what makes the second one load-bearing is not anything the cancelled run writes on its way
    /// out, but what a concurrent user action can write while the caller is parked on that run.
    /// `writeSettledPauseRecord` documents that window.
    private func writeInitialPauseRecord(
        gid: String
    ) async -> Task<Void, Never>? {
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

    /// Re-writes the pause's record after the cancelled run has finished, re-clearing whatever the
    /// unbounded wait on that run let a concurrent action put back.
    ///
    /// The re-established writes come from other operations, not from the cancelled run: its own
    /// teardown re-establishes none of this. All four of its failure-persistence handlers are gated
    /// on `shouldSuppressFailurePersistence(for:)`, true for as long as the caller holds this
    /// gallery's scheduling block; its page loop cancels the batch on that same block and skips its
    /// forced flush; and every page task removes its own background-task record on each exit,
    /// inside the task group the run awaits.
    ///
    /// The writers this re-clears are the queue-mobilizing entry points, stated as an invariant
    /// rather than as an inventory: NO queue-mobilizing entry point takes a scheduling block, so any
    /// of them is free to land inside the unbounded wait above and put back the queue intent this
    /// pause has just removed. The invariant holds from the other side — every operation that takes
    /// a block parks, deletes or moves a gallery, and none of them mobilizes the queue — which is
    /// why `DownloadSourceInventoryTests` pins the `blockScheduling(gid:)` call-site census instead:
    /// a mobilizer quietly gaining a block, or a new blocking operation appearing, fails that test.
    /// The enumeration this replaces named three such writers and source answered with a fourth,
    /// `enqueue(payload:)`, which advances the gid's queue intent and enqueues it exactly as
    /// `resume(gid:)` does. For an expiration-owned pause the `ownsExpirationPause` re-check above
    /// turns exactly that interleaving into `.superseded`, so this line is never reached; for a user
    /// pause there is deliberately no such guard, because an explicit pause a background retry could
    /// quietly undo is not a pause. `testAUserPauseIsNeverAbandonedByAnInterleavingRetry` pins the
    /// difference from both sides.
    private func writeSettledPauseRecord(gid: String) async {
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
