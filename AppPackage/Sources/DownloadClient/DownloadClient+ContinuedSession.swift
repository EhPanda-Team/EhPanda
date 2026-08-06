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

/// One read of the schedulable set: what it sums to, who was in it, and which of them still had
/// work left to do.
///
/// A small named value for the same reason as above — an unlabeled tuple type is banned at error
/// severity here — and one value rather than two calls because the ledger has to be reconciled
/// against the very read whose sums it corrects. Reconciling against a second read would let a
/// gallery be retired while the sums still counted it, or counted twice.
///
/// The incompleteness membership rides along for the same reason the sums do. D-G4-01's session
/// basis is decided from a gallery's record *and* from what this session has already seen it doing,
/// so the trust that grants the second half has to be accumulated from the same read the basis was
/// computed from. Taken from a second read, the numerator's opening rule and the retirement's
/// departure rule could disagree about the same gallery.
public struct SchedulableSnapshot: Equatable, Sendable {
    /// What the live schedulable set alone reports, before any retired pages are added to it.
    public let sessionProgress: ContinuedSessionProgress
    /// Session-completed pages per schedulable gallery, keyed by gallery identifier — the D-G4-01
    /// basis the numerator above is summed from, not the raw record counts.
    public let finishedPages: [String: Int]
    /// The galleries in this read whose records still report unfinished pages.
    public let incompleteGalleryIDs: Set<String>

    public init(
        sessionProgress: ContinuedSessionProgress,
        finishedPages: [String: Int],
        incompleteGalleryIDs: Set<String>
    ) {
        self.sessionProgress = sessionProgress
        self.finishedPages = finishedPages
        self.incompleteGalleryIDs = incompleteGalleryIDs
    }
}

/// One gallery an expiration sweep chose, paired with the ownership the sweep recorded for it in
/// the same breath as that choice.
///
/// A small named value rather than a pair of members, for the same reason as above: an unlabeled
/// tuple type is banned at error severity here.
private struct ExpirationPauseTarget {
    let gid: String
    let expiration: ExpirationPauseOwnership
}

