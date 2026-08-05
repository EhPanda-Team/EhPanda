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
    ///
    /// **The authority must be able to SEE every gallery its own predicate accepts (WR-01).**
    /// `isSchedulableDownload` accepts `displayStatus == .active` — the running gallery —
    /// independently of queue membership, so scoping the read by the persisted queue alone made the
    /// read and the predicate disagree exactly when the running gallery is absent from a non-empty
    /// queue. Three production routes reach that state: `nextUnqueuedSchedulableDownload` exists
    /// precisely to run a gallery the persisted queue has not caught up with, and both
    /// `handleProcessDownloadIncompleteError` and `settleDownloadFailure` remove the active gid from
    /// the queue store while `activeGalleryID` is still set and the deferred task teardown has not
    /// run. Dropping it distorted the card's pushed pair — a gallery's real progress leaving the
    /// numerator while it downloads, then being retired at a frozen value — and let an expiration's
    /// `pauseAllSchedulable` skip the one gallery actually consuming resources.
    ///
    /// The union widens WHICH records the scoped read fetches, never WHAT the predicate accepts. Its
    /// membership check is redundant defence rather than load-bearing arithmetic:
    /// `indexedDownloads(gids:)` filters `downloadIndex.values`, which holds exactly one record per
    /// gid, and `downloads(from:)` deduplicates by gid again — so a duplicated scoped gid could not
    /// double that gallery's pages in the summed denominator. The check stays because a cheap
    /// invariant at the read keeps the scoped list canonical if either downstream shape ever
    /// changes. The empty-queue branch keeps its full index read verbatim:
    /// `nextUnqueuedSchedulableDownload` and the resume-without-queue states depend on it.
    func schedulableDownloads() async -> [DownloadedGallery] {
        let queuedGIDs = queueStore.gids
        var scopedGIDs = queuedGIDs
        if let activeGalleryID, !scopedGIDs.contains(activeGalleryID) {
            scopedGIDs.append(activeGalleryID)
        }
        let downloads = queuedGIDs.isEmpty
            ? await indexedDownloads()
            : await indexedDownloads(gids: scopedGIDs)
        return downloads.filter(isSchedulableDownload)
    }
}
