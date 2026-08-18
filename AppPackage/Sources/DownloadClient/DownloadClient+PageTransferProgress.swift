import BackgroundProcessingClient
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// One page transfer the coordinator has started and not yet seen recorded: how much of it is
/// credited, and the timing facts a device archive is read for.
///
/// **The lifetime, which is the whole contract.** An entry is created when the transfer starts
/// (`rawPageDownloadResponse`); its credit grows by `max`, so a retry that restarts the byte count
/// at zero never rewinds what the page has already earned while in flight; it is REMOVED inside
/// `flushManifestPageProgress`, in the same synchronous stretch as the run measurement's own
/// subtraction, so a page's whole-page credit and its sub-page credit trade places atomically; it
/// is withdrawn by name at the page's `.failure` outcome — the one deliberate downward mover — and
/// it is dropped with the rest of the gallery's entries when the run exits.
///
/// **It is a RUN fact, not a session one**, for the same reason the run measurement is: a session
/// starting or ending makes no transfer less in flight, and scoping it to a session would strand a
/// transfer that outlives one.
struct InFlightPageTransfer: Sendable {
    /// This page's earned sub-page credit, in `ContinuedProcessingSession.subunitsPerUnit` per
    /// page. Monotone while the entry lives.
    ///
    /// **The `max` that keeps it monotone answers two things, not one.** A retry restarts the byte
    /// count at zero, and — because each forwarded byte report crosses onto this actor in its own
    /// task — two reports for the same transfer can land in the opposite order from the one they
    /// were issued in. Taking the greater value makes both inert; an assignment would let either
    /// rewind the card.
    var creditedSubunits: Int64 = 0
    /// When the CURRENT attempt started, so a retry measures its own time to first byte.
    var startDate: Date
    /// Whether the app was backgrounded when this attempt was created — the field that
    /// discriminates the "background-created transfers are discretionary" hypothesis.
    var startedInBackground: Bool
    var firstByteDate: Date?
    var isTransferring: Bool
    /// Whether this attempt has already been reported as starved, so the heartbeat's repeated
    /// sweeps report it once rather than every ten seconds.
    var stallLogged = false
}

// MARK: - In-Flight Page Transfers
extension DownloadCoordinator {
    /// Opens (or re-opens, for a retry) the in-flight entry for one page.
    ///
    /// Everything about the ATTEMPT is reset and the earned credit is deliberately kept: the page
    /// is the unit the card reports on, and a retry is the same page continuing rather than a new
    /// one starting.
    func beginPageTransfer(gid: String, pageIndex: Int) {
        let startDate = now()
        var transfer = inFlightPageTransfers[gid]?[pageIndex] ?? InFlightPageTransfer(
            startDate: startDate,
            startedInBackground: isSceneInBackground,
            isTransferring: true
        )
        transfer.startDate = startDate
        transfer.startedInBackground = isSceneInBackground
        transfer.firstByteDate = nil
        transfer.isTransferring = true
        transfer.stallLogged = false
        inFlightPageTransfers[gid, default: [:]][pageIndex] = transfer
    }

    /// Closes the attempt, and reports a transfer that ended having never received a byte.
    ///
    /// The entry itself survives: whether this page's credit stays, is traded for whole-page credit
    /// or is withdrawn is decided by the outcome downstream, not by the transfer stopping.
    func endPageTransfer(gid: String, pageIndex: Int) {
        guard var transfer = inFlightPageTransfers[gid]?[pageIndex] else { return }
        transfer.isTransferring = false
        let elapsed = now().timeIntervalSince(transfer.startDate)
        if transfer.firstByteDate == nil,
           !transfer.stallLogged,
           elapsed >= Self.pageTransferStallThreshold {
            transfer.stallLogged = true
            logStarvedPageTransfer(
                gid: gid,
                pageIndex: pageIndex,
                startedInBackground: transfer.startedInBackground,
                elapsedMilliseconds: Self.milliseconds(elapsed),
                outcome: "ended"
            )
        }
        inFlightPageTransfers[gid]?[pageIndex] = transfer
    }

    /// Credits one transfer's running byte total and, at most once per
    /// `intraPageProgressPushMinimumInterval`, pushes the result.
    ///
    /// A callback with no entry is ignored rather than resurrecting one: it is a late report for a
    /// page that has already been flushed, withdrawn or retired, and re-creating the entry would
    /// credit a page that has left the fraction.
    ///
    /// An unknown expected size credits nothing. There is no fraction to compute from it, and
    /// inventing one would report progress the transfer has not demonstrated; whole-page credit on
    /// landing, plus the heartbeat, still cover the page.
    func recordPageTransferBytes(
        gid: String,
        pageIndex: Int,
        bytesWritten: Int64,
        bytesExpected: Int64
    ) async {
        guard var transfer = inFlightPageTransfers[gid]?[pageIndex] else { return }
        if bytesWritten > 0, transfer.firstByteDate == nil {
            let firstByteDate = now()
            transfer.firstByteDate = firstByteDate
            logFirstPageTransferBytes(
                gid: gid,
                pageIndex: pageIndex,
                startedInBackground: transfer.startedInBackground,
                elapsedMilliseconds: Self.milliseconds(
                    firstByteDate.timeIntervalSince(transfer.startDate)
                ),
                bytesExpected: bytesExpected
            )
        }
        if bytesExpected > 0 {
            let subunits = ContinuedProcessingSession.subunitsPerUnit * bytesWritten / bytesExpected
            transfer.creditedSubunits = max(
                transfer.creditedSubunits,
                min(ContinuedProcessingSession.subunitsPerUnit, subunits)
            )
        }
        inFlightPageTransfers[gid]?[pageIndex] = transfer

        guard let continuedSessionID else { return }
        if let lastProgressPushDate,
           now().timeIntervalSince(lastProgressPushDate) < Self.intraPageProgressPushMinimumInterval {
            return
        }
        await pushContinuedSessionProgress(sessionID: continuedSessionID)
    }

