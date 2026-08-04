import AppModels
import BackgroundProcessingClient
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// Everything one continued-processing session reports about the work it covers: one summed page
/// fraction, plus how many galleries are still schedulable.
///
/// The fraction is not summed over the live schedulable set alone. A gallery leaving that set
/// retires the pages it finished into the session's ledger, and `pushContinuedSessionProgress`
/// adds that ledger to both sides of the pushed pair, so the pair keeps describing the whole queue
/// the session covers rather than whatever happens to remain schedulable (D-G2-01, extending
/// D-10). The gallery count is the remaining schedulable galleries and only those.
///
/// A small named value rather than a pair of numbers, for two reasons. An unlabeled tuple type is
/// banned at error severity here, and `DownloadProgress` already owns the clamping that stops a
/// corrupt manifest from yielding a zero denominator or a negative numerator.
public struct ContinuedSessionProgress: Equatable, Sendable {
    public let progress: DownloadProgress
    public let galleryCount: Int

    public init(
        progress: DownloadProgress,
        galleryCount: Int
    ) {
        self.progress = progress
        self.galleryCount = galleryCount
    }
}

/// One read of the schedulable set: what it sums to, and who was in it.
///
/// A small named value for the same reason as above — an unlabeled tuple type is banned at error
/// severity here — and one value rather than two calls because the ledger has to be reconciled
/// against the very read whose sums it corrects. Reconciling against a second read would let a
/// gallery be retired while the sums still counted it, or counted twice.
public struct SchedulableSnapshot: Equatable, Sendable {
    /// What the live schedulable set alone reports, before any retired pages are added to it.
    public let sessionProgress: ContinuedSessionProgress
    /// Finished pages per schedulable gallery, keyed by gallery identifier.
    public let finishedPages: [String: Int]

    public init(
        sessionProgress: ContinuedSessionProgress,
        finishedPages: [String: Int]
    ) {
        self.sessionProgress = sessionProgress
        self.finishedPages = finishedPages
    }
}

// MARK: - Continued Processing Session
extension DownloadCoordinator {
    /// Sums page progress across every gallery the scheduler would run, and reports which galleries
    /// those were, from a single index read.
    ///
    /// Every number here comes from one snapshot on purpose: mixing snapshots is what makes a
    /// reported fraction jump around, and it would also let the retirement ledger disagree with the
    /// sums it exists to correct.
    public func schedulableSnapshot() async -> SchedulableSnapshot {
        let downloads = await schedulableDownloads()
        return SchedulableSnapshot(
            sessionProgress: ContinuedSessionProgress(
                progress: DownloadProgress(
                    completedPageCount: downloads.map(\.completedPageCount).reduce(0, +),
                    pageCount: downloads.map(\.pageCount).reduce(0, +)
                ),
                galleryCount: downloads.count
            ),
            // `reduce(into:)` rather than `Dictionary(uniqueKeysWithValues:)`, which traps on a
            // duplicate key: the index's own deduplication would be the only thing between a
            // duplicated gallery folder and a crash on the card's progress path.
            finishedPages: downloads.reduce(into: [String: Int]()) { finished, download in
                finished[download.gid] = download.completedPageCount
            }
        )
    }

    /// The card's entire content surface: counts in, one localized string out.
    ///
    /// No gallery value is in scope here, and the localized key accepts nothing but integers, so
    /// no content-identifying text has a path onto the card. That is a requirement rather than an
    /// accident of the current wording: the card renders in system UI, outside the app's privacy
    /// mask and outside App Switcher snapshot protection, where a gallery name would be readable
    /// by anyone glancing at the screen.
    public func continuedSessionSubtitle(
        for progress: ContinuedSessionProgress
    ) -> String {
        String(
            localized: .continuedSessionSubtitle(
                completed: progress.progress.displayCompletedPageCount,
                total: progress.progress.displayPageCount,
                galleries: progress.galleryCount
            )
        )
    }

