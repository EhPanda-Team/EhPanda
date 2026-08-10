import AppModels
import BackgroundProcessingClient
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

/// Everything one continued-processing session reports about the work it covers: one summed page
/// fraction, plus how many galleries that fraction's denominator is made of.
///
/// The fraction is not summed over the live schedulable set alone. A gallery leaving that set
/// retires the pages it finished into the session's ledger, and `pushContinuedSessionProgress`
/// adds that ledger to both sides of the pushed pair, so the pair keeps describing the whole queue
/// the session covers rather than whatever happens to remain schedulable (D-G2-01, extending
/// D-10).
///
/// **D-G2C-01: the gallery count of every PUSHED value is that denominator's coverage** — the live
/// schedulable galleries plus every departed gallery whose retirement contributed pages to the
/// denominator. Both numbers therefore answer for the same set of galleries. A two-gallery run
/// reads two galleries on every frame, including its last, because both galleries' pages are in the
/// denominator on every frame.
///
/// **This value carries two different roles, and the type cannot tell them apart — read the
/// producer (DEC-B).** `SchedulableSnapshot.sessionProgress` is an intermediate: its `galleryCount`
/// is `schedulableDownloads().count`, the live schedulable count, which is what the
/// summed-from-one-read identity needs and what the coverage sum uses as its live half. Every value
/// handed to a subtitle writer — the pushed pair and `ensureContinuedSession`'s start submission —
/// carries the coverage instead, computed by the single shared `coverageGalleryCount` helper.
///
/// The pushed pair consequently no longer mixes bases. It previously reported a session-cumulative
/// fraction beside a live-only count; that mismatch was accepted when the terminal push was expected
/// to supply the card's last correct word, and the acceptance is obsolete — the device proved the
/// system does not repaint a push issued immediately before completion, so a basis that is only
/// truthful on the final frame is a basis that is never reliably truthful at all.
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
/// The incompleteness observation rides along for the same reason the sums do. D-G4-01's session
/// basis is decided from a gallery's record *and* from what this session has already seen it doing,
/// so the trust that grants the second half has to be accumulated from the same read the basis was
/// computed from. Taken from a second read, the numerator's opening rule and the retirement's
/// departure rule could disagree about the same gallery.
///
/// The queue-intent generation rides along for the same reason again, one level down. An
/// observation is evidence about one queue intent rather than about a gallery identifier (CR-02),
/// so the generation has to be stamped in the very read that decided the gallery was incomplete;
/// read later, a queue intent advancing in between would stamp the observation with a generation
/// that never saw the record it describes.
public struct SchedulableSnapshot: Equatable, Sendable {
    /// What the live schedulable set alone reports, before any retired pages are added to it.
    public let sessionProgress: ContinuedSessionProgress
    /// Session-completed pages per schedulable gallery, keyed by gallery identifier — the D-G4-01
    /// basis the numerator above is summed from, not the raw record counts.
    public let finishedPages: [String: Int]
    /// The galleries in this read whose records still report unfinished pages, each paired with
    /// the queue-intent generation that was current when this read saw it.
    public let incompleteGalleryGenerations: [String: Int]

