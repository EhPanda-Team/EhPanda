import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Process Download
extension DownloadCoordinator {
    public func processDownload(
        gid: String,
        generation: Int? = nil
    ) async {
        defer {
            // Ahead of the ownership clear on purpose: `retireRunProgressBasis` asks whether a
            // DIFFERENT live run owns this gallery's slot, and `finishActiveTaskIfOwned` nils both
            // halves of that ownership, so reading it afterwards would make every owning run look
            // superseded and retire nothing.
            retireRunProgressBasis(gid: gid, generation: generation)
            finishActiveTaskIfOwned(
                gid: gid,
                generation: generation,
                schedulesNext: true
            )
        }

        guard let download = await fetchDownload(gid: gid) else {
            return
        }
        let mode = queuedMode(for: download)
        let options = await downloadOptionsProvider()

        do {
            clearDownloadFailureState(gid: gid, includePageFailures: false)
            await notifyObservers()
            let result = try await fetchNormalizeAndDownload(
                gid: gid,
                download: download,
                mode: mode,
                options: options
            )
            guard !Task.isCancelled else { return }
            await completeDownload(
                gid: gid,
                download: download,
                result: result
            )
        } catch is CancellationError {
            return
        } catch {
            let context = FailureContext(
                gid: gid,
                originalDownload: download,
                mode: mode
            )
            await handleProcessDownloadError(error: error, context: context)
        }
    }

    private func completeDownload(
        gid: String,
        download: DownloadedGallery,
        result: ProcessDownloadResult
    ) async {
        // Gallery identifiers stay correlatable without disclosure by using hash masking. Errors
        // are private because gallery-folder paths embed titles; titles provide no operational value.
        logger.notice(
            """
            Download completed, gid: \(gid, privacy: .private(mask: .hash)), \
            pages: \(download.pageCount, privacy: .public).
            """
        )
        await settleCompletedDownload(gid: gid)
        let completedFolderURL = storage.folderURL(
            relativePath: result.folderRelativePath
        )
        removeSupersededFolders(
            gid: gid,
            token: download.token,
            keeping: completedFolderURL
        )
    }

    // A download can finish in a different folder than it started in
    // (re-slot after a title change), and an interrupted session can leave
    // both behind; only the completed folder may survive, or the stale
    // duplicate resurfaces once the surviving record is deleted.
    public func removeSupersededFolders(gid: String, token: String, keeping folderURL: URL) {
        do {
            try removeGalleryFolders(gid: gid, token: token, keeping: folderURL)
        } catch {
            logger.error("\(error, privacy: .private)")
        }
    }

    public func removeGalleryFolders(gid: String, token: String, keeping folderURL: URL? = nil) throws {
        let keptPath = folderURL?.standardizedFileURL.path
        for galleryFolderURL in storage.galleryFolderURLs(gid: gid, token: token) {
            guard galleryFolderURL.standardizedFileURL.path != keptPath else {
                continue
            }
            try storage.removeFolder(at: galleryFolderURL)
        }
    }

    private func handleProcessDownloadError(
        error: Error,
        context: FailureContext
    ) async {
        if let appError = error as? AppError {
            await handleProcessDownloadAppError(
                error: appError,
                context: context
            )
        } else if let partialError = error as? PartialDownloadError {
            await handleProcessDownloadPartialError(
                error: partialError,
                context: context
            )
        } else if let incompleteError = error as? IncompleteDownloadError {
            await handleProcessDownloadIncompleteError(
                error: incompleteError,
                context: context
            )
        } else {
            await handleProcessDownloadGenericError(
                error: error,
                context: context
            )
        }
    }

    private struct ProcessDownloadResult {
        let folderRelativePath: String
    }

    private func fetchNormalizeAndDownload(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode,
        options: DownloadRequestOptions
    ) async throws -> ProcessDownloadResult {
        let rawPageSelection = queuedPageSelections[gid]
        let fetchedPayload = try await fetchLatestPayload(
            for: download,
            mode: mode,
            options: options,
            pageSelection: rawPageSelection
        )
        let payload = normalizeFetchedPayload(
            fetchedPayload,
            mode: mode,
            rawPageSelection: rawPageSelection
        )
        let folderRelativePath = folderRelativePath(
            for: payload,
            parentFolderName: download.folderName
        )
        _ = try await performDownload(
            payload: payload,
            options: options,
            folderRelativePath: folderRelativePath,
            existingDownload: download
        )
        return ProcessDownloadResult(
            folderRelativePath: folderRelativePath
        )
    }