    /// Starts the one queue-wide session, if none is live and there is work for it to cover.
    ///
    /// Call this from a queue-mobilizing user action and from nowhere else. The scheduler
    /// validates foreground state itself and silently drops a submission it disagrees with, so a
    /// call from a non-user context — the queue resuming at cold launch, say — would mint an
    /// identifier for a session that never starts. Work that becomes schedulable without a tap
    /// therefore runs foreground-only until the next qualifying tap.
    ///
    /// Setting the liveness flag and stamping the session id synchronously, before the first
    /// point another caller could interleave, is the guard against two callers both reaching the
    /// start call. It matters for more than a duplicate card: identifiers are minted per session,
    /// and registering a second launch handler for one terminates the app.
    ///
    /// Interleavings around the suspending client start have explicit dispositions:
    /// - FORBIDDEN: a drain cannot clear ownership mid-start and let a second tap issue an
    ///   overlapping start the live store refuses. Ownership stays live until the client id lands,
    ///   so the second tap folds into the pending session.
    /// - REACHABLE BY DESIGN: a start the store refuses still rolls back and leaves work uncovered
    ///   until the next qualifying tap. D-03 and SC3 provide no fallback tier.
    /// - REACHABLE BY DESIGN: work that becomes schedulable without a tap stays foreground-only
    ///   until the next qualifying tap under D-07; deferred reconciliation never starts a session.
    /// - REACHABLE BY DESIGN: if the queue empties and refills during start, deferred
    ///   reconciliation re-reads the queue and keeps the surviving session covering the new work.
    ///
    /// Nothing here gates download work. The queue is already running by the time this is called,
    /// and a submission can silently never start, so the session is background insurance rather
    /// than a precondition for the work.
    public func ensureContinuedSession() async {
        guard !hasLiveContinuedSession, await hasPendingWork() else { return }
        let sessionID = UUID()
        hasLiveContinuedSession = true
        continuedSessionID = sessionID
        lastPushedCompletedPageCount = 0
        retiredSessionPages = [:]
        observedSchedulablePages = [:]

        let snapshot = await schedulableSnapshot()
        let clientSession = await backgroundProcessingClient.start(
            String(localized: .continuedSessionTitle),
            continuedSessionSubtitle(for: snapshot.sessionProgress),
            Int64(snapshot.sessionProgress.progress.displayCompletedPageCount),
            Int64(snapshot.sessionProgress.progress.displayPageCount)
        )
        guard let clientSession else {
            // TERMINAL: refusal ends this coordinator session, and teardown clears its debt.
            // The store still holds a predecessor whose completion has not landed. Roll this
            // call's bookkeeping back so the next D-07 tap can start a real session rather than
            // consuming a dead stream. A successor already owning the state must remain untouched.
            guard continuedSessionID == sessionID else { return }
            markContinuedSessionEnded(sessionID: sessionID)
            return
        }
        // The client start's main-actor hop is the real reentrancy window above. The pending-work
        // and progress reads are same-actor calls whose callees do not suspend today, and this
        // ownership re-check defends the path regardless.
        guard continuedSessionID == sessionID else {
            await backgroundProcessingClient.finish(clientSession.id, true)
            return
        }
        continuedClientSessionID = clientSession.id
        lastPushedCompletedPageCount = snapshot.sessionProgress.progress.displayCompletedPageCount
        // Seeded after the ownership re-check, so a superseded start seeds no membership: the
        // successor's own start snapshot is the only baseline its departures are measured against.
        observedSchedulablePages = snapshot.finishedPages
        continuedSessionTask = Task { [weak self] in
            for await event in clientSession.events {
                await self?.handleContinuedSessionEvent(event, sessionID: sessionID)
            }
            // The stream finishes itself, so falling out of this loop *is* the session ending;
            // no external cancellation exists, and none is needed.
            await self?.markContinuedSessionEnded(sessionID: sessionID)
        }
        if continuedSessionNeedsReconciliation {
            // Clear before awaiting: the reconcile may legitimately record fresh debt.
            continuedSessionNeedsReconciliation = false
            await reconcileContinuedSession()
        }
    }