    /// Drops a FAILED page's sub-page credit — the one deliberate downward mover this bookkeeping
    /// has, and the reason it is spelled as its own named function rather than folded into a
    /// cleanup sweep.
    ///
    /// What it moves is bounded and outside the whole-page floor: at most one page's worth of
    /// sub-page credit, never a recorded page. `lastPushedCompletedPageCount` and D-G7-01 therefore
    /// keep their documented meaning, and the next push may show a drop of less than one page —
    /// which is the honest reading of a page that will not land in this run.
    func withdrawInFlightPageCredit(gid: String, pageIndex: Int) {
        guard var transfers = inFlightPageTransfers[gid] else { return }
        transfers[pageIndex] = nil
        inFlightPageTransfers[gid] = transfers.isEmpty ? nil : transfers
    }

    /// Retires the named pages' in-flight entries, called from the flush that RECORDS them.
    ///
    /// Their sub-page credit is not lost, it is superseded: the same synchronous stretch that
    /// removes these entries records the pages, so the whole-page term rises by exactly what the
    /// sub-page term gives up and no push can observe a value between the two.
    func retireInFlightPageCredits(gid: String, pages: some Sequence<Int>) {
        guard var transfers = inFlightPageTransfers[gid] else { return }
        for page in pages {
            transfers[page] = nil
        }
        inFlightPageTransfers[gid] = transfers.isEmpty ? nil : transfers
    }

    /// Drops every in-flight entry for a gallery whose run has exited.
    func retireInFlightPageTransfers(gid: String) {
        inFlightPageTransfers[gid] = nil
    }

    /// The sub-page credit that belongs beside `snapshot`'s pushed pair.
    ///
    /// Summed ONLY over the galleries present in the very snapshot the pair was computed from, so
    /// it can never credit a gallery whose pages have left the denominator — the same
    /// summed-from-one-read discipline the pair itself is built on.
    func inFlightSubunitCount(for snapshot: SchedulableSnapshot) -> Int64 {
        var total: Int64 = 0
        for gid in snapshot.finishedPages.keys {
            guard let transfers = inFlightPageTransfers[gid] else { continue }
            for transfer in transfers.values {
                total += transfer.creditedSubunits
            }
        }
        return total
    }

    /// How many transfers are in flight for the galleries `snapshot` covers — the operational
    /// scalar the heartbeat's summary reports beside the fraction.
    func inFlightPageTransferCount(for snapshot: SchedulableSnapshot) -> Int {
        var total = 0
        for gid in snapshot.finishedPages.keys {
            total += inFlightPageTransfers[gid]?.values.count(where: \.isTransferring) ?? 0
        }
        return total
    }

    /// Records whether the app is backgrounded, so each transfer can be stamped with where it was
    /// created. Driven from AppReducer's scene phase; nothing here imports UIKit.
    public func setIsSceneInBackground(_ isInBackground: Bool) {
        isSceneInBackground = isInBackground
    }

    /// The ONE site that reports a transfer's first bytes.
    private func logFirstPageTransferBytes(
        gid: String,
        pageIndex: Int,
        startedInBackground: Bool,
        elapsedMilliseconds: Int,
        bytesExpected: Int64
    ) {
        let origin = Self.transferOrigin(startedInBackground: startedInBackground)
        logger.notice(
            """
            Page transfer first bytes, gid: \(gid, privacy: .private(mask: .hash)), \
            page \(pageIndex, privacy: .public), created \(origin, privacy: .public), \
            \(elapsedMilliseconds, privacy: .public) ms to first byte, \
            expected \(bytesExpected, privacy: .public) bytes.
            """
        )
    }

    /// The ONE site that reports a starved transfer, shared by both detectors (PD-5): the
    /// heartbeat's sweep of transfers still running, and `endPageTransfer`'s check on the way out —
    /// so a transfer the expiry's pause sweep cancelled still says how long it starved.
    func logStarvedPageTransfer(
        gid: String,
        pageIndex: Int,
        startedInBackground: Bool,
        elapsedMilliseconds: Int,
        outcome: String
    ) {
        let origin = Self.transferOrigin(startedInBackground: startedInBackground)
        logger.notice(
            """
            Page transfer starved, gid: \(gid, privacy: .private(mask: .hash)), \
            page \(pageIndex, privacy: .public), created \(origin, privacy: .public), \
            \(elapsedMilliseconds, privacy: .public) ms without bytes, \(outcome, privacy: .public).
            """
        )
    }

    /// A closed two-value vocabulary, so the field can go out `public` without carrying anything
    /// derived from the gallery or the device.
    private static func transferOrigin(startedInBackground: Bool) -> String {
        startedInBackground ? "background" : "foreground"
    }

    private static func milliseconds(_ interval: TimeInterval) -> Int {
        Int((interval * 1000).rounded())
    }
}
