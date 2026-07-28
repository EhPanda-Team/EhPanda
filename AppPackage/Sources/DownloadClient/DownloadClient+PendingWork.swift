import Foundation

// MARK: - Pending Work
extension DownloadCoordinator {
    /// Whether any download still needs the in-process orchestration to run.
    ///
    /// The queue's schedulable-work predicate, so it must agree with the scheduler about
    /// what counts as schedulable work.
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
}