    /// Applies the policy each session event carries.
    ///
    /// Expiration is deliberately a single path. A user cancelling on the card and the system
    /// reclaiming resources arrive through the same callback, and the API offers nothing to tell
    /// them apart, so one policy has to serve both. Pausing every schedulable gallery honors a
    /// deliberate cancel exactly as pausing each download in the app would; the cost is that a
    /// system reclaim also leaves the queue paused until the user resumes it. That cost is
    /// accepted, because no fallback tier exists: after a reclaim the work could not have
    /// continued anyway. The loop remains bound to the expiring session so a successor started
    /// during a per-gallery pause is not paused by a stale expiration. Read as two behaviors that
    /// happen to coincide, the uniformity looks like a bug, which is exactly why it is written
    /// down here.
    ///
    /// That policy belongs to the live session alone, which is why the identity gate comes first:
    /// an event surfacing from a superseded session's stream must not log as current, must not
    /// clear the live session's state, and above all must not pause work a newer session covers.
    public func handleContinuedSessionEvent(
        _ event: BackgroundProcessingEvent,
        sessionID: UUID
    ) async {
        guard continuedSessionID == sessionID else { return }
        switch event {
        case .granted:
            // Nothing to start: the work has been running since the tap that requested this.
            logger.notice("Continued-processing session granted.")
        case .expired:
            logger.notice("Continued-processing session expired, pausing schedulable downloads.")
            markContinuedSessionEnded(sessionID: sessionID)
            await pauseAllSchedulable(expiring: sessionID)
        case .unavailable:
            // Silent by contract: nothing reaches a reducer, there is no error surface, and the
            // queue behaves exactly as it does in the foreground.
            logger.notice("Continued-processing session unavailable, the queue runs foreground-only.")
            markContinuedSessionEnded(sessionID: sessionID)
        }
    }

    /// Clears every trace of *this* session, and of no other.
    ///
    /// Safe to call more than once for the same session, and routinely called twice: the event
    /// handler ends the session before acting on an expiration, and the consuming task ends it
    /// again when the stream finishes immediately behind that same event.
    ///
    /// The identity guard is why the second call is harmless even when a *different* session is
    /// live by then. That teardown routinely lands late — the expired branch awaits an unbounded
    /// run of per-gallery pauses before its loop exits — and on this reentrant actor a
    /// queue-mobilizing tap can legitimately start a successor inside that window. A teardown
    /// finding a different id must be a no-op, or it detaches the live session: the coordinator
    /// would believe none exists while the system still shows its card, so nothing would push
    /// progress and nothing would complete it.
    public func markContinuedSessionEnded(sessionID: UUID) {
        guard continuedSessionID == sessionID else { return }
        continuedSessionID = nil
        continuedClientSessionID = nil
        continuedSessionNeedsReconciliation = false
        hasLiveContinuedSession = false
        continuedSessionTask = nil
        lastPushedCompletedPageCount = 0
        retiredSessionPages = [:]
        observedSchedulablePages = [:]
    }

    /// Pauses every gallery the scheduler would run, one at a time, through the same primitive an
    /// in-app pause uses.
    ///
    /// Reusing the per-gallery primitive rather than adding a bulk mutation path is what makes
    /// the card's cancel literally consistent with pausing each download by hand: that primitive
    /// already maintains the scheduling-blocked set, the manifest state and observer
    /// notification, and a second path would have to re-implement all three in step with it.
    ///
    /// The session must already be marked ended before this runs, because each pause reschedules
    /// and the reschedule tail reconciles the session. Each gallery's pause is bound to both the
    /// expiring session and the queue-intent generation current when this loop chose it, so a D-07
    /// tap that lands across the pause's suspensions advances the intent and makes the stale pause
    /// abandon its write.
    public func pauseAllSchedulable(expiring sessionID: UUID) async {
        let gids = await schedulableDownloads().map(\.gid)
        for gid in gids {
            guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
            let expiration = ExpirationPauseOwnership(
                sessionID: sessionID,
                queueIntentGeneration: queueIntentGeneration(for: gid)
            )
            _ = await pause(gid: gid, expiration: expiration)
        }
    }