    private func handleProcessDownloadAppError(
        error: AppError,
        context: FailureContext
    ) async {
        guard !isCancellationLikeAppError(error) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        logger.error(
            """
            Download failed, gid: \(context.gid, privacy: .private(mask: .hash)), \
            mode: \(context.mode.rawValue, privacy: .public), \
            error: \(error.localizedDescription, privacy: .private)
            """
        )
        await persistFailure(error: error, context: context)
    }

    private func handleProcessDownloadPartialError(
        error: PartialDownloadError,
        context: FailureContext
    ) async {
        let pageError =
            error.failedPages.first?.error ?? .unknown
        guard !isCancellationLikeAppError(pageError) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        failedPageErrors[context.gid] = Dictionary(
            uniqueKeysWithValues: error.failedPages.map({ ($0.index, $0) })
        )
        logger.error(
            """
            Download partially failed, gid: \(context.gid, privacy: .private(mask: .hash)), \
            mode: \(context.mode.rawValue, privacy: .public), \
            failedPages: \(String(describing: error.failedPages.map(\.index)), privacy: .public)
            """
        )
        await persistFailure(error: pageError, context: context)
    }

    private func handleProcessDownloadIncompleteError(
        error _: IncompleteDownloadError,
        context: FailureContext
    ) async {
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        clearDownloadQueueIntent(gid: context.gid)
        await queueStore.remove(context.gid)
        await reloadDownloadRecord(
            gid: context.gid,
            token: context.originalDownload.token
        )
    }

    private func handleProcessDownloadGenericError(
        error: Error,
        context: FailureContext
    ) async {
        let appError = AppError.fileOperationFailed(
            error.localizedDescription
        )
        guard !isCancellationLikeAppError(appError) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        logger.error("\(error, privacy: .private)")
        await persistFailure(
            error: appError,
            context: context
        )
    }

    public func settleCompletedDownload(gid: String) async {
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
        await backgroundTaskStore.removeAll(for: gid)
    }

    public func finishActiveTaskIfOwned(
        gid: String,
        generation: Int?,
        schedulesNext: Bool
    ) {
        guard isActiveTaskOwner(gid: gid, generation: generation) else {
            return
        }
        activeTask = nil
        activeGalleryID = nil
        Task {
            // Display statuses derive from `activeGalleryID`, so an emission from
            // inside `processDownload` would still report this download as
            // `.active`; every exit path notifies here instead, after ownership
            // is cleared, so the settled status (completed/error) is what lands.
            await self.notifyObservers()
            guard schedulesNext else {
                // The collision-cleanup branch: another owner is already driving the queue,
                // so rescheduling here would double-schedule. It still has to reach the
                // session, because the scheduling tail is what normally reconciles one and
                // this download may have been the last in flight. This is the
                // ACTIVE-OWNERSHIP CONVERGENCE disposition for a deliberately non-scheduling exit.
                await self.reconcileContinuedSession()
                return
            }
            await self.scheduleNextIfNeeded()
        }
    }

    /// Ends this run's own progress measurement.
    ///
    /// **Why it lives in `processDownload`'s `defer` and nowhere else.** The run has five exits — the
    /// pre-fetch early return, the mid-run cancellation guard, the `CancellationError` catch, the
    /// success path and the general failure catch — and the `defer` is the only point all five pass
    /// through. Neither settle covers them: `settleCompletedDownload` is on the success path alone,
    /// and `settleDownloadFailure` is reached from only some arms of the failure catch, since
    /// `handleProcessDownloadAppError`, `handleProcessDownloadPartialError` and
    /// `handleProcessDownloadGenericError` each return early for a cancellation-like error and for
    /// suppressed persistence, while `handleProcessDownloadIncompleteError` reaches no settle at all.
    /// `finishActiveTaskIfOwned` is not a candidate either: the `defer` reaches it on every exit, but
    /// its own body is gated behind `isActiveTaskOwner`, so a non-owning exit would retire nothing.
    ///
    /// **A run that exits before ever announcing retires nothing of its own**, because it recorded
    /// nothing and removing an absent member is a no-op. What it can still clear is a PREVIOUS
    /// run's entry for the same gallery, which is correct: that run is over too.
    ///
    /// **The overlapping-run disposition.** `scheduleNextIfNeededCore` will not start a second run
    /// while `activeTask` is live, but `pause`, `delete` and the folder operations each null
    /// `activeTask` while the run they interrupt is still executing, so a following resume can
    /// legitimately schedule a successor for the same gallery at a new `activeTaskGeneration`. An
    /// ungated retirement in the predecessor's `defer` would then drop the SUCCESSOR's measurement,
    /// which is the G-15-26 zero-progress card reintroduced by its own fix. So a run whose
    /// gallery's active slot is held by a live run at a different generation retires nothing and
    /// leaves the entry to its owner, which retires it at its own exit. The generation-LESS case is
    /// a separate disposition and `isSupersededByALiveRun` states it; it is not repeated here. The
    /// stale entry this tolerates is bounded — the successor's own announcement replaces it inside
    /// a D-G7-01 bracket, which withdraws the credited gap exactly.
    ///
    /// **The freeze runs FIRST, while the measurement is still standing, because what it publishes
    /// is the value the measurement produces.** `freezeSessionCreditForRetiringRun` carries the
    /// derivation; the short version is that a departure can be detected on either side of this
    /// `defer` and the frozen value is what makes both sides retire the same number.
    ///
    /// **The removal is deliberately NOT a D-G7-01 bracket.** For an honest record the handoff is
    /// level — every landed page was flushed, so the record's raw count equals the final
    /// measurement — and for the refusal family the credited count falls back to the queued-window
    /// zero while the gallery merely sits in the queue. Withdrawing that drop from the floor would
    /// hand the card a visible regression over work the run really did; leaving the floor holding
    /// it is the chosen direction, a numerator that does not rise rather than one that falls, and
    /// the gallery's own departure retires the frozen value regardless.
    private func retireRunProgressBasis(gid: String, generation: Int?) {
        guard !isSupersededByALiveRun(gid: gid, generation: generation) else { return }
        freezeSessionCreditForRetiringRun(gid: gid)
        runProgressBases[gid] = nil
    }

