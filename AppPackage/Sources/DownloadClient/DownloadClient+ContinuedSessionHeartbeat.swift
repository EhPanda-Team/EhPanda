import BackgroundProcessingClient
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// What one accepted push reported, handed back so a caller can act on it without recomputing the
/// snapshot the push already built.
///
/// It exists for the heartbeat's summary rule: "log only when the numerator changed" needs the
/// numerator the push actually issued, and re-deriving it at the caller would be a second reader of
/// the pushed pair — the defect class this module has already lost rounds to.
public struct ContinuedSessionPushRecord: Equatable, Sendable {
    public let completedPageCount: Int
    public let pageCount: Int
    public let inFlightSubunitCount: Int64
    public let galleryCount: Int
    public let inFlightTransferCount: Int

    public init(
        completedPageCount: Int,
        pageCount: Int,
        inFlightSubunitCount: Int64,
        galleryCount: Int,
        inFlightTransferCount: Int
    ) {
        self.completedPageCount = completedPageCount
        self.pageCount = pageCount
        self.inFlightSubunitCount = inFlightSubunitCount
        self.galleryCount = galleryCount
        self.inFlightTransferCount = inFlightTransferCount
    }
}

/// The last summary this session logged, so an unchanged numerator is reported once rather than
/// every tick.
private struct HeartbeatSummary {
    let completedSubunits: Int64
    let date: Date
}

// MARK: - Continued Session Heartbeat
extension DownloadCoordinator {
    /// Starts the repeating re-push that keeps a live session's card from reading as stalled.
    ///
    /// **Why a heartbeat exists beside the page-landing push.** Progress reaches the card only when
    /// a page lands, and the default worker count is one — so a single slow page freezes the
    /// numerator for as long as that page takes. The scheduler forcibly expires the tasks reporting
    /// the least progress, at around thirty seconds without an update, which is well inside the time
    /// one large page can take. Re-pushing the CURRENT pair every ten seconds says "still working"
    /// without inventing progress.
    ///
    /// One task per live session, cancelled at `markContinuedSessionEnded`, so a session boundary
    /// can never leave a beat pointed at a card that is gone.
    func startContinuedSessionHeartbeat(sessionID: UUID) {
        continuedSessionHeartbeatTask?.cancel()
        continuedSessionHeartbeatTask = Task { [weak self, clock] in
            var lastSummary: HeartbeatSummary?
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: Self.continuedSessionHeartbeatInterval)
                } catch {
                    // The only throw here is cancellation, which is how the session ends this task.
                    return
                }
                guard let self else { return }
                lastSummary = await self.beatContinuedSession(
                    sessionID: sessionID,
                    lastSummary: lastSummary
                )
            }
        }
    }

    /// One beat: sweep the in-flight transfers for starvation, re-push, and summarise if the
    /// summary would say something new.
    ///
    /// Gated on the session still being ours AND on there being pending work. `hasPendingWork()` is
    /// the queue's own predicate; a drained queue needs no heartbeat, and beating over one would
    /// keep a card alive that the drain is about to complete.
    fileprivate func beatContinuedSession(
        sessionID: UUID,
        lastSummary: HeartbeatSummary?
    ) async -> HeartbeatSummary? {
        guard continuedSessionID == sessionID, await hasPendingWork() else { return lastSummary }
        sweepStarvedPageTransfers()
        guard continuedSessionID == sessionID,
              let pushed = await pushContinuedSessionProgress(sessionID: sessionID)
        else { return lastSummary }

        let completedSubunits = Int64(pushed.completedPageCount)
            * ContinuedProcessingSession.subunitsPerUnit
            + pushed.inFlightSubunitCount
        let beatDate = now()
        if let lastSummary,
           lastSummary.completedSubunits == completedSubunits,
           beatDate.timeIntervalSince(lastSummary.date) < Self.heartbeatSummaryMinimumInterval {
            return lastSummary
        }
        logger.notice(
            """
            Continued-session heartbeat: \(pushed.completedPageCount, privacy: .public) / \
            \(pushed.pageCount, privacy: .public) pages, \
            \(pushed.inFlightSubunitCount, privacy: .public) in-flight subunits, \
            \(pushed.galleryCount, privacy: .public) galleries, \
            \(pushed.inFlightTransferCount, privacy: .public) transfers in flight.
            """
        )
        return HeartbeatSummary(completedSubunits: completedSubunits, date: beatDate)
    }

    /// Reports every transfer that is still running and has had no bytes for at least
    /// `pageTransferStallThreshold`, through the same helper `endPageTransfer` uses (PD-5).
    private func sweepStarvedPageTransfers() {
        let sweepDate = now()
        for (gid, transfers) in inFlightPageTransfers {
            for (pageIndex, transfer) in transfers {
                let elapsed = sweepDate.timeIntervalSince(transfer.startDate)
                guard transfer.isTransferring,
                      transfer.firstByteDate == nil,
                      !transfer.stallLogged,
                      elapsed >= Self.pageTransferStallThreshold
                else { continue }
                inFlightPageTransfers[gid]?[pageIndex]?.stallLogged = true
                logStarvedPageTransfer(
                    gid: gid,
                    pageIndex: pageIndex,
                    startedInBackground: transfer.startedInBackground,
                    elapsedMilliseconds: Int((elapsed * 1000).rounded()),
                    outcome: "still transferring"
                )
            }
        }
    }

    /// Records the device conditions a deferred background transfer would be explained by.
    ///
    /// Logged at a session's start and inside the expiry arm, which are the two moments the next
    /// device archive is read at: the pair says whether anything about the device changed between
    /// a session that ran and a session the system took away. Every field is a closed symbol name
    /// or a Bool, so all of it goes out `public`.
    func logContinuedSessionEnvironment(moment: String) {
        let environment = environmentProbe.snapshot()
        logger.notice(
            """
            Continued-session environment at \(moment, privacy: .public): \
            network \(environment.network.rawValue, privacy: .public), \
            low power \(environment.isLowPowerModeEnabled, privacy: .public), \
            thermal \(environment.thermalDescription, privacy: .public).
            """
        )
    }
}