    /// Matches a live session to current queue state.
    ///
    /// Built to hang off the single point every queue mutation converges on, so a session can
    /// never be left running after the last download is paused or deleted — those paths null the
    /// active task directly, but they still reschedule afterwards.
    ///
    /// The id is bound before the schedulable-work read and re-checked after it because that read
    /// suspends: a reconcile that crosses a session transition there must neither clear the
    /// successor's state nor finish the successor's client-side stream.
    public func reconcileContinuedSession() async {
        guard hasLiveContinuedSession, let sessionID = continuedSessionID else { return }
        guard await hasPendingWork() else {
            guard continuedSessionID == sessionID else { return }
            // DEFERRED: a drain crossing the suspending start is early, not authoritative. Keep
            // ownership so a second tap cannot reach an overlapping start the live store refuses.
            guard let clientSessionID = continuedClientSessionID else {
                continuedSessionNeedsReconciliation = true
                return
            }
            // Ended first: completion is the last thing this session does, and the client's
            // stream finishing behind it must find no state left to clear.
            markContinuedSessionEnded(sessionID: sessionID)
            await backgroundProcessingClient.finish(clientSessionID, true)
            return
        }
        await pushContinuedSessionProgress(sessionID: sessionID)
    }

    /// Folds galleries that have left the schedulable set into this session's retirement ledger.
    ///
    /// **D-G2-01: a gallery leaving retires exactly the pages it had already finished — added to
    /// both the numerator and the denominator of every later push — and nothing more.** Its
    /// unfinished pages leave the denominator with it. One formula covers completion, pause,
    /// delete, the queued-work-item cancel and the expiration pause-all alike, for three reasons:
    ///
    /// 1. The denominator must describe work this session has done plus work it still intends to
    ///    do. Pages of a paused or deleted gallery will never be done in this session, so keeping
    ///    them would pin the card permanently below 1.0 — the mirror image of the defect this
    ///    ledger fixes.
    /// 2. Dropping the finished pages as well would rewind the numerator, which is the stall
    ///    signal the scheduler reads.
    /// 3. Symmetric retirement is the only rule under which the numerator never rewinds *and* the
    ///    fraction reaches 1.0 exactly at queue drain. A completed gallery is that same rule with
    ///    nothing left over — finished equals total — which is why no call site has to classify
    ///    *why* a gallery left.
    ///
    /// Membership is swept here rather than hooked into `settleCompletedDownload` because galleries
    /// leave through at least six paths, and instrumenting the one path a user happened to report
    /// would leave the other five. Sweeping at the single point that already reads the schedulable
    /// set covers every departure by construction, and covers a rejoining gallery too.
    ///
    /// One consequence looks like a leak and is not: a gallery that both joins and fully departs
    /// between two pushes is never observed, so it enters neither the live sum nor the ledger. That
    /// is correct rather than lossy — it was never part of the fraction, so its absence rewinds
    /// nothing and double-counts nothing. The alternative, a ledger fed from every queue mutation
    /// rather than from observed membership, would have to distinguish work this session actually
    /// reported from work it never saw.
    private func reconcileRetiredSessionPages(finishedPages: [String: Int]) async {
        // A gallery that rejoined is counted by the live sum again, so leaving it retired would
        // count its finished pages twice.
        for gid in finishedPages.keys {
            retiredSessionPages[gid] = nil
        }
        let departedGIDs = observedSchedulablePages.keys.filter({ finishedPages[$0] == nil })
        if !departedGIDs.isEmpty {
            // The record is authoritative where the last observation is merely recent: reading it
            // is what makes a gallery that completed between two pushes retire its full page count.
            let departedRecords = await indexedDownloads(gids: departedGIDs)
                .reduce(into: [String: DownloadedGallery]()) { records, download in
                    records[download.gid] = download
                }
            for gid in departedGIDs {
                guard let record = departedRecords[gid] else {
                    // Deleted outright: no record survives it, so the last observation is all the
                    // evidence there is of what this session finished for it.
                    retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0
                    continue
                }
                retiredSessionPages[gid] = min(max(record.completedPageCount, 0), record.pageCount)
            }
        }
        // Replacing the map is what makes each departure detected exactly once; a retired value is
        // then frozen until that gallery rejoins the schedulable set.
        observedSchedulablePages = finishedPages
    }