    /// Whether a DIFFERENT live run holds this gallery's active slot, so this run's exit must
    /// retire nothing.
    ///
    /// **The generation-less case is a policy, and this branch is where it is stated.**
    /// `processDownload(gid:generation:)` is public and its `generation` defaults to `nil`, while
    /// the only stamp ever issued is the scheduler's (`+Scheduling.swift`), so a run can reach this
    /// gate carrying nothing to compare. Such a run cannot prove it owns this gallery's active slot,
    /// and it is treated as superseded: it retires nothing and leaves the entry to whichever run
    /// does own the slot.
    ///
    /// **The asymmetry is the reason, not the choice.** Leaving the entry to its owner costs one
    /// stale proof, and costs it only until that owner reaches its own exit and retires it there.
    /// Retiring on a live successor's behalf drops that successor's proof, which reproduces the
    /// G-15-26 zero-progress card — an in-flight repair contributing nothing for the rest of its
    /// re-download — through the very fix that exists to prevent it. A bounded overcount against an
    /// unbounded stall is not a close call.
    ///
    /// The comparison below would already answer `true` for `nil` through optional promotion; the
    /// branch changes no disposition. It is written so a reader can tell the case was decided rather
    /// than inherited from the types, which is why the sibling predicate directly below spells its
    /// own optional out too. `retireRunProgressBasis`'s doc owns the overlapping-run argument this
    /// direction stays consistent with, and it is not restated here.
    private func isSupersededByALiveRun(
        gid: String,
        generation: Int?
    ) -> Bool {
        guard activeTask != nil, activeGalleryID == gid else { return false }
        guard let generation else { return true }
        return generation != activeTaskGeneration
    }

    /// Whether this run may clear the gallery's active slot on its way out.
    ///
    /// **The generation-less arm, derived from the callers rather than asserted.** This predicate
    /// has one caller, `finishActiveTaskIfOwned`, which has two of its own: the scheduler's
    /// `processScheduledDownload`, which always passes the generation it stamped into
    /// `activeTaskGeneration`, and `processDownload`'s `defer`, which forwards whatever its own
    /// caller supplied — `nil` for anyone who took the public entry point's default. A
    /// generation-less run is therefore by construction a run the scheduler never stamped, and it
    /// has no identity to match.
    ///
    /// With no identity to check, ownership can only be inferred from the slot being IDLE, which is
    /// what the two conditions below require. A live `activeTask` means some run holds the slot and
    /// it is not this one; clearing it there would strand that run, because ACTIVE-OWNERSHIP
    /// CONVERGENCE records that once ownership is cleared the real owner's deferred cleanup is
    /// rejected, and the queue loses its last scheduling opportunity. An `activeGalleryID` claimed
    /// by a different gallery is the same hazard read through the other half of the pair.
    private func isActiveTaskOwner(
        gid: String,
        generation: Int?
    ) -> Bool {
        if let generation {
            return activeGalleryID == gid
                && activeTaskGeneration == generation
        }
        guard activeTask == nil else { return false }
        return activeGalleryID == nil || activeGalleryID == gid
    }
}
