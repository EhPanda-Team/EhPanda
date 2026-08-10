import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Retry & RetryPages
extension DownloadCoordinator {
    public func retry(
        gid: String,
        mode: DownloadStartMode
    ) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        do {
            try await performRetry(gid: gid, download: download, mode: mode)
            await ensureContinuedSession()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            return .failure(.unknown)
        }
    }

    private func performRetry(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode
    ) async throws {
        let resolvedMode = effectiveRetryMode(
            for: download, requestedMode: mode
        )
        clearDownloadSessionState(gid: gid)
        advanceQueueIntentGeneration(for: gid)
        queuedModes[gid] = resolvedMode
        queuedPageSelections[gid] = nil
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    /// Queues repair work for exactly the caller's pages, or refuses the request outright.
    ///
    /// **The domain check comes first, and everything else follows it (CR-04).** `pageIndices` is
    /// public input: a stale inspection, a page count that shrank upstream, or any malformed caller
    /// can name numbers this gallery does not have. They are filtered against the CURRENT record's
    /// page domain immediately after the fetch, and a request left with nothing valid — including
    /// an explicitly empty one — returns `.failure(.notFound)` right there. Nothing has moved at
    /// that point: no failure cleared, no queue-intent generation advanced, no queued mode or
    /// selection written, no enqueue, no schedule, and no continued session. The ordering is the
    /// substance of the guard rather than tidiness, because acting on an inadmissible request is
    /// acting on a request the user never made.
    ///
    /// An explicitly empty selection is refused rather than answered `.success(())`. Reporting
    /// success for work nobody asked for is the same collapse read from the other side: the caller
    /// cannot tell that reply apart from one that queued something.
    ///
    /// **An update record refreshes as a WHOLE, deliberately.** Once at least one requested page is
    /// admissible, a record with a pending update delegates to `retry(gid:mode:)`, which queues the
    /// gallery with NO page selection. That is not `.repair`'s subset preservation failing quietly:
    /// an update re-fetches against a NEW page count, so a subset drawn against the old one names
    /// pages that may no longer be the same pages. The at-least-one-valid-page requirement is what
    /// keeps the exception from becoming a widening — an empty or entirely out-of-domain request
    /// never reaches it.
    public func retryPages(
        gid: String,
        pageIndices: [Int]
    ) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        // G-15-14's rule applies to the admission test too: comparing against the count means no
        // `1...pageCount` range exists here to be invalid, and a record claiming no pages simply
        // admits nothing instead of trapping the process.
        let selectedPageIndices = Set(pageIndices)
            .filter({ $0 >= 1 && $0 <= download.pageCount })
            .sorted()
        guard !selectedPageIndices.isEmpty else { return .failure(.notFound) }

        let mode = resumeMode(for: download)
        if mode == .update { return await retry(gid: gid, mode: .update) }

        let folderURL = download.folderURL
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(.notFound)
        }
        do {
            try await performRetryPages(
                gid: gid,
                download: download,
                mode: .repair,
                selectedPageIndices: selectedPageIndices,
                folderURL: folderURL
            )
            await ensureContinuedSession()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            return .failure(.unknown)
        }
    }

    private func performRetryPages(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode,
        selectedPageIndices: [Int],
        folderURL: URL
    ) async throws {
        clearSelectedFailedPages(gid: gid, selectedPageIndices: selectedPageIndices)
        clearDownloadFailureState(gid: gid, includePageFailures: false)
        advanceQueueIntentGeneration(for: gid)
        queuedModes[gid] = mode
        queuedPageSelections[gid] = selectedPageIndices
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    public func loadLocalPageURLs(
        gid: String
    ) async -> Result<[Int: URL], AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        return .success(download.localPageURLs)
    }

    public func rescanLocalPageURLs(
        gid: String
    ) async -> [Int: URL]? {
        guard let token = downloadIndex[gid]?.manifest.token else { return nil }
        return await reloadDownloadRecord(gid: gid, token: token)?.localPageURLs
    }
}
