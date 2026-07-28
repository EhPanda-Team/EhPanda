import AppModels
import BackgroundProcessingClient
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// Everything one continued-processing session reports about the work it covers: page progress
/// summed across every schedulable gallery, plus how many galleries that is.
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

// MARK: - Continued Processing Session
extension DownloadCoordinator {
    /// Sums page progress across every gallery the scheduler would run, from a single index read.
    ///
    /// Both numbers come from one snapshot on purpose: mixing snapshots is what makes a reported
    /// fraction jump around.
    public func schedulableProgress() async -> ContinuedSessionProgress {
        let downloads = await schedulableDownloads()
        return ContinuedSessionProgress(
            progress: DownloadProgress(
                completedPageCount: downloads.map(\.completedPageCount).reduce(0, +),
                pageCount: downloads.map(\.pageCount).reduce(0, +)
            ),
            galleryCount: downloads.count
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
    /// Nothing here gates download work. The queue is already running by the time this is called,
    /// and a submission can silently never start, so the session is background insurance rather
    /// than a precondition for the work.
    public func ensureContinuedSession() async {
        guard !hasLiveContinuedSession, await hasPendingWork() else { return }
        let sessionID = UUID()
        hasLiveContinuedSession = true
        continuedSessionID = sessionID
        lastPushedCompletedPageCount = 0

        let snapshot = await schedulableProgress()
        let clientSession = await backgroundProcessingClient.start(
            String(localized: .continuedSessionTitle),
            continuedSessionSubtitle(for: snapshot),
            Int64(snapshot.progress.displayCompletedPageCount),
            Int64(snapshot.progress.displayPageCount)
        )
        guard let clientSession else {
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
        lastPushedCompletedPageCount = snapshot.progress.displayCompletedPageCount
        continuedSessionTask = Task { [weak self] in
            for await event in clientSession.events {
                await self?.handleContinuedSessionEvent(event, sessionID: sessionID)
            }
            // The stream finishes itself, so falling out of this loop *is* the session ending;
            // no external cancellation exists, and none is needed.
            await self?.markContinuedSessionEnded(sessionID: sessionID)
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
        hasLiveContinuedSession = false
        continuedSessionTask = nil
        lastPushedCompletedPageCount = 0
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
            let clientSessionID = continuedClientSessionID
            // Ended first: completion is the last thing this session does, and the client's
            // stream finishing behind it must find no state left to clear.
            markContinuedSessionEnded(sessionID: sessionID)
            if let clientSessionID {
                await backgroundProcessingClient.finish(clientSessionID, true)
            }
            // A nil client id means this session's start is still in flight. Its own ensure
            // re-check completes the session it created; completing anything here without an id
            // would recreate the wrong-session completion defect.
            return
        }
        await pushContinuedSessionProgress(sessionID: sessionID)
    }

    /// Pushes one snapshot's counts, and the subtitle built from it, to the card.
    ///
    /// The monotonic clamp lives here rather than in the client because the client is
    /// domain-agnostic: it cannot know that a total shrinking as a gallery leaves the queue is
    /// legal and expected, while a completed count going backwards is not. The scheduler reads a
    /// steadily advancing completed count as evidence the task is not stalled, and forcibly
    /// expires the tasks that look most stalled first, so this is a liveness requirement rather
    /// than cosmetics.
    public func pushContinuedSessionProgress(sessionID: UUID) async {
        guard continuedSessionID == sessionID else { return }
        let snapshot = await schedulableProgress()
        guard continuedSessionID == sessionID else { return }
        // Read the client identity only after the ownership re-check. Capturing it before the
        // suspending progress read could present a predecessor's id after a successor took over;
        // nil here means start is still in flight and there is no card to push to yet.
        guard let clientSessionID = continuedClientSessionID else { return }
        let completedPageCount = max(
            lastPushedCompletedPageCount,
            snapshot.progress.displayCompletedPageCount
        )
        lastPushedCompletedPageCount = completedPageCount
        // The counts the card renders as a bar and the counts it renders as text are built from
        // this one value, not from the raw snapshot, because they are two views of the same fact
        // and a reader can see both at once. They only differ from the snapshot in the rare queue
        // shrink handled above — but that is exactly when a bar sitting at full while the text
        // reads "0 / 4 pages" would look like a defect.
        let pushed = ContinuedSessionProgress(
            progress: DownloadProgress(
                completedPageCount: completedPageCount,
                // Held at or above the monotonic completed count, so the rare shrink that drops
                // the summed total below pages this session has already finished still cannot
                // report a fraction above one.
                pageCount: max(snapshot.progress.displayPageCount, completedPageCount)
            ),
            galleryCount: snapshot.galleryCount
        )
        await backgroundProcessingClient.updateProgress(
            clientSessionID,
            Int64(pushed.progress.displayCompletedPageCount),
            Int64(pushed.progress.displayPageCount),
            continuedSessionSubtitle(for: pushed)
        )
    }

}