// MARK: - Continued Processing Session
extension DownloadCoordinator {
    /// Sums *this session's* page progress across every gallery the scheduler would run, and reports
    /// which galleries those were, from a single index read.
    ///
    /// Every number here comes from one snapshot on purpose: mixing snapshots is what makes a
    /// reported fraction jump around, and it would also let the retirement ledger disagree with the
    /// sums it exists to correct.
    ///
    /// **D-G4-01: a schedulable gallery's session-completed page count is its record's
    /// `completedPageCount` when the record reads incomplete or this session has already trusted the
    /// gallery — having observed it incomplete, or having proven at the run's own preparation that
    /// the run still has pages of its own to fetch — and zero otherwise.** The
    /// per-gallery `pageCount` denominator and the schedulable `galleryCount` are untouched by the
    /// rule; only the numerator's basis is.
    ///
    /// It exists because schedulability and progress answer different questions. `shouldSchedule`
    /// returns true for any queued work item before it ever consults `isIncomplete`, so a gallery
    /// whose record is already complete is schedulable the moment it is queued for an update, a
    /// redownload, a repair or a bare re-enqueue — correctly, because the redo has to run. Counting
    /// its manifest's finished pages as session progress then opens the card at its own ceiling,
    /// latches `lastPushedCompletedPageCount` there and lets the monotonic floor pin it at 100% for
    /// the whole session: the pinned card the retirement ledger exists to prevent, reached through a
    /// different door, and one the scheduler reads as a stalled task before it force-expires the
    /// least-progressing ones. Those pages are the redo's *target*, not work this session did.
    ///
    /// **How long the zero branch actually covers each of those routes, re-derived.** The list above
    /// says which taps make a complete-reading gallery schedulable; it does not say the zero lasts.
    /// For every one of them the zero covers only the window between the qualifying tap and the
    /// run's own working-seed preparation. An update or a redownload deletes the working folder and
    /// prepares a fresh all-empty manifest; a repair keeps its folder, and **D-G5-01**
    /// (`reconcileWorkingManifestAgainstPageFiles`, `DownloadClient+ExecutionSupport.swift`) blanks
    /// the hash of every page whose file is gone, which is what a repair exists for — so its record
    /// reads incomplete from that moment too, and the raw-counting half takes over. Reading the list
    /// as a claim that a repair is *handled by counting zero* is what G-15-5 was: without D-G5-01
    /// the repair's zero never ended, and the session finished a terminal `0 / N` card over real
    /// work.
    ///
    /// Blanking is not guaranteed, though, which is why record honesty cannot be the whole rule. The
    /// reconciliation has three refusal exits, and at any of them the manifest comes back verbatim:
    /// a repair of a record that reads COMPLETE stays complete-reading for the whole run, and the
    /// flush path only ever moves a record upward. That is G-15-23 — G-15-5's card reached again
    /// through the honesty defence itself — and the trust set is what covers it.
    ///
    /// Honesty is necessary but not sufficient, because the record alone never speaks for a session.
    /// The run therefore announces its post-preparation basis before any page work
    /// (`prepareWorkingSeedAnnouncingProgress`) and, when its own pending page list is non-empty,
    /// records the proof in the same breath. That list — the one the run's page loop is fed, honoring
    /// the payload's page selection — rather than the folder's shortfall against its manifest, which
    /// credits a selected-page retry that will fetch nothing (G-15-27). That makes the observation
    /// independent of flush cadence — deterministically so where one flush batch would otherwise
    /// carry every missing page and restore completeness before its own push — and independent of
    /// whether the reconciliation blanked anything at all.
    ///
    /// **The proof is owned by the run, and this set is seeded from it (G-15-26).** The recording
    /// goes to `provenPageWorkRunGIDs`, which no session boundary touches, and every session start
    /// seeds this set from it inside its synchronous reset; a run that starts inside a live session
    /// is additionally admitted here immediately, so the same fact reaches the session by two routes
    /// and neither depends on the other. Owning it in this set alone lost it whenever the session
    /// lifecycle did not bracket the run — an `.unavailable` teardown mid-run, and a queue resumed at
    /// launch, where D-07 forbids a session entirely. `ensureContinuedSession`'s merged post-start
    /// seed is separately what keeps an observation that lands inside the client start's main-actor
    /// hop.
    ///
    /// Each half of the predicate earns its place:
    /// - The record's own incompleteness is the common case, and it is what stops mid-run progress
    ///   from ever being masked: the instant a redo's own manifest writes make the record
    ///   incomplete, its finished pages count raw, with no dependence on trust having caught up.
    /// - The trust set covers the completion flush, where a gallery the session watched doing real
    ///   work reports its full count while its record already reads complete again and it is still
    ///   inside its own schedulable set — and, through the run's own proof, the refusal family, where
    ///   the record reads complete for the entire run and there is no incompleteness for the
    ///   push-side writer to observe.
    ///
    /// Keying on the record rather than on `queuedModes` is deliberate and was the design's one
    /// hardening. A mode-keyed basis stays set for a whole active run, so it would mask the redo's
    /// real progress at zero — a fresh stall — and it is never set at all on the bare enqueue that
    /// reuses a complete manifest, so that route would have stayed open.
    func schedulableSnapshot() async -> SchedulableSnapshot {
        let downloads = await schedulableDownloads()
        // `reduce(into:)` rather than `Dictionary(uniqueKeysWithValues:)`, which traps on a
        // duplicate key: the index's own deduplication would be the only thing between a
        // duplicated gallery folder and a crash on the card's progress path.
        let sessionCompletedPages = downloads.reduce(into: [String: Int]()) { pages, download in
            let isSessionWork = download.isIncomplete
                || observedIncompleteSessionGIDs.contains(download.gid)
            pages[download.gid] = isSessionWork ? download.completedPageCount : 0
        }
        return SchedulableSnapshot(
            sessionProgress: ContinuedSessionProgress(
                progress: DownloadProgress(
                    // Summed from the very map the ledger observes, so the pushed numerator and the
                    // per-gallery values a departure is measured against cannot come apart.
                    completedPageCount: sessionCompletedPages.values.reduce(0, +),
                    pageCount: downloads.map(\.pageCount).reduce(0, +)
                ),
                galleryCount: downloads.count
            ),
            finishedPages: sessionCompletedPages,
            incompleteGalleryIDs: Set(downloads.filter(\.isIncomplete).map(\.gid))
        )
    }