    /// Pushes one snapshot's counts, and the subtitle built from it, to the card.
    ///
    /// A gallery completing is the **ordinary** departure from the schedulable set rather than a
    /// rare one: `settleCompletedDownload` removes every finished gallery from the queue store, and
    /// its now-complete manifest fails `shouldSchedule` afterwards. Summing only the live set
    /// therefore took a completed gallery's pages out of the numerator and the denominator at once,
    /// and the two clamps below pinned the pair at a literal 100% card that could not advance again
    /// until the survivors collectively re-earned those pages. The retirement ledger — not the
    /// clamp — is what keeps the count rising across a gallery boundary, by putting those pages
    /// back on both sides.
    ///
    /// The monotonic floor survives as residual defence only. With the accounting basis no longer
    /// shrinking, the one movement it still catches is a genuine regression in a gallery's own
    /// finished count — pages disappearing from disk between two flushes — which the scheduler
    /// would read as a task losing ground, and it forcibly expires the tasks that look most stalled
    /// first. It lives here rather than in the client because the client is domain-agnostic: it
    /// cannot know which movements of these numbers are legal.
    ///
    /// The total clamp exists so the bar and the text can never describe different pairs. A reader
    /// sees both at once, and a bar sitting at full beside text reading "0 / 4 pages" looks like a
    /// defect however defensible each number is on its own.
    ///
    /// The live sums enter the arithmetic raw, and exactly one display clamp applies, at the end,
    /// over the summed pair. Adding the retired total to an already-clamped denominator would be
    /// the natural mistake and a wrong one: `displayPageCount` floors at one page, so an emptied
    /// schedulable set would contribute a phantom page and no drained queue could ever report a
    /// fraction of exactly one.
    ///
    /// Interleaving dispositions: the snapshot read and the retirement reconcile can both suspend,
    /// so ownership is re-checked after each of them. The reconcile deliberately runs before the
    /// client-identity guard — a departure during the start window must still be recorded even when
    /// there is no card to paint yet, and the deferred reconcile after start then pushes counts
    /// that already account for it.
    public func pushContinuedSessionProgress(sessionID: UUID) async {
        guard continuedSessionID == sessionID else { return }
        let snapshot = await schedulableSnapshot()
        guard continuedSessionID == sessionID else { return }
        await reconcileRetiredSessionPages(finishedPages: snapshot.finishedPages)
        guard continuedSessionID == sessionID else { return }
        // Read the client identity only after the ownership re-check. Capturing it before the
        // suspending progress read could present a predecessor's id after a successor took over;
        // SKIPPED: nil means there is no card to paint yet. The deferred reconcile after start
        // re-reads schedulable work and pushes fresh counts, so this update is recovered.
        guard let clientSessionID = continuedClientSessionID else { return }
        let liveProgress = snapshot.sessionProgress.progress
        let retiredPageCount = retiredSessionPages.values.reduce(0, +)
        let sessionProgress = DownloadProgress(
            completedPageCount: liveProgress.completedPageCount + retiredPageCount,
            pageCount: liveProgress.pageCount + retiredPageCount
        )
        let completedPageCount = max(
            lastPushedCompletedPageCount,
            sessionProgress.displayCompletedPageCount
        )
        lastPushedCompletedPageCount = completedPageCount
        let pushed = ContinuedSessionProgress(
            progress: DownloadProgress(
                completedPageCount: completedPageCount,
                pageCount: max(sessionProgress.displayPageCount, completedPageCount)
            ),
            galleryCount: snapshot.sessionProgress.galleryCount
        )
        await backgroundProcessingClient.updateProgress(
            clientSessionID,
            Int64(pushed.progress.displayCompletedPageCount),
            Int64(pushed.progress.displayPageCount),
            continuedSessionSubtitle(for: pushed)
        )
    }

}
