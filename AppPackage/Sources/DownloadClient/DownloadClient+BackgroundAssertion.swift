import Foundation

// MARK: - Background Execution Assertion
extension DownloadCoordinator {
    /// Whether any download still needs the in-process orchestration to run.
    ///
    /// Drives the background-task assertion and the `BGProcessingTask` drain loop, so
    /// it must agree with the scheduler about what counts as schedulable work.
    public func hasPendingWork() async -> Bool {
        // A running task is unambiguous work; skip the disk-backed index read.
        if activeTask != nil { return true }
        let queuedGIDs = queueStore.gids
        let downloads = queuedGIDs.isEmpty
            ? await indexedDownloads()
            : await indexedDownloads(gids: queuedGIDs)
        return downloads.contains {
            !schedulingBlockedGalleryIDs.contains($0.gid) && shouldSchedule(download: $0)
        }
    }

    /// Begins or ends the OS background-task assertion to match the current queue
    /// state. Invoked from the tail of `scheduleNextIfNeeded()`, the single point every
    /// queue mutation converges on, so the assertion can never be leaked when the last
    /// active download is paused or deleted (those paths null `activeTask` directly but
    /// still reschedule afterward).
    public func reconcileBackgroundAssertion() async {
        guard await hasPendingWork() else {
            await endBackgroundAssertion()
            return
        }
        guard backgroundAssertionToken == nil, !isBeginningBackgroundAssertion else {
            return
        }
        isBeginningBackgroundAssertion = true
        let token = await backgroundTaskClient.begin { [weak self] in
            Task { await self?.endBackgroundAssertion() }
        }
        // `begin` hops to the main actor, a suspension point across which the queue may
        // have drained; re-validate before committing to holding the assertion.
        if await hasPendingWork() {
            backgroundAssertionToken = token
            isBeginningBackgroundAssertion = false
        } else {
            isBeginningBackgroundAssertion = false
            await backgroundTaskClient.end(token)
        }
    }

    private func endBackgroundAssertion() async {
        guard let token = backgroundAssertionToken else { return }
        backgroundAssertionToken = nil
        await backgroundTaskClient.end(token)
    }
}