    /// The card's entire content surface: counts in, one localized string out.
    ///
    /// No gallery value is in scope here, and the localized key accepts nothing but integers, so
    /// no content-identifying text has a path onto the card. That is a requirement rather than an
    /// accident of the current wording: the card renders in system UI, outside the app's privacy
    /// mask and outside App Switcher snapshot protection, where a gallery name would be readable
    /// by anyone glancing at the screen.
    func continuedSessionSubtitle(
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
    /// Setting the liveness flag and stamping the session id is the guard against two callers both
    /// reaching the start call. It matters for more than a duplicate card: identifiers are minted
    /// per session, and registering a second launch handler for one terminates the app.
    ///
    /// The guard line below awaits `hasPendingWork()`, which reads `activeTask` and then the queue
    /// store through `schedulableDownloads()`. These are same-actor calls that do not suspend today,
    /// so the stretch from that guard through the id stamp admits no interleaving as written; an
    /// `await` introduced inside them reopens the two-starters window this guard closes and needs
    /// its own re-validation.
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
    func ensureContinuedSession() async {
        guard !hasLiveContinuedSession, await hasPendingWork() else { return }
        let sessionID = UUID()
        hasLiveContinuedSession = true
        continuedSessionID = sessionID
        lastPushedCompletedPageCount = 0
        retiredSessionPages = [:]
        observedSchedulablePages = [:]
        // SEEDED here rather than emptied, and here rather than beside the merges below, because the
        // card's OPENING subtitle is computed from the snapshot taken on the next line — after this
        // synchronous reset and before the client start. A run that proved its page work while no
        // session was live, or while a predecessor session was being torn down, is credited by this
        // session from its very first push; a seed folded in with the post-start merges would arrive
        // after that subtitle was already fixed, passing a mid-session assertion while leaving the
        // card's opening reading at zero (G-15-26). The proof belongs to the run, not to any session,
        // so reading it here is not inheriting a predecessor's state.
        observedIncompleteSessionGIDs = provenPageWorkRunGIDs

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
        // and progress reads are same-actor calls that do not suspend today; an `await` introduced
        // inside them reopens this window and needs its own re-validation, and this ownership
        // re-check defends the path regardless.
        guard continuedSessionID == sessionID else {
            await backgroundProcessingClient.finish(clientSession.id, true)
            return
        }
        continuedClientSessionID = clientSession.id
        // Merged rather than assigned, for the reason the two collections below give, reaching the
        // scalar through a different writer. A D-G7-01 withdrawal landing inside the client start's
        // main-actor hop is a real correction made by THIS session's own scheduled run, and it
        // outranks the pre-hop snapshot, which still counted the pages that correction just blanked.
        // The withdrawal is the scalar's ONLY writer inside that window — a start-window push
        // returns at the nil-client guard before it reaches its floor update — so the value here is
        // zero minus any hop-window corrections, and adding it folds them in instead of discarding
        // them. The clamp at zero is what keeps a correction for work the snapshot never counted
        // from over-withdrawing: it may only under-seed, which is the safe direction, because a
        // floor seeded low re-latches at the very next push while a floor seeded high is the defect.
        lastPushedCompletedPageCount = max(
            snapshot.sessionProgress.progress.displayCompletedPageCount + lastPushedCompletedPageCount,
            0
        )
        // Merged rather than assigned, because a push landing inside the client start's main-actor
        // hop is a real observation by THIS session and outranks the pre-hop snapshot. That push's
        // reconcile deliberately runs ahead of the nil-client guard, so it records membership and
        // trust while there is still no card to paint; assigning the pre-hop snapshot over it
        // discarded exactly that. On the canonical `retryPages` route the run is scheduled before
        // this trailing ensure, so the run-start announcement (D-G5-01) can land precisely here —
        // and with the old assignment a single-missing-page repair lost the trust it had just
        // earned and finished a pinned-zero card in that interleaving.
        //
        // The seeding's position still carries the superseded-start rule, and merging cannot weaken
        // it: "a superseded start seeds nothing" is enforced by the ownership guard above, which a
        // superseded start never passes.
        //
        // What each collection can already hold at this point differs, and the difference is
        // deliberate (G-15-26). `observedSchedulablePages` was emptied by this session's own
        // synchronous reset, so anything in it is this session's own identity-gated observation.
        // `observedIncompleteSessionGIDs` was SEEDED there from `provenPageWorkRunGIDs`, so it can
        // additionally hold proofs recorded by runs that are still in flight — including runs that
        // prepared under a predecessor session, or under no session at all. That is not a
        // predecessor's session state leaking in: a run's proof of its own page work is a fact about
        // the run, which is why it outlives the session boundary and not the run boundary.
        //
        // The merge below is still a merge for its original reason, and that reason is orthogonal:
        // it folds in observations made INSIDE the client start's main-actor hop, which the pre-hop
        // snapshot could not have seen. Assigning the snapshot over them discarded exactly the trust
        // a run-start announcement landing in that window had just earned.
        observedSchedulablePages.merge(
            snapshot.finishedPages,
            uniquingKeysWith: { observed, _ in observed }
        )
        observedIncompleteSessionGIDs.formUnion(snapshot.incompleteGalleryIDs)
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
    func handleContinuedSessionEvent(
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
    /// **Session state only. A session boundary is not a run boundary (G-15-26).** Every collection
    /// cleared below describes what THIS session observed; none of them describes a run. In
    /// particular `provenPageWorkRunGIDs` is deliberately not cleared here, and adding it would
    /// re-open the exact defect this teardown caused: the `.unavailable` arm calls this and nothing
    /// else, leaving the queue running foreground-only, so clearing the run's proof here stripped an
    /// in-flight repair of the trust it had already earned and left it contributing zero for the rest
    /// of its re-download. The run's own exit retires that proof, at `processDownload`'s `defer`.
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
    func markContinuedSessionEnded(sessionID: UUID) {
        guard continuedSessionID == sessionID else { return }
        continuedSessionID = nil
        continuedClientSessionID = nil
        continuedSessionNeedsReconciliation = false
        hasLiveContinuedSession = false
        continuedSessionTask = nil
        lastPushedCompletedPageCount = 0
        retiredSessionPages = [:]
        observedSchedulablePages = [:]
        observedIncompleteSessionGIDs = []
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
    /// and the reschedule tail reconciles the session.
    ///
    /// **Every target's ownership is captured WITH the gid list, never at that target's own
    /// iteration (G-15-22).** Each pause is bound to the expiring session and to the queue-intent
    /// generation that was current when the SWEEP chose its targets, so a D-07 tap landing anywhere
    /// after that capture — including in the whole stretch before the tapped gallery's iteration is
    /// reached — advances a generation this loop has already RECORDED. `ownsExpirationPause` then
    /// fails, the stale pause abandons its write as `.superseded`, and that arm re-converges and
    /// re-ensures, which is what starts the session the tap asked for. Read at each iteration
    /// instead, the expectation for a gallery the tap had already moved was the advanced value
    /// compared against itself: the pause settled over the user's action, the design's own
    /// compensation never ran, and the tap produced nothing at all.
    ///
    /// The capture stretch is synchronous, which is what makes every recorded expectation a pre-tap
    /// one: `schedulableDownloads()` performs no suspending call today — `queueStore.gids` is a
    /// synchronous property read and `indexedDownloads(gids:)` awaits nothing — so nothing can
    /// interleave between that read and the pairs built from it. An `await` introduced there
    /// reopens exactly this window and needs its own re-validation, which is the note
    /// `ensureContinuedSession` and `pushContinuedSessionProgress` already record for their own
    /// guards.
    func pauseAllSchedulable(expiring sessionID: UUID) async {
        let targets = await schedulableDownloads().map { download in
            ExpirationPauseTarget(
                gid: download.gid,
                expiration: ExpirationPauseOwnership(
                    sessionID: sessionID,
                    queueIntentGeneration: queueIntentGeneration(for: download.gid)
                )
            )
        }
        for target in targets {
            guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
            _ = await pause(gid: target.gid, expiration: target.expiration)
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
    ///
    /// **D-G2B-01: the drain branch emits exactly one progress push, positioned after the
    /// `continuedClientSessionID` deferral and before `markContinuedSessionEnded`.** Completion
    /// carries no subtitle — it reaches `setTaskCompleted` and nothing else — so without that push
    /// the last string the card holds is the final gallery's forced flush, taken while that gallery
    /// was still downloading and therefore still inside its own schedulable set. That string always
    /// names one remaining gallery, whatever the queue actually did afterwards.
    ///
    /// The position is the whole fix, because the same call a few lines later compiles, ships and
    /// does nothing. After `markContinuedSessionEnded` it is rejected twice over: that teardown
    /// clears `continuedSessionID`, which fails the push's own ownership guard, *and* it zeroes
    /// `retiredSessionPages`, so even a push that got through would report a bare live sum. After
    /// the completion the store has released the task, and `updateProgress` returns at its own
    /// identity guard with nothing left to paint.
    ///
    /// The terminal fraction is honest arithmetic rather than a special case. The retirement ledger
    /// already holds every page this session finished, so a drained queue sums to N of N with no
    /// gallery remaining, and no new arithmetic is introduced here.
    ///
    /// The push's tail crosses the client seam — `updateProgress` hops to the `@MainActor`
    /// `ContinuedProcessingSession` — where this branch's tail was previously suspension-free. The
    /// index read and the ledger's record read inside the push are same-actor calls that do not
    /// suspend today; that main-actor hop is the whole of the window. Ownership *and* the drain
    /// predicate are therefore re-checked behind it (**D-G3-01: teardown runs only over a still-true
    /// justifying observation**). Re-checking identity alone would guard the invariant that cannot
    /// fail: minting a successor requires `ensureContinuedSession` to pass `!hasLiveContinuedSession`
    /// and that flag stays true until teardown, while drain-ness can and does go stale there.
    ///
    /// The re-check itself must not suspend, exactly as `ensureContinuedSession` states for its own
    /// guard: `hasPendingWork()` reads `activeTask` and then the queue store through
    /// `schedulableDownloads()`, and these are same-actor calls that do not suspend today; an
    /// `await` introduced inside them reopens the window behind this guard and needs its own
    /// re-validation.
    ///
    /// One stale-shaped push is accepted rather than removed. The terminal push's arguments are
    /// computed before the hop, so a mid-hop mobilization means the card can briefly hold a
    /// terminal-shaped pair before the next live push corrects it. Re-checking ahead of the push
    /// cannot exist, because the push *is* the suspension; the numerator floor holds throughout and
    /// the very next convergence repaints, so this is a transient string rather than a state defect.
    func reconcileContinuedSession() async {
        guard hasLiveContinuedSession, let sessionID = continuedSessionID else { return }
        guard await hasPendingWork() else {
            guard continuedSessionID == sessionID else { return }
            // DEFERRED: a drain crossing the suspending start is early, not authoritative. Keep
            // ownership so a second tap cannot reach an overlapping start the live store refuses.
            guard let clientSessionID = continuedClientSessionID else {
                continuedSessionNeedsReconciliation = true
                return
            }
            // D-G2B-01: the card's last word, taken while this session still owns it.
            await pushContinuedSessionProgress(sessionID: sessionID)
            guard continuedSessionID == sessionID else { return }
            // D-G3-01: the push crossed the client seam's main-actor hop, so the drain decision
            // taken before it is no longer authoritative. Work mobilized inside that window folded
            // into this session — its own `ensureContinuedSession` is inert while
            // `hasLiveContinuedSession` is true — so completing here would surrender coverage
            // nothing can restore until the next qualifying tap (D-03/SC3: no fallback tier).
            // Leave the session live; the next convergence reconciles it.
            guard await hasPendingWork() == false else { return }
            logger.notice("Continued-processing session drained, terminal progress pushed.")
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
    ///
    /// **The record's authority is earned, not assumed (D-G4-01).** It is authoritative about the
    /// *manifest*; only for a gallery this session has already trusted — observed incomplete, or
    /// proven page work for at the run's own preparation — is it also authoritative about this
    /// session's work. A redo that never ran — a complete manifest queued
    /// for an update and then cancelled — would otherwise retire pages the session never downloaded
    /// into both sides of the fraction and report a finished session. So a departed gallery outside
    /// `observedIncompleteSessionGIDs` retires its last observation instead, which the same rule
    /// made zero while it was present.
    ///
    /// This is not a departure-reason branch. The formula still takes no reason parameter, no call
    /// site classifies why a gallery left, and completion, pause, delete, cancel and expiration are
    /// treated identically; the gate reads only what this session observed while the gallery was
    /// there.
    ///
    /// Accepted residual: a never-trusted redo that starts *and* finishes entirely between two
    /// observations retires at its observed basis of zero. That is the unobserved-work convention
    /// above reached from one observation further out, and the direction is deliberate —
    /// under-retiring keeps the fraction at or below truth, while over-retiring is the defect.
    private func reconcileRetiredSessionPages(snapshot: SchedulableSnapshot) async {
        let finishedPages = snapshot.finishedPages
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
                guard observedIncompleteSessionGIDs.contains(gid) else {
                    // Never watched doing work, so its record speaks for the manifest rather than
                    // for this session: retire what was observed, which the basis made zero.
                    retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0
                    continue
                }
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
        // Accumulated from the same read the basis was computed from, so the numerator's opening
        // rule and the departure rule can never disagree about a gallery.
        observedIncompleteSessionGIDs.formUnion(snapshot.incompleteGalleryIDs)
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
    /// The monotonic floor survives as residual defence only. Deliberate downward movers of the
    /// accounting basis exist wherever the coordinator rewrites the index record, and enumerating
    /// them is the recorded four-round failure this doc no longer attempts: G-15-7 was created by a
    /// written premise naming a single mover while source held at least four. **D-G7-01**
    /// (`withdrawingCountedBasisMovement`, `DownloadClient+ExecutionSupport.swift`) instead
    /// withdraws each movement's counted portion at the movement, keyed on the pre/post
    /// `downloadIndex[gid]` delta, in the same synchronous stretch that lowers the basis. So the one
    /// movement this floor still catches is a movement with NO coordinator write behind it — a
    /// genuine regression in a gallery's own finished count, pages disappearing from disk between
    /// two flushes — which the scheduler would read as a task losing ground, and it forcibly expires
    /// the tasks that look most stalled first. Masking a movement the coordinator itself made is the
    /// defect G-15-6 was and G-15-7 kept: the credit for every later page of real work is absorbed
    /// until the summed numerator climbs back over the pre-movement total. It lives here rather than
    /// in the client because the client is domain-agnostic: it cannot know which movements of these
    /// numbers are legal.
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
    /// Interleaving dispositions: the snapshot read and the retirement reconcile are same-actor
    /// calls that do not suspend today; an `await` introduced inside them reopens the window each
    /// following guard closes and needs its own re-validation, and the ownership re-checks after
    /// them stand as defence under that single justification. This push's ONE real suspension is
    /// its tail, where `updateProgress` crosses the client seam's main-actor hop.
    ///
    /// The reconcile deliberately runs before the client-identity guard — a departure during the
    /// start window must still be recorded even when there is no card to paint yet — so whichever
    /// push next reaches the card already accounts for it.
    func pushContinuedSessionProgress(sessionID: UUID) async {
        guard continuedSessionID == sessionID else { return }
        let snapshot = await schedulableSnapshot()
        guard continuedSessionID == sessionID else { return }
        await reconcileRetiredSessionPages(snapshot: snapshot)
        guard continuedSessionID == sessionID else { return }
        // Read the client identity only after the ownership re-check, so the ordering survives an
        // `await` introduced into the reads above: a capture taken ahead of them could present a
        // predecessor's id after a successor took over.
        //
        // SKIPPED: nil means there is no card to paint yet, and this update is DROPPED rather than
        // replayed. Reconciliation debt is recorded in exactly one place — the drain branch of
        // `reconcileContinuedSession` — so every other push landing in the start window returns
        // here recording nothing: the flush push, the run-start announcement (D-G5-01) and the
        // non-drain convergence tail alike. That asymmetry is deliberate. A dropped TERMINAL word
        // is the one loss no later push can repaint, which is why the drain branch defers; a
        // dropped live push is repainted by the next flush or convergence push, each of which
        // recomputes the whole pair from the authoritative snapshot rather than carrying this one
        // forward. Setting the debt flag here instead would discharge a deferred reconcile for
        // every start-window push, running repair work for windows that need none and changing
        // production choreography for no observable defect.
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
