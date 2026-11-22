public import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Queue Operations
extension DownloadCoordinator {
    /// Changes where a gallery waits in the download queue (B-2): Download Next moves it to the front of the
    /// waiting items, Move Up and Move Down one place earlier or later among them, Download Last to the end. The
    /// active gallery keeps running throughout.
    ///
    /// The applicability predicate is the downloads menu's own (`DownloadQueueOperation.isApplicable`), read here
    /// against the record and place the coordinator derives afresh, so a menu that rendered from a stale snapshot
    /// is refused rather than obeyed: `.notFound` for a gallery that is gone, `.unknown` for an operation its
    /// status or place no longer allows, with nothing moved.
    ///
    /// A paused item (Download Next only) is mobilized through `resume(gid:)` and `ensureContinuedSession()`
    /// unchanged, exactly as the pause toggle's resume branch does, and then placed. That is why no new queue
    /// entrance or queue-intent advance exists here: the entrance census stays at five. The operation takes no
    /// scheduling block, which keeps the rule `writeSettledPauseRecord`'s doc states (no queue-mobilizing entry
    /// point takes one) and leaves the block census at five.
    ///
    /// The reorder is slot-preserving (`DownloadQueueStore.reorder(_:)`), so the active gallery and any entry that
    /// is not a waiting item keep their slots. Every accepted change converges through `notifyObservers()` and
    /// `scheduleNextIfNeeded()`. It deletes nothing.
    public func performQueueOperation(
        gid: String,
        operation: DownloadQueueOperation
    ) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        guard operation.isApplicable(status: download.displayStatus, place: download.queuePlace) else {
            return .failure(.unknown)
        }
        let mobilizes = download.displayStatus == .inactive
        if mobilizes {
            let resumed = await resume(gid: gid)
            guard case .success = resumed else { return resumed }
            await ensureContinuedSession()
        }
        // A resumed item that the resume itself started.
        if activeGalleryID == gid {
            return .success(())
        }
        let waiting = waitingQueueGIDs()
        guard let offset = waiting.firstIndex(of: gid) else {
            return mobilizes ? .success(()) : .failure(.unknown)
        }
        if !mobilizes {
            // The place may have moved since the menu rendered.
            let place = DownloadQueuePlace(position: offset + 1, waitingCount: waiting.count)
            guard operation.isApplicable(status: .queued, place: place) else {
                return .failure(.unknown)
            }
        }
        var order = waiting
        switch operation {
        case .downloadNext:
            order.remove(at: offset)
            order.insert(gid, at: 0)
        case .moveUp:
            order.swapAt(offset, offset - 1)
        case .moveDown:
            order.swapAt(offset, offset + 1)
        case .downloadLast:
            order.remove(at: offset)
            order.append(gid)
        }
        // Only a resumed item that is already next gets here; the resume already converged.
        guard order != waiting else {
            return .success(())
        }
        await queueStore.reorder(order)
        await notifyObservers()
        await scheduleNextIfNeeded()
        logger.notice(
            """
            Download queue reordered, gid: \(gid, privacy: .private(mask: .hash)), \
            operation: \(operation.rawValue, privacy: .public).
            """
        )
        return .success(())
    }
}
