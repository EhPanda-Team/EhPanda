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
    /// Download Now (B-1) interrupts the active gallery through `interruptActiveRun(of:)`: the interrupted
    /// gallery is not paused and does not leave the queue, it waits directly after the selected one. With nothing
    /// active the item goes first and the convergence starts it. An active run the persisted queue does not hold
    /// (started from the scheduler's unqueued path) is not interrupted, so the item then waits first, as with
    /// Download Next.
    ///
    /// A paused item (Download Next and Download Now) is mobilized through `resume(gid:)` and
    /// `ensureContinuedSession()` unchanged, exactly as the pause toggle's resume branch does, and then placed.
    /// That is why no new queue entrance or queue-intent advance exists here: the entrance census stays at five.
    /// The operation takes no
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
        let interrupted = interruptibleActiveGalleryID(for: operation)
        var order = waiting
        switch operation {
        case .downloadNow:
            order = [gid] + (interrupted.map({ [$0] }) ?? []) + waiting.filter({ $0 != gid })
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
        if let interrupted {
            await interruptActiveRun(of: interrupted)
        }
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

    /// The active gallery Download Now interrupts: only for Download Now, and only when the persisted queue holds it.
    private func interruptibleActiveGalleryID(for operation: DownloadQueueOperation) -> String? {
        guard operation == .downloadNow, let activeID = activeGalleryID, queueStore.contains(activeID) else {
            return nil
        }
        return activeID
    }

    /// Cancels the active run of `interrupted` and clears the active slot, then waits for the cancelled run to end.
    ///
    /// It must be followed by `notifyObservers()` and `scheduleNextIfNeeded()` with no exit in between, because it
    /// clears the active slot (ACTIVE-OWNERSHIP CONVERGENCE); its one caller does exactly that. It awaits the
    /// cancelled run, like pause and delete, so the run-exit write-back lands before the next run starts. The
    /// interrupted gallery is not paused, keeps its queue slot directly after the selected one, keeps its queue
    /// intent, and its manifest is left as its own run's exit leaves it (B-1, manifest SSOT).
    ///
    /// It takes no scheduling block, deliberately: every failure-persistence handler is gated on
    /// `shouldSuppressFailurePersistence`, whose `Task.isCancelled` arm stays true in the cancelled run's own task
    /// for the rest of its life; the page loop already stops on cancellation and skips its forced flush; the
    /// interrupted gallery is meant to stay schedulable, which a block would defeat; and a successor run of the same
    /// gallery during the wait is `isSupersededByALiveRun`'s overlapping-run disposition. So the block census and
    /// the rule that no queue-mobilizing entry point takes one stand.
    ///
    /// A `.redownload` or `.update` run that had already replaced its folder would replace it again, and lose the
    /// pages it saved, if it restarted under the same mode. So the interrupted gallery continues as `.repair`. "Had
    /// prepared" is read from the run's measurement, which stands from the preparation's announcement to the run's
    /// exit; the queue-intent generation and queue guards leave a mode a concurrent action wrote alone.
    private func interruptActiveRun(of interrupted: String) async {
        guard activeGalleryID == interrupted, let interruptedTask = activeTask else { return }
        let intentGeneration = queueIntentGeneration(for: interrupted)
        let hadPrepared = liveRunProgressBasis(gid: interrupted) != nil
        interruptedTask.cancel()
        activeTask = nil
        activeGalleryID = nil
        logger.notice("Download interrupted for Download Now, gid: \(interrupted, privacy: .private(mask: .hash)).")
        await interruptedTask.value
        guard queueIntentGeneration(for: interrupted) == intentGeneration,
              hadPrepared,
              queueStore.contains(interrupted),
              let mode = queuedModes[interrupted],
              mode == .redownload || mode == .update
        else { return }
        queuedModes[interrupted] = .repair
    }
}