    public init(
        sessionProgress: ContinuedSessionProgress,
        finishedPages: [String: Int],
        incompleteGalleryGenerations: [String: Int]
    ) {
        self.sessionProgress = sessionProgress
        self.finishedPages = finishedPages
        self.incompleteGalleryGenerations = incompleteGalleryGenerations
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
    /// **D-G4-01, restated over the measured basis: a schedulable gallery's credited count is its
    /// run's own measurement while a run is in flight; its record's count when the record reads
    /// incomplete, or reads complete after this session observed it incomplete; and zero
    /// otherwise.** The per-gallery `pageCount` denominator and this snapshot's own live
    /// `galleryCount` are untouched by the rule; only the numerator's basis is. (What the card is
    /// handed is a different number: pushed counts carry the coverage of D-G2C-01, derived from this
    /// live count plus the ledger. This snapshot is its input, not its contract.) The full
    /// derivation lives on
    /// `sessionCreditedPages` below, which is the single definition every reader of the credited
    /// count shares.
    ///
    /// The zero branch exists because schedulability and progress answer different questions.
    /// `shouldSchedule` returns true for any queued work item before it ever consults
    /// `isIncomplete`, so a gallery whose record is already complete is schedulable the moment it
    /// is queued for an update, a redownload, a repair or a bare re-enqueue — correctly, because
    /// the redo has to run. Counting its manifest's finished pages as session progress then opens
    /// the card at its own ceiling, latches `lastPushedCompletedPageCount` there and lets the
    /// monotonic floor pin it at 100% for the whole session — a reading the scheduler treats as a
    /// stalled task before it force-expires the least-progressing ones. Those pages are the redo's
    /// *target*, not work this session did.
    ///
    /// The zero covers only the window between the qualifying tap and the run's own working-seed
    /// preparation, which announces a measured basis for any run with pages of its own to fetch
    /// (`prepareWorkingSeedAnnouncingProgress`). An update or a redownload additionally deletes
    /// the working folder and prepares a fresh all-empty manifest, and a repair's reconciliation
    /// (**D-G5-01**, `reconcileWorkingManifestAgainstPageFiles`) blanks the hash of every page
    /// whose file is gone, so on those routes the record honestly reads incomplete from the
    /// preparation on as well. The one family the record can never speak for — a reconciliation
    /// that REFUSES its destructive half and hands a lying complete manifest back verbatim
    /// (G-15-23) — is covered by the same announcement, because the announcement never consults
    /// the record at all.
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
            pages[download.gid] = sessionCreditedPages(
                gid: download.gid,
                completedPageCount: download.completedPageCount,
                pageCount: download.pageCount
            )
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
            // Stamped from the same actor-isolated read that computed the sums above, so an
            // observation can never carry a generation that did not see the record it describes
            // (CR-02). `reduce(into:)` for the sibling's reason: a duplicated gallery folder must
            // not trap the card's progress path.
            incompleteGalleryGenerations: downloads
                .filter(\.isIncomplete)
                .reduce(into: [String: Int]()) { generations, download in
                    generations[download.gid] = queueIntentGeneration(for: download.gid)
                }
        )
    }

    /// The pages THIS SESSION may credit one gallery with — the single definition the opening
    /// snapshot, the departure retirement, the run-exit freeze and the D-G7-01 withdrawal all
    /// read.
    ///
    /// One definition rather than several expressions, because no two readers may disagree about
    /// the same gallery: the snapshot decides what a gallery contributes while it is present and
    /// the retirement decides what it leaves behind, so a mismatch makes the summed numerator
    /// step at the departure in whichever direction the mismatch points — the same property the
    /// summed-from-one-map comment in `schedulableSnapshot` claims for the numerator, stated for
    /// the per-gallery value instead.
    ///
    /// **The three regimes, in consultation order.**
    ///
    /// 1. **A gallery whose run is in flight counts its run's own measurement** —
    ///    `RunProgressBasis.creditedPageCount`, inherited work plus landed pages. The record is
    ///    not consulted at all, and that absence is the design: every earlier rule inferred run
    ///    progress from the record and corrected the inference — a trust grant, a subtracted
    ///    debt, a guarded subtraction — and each correction's boundary housed the next defect,
    ///    G-15-34's non-monotonic crossover being the last of the family. The measurement is
    ///    monotone because `outstandingPages` only shrinks, and continuous across the record
    ///    completing because nothing here reads the record.
    /// 2. **With no run in flight, an honest record speaks for itself.** A record that reads
    ///    INCOMPLETE counts raw: pre-session foreground progress, an exited run's flushed pages
    ///    and a cache capture's landings are all covered work, and counting them the instant the
    ///    record shows them is what keeps progress unmaskable. A record that reads COMPLETE
    ///    counts raw only when this session OBSERVED it incomplete UNDER THE CURRENT QUEUE INTENT:
    ///    within one session and one generation a record moves from incomplete to complete only
    ///    through landed pages, so that count is work the session watched happen. The refusal
    ///    family cannot reach this branch — its record never reads incomplete, so it is never
    ///    observed — which closes G-15-30's hazard structurally rather than by a subtraction.
    /// 3. **Anything else counts zero**, which is D-G4-01's queued window: a complete-reading
    ///    gallery schedulable for a redo that has not announced contributes nothing, because
    ///    those pages are the redo's target rather than this session's progress.
    ///
    /// **The generation equality in regime 2 is what makes the observation evidence about a RUN
    /// rather than about a gallery id (CR-02).** A gallery can complete, retire and be re-queued
    /// without the queue-wide session ever ending — a second gallery keeps it alive, and D-06
    /// forbids minting a successor session — so the predecessor's observation would otherwise
    /// still be standing when the successor's complete pre-redo manifest is read. It would take
    /// the raw branch and open the card at the redo's own target, which is precisely the ceiling
    /// regime 3 exists to hold at zero. Every queue-mobilizing entry point advances the generation
    /// before its snapshot is taken, so the mismatch retires the stale observation by construction
    /// rather than by a clear each of those paths would have to remember.
    ///
    /// **The regimes hand off continuously, which is the property G-15-34 was the absence of.**
    /// At the announce, an honest record's raw count equals the inherited set's size — both are
    /// valued by the same scan the reconciliation just used — and a complete-reading refusal
    /// gallery steps to the intersection of its claims with the work it does not owe, never
    /// downward past what the evidence supports; the deliberate downward movers (a record's
    /// positively-absent claims, a complete record's owed claims) are excused from the floor by
    /// the announce's own D-G7-01 bracket. At a run exit, an honest record's raw count equals the
    /// final measurement — every landed page was flushed — and a refusal-family departure retires
    /// the value `freezeSessionCreditForRetiringRun` published while the basis still stood. At a
    /// fresh QUEUE INTENT the generation equality above stops holding and a complete record steps
    /// from its raw count to regime 3's zero — a boundary the other two cannot cover, because no
    /// record moved and no run exited, and the one this enumeration was missing (CR-01). It is a
    /// deliberate downward mover like the rest, excused by the bracket
    /// `advanceQueueIntentGeneration` wraps around its OWN increment rather than by any caller's,
    /// so a queue-mobilizing path added later inherits the exemption instead of having to be
    /// instrumented for it. No regime boundary can therefore drop the credited count unbracketed;
    /// every deliberate mover — including the one that moves no record at all — carries a D-G7-01
    /// bracket, and everything else only climbs.
    func sessionCreditedPages(
        gid: String,
        completedPageCount: Int,
        pageCount: Int
    ) -> Int {
        if let basis = runProgressBases[gid] { return basis.creditedPageCount }
        let recorded = min(max(completedPageCount, 0), max(pageCount, 0))
        guard recorded >= pageCount else { return recorded }
        return observedIncompleteSessionGenerations[gid] == queueIntentGeneration(for: gid)
            ? recorded
            : 0
    }

    /// The same definition read against the CURRENT index record, for callers that hold no
    /// snapshot row: the run-exit freeze, the departure retirement's live-run branch and the
    /// D-G7-01 withdrawal bracket. A gallery with no live basis and no record credits zero, which
    /// is why callers that must distinguish "credits zero" from "has nothing left to read" guard
    /// on `hasSessionCreditReading` first.
    func sessionCreditedPages(gid: String) -> Int {
        let manifest = downloadIndex[gid]?.manifest
        return sessionCreditedPages(
            gid: gid,
            completedPageCount: manifest?.completedPageCount ?? 0,
            pageCount: manifest?.pageCount ?? 0
        )
    }

    /// Whether the credited-pages definition has ANY reading left for `gid` — a live run's
    /// measurement or an index record. The D-G7-01 bracket and the run-exit freeze both need the
    /// distinction between "credits zero" and "has nothing to read": a gallery whose readings are
    /// all gone is a DEPARTURE, valued once by `reconcileRetiredSessionPages`, and treating it as
    /// a zero would withdraw or freeze the same correction that reconcile already makes.
    func hasSessionCreditReading(gid: String) -> Bool {
        runProgressBases[gid] != nil || downloadIndex[gid] != nil
    }

    /// Publishes a retiring run's own final credited count as this session's last observation of
    /// the gallery, immediately before that run's measurement is withdrawn.
    ///
    /// **This is what makes the departure retirement ordering-INSENSITIVE rather than merely
    /// lucky.** A gallery can leave the schedulable set in either order relative to its run's
    /// exit. A completion, a failure and the incomplete-error dequeue all depart from INSIDE the
    /// run, so `processDownload`'s `defer` retires first and the departure is only detected by the
    /// push that the exit's own convergence issues afterwards; a user pause and D-11's expiration
    /// sweep are issued from OUTSIDE the run, so they can depart a gallery whose run is still
    /// holding its measurement, and neither call site controls that ordering.
    /// `reconcileRetiredSessionPages` then reads its live-basis branch in the second ordering and
    /// its last-observation branch in the first. Without this line those two branches read
    /// different quantities — the run's final measurement in one, whatever the last push happened
    /// to record in the other. Freezing the value here, while the basis still stands, makes the
    /// last-observation branch read exactly what the live-basis branch would have computed.
    ///
    /// Only a gallery this session is CURRENTLY observing is written. Inventing an entry for one it
    /// never saw would present a fresh departure to the next reconcile for a gallery that was never
    /// in the fraction, and the unobserved-work convention `reconcileRetiredSessionPages` records is
    /// that such a gallery enters neither the live sum nor the ledger. The reading guard preserves
    /// the same convention on the other side: a gallery whose basis AND record are both already
    /// gone keeps its last pushed observation rather than having it overwritten with a zero the
    /// definition never computed from evidence.
    func freezeSessionCreditForRetiringRun(gid: String) {
        guard observedSchedulablePages[gid] != nil,
              hasSessionCreditReading(gid: gid)
        else { return }
        observedSchedulablePages[gid] = sessionCreditedPages(gid: gid)
    }

    /// **D-G2C-01: the gallery count every subtitle writer pushes is the denominator's coverage —
    /// the galleries in the live schedulable snapshot, plus the galleries whose `retiredSessionPages`
    /// entry is greater than zero.**
    ///
    /// The count answers the same question the denominator does: which galleries' pages is Y made
    /// of? The live set contributes each gallery's whole `pageCount`, and D-G2-01 retirement puts a
    /// departed gallery's finished pages back on both sides of every later push — so both halves are
    /// in Y, and both halves are named. Counting only the live half is what put "1 gallery" beside a
    /// denominator spanning a whole two-gallery session on the device, and it is why the last frame
    /// of a run was the ONLY frame that could ever have said otherwise.
    ///
    /// That last point is the reason this exists rather than a better terminal push. The system-owned
    /// card does not repaint an update issued immediately before `setTaskCompleted`, which the app can
    /// neither win nor observe; under the coverage basis every frame of a run carries the same count,
    /// so the card is truthful whichever frame the OS happens to render last. The race is removed
    /// rather than raced harder.
    ///
    /// **A zero retirement is not counted.** A gallery that departed having finished nothing retires
    /// zero pages, and its unfinished pages left the denominator with it — so no part of it is
    /// represented by Y, and the letter of the rule says it is not represented in the count either.
    /// This is also what keeps a drained card over work nobody touched honestly at zero galleries
    /// rather than naming galleries whose pages the fraction does not carry.
    ///
    /// **It must be read after `reconcileRetiredSessionPages`.** That reconcile drops a rejoining
    /// gallery's ledger entry before the live sum counts it again, so summing the snapshot's count
    /// with the positive entries afterwards is double-count-free by the very construction the
    /// fraction already relies on. Read before it, a rejoining gallery would be counted twice — once
    /// live and once retired — which is exactly the shape the fraction's own dedupe exists to stop.
    ///
    /// **One definition, shared by every writer.** All four production pushes flow through
    /// `pushContinuedSessionProgress`, and `ensureContinuedSession`'s start submission is the one
    /// other subtitle writer; both call this. A second writer computing its own count is the defect
    /// class this closes, so the single definition is the guard rather than a convenience. At the
    /// start submission the ledger was emptied two lines earlier, so this degenerates to the live
    /// count there by construction — the same value that writer pushed before.
    ///
    /// Note the asymmetry with `SchedulableSnapshot.sessionProgress.galleryCount`, which stays the
    /// live schedulable count: that value is the summed-from-one-read live half this sum reads, not
    /// the contract. Only PUSHED counts carry the coverage.
    func coverageGalleryCount(for snapshot: SchedulableSnapshot) -> Int {
        snapshot.sessionProgress.galleryCount + retiredSessionPages.values.count(where: { $0 > 0 })
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
        // Emptied rather than seeded: this map records only what THIS session observes. A run in
        // flight across the session boundary needs no seed here, because the credited-pages
        // definition reads its basis — which no session boundary touches — ahead of this map, so
        // the card's OPENING subtitle, computed from the snapshot on the next line, credits it
        // from the very first push (G-15-26).
        observedIncompleteSessionGenerations = [:]

        let snapshot = await schedulableSnapshot()
        // Through the same shared helper the push uses, so no subtitle writer owns a private count
        // basis (D-G2C-01). `retiredSessionPages` was emptied a few lines above, so the coverage is
        // the live count here and this opening string is byte-identical to what it always was — the
        // point is structural: the two writers cannot drift apart later.
        let openingProgress = ContinuedSessionProgress(
            progress: snapshot.sessionProgress.progress,
            galleryCount: coverageGalleryCount(for: snapshot)
        )
        let clientSession = await backgroundProcessingClient.start(
            String(localized: .continuedSessionTitle),
            continuedSessionSubtitle(for: openingProgress),
            Int64(openingProgress.progress.displayCompletedPageCount),
            Int64(openingProgress.progress.displayPageCount)
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
        // observations while there is still no card to paint; assigning the pre-hop snapshot over
        // it discarded exactly that. On the canonical `retryPages` route the run is scheduled
        // before this trailing ensure, so the run-start announcement (D-G5-01) can land precisely
        // here.
        //
        // The seeding's position still carries the superseded-start rule, and merging cannot weaken
        // it: "a superseded start seeds nothing" is enforced by the ownership guard above, which a
        // superseded start never passes.
        //
        // Both collections were emptied by this session's own synchronous reset, so anything in
        // them by now is this session's own identity-gated observation from inside the hop. A run
        // in flight across the boundary needs neither: its credited count reaches every push
        // through its basis, which no session boundary touches (G-15-26).
        observedSchedulablePages.merge(
            snapshot.finishedPages,
            uniquingKeysWith: { observed, _ in observed }
        )
        // The GREATER generation wins, which is the same "an in-hop observation outranks the
        // pre-hop snapshot" rule the merge above states, expressed over a value that orders. A
        // queue intent advancing inside the client start's main-actor hop is a real user action
        // this session must answer to, and taking the snapshot's older stamp would resurrect the
        // predecessor observation the advance had just invalidated (CR-02).
        observedIncompleteSessionGenerations.merge(
            snapshot.incompleteGalleryGenerations,
            uniquingKeysWith: { observed, snapshotted in max(observed, snapshotted) }
        )
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
    /// particular `runProgressBases` is deliberately not cleared here, and adding it would re-open
    /// the exact defect this teardown caused: the `.unavailable` arm calls this and nothing else,
    /// leaving the queue running foreground-only, so clearing the run's measurement here stripped
    /// an in-flight repair of the credit it had already earned and left it contributing zero for
    /// the rest of its re-download. The run's own exit retires that measurement, at
    /// `processDownload`'s `defer`.
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
        observedIncompleteSessionGenerations = [:]
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
    /// was still downloading and therefore still inside its own schedulable set: a fraction one
    /// landed page short of the truth.
    ///
    /// **This push is defence, not the only truthful frame (D-G2C-01).** It was originally the sole
    /// frame that could report the queue as drained, which made the card's correctness depend on the
    /// system repainting an update issued microseconds before completion — and the device showed it
    /// does not. Since the pushed gallery count became the denominator's coverage, this push reports
    /// the same count as every frame before it, and only the fraction differs; the last word is
    /// merely more precise here, never the difference between a truthful card and a stale one.
    /// Nothing downstream may be built on this push rendering.
    ///
    /// The position is the whole fix, because the same call a few lines later compiles, ships and
    /// does nothing. After `markContinuedSessionEnded` it is rejected twice over: that teardown
    /// clears `continuedSessionID`, which fails the push's own ownership guard, *and* it zeroes
    /// `retiredSessionPages`, so even a push that got through would report a bare live sum. After
    /// the completion the store has released the task, and `updateProgress` returns at its own
    /// identity guard with nothing left to paint.
    ///
    /// The terminal fraction is honest arithmetic rather than a special case. The retirement ledger
    /// already holds every page this session finished, so a drained queue sums to N of N, beside the
    /// count of the galleries those N pages came from — every gallery that retired a positive count,
    /// since the live set is now empty. No new arithmetic is introduced here.
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
    /// The same acceptance for pushes in general — including why the deliveries are not serialized
    /// into their computation order — lives on `pushContinuedSessionProgress`.
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
    /// **What a departure retires is the credited-pages definition's answer, read from the best
    /// evidence still standing (D-G4-01, G-15-30).** A gallery departed while its run is still
    /// live retires the run's own current measurement. One departed with no live run retires what
    /// its record can honestly answer for: a record this session observed incomplete speaks for
    /// the covered work — including pages finished between the last push and the departure — while
    /// a gallery never observed doing honest work retires its last observation instead, which the
    /// same definition made zero while it was present, or which the run-exit freeze published as
    /// the run's final measurement. A redo that never ran — a complete manifest queued for an
    /// update and then cancelled — therefore retires nothing, rather than retiring pages the
    /// session never downloaded into both sides of the fraction and reporting a finished session.
    ///
    /// This is still not a departure-reason branch. The formula takes no reason parameter, no call
    /// site classifies why a gallery left, and completion, pause, delete, cancel and expiration are
    /// treated identically; the branches below read only which evidence survives, never why the
    /// gallery departed.
    ///
    /// Departures are also detected on either side of a run's own exit, and both sides retire the
    /// same number by construction: `freezeSessionCreditForRetiringRun` publishes the run's final
    /// measurement as this session's last observation before the basis is withdrawn, so the
    /// last-observation branch below reads what the live-basis branch would have computed. That
    /// derivation lives on the freeze itself.
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
            // The surviving evidence is authoritative where the last observation is merely
            // recent: reading it is what makes a gallery that completed between two pushes retire
            // the pages it finished in that window rather than the stale value the last push saw.
            let departedRecords = await indexedDownloads(gids: departedGIDs)
                .reduce(into: [String: DownloadedGallery]()) { records, download in
                    records[download.gid] = download
                }
            for gid in departedGIDs {
                if runProgressBases[gid] != nil {
                    // Departed while its run is still live — an outside-run pause or expiration
                    // sweep. The run's own measurement is fresher than the last push's
                    // observation, and it is the very value the run-exit freeze will publish, so
                    // both detection orderings retire the same number.
                    retiredSessionPages[gid] = sessionCreditedPages(gid: gid)
                    continue
                }
                guard observedIncompleteSessionGenerations[gid] == queueIntentGeneration(for: gid) else {
                    // Never watched doing honest work UNDER THE CURRENT QUEUE INTENT: retire what
                    // was observed, which the definition made zero while the gallery was present —
                    // or which the run-exit freeze published as the run's final measurement. The
                    // equality is the credited-pages definition's own, so the departure rule and
                    // the numerator's rule cannot disagree about a re-queued gallery either.
                    retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0
                    continue
                }
                guard let record = departedRecords[gid] else {
                    // Deleted outright: no record survives it, so the last observation is all the
                    // evidence there is of what this session finished for it.
                    retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0
                    continue
                }
                retiredSessionPages[gid] = sessionCreditedPages(
                    gid: gid,
                    completedPageCount: record.completedPageCount,
                    pageCount: record.pageCount
                )
            }
        }
        // Replacing the map is what makes each departure detected exactly once; a retired value is
        // then frozen until that gallery rejoins the schedulable set.
        observedSchedulablePages = finishedPages
        // Accumulated from the same read the basis was computed from, so the numerator's opening
        // rule and the departure rule can never disagree about a gallery. The greater generation
        // wins for the reason the session seed's merge records: a newer observation is a later
        // fact about the same gallery, and an older stamp overwriting it would resurrect an
        // observation a queue intent had already invalidated (CR-02).
        observedIncompleteSessionGenerations.merge(
            snapshot.incompleteGalleryGenerations,
            uniquingKeysWith: { observed, snapshotted in max(observed, snapshotted) }
        )
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
    /// The gallery count pushed beside that fraction is read from the same two places, by
    /// `coverageGalleryCount`: the snapshot's live galleries plus the ledger's positive entries
    /// (**D-G2C-01**). It is deliberately taken after `reconcileRetiredSessionPages` below, so a
    /// rejoining gallery has already left the ledger and is counted once — the same construction the
    /// fraction depends on, reused rather than re-derived. The snapshot's own `galleryCount` is the
    /// live half of that sum and is never pushed on its own.
    ///
    /// The monotonic floor survives as residual defence only. Deliberate downward movers of the
    /// accounting basis exist wherever the coordinator rewrites the index record, and enumerating
    /// them is the recorded four-round failure this doc no longer attempts: G-15-7 was created by a
    /// written premise naming a single mover while source held at least four. **D-G7-01**
    /// (`withdrawingCountedBasisMovement`, `DownloadClient+ExecutionSupport.swift`) instead
    /// withdraws each movement's counted portion at the movement, measured on the credited-pages
    /// definition around it, in the same synchronous stretch that lowers the basis. So the one
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
    /// **Two pushes can be in flight across that hop at once, and the order they LAND in is not the
    /// order they were computed in.** What this actor guarantees is the COMPUTED series: the pair
    /// and the floor latch in one synchronous same-actor stretch, so inside a single
    /// accounting-basis regime a later push can only compute a numerator at or above an earlier
    /// one's. Delivery carries no such guarantee, so the card can hold one displaced observation
    /// until the next push repaints it — the acceptance the drain branch records for its terminal
    /// push, stated here for every push.
    ///
    /// **Serializing issuance — chaining each delivery behind the previous one on this actor — was
    /// considered and REJECTED, for three reasons.**
    ///
    /// 1. It does not buy the property it looks like it buys. The recorded inversion that prompted
    ///    the question is a numerator falling because a D-G7-01 withdrawal landed BETWEEN two
    ///    pushes: a deliberate downward correction of the basis, already in computation order,
    ///    which a chain reproduces exactly. What a chain removes is the displaced observation,
    ///    which the next push already repaints.
    /// 2. Concurrency at this seam is load-bearing rather than incidental, and two cases pin it:
    ///    `testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain` mobilizes work inside the drain's
    ///    parked terminal push, and `testAHeldProgressPushCannotRepaintASuccessorSessionsCard` lets
    ///    a successor take the card while a predecessor's push is parked. Both need a second
    ///    crossing while the first is still parked, and what resolves the late arrival is the
    ///    client's own identity guard, not an ordering queue. A chain would deadlock both — each
    ///    releases the parked push only after a later one lands — which is the staging telling the
    ///    truth about production: a push that lost ownership across its own hop is REJECTED at the
    ///    client, and queueing it behind its predecessor would only delay that rejection.
    /// 3. Liveness points the other way. This push exists because the scheduler force-expires the
    ///    tasks reporting the least progress, so chaining would couple every report to the slowest
    ///    preceding main-actor hop. A transient out-of-order frame is the cheaper failure.
    ///
    /// The suite holds the matching contract rather than a stricter one:
    /// `expectTheCompletedSeriesNeverLosesGround` accepts one displaced observation that the next
    /// push repaints and fails everything else, and a case that stages a withdrawal asserts its
    /// series per regime.
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
            // The denominator's coverage rather than the snapshot's live count (D-G2C-01), read
            // after the reconcile above so a rejoining gallery is counted once.
            galleryCount: coverageGalleryCount(for: snapshot)
        )
        await backgroundProcessingClient.updateProgress(
            clientSessionID,
            Int64(pushed.progress.displayCompletedPageCount),
            Int64(pushed.progress.displayPageCount),
            continuedSessionSubtitle(for: pushed)
        )
    }
}
