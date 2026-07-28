import AppModels
import Foundation

// MARK: - Pending Work
extension DownloadCoordinator {
    /// Whether any download still needs the in-process orchestration to run.
    ///
    /// The queue's schedulable-work predicate, so it must agree with the scheduler about
    /// what counts as schedulable work.
    public func hasPendingWork() async -> Bool {
        // A running task is unambiguous work, and skipping the disk-backed index read for it is
        // deliberate. This is an additional invariant, not another schedulable-work definition.
        if activeTask != nil { return true }
        return await schedulableDownloads().isEmpty == false
    }

    /// The one authority for selecting work the scheduler can run.
    ///
    /// Scheduling, the pending-work gate and the continued-session card all select through this
    /// function, so queue lifetime and reported counts cannot acquire separate definitions.
    func schedulableDownloads() async -> [DownloadedGallery] {
        let queuedGIDs = queueStore.gids
        let downloads = queuedGIDs.isEmpty
            ? await indexedDownloads()
            : await indexedDownloads(gids: queuedGIDs)
        return downloads.filter(isSchedulableDownload)
    }
}
