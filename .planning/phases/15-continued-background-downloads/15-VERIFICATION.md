---
phase: 15-continued-background-downloads
verified: 2026-08-05T12:30:00Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
amended: 2026-08-05T12:30:00Z
amendment_note: "This file is written in rounds and each part records the HEAD it was derived at; nothing is re-derived retroactively. The body above the FIRST amendment heading was written at HEAD d246b1a3, BEFORE gap-closure plan 15-22 landed. Gaps G-15-3 and G-15-4 were added afterwards from the post-15-22 code review (15-REVIEW.md, commit 7b8513d2) and confirmed against source by the execute-phase orchestrator; both were CLOSED by plans 15-23 and 15-24. Gap G-15-5 was added on top from the post-15-24 re-review (15-REVIEW.md, commit 613270a7), confirmed against source, and was CLOSED by plan 15-25. The SECOND amendment heading is round 9, written at HEAD 6fc528f1 after 15-25 landed: it verifies G-15-5's closure in source and records the new blocker G-15-6, re-derived independently from the post-15-25 review. The THIRD amendment heading is round 10, written at HEAD 829b55d8 after 15-26 landed: it verifies G-15-6's mechanism closed in source, records six new gaps G-15-7..G-15-12 re-derived independently from the post-15-26 review, and downgrades SC1 from verified to failed. The FOURTH amendment heading is round 11, written at HEAD 4e7608be after plans 15-27..15-32 landed: it verifies G-15-7, G-15-8, G-15-10, G-15-11 and G-15-12 closed in source, finds G-15-9 only PARTIALLY closed, restores SC1 to verified, and records six new gaps G-15-13..G-15-18 re-derived independently from the post-round-11 review (15-REVIEW.md, commit 4e7608be), with WR-05 judged and deliberately NOT promoted."
next_action: "Close blocker G-15-13 by giving the blanking consumer a positive PER-FILE signal (the residue of G-15-9, which round 11 closed only for the total-scan case), close blocker G-15-14 with the two zero-page range guards, then close the four warning groups G-15-15..G-15-18. Re-run 15-UAT.md test 2 on a physical iOS 26 device AFTERWARDS. The device item is an independent axis: SC2 is both defeated in code by G-15-13 and still behaviourally unverified on hardware, and closing the gaps does not discharge the device item."
next_command: "/gsd-plan-phase 15 --gaps"
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "G-15-7 — CLOSED by plan 15-29 (commit 46bf72de), re-derived in source at HEAD 4e7608be. The withdrawal is no longer attached to a named mover: `withdrawingCountedBasisMovement(gid:_:)` (`DownloadClient+ExecutionSupport.swift:268-282`) reads `downloadIndex[gid]?.manifest.completedPageCount` BEFORE the movement, evaluates the counted-basis predicate against that index record (`beforeCount < pageCount || observedIncompleteSessionGIDs.contains(gid)`), reads it again after, and subtracts `max(before - after, 0)` when `continuedSessionID != nil`. It brackets the WHOLE of `prepareWorkingSeed` (`:301`), so the folder deletion, the fresh manifest, the blanking and any sibling a later round adds are enclosed by construction rather than enumerated. The enqueue route's `writeInitialManifest` uses the same one implementation (`DownloadClient+PublicAPI.swift:126`). An absent after-record falls back to `beforeCount`, so a deletion withdraws nothing and the retirement ledger's departure rule is not double-counted. Regressions exist and stage COUNTED records: `testARedownloadOfACountedGalleryWithdrawsItsBasisSoTheNextPushAdvances`, `testAnUpdateOfATrustedGalleryWithdrawsItsCountedPortion`, `testAPageCountMismatchFreshManifestWithdrawsTheCountedBasis` (DownloadContinuedSessionBasisTests)."
    - "G-15-8 — CLOSED by plan 15-31 (commits b1973e17, dab4a285), re-derived in source. `moveDownload` (`DownloadClient+Folders.swift:166-233`) now takes its block AFTER the invalid-name guard and releases plus converges (`releaseScheduling` → `notifyObservers` → `scheduleNextIfNeeded`) on all six exits, success included, so the moved gallery can no longer be left queued and unscheduled. The recommended bundle was taken too: `schedulingBlockedGalleryIDs` became the reference count `schedulingBlockedGalleryCounts` with `blockScheduling`/`releaseScheduling` helpers (`DownloadClient+Manager.swift:585-616`), so two overlapping operations on one gid no longer unblock on the first completion. `commitPause`'s exits were swept in the same pass. Regressions: `testAMoveLeavesTheGalleryUnblockedAndTheQueueConverged`, `testAFailedMoveReleasesTheBlockAndConverges`, `testOverlappingBlocksOnTheSameGalleryReleaseIndependently` (DownloadOwnershipConvergenceTests)."
    - "G-15-10 — CLOSED by plan 15-27 (commit dc9ca42e), verified verbatim. The spy's single-session guard and its armed refusal are now separate guards (`DownloadFeatureTestSupportTypes.swift:273-278`): `guard $0.currentSessionID == nil else { return true }` returns WITHOUT consuming the arm, and only the refusal branch resets `refusesNextStart`. A start refused for liveness therefore leaves an armed refusal held for the start it was armed against."
    - "G-15-11 — CLOSED by plan 15-28 (commit 7a37e40b), verified by grep. `public func` returns zero hits for all nine session mutators (`schedulableSnapshot`, `continuedSessionSubtitle`, `ensureContinuedSession`, `handleContinuedSessionEvent`, `markContinuedSessionEnded`, `pauseAllSchedulable`, `reconcileContinuedSession`, `pushContinuedSessionProgress`, `prepareWorkingSeedAnnouncingProgress`); each is module-internal and reached from the suites through the `#if DEBUG` seam. Residue: nine pieces of session STATE are still `public var` and one suite reads `continuedSessionTask` directly, carried as part of G-15-18."
    - "G-15-12 — CLOSED by plan 15-32 (commits 2c71852a, 30e3473f), verified in source. `UncheckedBox` is renamed `LockedBox` throughout the suites; `forceUnwrapped` returns zero hits across `AppPackage/Sources/DownloadClient/`; the privacy invariant now asserts a named per-file map (`expectedHashMaskedCounts`) instead of the underivable `maskedCount >= 8`; `DownloadPendingWorkTests` gained the active-gallery-union case; and no test file is near the 1000-line `file_length` gate any more (largest in the module is `DownloadCoordinatorStorageTests.swift` at 994, `DownloadContinuedSessionLedgerTests.swift` at 812)."
  gaps_remaining: [G-15-9]
  regressions:
    - "G-15-13 — G-15-9 is only PARTIALLY closed by plan 15-30. The positive-signal requirement was implemented for the TOTAL case only (`scanSucceeded` at the directory level, plus an all-or-nothing `blankedPageCount < manifest.completedPageCount` refusal). The per-file conflation the gap named — `sanitizeAssetFileIfNeeded` returning false both when a file is absent and when it is present but unprobeable — is untouched, so a mass PARTIAL probe failure still destroys recorded hashes irreversibly and still withdraws from the floor for a movement that never happened. This is the fifth consecutive round in which a fix scoped to the case its regression stages left the sibling case open."
  verification_scope_note: "Round 11 re-derived every closure claim in source at HEAD 4e7608be rather than reading the SUMMARYs, and independently assessed all 16 findings of the post-round-11 review. Two review findings were judged and NOT promoted: WR-05 (the app still declares `UIBackgroundModes: [processing]`) is an explicitly recorded discuss-phase decision — ROADMAP.md's Phase 15 section states `Info.plist` keeps its background-modes declaration — so it is a settled decision rather than a gap; and WR-08's synchronous-launch wedge is unreachable in production (`ContinuedProcessingSession` is `@MainActor` and the system delivers launches on the main queue, so `submit` cannot reenter it), recorded as ordering hygiene inside G-15-18 rather than as a defect. CR-01's stated triggers were narrowed: descriptor exhaustion does not reach `canReadNonEmptyFile` (`attributesOfItem` needs no descriptor) and a data-protection denial leaves `attributesOfItem` answering, so the reachable trigger is the narrower one where `attributesOfItem` itself throws on many-but-not-all files. The defect is recorded on the same reachability class G-15-9 was accepted on."
gaps:
  - id: G-15-3
    severity: blocker
    closed_by: "15-23 (commit 60b660fb) — recorded closed in re_verification.gaps_closed above"
    source: "15-REVIEW.md CR-01 (post-15-22 review), confirmed in source by the execute-phase orchestrator"
    introduced_by: "15-22"
    truth_violated: "SC1 — a continued-processing session stays alive for as long as the queue has schedulable work."
    summary: "The terminal progress push plan 15-22 added to the drain branch of `reconcileContinuedSession` turned a previously suspension-free tail into a reentrant one, so the session can be torn down over work that arrived after the drain was observed."
    detail: |
      `DownloadCoordinator` is an actor; `ContinuedProcessingSession` is a `@MainActor final class`
      and `BackgroundProcessingClient.updateProgress` hops to it. That hop is the real suspension
      point. Before 15-22 the drain branch observed `hasPendingWork() == false` and then tore the
      session down synchronously via `markContinuedSessionEnded`, so the observation could not go
      stale. The new `await pushContinuedSessionProgress(...)` sits between those two points and
      suspends across the main-actor hop.

      The re-check added behind the push is `continuedSessionID == sessionID`, which provably
      cannot fail in that window: minting a successor requires `ensureContinuedSession` to pass
      `!hasLiveContinuedSession`, and that flag stays `true` until the very next line. So the
      mitigation guards a property that cannot change and leaves unguarded the one that can —
      drain-ness. An `enqueue`/`resume`/`retry` landing during the hop adds pending work, its own
      `ensureContinuedSession()` is inert for the same reason, and the drain then resumes into
      teardown. Phase 15 removed the discretionary BGTask tier, so there is no fallback.

      The doc comment the commit added is also factually wrong about which call suspends — it names
      "an index read plus the ledger's record read", both of which are same-actor and do not
      suspend. The wrong premise is why the wrong invariant was guarded.
    why_tests_missed_it: "`BackgroundProcessingClientSpy.updateProgress` never suspends unless a case arms a gate, and no drain case arms one. Every drain assertion 15-22 added is green against a tail that is atomic in the double and reentrant in production."
    suggested_fix: "Re-check drain-ness rather than session identity behind the push (`guard await hasPendingWork() == false else { return }`), correct the doc comment to name the `updateProgress` main-actor hop as the suspension point, and arm a spy suspension gate on a drain case so the race is actually expressible in the suite."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
  - id: G-15-4
    severity: blocker
    closed_by: "15-24 (commit 0c0f3995) — recorded closed in re_verification.gaps_closed above"
    source: "15-REVIEW.md CR-02 (post-15-22 review), confirmed in source by the execute-phase orchestrator"
    introduced_by: "pre-existing — predates 15-22"
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress."
    summary: "A complete gallery queued for update/redownload opens the continued-processing card at 100% and the monotonic floor pins it there for the rest of the session."
    detail: |
      `shouldSchedule` returns `true` on `download.isQueuedWorkItem` before it ever checks
      `isIncomplete`, so a gallery that is already complete but queued for `.update` is schedulable
      and is counted in the session snapshot as N finished of N total. `ensureContinuedSession`
      submits `start(..., N, N)`, `lastPushedCompletedPageCount` latches at N, and the `max()` floor
      keeps the numerator there. When the rewritten manifest has the same page count the card reads
      N / N and never advances — the same pinned-at-1.0 card the G-15-2 ledger was built to fix,
      reached by a different route. The scheduler force-expires the tasks reporting least progress,
      and D-11 makes an expiration pause every schedulable download.
    suggested_fix: "Order the completeness check ahead of the `isQueuedWorkItem` short-circuit, or exclude already-complete update/redownload items from the session snapshot's finished-page basis, so the session does not open at its own ceiling."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
  - id: G-15-5
    severity: blocker
    closed_by: "15-25 (commits 06763885, 7b0fa678) — re-derived in source and verified closed in the round-9 amendment below"
    source: "15-REVIEW.md CR-01 (post-15-24 re-review), confirmed in source by the execute-phase orchestrator"
    introduced_by: "15-24 — the G-15-4 fix"
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress; and SC1 through the stall-expiration consequence D-11 amplifies."
    summary: "A `.repair` of a gallery whose record already reads complete never earns session trust, so it reports 0 pages for its entire run and finishes the card at a pinned zero."
    detail: |
      D-G4-01 grants session trust only from `Set(downloads.filter(\.isIncomplete).map(\.gid))`
      (`DownloadClient+ContinuedSession.swift:123`), and `isIncomplete` is
      `completedPageCount < pageCount`, where `completedPageCount` counts the manifest's
      non-empty page hashes (`DownloadedGallery+Manifest.swift:67-69`). A repair never lowers
      that count:

      - `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
        (`DownloadClient+ExecutionSupport.swift:281-282`), so the working folder survives, unlike
        `.redownload`/`.update`, which return `false` and have the folder deleted.
      - `ensureWorkingManifest` then finds a valid manifest and returns it verbatim
        (`DownloadClient+ExecutionSupport.swift:251-257`); no fresh all-empty-hash manifest is
        written.
      - Nothing blanks hashes for pages whose files vanished, and the repair's own flushes write
        non-empty hashes.

      So the gid can never enter `observedIncompleteSessionGIDs`, `isSessionWork` stays `false`,
      its session count is `0` for the whole run, and its untrusted departure retires `0` — a
      terminal card of `0 / N pages · 0 galleries` reported with `finish(_, true)`.

      This is a first-class production path, not a corner: the scheduler's own mode selection at
      `DownloadClient+SchedulingHelpers.swift:52-57` reaches
      `if case .missingFiles = storage.validate(...) { return .repair }` only AFTER the
      `download.isIncomplete` branch above it fails — that is, exactly when the record reads
      complete and the files are missing. It is also reachable from product UI via
      `DownloadsView+Subviews.swift:76` → `DownloadInspectorReducer:169` → `retryPages` →
      `DownloadClient+RetryHelpers.swift:66` (`mode: .repair`), and from
      `DetailView.swift:264` when `downloadNeedsRepair` is true.

      Per D-11 the scheduler force-expires the tasks reporting the LEAST progress and an
      expiration pauses every schedulable download, so this trades G-15-4's pinned-100% card for
      a pinned-0% one, which is strictly worse for SC1 liveness.
    why_tests_missed_it: "The one ledger case that exercises trust manufactures incompleteness by hand via `patchManifest(of:completedPageCount:in:)` — precisely the step a repair never performs — so the suite is green against a basis the repair path can never satisfy."
    suggested_fix: "Grant session trust from an observation the repair path can actually produce rather than from the record's manifest hash count alone — e.g. admit a gid to `observedIncompleteSessionGIDs` when its resolved start mode is a redo (`.repair` included) that this session scheduled, or have the repair's own file-validation result mark the record incomplete before the snapshot reads it. Any fix must keep D-G4-01's original guarantee that a queued update/redownload cannot open at its own ceiling, and must not make a queued redo unschedulable (the rejected option 1 of G-15-4)."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
  - id: G-15-6
    severity: blocker
    closed_by: "15-26 (round 9 fix) — mechanism verified closed in source at HEAD 829b55d8 in the round-10 amendment below. Its STATED INVARIANT is not satisfied; that residue is carried as G-15-7."
    source: "15-REVIEW.md CR-01 (post-15-25 review), confirmed in source by the execute-phase orchestrator and independently re-derived in source by this verification"
    introduced_by: "15-25 — the G-15-5 fix"
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress; and SC1 through the stall-expiration consequence D-11 amplifies."
    summary: "The session's monotonic floor is a single scalar over the whole-queue SUMMED numerator, and D-G5-01's reconciliation is the first mechanism in this phase that can LOWER an already-counted gallery's page count mid-session. The floor then absorbs the credit for every page of real work that follows the correction, freezing the card for as long as it takes the queue to climb back over the pre-correction total."
    detail: |
      `pushContinuedSessionProgress` applies

          let completedPageCount = max(
              lastPushedCompletedPageCount,
              sessionProgress.displayCompletedPageCount
          )

      (`DownloadClient+ContinuedSession.swift:563-567`) and re-latches the scalar at line 567.
      `sessionProgress` is the queue-wide sum (live sum + retired ledger, `:557-562`), so the
      floor is one number over every gallery at once.

      Its correctness argument is written on the same function at `:524-529`: "With the accounting
      basis no longer shrinking, the one movement it still catches is a genuine regression in a
      gallery's own finished count — pages disappearing from disk between two flushes."
      **D-G5-01 invalidates that premise.** `reconcileWorkingManifestAgainstPageFiles`
      (`DownloadClient+ExecutionSupport.swift:321-340`) makes exactly that movement a legitimate,
      coordinator-caused basis correction: it blanks the hash of every page whose file is absent,
      writes the manifest and calls `updateDownloadIndex`, so the record the snapshot reads drops.
      The floor cannot tell a correction it caused from a regression it was built to mask.

      Every link of the chain was re-derived in source:

      - `resumeMode` returns `.repair` for a record that is `.inactive` and already `isIncomplete`
        (`DownloadClient+SchedulingHelpers.swift:44-52`). Such a record is counted RAW by
        D-G4-01's first half (`schedulableSnapshot`, `+ContinuedSession.swift:127-129`), so its
        pages are in the numerator and in the floor from session start
        (`lastPushedCompletedPageCount` is seeded from that same snapshot at `:226`).
      - `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
        (`+ExecutionSupport.swift:379-380`), and `ensureWorkingManifest` returns the valid manifest
        verbatim (`:345-355`), so the reused manifest reaches the reconciliation.
      - The reconciliation blanks K hashes; `prepareWorkingSeedAnnouncingProgress` (`:273-287`)
        then pushes the lowered basis, and the floor clamps it straight back up.

      **Correction to the reviewer's dynamics, re-derived rather than inherited.** The review's
      narrative has a second gallery's progress masked concurrently. The queue is SERIAL —
      `scheduleNextIfNeededCore` returns early on `guard activeTask == nil`
      (`+Scheduling.swift:44`) — so nothing else downloads during the repair, and in the
      pure-serial case where the repair restores all K blanked pages the card is frozen for the
      same span it was frozen for before 15-25 (the record used to sit at its pre-blanking value
      throughout the run). That case is a wash, not a regression. The reachable REGRESSION is the
      case where the blanked pages are not all re-earned by the gallery that lost them:

      - the repair is paused, expires, fails or is deleted part-way, so it departs and the ledger
        retires it at its HONEST lowered count (`reconcileRetiredSessionPages` values a departure
        from the record) while the floor still holds the pre-blanking total. Every page the next
        gallery downloads is then invisible until the queue climbs back over the floor;
      - or a second gallery is reconciled in the same session, depressing the honest sum further
        below a floor that never comes down.

      Before 15-25 no counted gallery's basis could shrink, so the floor never bit on a movement
      the coordinator itself made. This is therefore a strict regression into the same
      D-11 stall-expiration family as G-15-5: a card whose numerator does not advance while work
      proceeds is the maximally stalled reading the scheduler force-expires first, and this
      phase's expiration policy turns that into a pause of every schedulable download.

      Reachability does not depend on the Files app. `materializeRepairSeed`
      (`DownloadStore+Operations.swift:38-75`) copies the manifest whole but only the pages whose
      source files exist and pass sanitization, so the repair-seed materialization route can leave
      an already-incomplete record with claims the reconciliation must blank, entirely in-app.
    why_tests_missed_it: "No ledger case stages a session in which a gallery's counted basis is lowered. The 14 cases in DownloadContinuedSessionLedgerTests were enumerated; Test E (`testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`, `:605`) stages the opposite — a complete-reading, therefore UNTRUSTED record whose floor contribution is zero — so the floor never engages, and it is single-gallery, where the effect is a no-op by construction. The full FeatureTests plan is green at this HEAD; that is not evidence against this gap."
    suggested_fix: "Excuse a coordinator-caused correction from the floor rather than weakening the floor. Have the reconciliation report how many pages it blanked, and withdraw from `lastPushedCompletedPageCount` exactly the portion the basis was actually counting (record incomplete at snapshot time, or gid already in `observedIncompleteSessionGIDs`) before the announcement pushes — an untrusted complete-reading record contributed nothing and must withdraw nothing, or D-G4-01's ceiling guarantee reopens. Whatever shape is chosen, restore the invariant the push's own doc comment asserts (the floor may only mask movements the coordinator did not deliberately make) and correct that comment. The regression case must be built so it can actually fail: staging two galleries and blanking K pages of one is vacuous in a serial queue unless the reconciled gallery then departs without re-earning them (pause/fail/delete part-way) or a second reconciliation depresses the sum — assert that the surviving gallery's next K pushes still advance."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
  - id: G-15-7
    closed_by: "15-29 (commit 46bf72de) — verified closed in source in the round-11 amendment below"
    severity: blocker
    source: "15-REVIEW.md CR-01 + WR-05 (post-15-26 review, commit 829b55d8), every link independently re-derived in source by this verification; the reachability staging is this verification's own finding and CORRECTS the review"
    introduced_by: "15-26 — the G-15-6 fix, by scoping. The freeze itself is older; 15-26 declared it closed on a premise that is false."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress; and SC1 through the stall-expiration consequence D-11 amplifies (a frozen numerator is the maximally stalled reading the scheduler force-expires first, and `handleContinuedSessionEvent`'s `.expired` arm pauses EVERY schedulable download)."
    summary: "D-G6-01's withdrawal is attached to the blanking LOOP, not to the basis MOVEMENT, and its stated invariant — that the accounting basis has exactly one deliberate downward mover — is false. At least four deliberate movers exist, three of them inside the very function the withdrawal lives in. A `.redownload` or `.update` of a counted gallery drops its basis from C to 0 and withdraws nothing, so the floor keeps holding C and the card freezes for C pages of real work."
    detail: |
      **The un-withdrawn movers, all re-derived at HEAD 829b55d8.**

      1. `setupWorkingFolder` (`+ExecutionSupport.swift:453-483`) deletes the working folder when
         `shouldReuseWorkingFolder` is false, and `repairSeed` (`:553-572`) guards `payload.mode ==
         .repair`, so on `.redownload` / `.update` no seed is materialized — a bare directory is
         created.
      2. `ensureWorkingManifest` (`:407-422`) then writes a fresh all-empty manifest and calls
         `updateDownloadIndex(folderURL:manifest:)` at `:420`. That writes
         `downloadIndex[manifest.gid]` (`+Persistence.swift:250-256`) — the exact record
         `schedulableSnapshot` sums the numerator from, via `schedulableDownloads()` →
         `indexedDownloads(gids:)`. The record is now 0 of N.
      3. `reconcileWorkingManifestAgainstPageFiles` (`:376-402`) is reached with that all-empty
         manifest. Its loop guard is `pages[page]?.isEmpty == false` (`:384`), which never fires,
         so `blankedPageCount == 0` and control returns at `guard blankedPageCount > 0 else {
         return manifest }` (`:388`) — BEFORE the counted-basis test and the withdrawal at
         `:396-400`. Nothing is withdrawn.
      4. A fourth mover lives outside this file: `writeInitialManifest`
         (`+PublicAPI.swift:112-128`) writes a fresh all-empty manifest and re-indexes whenever
         `reusableExistingManifest` returns nil — the enqueue route's version of the same movement.

      **The route is a first-class UI action, and it is the action that starts the session.**

      - `DetailView.swift:264` sends `.retryDownloadButtonTapped(store.downloadNeedsRepair ?
        .repair : .redownload)`. `downloadNeedsRepair` (`DetailReducer.swift:93-97`) requires
        `badge.progress.completedPageCount == 0`, so an errored gallery with ANY downloaded pages
        takes the `.redownload` arm. Verified verbatim in both files.
      - `retry(gid:mode:)` (`+RetryHelpers.swift:9-26`) runs `performRetry` (enqueue →
        `notifyObservers` → `scheduleNextIfNeeded`, which SPAWNS the run task) and then
        `await ensureContinuedSession()` at `:18`.
      - The session snapshot counts the gallery RAW, because an errored record with C of N pages
        (0 < C < N) satisfies `download.isIncomplete`, the first disjunct of `isSessionWork`
        (`+ContinuedSession.swift:127-129`). The card opens at C / N and
        `lastPushedCompletedPageCount` is seeded to C (`:236-239`).
      - The spawned run reaches the wipe only after `fetchLatestPayload`
        (`+ExecutionFetch.swift:15-21`, a network `GalleryDetailRequest`), then `performDownload`
        → `prepareWorkingSeedAnnouncingProgress` → movers 1-3 above.
      - `prepareWorkingSeedAnnouncingProgress` (`:280-294`) then pushes, because the fresh manifest
        is incomplete: honest sum 0, `max(C, 0) = C`. Every one of the next C page flushes pushes
        the same C. The numerator does not move while C real pages download.

      **Reachability staging — this verification's own finding, correcting the review and settling
      the orchestrator's open question.** The harmful ordering is NOT confined to a multi-gallery
      queue. In a SINGLE-gallery arc the floor seed provably precedes the wipe:
      `ensureContinuedSession`'s snapshot is taken from same-actor and queue-store reads issued
      immediately after the run task is spawned, while the run cannot reach `prepareWorkingSeed`
      without first completing a network `GalleryDetailRequest`. For the wipe to precede the seed a
      full gallery-detail round trip would have to complete inside those few reads — and even if it
      did, the snapshot would then read 0 and seed the floor at 0, which is the harmless direction.
      So the single-gallery `.redownload` of an errored gallery is by itself a reachable freeze, and
      the multi-gallery case (a queue-wide session already live for gallery A while `.redownload` is
      tapped on counted gallery B) is a second, strictly worse one, in which A's real progress is
      masked by B's un-withdrawn drop. The hop-window interleaving is equally covered: the additive
      seed evaluates to `max(C + 0, 0) = C` because the reconciliation returned before its
      withdrawal, so the freeze is identical.

      **Two further instances of the same root cause.** `validatedManifest`
      (`+PersistenceNormalize.swift:6-20`) returns nil when the stored manifest's page count differs
      from the payload's, or when the manifest is unreadable — driving `ensureWorkingManifest` down
      the same fresh-manifest branch on `.initial` and `.repair`, so a gallery that gained pages
      upstream or whose manifest was truncated by a crash drops its whole counted basis with no
      withdrawal. And an `.update` of a gallery already in `observedIncompleteSessionGIDs` (trusted,
      therefore counted raw) is wiped by `shouldReuseWorkingFolder`'s `.update` arm and withdraws
      nothing.

      **WR-05 is the same defect measured from the other side and is folded in here.** The
      withdrawal's amount (`blankedPageCount`) and its counted-basis test (`manifest.completedPageCount
      < manifest.pageCount`) are read from the WORKING manifest, while the numerator is summed from
      the INDEX record. Those coincide only when the working folder is the record's folder; they
      diverge on the re-slot-after-title-change path the codebase explicitly supports
      (`+Execution.swift:78-88`), leaving the floor holding the difference.

      `15-26-SUMMARY.md`'s own sweep, Table 2 row 5, records `.redownload / .update / fresh
      .initial` as "Blanks? no / Withdraws? no — HOLDS". That disposition is correct only for a
      basis that was already zero. It is wrong for every counted record — exactly the population
      D-G4-01's raw-counting half exists to serve.
    reachability: "CONFIRMED reachable, single-gallery AND multi-gallery. See the staging paragraph above; the ordering argument was derived from the actor semantics of `retry` → `scheduleNextIfNeededCore` (task spawn) → `ensureContinuedSession` (snapshot) versus `processDownload` → `fetchNormalizeAndDownload` → `fetchLatestPayload` (network) → `performDownload` → `prepareWorkingSeed`."
    why_tests_missed_it: "No case stages a COUNTED record through a wiping mode. The `.redownload` staging that exists — `testAMidQueueUpdateCancelDoesNotInflateTheSurvivors` (`DownloadContinuedSessionLedgerTests.swift:486-504`) — uses `SessionGallery(gid: \"210290\", pageCount: 6, completedPageCount: 6)`, a COMPLETE-reading and therefore untrusted record whose floor contribution is zero, so the wipe moves a basis that was already zero and the floor never engages. `testARedoObservedRunningEarnsItsRecordBackAtTheDrain` (`:541`) stages the same 6/6 shape. That is the vacuous staging this gap's regression must not repeat."
    suggested_fix: |
      Do NOT patch the two named movers. This is the fourth consecutive round in which a fix scoped
      to a named mechanism left its siblings open, and enumerating movers is precisely what failed
      here: 15-26 enumerated one, source has four. Pair the withdrawal with the BASIS MOVEMENT so
      the invariant holds by construction for movers nobody has enumerated yet.

      Concretely: in `prepareWorkingSeed` (which is non-`async`, so the whole stretch stays atomic
      and no interleaved push can observe a lowered basis under an un-lowered floor), read the INDEX
      record — the value the numerator is actually summed from — before any mover runs, evaluate the
      counted-basis predicate against it (`isIncomplete` or gid in `observedIncompleteSessionGIDs`),
      read it again after the preparation, and withdraw `max(before - after, 0)` when
      `continuedSessionID != nil`. Remove the withdrawal from
      `reconcileWorkingManifestAgainstPageFiles`. This subsumes WR-05 (the working manifest and the
      index record no longer have to agree) and keeps the unclamped-subtraction / additive-seed
      contract intact.

      Sweep scope, to be stated in the plan as an invariant rather than a list: every writer of
      `downloadIndex[gid]` that a live session can observe. The enumerated writers at this HEAD are
      `updateDownloadIndex` (`+ExecutionSupport.swift:393`, `:420`; `+ExecutionPerform.swift:179`;
      `+Persistence.swift:247`; `+PublicAPI.swift:123`, `:128`, `:316`), the direct assignments
      (`+Persistence.swift:150`, `:153`; `+Folders.swift:144`, `:223`; `+PublicAPI.swift:229`), and
      the fresh-manifest branch of `writeInitialManifest`. Deletions are already handled by the
      retirement ledger's departure rule and must NOT also withdraw; say so in the plan.

      Correct both paragraphs asserting a single downward mover
      (`+ExecutionSupport.swift:338-351`, `+ContinuedSession.swift:537-548`) — a wrong written
      premise is what produced G-15-3 and this gap, and it must not survive the fix.

      The regression must stage a COUNTED gallery: an errored record with `completedPageCount > 0`
      (and `< pageCount`) retried with `.redownload`, with the pre-fix frozen band observed, and it
      must assert that the first push after the wipe ADVANCES rather than repeating the pre-wipe
      numerator. Staging an already-complete or untrusted record is vacuous here, exactly as
      blanking in a serial two-gallery queue was vacuous for G-15-6. Add the `.update`-of-a-trusted
      -gallery variant and the `validatedManifest`-mismatch variant in the same suite.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
  - id: G-15-8
    closed_by: "15-31 (commits b1973e17, dab4a285) — verified closed in source in the round-11 amendment below"
    severity: blocker
    source: "15-REVIEW.md WR-02 (post-15-26 review), independently confirmed in source by this verification, with an additional consequence the review did not name"
    introduced_by: "pre-existing in shape; phase-15 consequence — the session did not exist before this phase"
    truth_violated: "SC1 — a download started in the foreground continues to completion after the app is backgrounded."
    summary: "`moveDownload` holds a scheduling block across three suspensions and returns on all six exits without converging, so the live session can be completed over work that is merely hidden, and the moved gallery is left queued but unscheduled."
    detail: |
      `moveDownload` (`+Folders.swift:152-206`) inserts `gid` into `schedulingBlockedGalleryIDs`
      with a function-scoped `defer`, then suspends at `fetchDownload` (`:167`) and
      `reloadDownloadRecord` (`:200`, `:203`), and every one of its six exits returns without
      calling `scheduleNextIfNeeded()`. Its siblings converge explicitly and carry the
      "ACTIVE-OWNERSHIP CONVERGENCE" comment this phase introduced: `deleteFolder`
      (`+Folders.swift:117-149`) releases each contained gid and converges on both error exits,
      `delete` (`+PublicAPI.swift:196-231`) does the same. `moveDownload` is the one member of that
      family the phase's five convergence rounds never swept.

      While the block is held, `isSchedulableDownload` (`+Scheduling.swift:118-123`) excludes the
      gid, so `schedulableDownloads()` — the single authority the card, the pending-work gate and
      the scheduler all read — cannot see it. If the moved gallery is the only schedulable work and
      a convergence lands in that window, `reconcileContinuedSession` (`+ContinuedSession.swift:410-436`)
      reads `hasPendingWork() == false`, pushes a terminal pair, calls `markContinuedSessionEnded`
      and `finish(_, true)`. The window is real and is produced by the ordinary completion path:
      `finishActiveTaskIfOwned` (`+Execution.swift:244-271`) nulls `activeTask` / `activeGalleryID`
      synchronously and then spawns a `Task` that awaits `notifyObservers()` before
      `scheduleNextIfNeeded()`, whose tail is that reconcile.

      **Consequence the review did not name.** Because `moveDownload` also never schedules on its
      success path, the moved gallery is not merely hidden during the window — after the block is
      released by the `defer` it stays queued and idle until some unrelated mutation converges. So
      the same defect can both end the session AND stall the queue. D-03/SC3 provide no fallback
      tier: nothing restarts a session without a fresh qualifying tap.
    suggested_fix: |
      Release the block and converge on every exit, exactly as `delete` and `deleteFolder` do:

          schedulingBlockedGalleryIDs.remove(gid)
          await notifyObservers()
          await scheduleNextIfNeeded()

      State the invariant once — "no exit may leave a gid blocked or the queue unconverged" — and
      sweep the whole `schedulingBlockedGalleryIDs` insert set against it rather than patching this
      one function, since scoping to the named site is this phase's recorded recurring failure.

      RECOMMENDED TO BUNDLE (review WR-03, confirmed in source but not promoted to its own gap
      because it predates this phase and defeats no success criterion): the set is an uncounted
      `Set` released by `defer` at four sites (`+PublicAPI.swift:183-186`, `+Folders.swift:100-106`,
      `:163-166`, `+Scheduling.swift:194-197`), every one of which suspends while holding it on a
      reentrant actor, so two overlapping operations on the same gid release the block when the
      FIRST finishes. Making it a reference count (`[String: Int]` with block/release helpers and
      `isSchedulableDownload` testing `== nil`) removes the class rather than the instance, and this
      gap's fix touches the same call sites.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift"
  - id: G-15-9
    closed_by: "15-30 (commit 0cf7d1b1) — PARTIALLY closed: the total-scan case only. The mass-partial residue is carried forward as G-15-13"
    severity: blocker
    source: "15-REVIEW.md WR-01 (post-15-26 review), every link independently confirmed in source by this verification"
    introduced_by: "15-25 — D-G5-01 made a previously harmless empty answer destructive"
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress (a false correction moves the pushed numerator for a movement that never happened), and the project's root-cause rule that an error must never be swallowed into a destructive action."
    summary: "`reconcileWorkingManifestAgainstPageFiles` treats a best-effort file probe's empty answer as authoritative evidence that page files are gone, and acts on it irreversibly — blanking recorded content hashes, persisting the manifest, re-indexing the record, and now also withdrawing from the session floor. A single transient, unlogged directory-enumeration failure can blank EVERY claimed page of a gallery."
    detail: |
      The probe swallows failure at three levels, all verified in source:

      - `existingAssetFileURLs` (`DownloadStore.swift:374-391`) returns `[]` on any
        `contentsOfDirectory` failure, with an explicit comment that the error is deliberately not
        logged.
      - `existingPageRelativePaths` (`:159-181`) drops any page whose file fails
        `sanitizeAssetFileIfNeeded` (`:176`).
      - `sanitizeAssetFileIfNeeded` (`:561-584`) falls back to `canReadNonEmptyFile` when
        `attributesOfItem` throws, and `canReadNonEmptyFile` (`:608-616`) returns `false` on ANY
        `FileHandle(forReadingFrom:)` or `read` failure — descriptor exhaustion, a transient
        `EBUSY`, a data-protection denial while the device is locked (which is precisely the state
        a backgrounded continued-processing session runs in).

      `prepareWorkingSeed` computes `existingPages` once (`+ExecutionSupport.swift:235-238`) and
      hands that single dictionary to the reconciliation, so one failed enumeration means EVERY
      claimed page is blanked in one pass: the manifest is rewritten, `updateDownloadIndex`
      publishes a 0-of-N record, and — with a session live and the record counted — the floor is
      withdrawn by the full count for a correction that was never real. Nothing logs any of it.

      Before D-G5-01 the same empty answer was harmless: it only caused a re-fetch. It now mutates
      durable state. A page whose file is present and intact but momentarily unreadable loses its
      recorded content hash, so `validateImageData` cannot content-verify it again until a full run
      re-hashes it, and both `resumeMode` and `loadManifest`'s `.missingFiles` gate change answers.
      This runs on every mode that reuses a manifest it did not write, including the ordinary
      `.initial` resume that is this phase's main flow.
    suggested_fix: "Make the destructive half require a positive signal. Have `existingAssetFileURLs` surface enumeration failure (throw, or return an optional) instead of `[]`, and have `reconcileWorkingManifestAgainstPageFiles` refuse to blank when the scan failed, or when it would blank EVERY claimed page of a folder whose manifest read succeeded. Log the blanking at `.notice` with the blanked count and the hash-masked gid — the existing privacy invariant already fixes the spelling — so a device archive can show whether a blanking was real. Add a case in which the probe fails wholesale and assert that no hash is blanked, no index write happens and no withdrawal is taken."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
  - id: G-15-10
    closed_by: "15-27 (commit dc9ca42e) — verified closed in source in the round-11 amendment below"
    severity: blocker
    source: "15-REVIEW.md WR-07 (post-15-26 review), confirmed verbatim in source by this verification"
    introduced_by: "15-08 / 15-23 — the spy's refusal control and its suspension gates"
    truth_violated: "No success criterion directly. Promoted to blocker under this project's recorded failure mode: test-double infidelity is how three consecutive blockers in this phase (G-15-3, G-15-4, G-15-5) survived their suites, and the owner's standing mandate for this phase is contract-faithful doubles."
    summary: "`BackgroundProcessingClientSpy.start` consumes the one-shot `refuseNextStart()` arm on refusals it did not cause, so a case that arms a refusal and then races a second start observes the refusal against the wrong call and silently loses the arm it believes it still holds."
    detail: |
      `DownloadFeatureTestSupportTypes.swift:264-268` reads:

          guard $0.currentSessionID == nil, !$0.refusesNextStart else {
              $0.refusesNextStart = false
              return true
          }

      The guard fires for TWO reasons — the spy's single-session guard (`currentSessionID != nil`)
      and the armed refusal — and resets the arm on both. Every regression that stages a refusal
      alongside an overlapping start is therefore asserting against an arm whose consumption it
      cannot account for. This is the same class of defect as the non-suspending `updateProgress`
      that let G-15-3 ship green, one layer up.
    suggested_fix: |
      Reset only on the branch that consumed it:

          guard $0.currentSessionID == nil else { return true }
          guard !$0.refusesNextStart else {
              $0.refusesNextStart = false
              return true
          }
          return false

      Then audit every case that calls `refuseNextStart()` for an assertion that silently depended
      on the old behaviour, and add a case that arms a refusal, races a second start and asserts the
      arm is still held.
    files:
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift"
  - id: G-15-11
    closed_by: "15-28 (commit 7a37e40b) — mutators closed; the public session STATE residue is carried as part of G-15-18"
    severity: warning
    source: "15-REVIEW.md WR-04 (post-15-26 review), the zero-external-caller claim independently verified by grep over App/, ShareExtension/ and every AppPackage/Sources module other than DownloadClient"
    introduced_by: "15-05 / 15-06 / 15-25 — the session lifecycle surface as it was built"
    truth_violated: "SC4's intent — the continued-processing capability is reached through one testable seam. Nine coordinator-side session mutators being `public` means any module linking DownloadClient can detach or cancel the live session without going through that seam."
    summary: "Nine session-lifecycle mutators are `public` with zero production callers outside the DownloadClient module; they are public solely for the cross-module test target."
    detail: |
      `schedulableSnapshot`, `continuedSessionSubtitle`, `ensureContinuedSession`,
      `handleContinuedSessionEvent`, `markContinuedSessionEnded`, `pauseAllSchedulable`,
      `reconcileContinuedSession`, `pushContinuedSessionProgress`
      (`+ContinuedSession.swift:121, 153, 192, 290, 324, 350, 410, 565`) and
      `prepareWorkingSeedAnnouncingProgress` (`+ExecutionSupport.swift:280`) are all `public`. A
      grep for each of the nine over `App/`, `ShareExtension/` and every `AppPackage/Sources/*`
      module other than `DownloadClient` returns zero callers. Any linking module can therefore call
      `markContinuedSessionEnded(sessionID:)` or `pauseAllSchedulable(expiring:)` and detach or
      cancel the live session. The module already carries the correct pattern in
      `DownloadClient+Testing.swift` (`#if DEBUG` plus a `testing…` prefix), and plan 15-26 already
      accepted this finding class once by making `prepareWorkingSeed` private.
    suggested_fix: "Drop these to package/internal access and expose whatever the suites genuinely need through the existing `#if DEBUG` seam in `DownloadClient+Testing.swift`. Sequence this with G-15-7, whose regression drives the preparation directly and therefore needs whichever seam is chosen."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift"
  - id: G-15-12
    closed_by: "15-32 (commits 2c71852a, 30e3473f) — verified closed in source in the round-11 amendment below"
    severity: warning
    source: "15-REVIEW.md WR-06, IN-01, IN-02, IN-03, IN-04, IN-05 (post-15-26 review); each confirmed in source by this verification, with the reachability of WR-06 CORRECTED downward"
    introduced_by: "mixed — IN-01..IN-03 carried forward from the post-15-24 review and deliberately left open there"
    truth_violated: "None directly. Grouped and recorded because this project's bar treats nitpicks as blocking, and because two of these items are the exact failure shape that produced G-15-3 and G-15-7: a written premise that is wrong."
    summary: "Six confirmed hygiene items: a dead force-unwrap, two wrong or missing written rationales, an invariant scanner blind spot, an unexplained threshold, a misnamed test box with a one-line-from-failing file."
    detail: |
      - **WR-06** — `resolveSource` passes `payload.gallery.galleryURL.forceUnwrapped`
        (`+ExecutionSupport.swift:177`) into a non-optional `URL` parameter, while
        `resolvedImageSource` in the same file (`:504`) handles the same optional with
        `?? payload.host.url`. CORRECTION to the review: the reviewer's stated harm (a crash the
        user sees as the card vanishing) does NOT hold at this HEAD — the only producer of a payload
        that reaches `resolveSource` is `fetchLatestPayload`, which guards
        `guard let galleryURL else { throw AppError.notFound }` (`+ExecutionFetch.swift:13-14`) and
        assigns that non-optional value into `Gallery.galleryURL`. The item stands as a dead
        force-unwrap and two treatments of one optional a few hundred lines apart, not as a
        reachable crash.
      - **IN-04** — `schedulableDownloads()`'s doc (`+PendingWork.swift:35-43`) justifies its dedupe
        by claiming a gid reaching `indexedDownloads(gids:)` twice would double that gallery's pages
        in the denominator. It could not: `indexedDownloads(gids:)` (`+Persistence.swift:51-57`)
        filters `downloadIndex.values`, which holds exactly one record per gid, and
        `downloads(from:)` deduplicates again. The check is harmless; its stated reason is wrong,
        and a wrong written reason is what justified the bad edit in G-15-3 and G-15-7.
      - **IN-01** — `resumeMode`'s `storage.validate` branch (`+SchedulingHelpers.swift:47-52`) is
        near-dead after D-G5-01 and carries no note saying why it is still needed.
      - **IN-02** — `+ResponseValidation.swift:270` interpolates a request URL with no privacy
        classification; behaviour is correct (the unified log defaults dynamic strings to private)
        but the invariant scanner (`DownloadLogPrivacyInvariantTests.swift:30-50`) only greps for
        `, privacy: .public`, so an unclassified interpolation is invisible to it.
      - **IN-03** — `maskedCount >= 8` (`DownloadLogPrivacyInvariantTests.swift:81`) pins nothing
        derivable and drifts silently as logs are added.
      - **IN-05** — `UncheckedBox` (`DownloadFeatureTestSupportTypes.swift:8-19`) is `Mutex`-backed
        and genuinely checked; the name invites the `@unchecked Sendable` pattern this project bans
        at error severity. `DownloadPendingWorkTests` has one case and none for the `activeGalleryID`
        union plan 15-26 added to the authority it names. And
        `DownloadContinuedSessionTests.swift` is 999 lines against a `file_length` ERROR gate of
        1000 (`.swiftlint.yml:36-38`) — verified by `wc -l`; one added line breaks the build.
    suggested_fix: "WR-06: use the sibling's fallback or `guard let galleryURL else { throw AppError.notFound }`. IN-04: correct the sentence to say the check is redundant defence, or drop the check. IN-01: record on the branch why it is still reachable. IN-02: write the classification explicitly and consider a scanner rule that flags unclassified interpolations. IN-03: assert against a named list of masked log messages, or state which eight sites the number corresponds to. IN-05: rename to `LockedBox`, add a `hasPendingWork` / `schedulableDownloads` case for the active-but-unqueued union to `DownloadPendingWorkTests`, and move a case out of `DownloadContinuedSessionTests.swift` to restore headroom."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
  - id: G-15-13
    severity: blocker
    source: "15-REVIEW.md CR-01 (post-round-11 review, commit 4e7608be), every link independently re-derived in source by this verification; the reachability is NARROWED below and corrects the review"
    introduced_by: "15-30 — the G-15-9 fix, by scoping. The destructive conflation is older (15-25's D-G5-01 made it destructive); 15-30 guarded one half of it and left the other."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress (a false correction lowers the record the numerator is summed from and withdraws the same amount from the monotonic floor, for a movement that never happened), and SC3's no-lost-or-duplicated-work clause (every blanked page is re-downloaded)."
    summary: "The G-15-9 positive-signal guard covers only a TOTAL blanking. One surviving page file disables it entirely, and the per-file probe still conflates `file absent` with `file present but unprobeable`, so a mass partial probe failure destroys up to N-1 recorded content hashes irreversibly and withdraws the same count from the session floor."
    detail: |
      Both halves verified verbatim at HEAD 4e7608be.

      **The guard.** `reconcileWorkingManifestAgainstPageFiles`
      (`DownloadClient+ExecutionSupport.swift:460-497`) blanks the hash of every page whose number is
      absent from `existingPages`, then refuses only when

          guard blankedPageCount < manifest.completedPageCount else { return manifest }

      `DownloadManifest.completedPageCount` counts pages with a non-empty hash and only such pages are
      blanked by the loop above, so this fires EXACTLY when every claimed page would go. A gallery with
      100 claimed pages and 99 failed per-file probes yields `99 < 100`: the guard passes, 99 hashes are
      destroyed, `storage.writeManifest` and `updateDownloadIndex` republish the record at 1-of-100, and
      the enclosing D-G7-01 bracket (`:268-282`) withdraws 99 from `lastPushedCompletedPageCount`.

      **The root cause, one level down.** `pageFileScan` (`DownloadStore.swift:188-213`) drops a page
      when `sanitizeAssetFileIfNeeded(at:)` returns false, and that function returns false BOTH when the
      file is genuinely gone or zero-byte AND when `attributesOfItem` throws and the
      `canReadNonEmptyFile` fallback (`:648-656`) cannot open it. The resulting `[Int: String]` therefore
      carries the same absent-vs-unprobeable conflation `scanSucceeded` fixed at the directory level, and
      the destructive consumer reads `existingPages[page] == nil` as proof of absence. Raising the
      threshold is not a fix: a genuine partial repair (three of ten files deleted through the Files app)
      must still blank exactly those three, so the caller needs a positive per-file signal, not a bigger
      margin.

      **Reachability, narrowed from the review.** The review names descriptor exhaustion and a locked
      device; neither reaches the failing branch. `attributesOfItem` is metadata-only, so it needs no
      descriptor (EMFILE never gets there) and it answers for a data-protected file whose CONTENT is
      unreadable, in which case a non-zero size returns true and nothing is blanked. The reachable
      trigger is the narrower one where `attributesOfItem` ITSELF throws for many-but-not-all files —
      an I/O error, a permission change, a volume going away mid-scan. That is the same reachability
      class on which G-15-9 was accepted as a blocker one round ago, and the consequence is identical
      and irreversible, so it is recorded at the same severity.
    why_tests_missed_it: "`testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` (`DownloadContinuedSessionBasisTests.swift`) is the only probe-failure case and it stages the TOTAL failure the guard does cover. No case stages a scan that succeeds at the directory level and fails for most-but-not-all files, which is the population the guard's own written rationale claims to protect."
    suggested_fix: |
      Give the destructive consumer a positive per-file signal instead of widening the margin. Surface
      probe failure alongside the pages — e.g. extend `PageFileScan` (`DownloadStore.swift:63-70`) with
      `unprobedPages: Set<Int>` holding pages whose file WAS listed but whose probe failed — and refuse
      to blank any page in that set, since a non-answer is never authority to destroy a hash. Keep the
      existing all-or-nothing guard as a second line of defence, and correct the doc paragraph at
      `DownloadClient+ExecutionSupport.swift:450-459`, which currently claims the refusal recognises
      "per-file probe failure en masse" — the exact case it does not cover. A wrong written premise is
      what produced G-15-3 and G-15-7 and it must not survive this fix.

      The regression must stage the PARTIAL case: a manifest with N claimed pages, a directory listing
      that succeeds, and per-file probes failing for N-1 of them. Assert that no hash is blanked, no
      manifest write and no `updateDownloadIndex` happen, and no withdrawal is taken from the floor.
      Add the genuine-partial companion (a scan that succeeds and legitimately finds K files missing)
      so the fix cannot be satisfied by disabling partial blanking altogether.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
  - id: G-15-14
    severity: blocker
    source: "15-REVIEW.md CR-02 (post-round-11 review), both sites and the absence of any guard between enqueue and the run independently confirmed in source by this verification"
    introduced_by: "pre-existing — both lines predate this phase (`ad9f7402`, `490ea668`). Recorded here because the phase deleted the fallback tier, so a process trap now loses a background session with nothing to resume it, and because the review scanned these files as phase scope."
    truth_violated: "SC1 — a download started in the foreground continues to completion after the app is backgrounded (a trap kills the process mid-run), and SC3's no-lost-work clause."
    summary: "Two sites build `1...payload.galleryDetail.pageCount` from a value the same module guards as possibly zero in two other places. `1...0` is an invalid `ClosedRange` and traps at runtime, so a gallery whose freshly fetched detail parses with no page count kills the app instead of failing the download."
    detail: |
      The two unguarded sites, verified verbatim:

      - `pendingPageIndices` — `return (1...payload.galleryDetail.pageCount).filter { ... }`
        (`DownloadClient+ExecutionSupport.swift:673`).
      - `initializePageDownloadState` — `let pageIndices = Array(1...context.payload.galleryDetail.pageCount)`
        (`DownloadClient+PageDownload.swift:80-82`).

      That zero is a reachable input is established by the module itself: `makeInitialManifest`
      (`DownloadClient+ExecutionSupport.swift:12-15`) branches on `pageCount > 0` before building its
      page dictionary, and `reusableExistingManifest` (`DownloadClient+PublicAPI.swift:155-157`) guards
      the same value. Neither of those guards protects the two sites above, and no guard sits between
      the queue and the run: `enqueue` (`DownloadClient+PublicAPI.swift:62-92`) validates the folder
      name and nothing about the page count, and `performDownload` runs against a FRESHLY fetched
      payload from `fetchLatestPayload` → `normalizeFetchedPayload`, so the count that reaches the range
      is a new parse, not the one the user saw. An expunged gallery, a partially rendered detail page or
      an upstream HTML change therefore traps the process.

      `prepareWorkingSeed` does not stop it: `makeInitialManifest` produces an empty page dictionary and
      `pageFileScan` returns early on `pageNumbers.isEmpty`, so control reaches the range intact.
    suggested_fix: "Return early for the empty case at both sites, matching the sibling guards (`guard payload.galleryDetail.pageCount > 0 else { return [] }` and `guard pageCount > 0 else { return }`). Consider additionally rejecting a zero-page payload at `enqueue` so the queue never holds a gallery the run cannot finish, and decide deliberately whether a zero-page refetch should settle the download as failed rather than silently no-op. Cover both sites with cases that pass a zero page count and assert no trap and an empty result."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
  - id: G-15-15
    severity: warning
    source: "15-REVIEW.md WR-01, WR-02, WR-04 (post-round-11 review); all three confirmed in source by this verification, WR-04 by enumerating the writers"
    introduced_by: "mixed — WR-04's list was written by 15-29, WR-01's and WR-02's premises accumulated over the session rounds"
    truth_violated: "None directly at this HEAD. Recorded because a written premise that source contradicts is this phase's single recurring failure shape: it produced G-15-3 (a doc naming the wrong suspension point, which is why the wrong invariant was guarded) and G-15-7 (a doc asserting one downward mover where source had four)."
    summary: "Three load-bearing doc comments assert things source does not support: a recovery that exists on only one of four branches, two functions in one file asserting opposite things about whether the same call chain suspends, and an exhaustive-sounding floor-writer list that omits a writer."
    detail: |
      - **WR-01** — `pushContinuedSessionProgress`'s nil-client skip
        (`DownloadClient+ContinuedSession.swift:576-577`) says "The deferred reconcile after start
        re-reads schedulable work and pushes fresh counts, so this update is recovered." The deferred
        reconcile runs only when `continuedSessionNeedsReconciliation` is true, and a grep over the
        module shows that flag is SET in exactly one place — the drain branch at `:417`. Every other
        push that lands inside the client start's main-actor hop (the flush push, the run-start
        announcement, the non-drain tail at `:437`) returns at this guard recording no debt. Benign
        today because a drain always emits a terminal push; the defect is that the comment cannot be
        used to reason about the window.
      - **WR-02** — `reconcileContinuedSession` (`:399-403`) states the re-check "must not suspend"
        and that `hasPendingWork()` → `schedulableDownloads()` "do not suspend today", while
        `pushContinuedSessionProgress` (`:563-564`) states "the snapshot read and the retirement
        reconcile can both suspend". The snapshot read is `schedulableSnapshot()` →
        `schedulableDownloads()` → `indexedDownloads(gids:)`, the SAME chain, and it was traced in
        source for this verification: `queueStore.gids` reads a `@Shared` value on a `struct`
        (`DownloadQueueStore.swift:15-17`) and `indexedDownloads` filters `downloadIndex` on the
        coordinator actor (`DownloadClient+Persistence.swift:36-57`), so nothing in it suspends. The
        first premise is the true one and the second is wrong. D-G3-01's whole argument rests on the
        first. A third instance sits on `ensureContinuedSession` (`:192-195`), whose doc claims the
        liveness flag is set "before the first point another caller could interleave" while the guard
        line above it contains an `await`.
      - **WR-04** — `lastPushedCompletedPageCount`'s doc (`DownloadClient+Manager.swift:431-442`)
        opens "Four writers, and no others" and enumerates the reset, the additive seed, the re-latch
        and the D-G7-01 withdrawal. Source has FIVE: `+ContinuedSession.swift:197`, `:236`, `:589`,
        `+ExecutionSupport.swift:279`, and `markContinuedSessionEnded`'s `lastPushedCompletedPageCount = 0`
        at `+ContinuedSession.swift:331`, which the list omits. The closing sentence ("cleared when a
        session starts and when one ends") describes the missing writer and therefore contradicts the
        count in the same paragraph.
    suggested_fix: "WR-01: state what is true (only the drain branch records reconciliation debt, so this update is NOT replayed and the next flush or convergence repaints), or set the flag here and make the existing sentence accurate for every caller — decide which, do not leave both. WR-02: pick one wording and apply it at all three sites, e.g. 'these are same-actor calls that do not suspend today; an `await` introduced inside them reopens this window and needs its own re-validation', keeping the defensive re-checks under that single justification. WR-04: either count the teardown or drop the count and state the rule; an exhaustive-sounding list that is not exhaustive is what this phase has already lost four rounds to."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
  - id: G-15-16
    severity: warning
    source: "15-REVIEW.md WR-03 and IN-05 (post-round-11 review); the unreachability of both catch arms confirmed by reading every callee, the unused parameters and the duplicated mutations confirmed verbatim"
    introduced_by: "15-31 — the G-15-8 convergence sweep counted two exits that cannot happen; the helpers' shape predates it"
    truth_violated: "None directly. The G-15-8 closure's exit inventory is overstated by two, and the invariant that guards it cannot fail in the suite."
    summary: "`commitPause`'s two `catch` arms are unreachable dead code while a comment asserts they are 'that path's single release', both pause helpers declare `throws` and take a `download` parameter neither body reads, `writeSettledPauseRecord` re-runs `writeInitialPauseRecord`'s three mutations verbatim with no stated reason, and a scheduling-block imbalance is only ever a log line."
    detail: |
      `writeInitialPauseRecord` (`DownloadClient+Scheduling.swift:275-291`) and
      `writeSettledPauseRecord` (`:293-300`) are declared `async throws`, but their bodies call only
      `clearDownloadSessionState`, `queueStore.remove(_:)`, `backgroundTaskStore.removeAll(for:)` and
      `notifyObservers()` — every one non-throwing. No other call inside `commitPause`'s `do` block
      throws either, so both `catch` arms at `:245-263` are unreachable, and the comment at `:246-247`
      describing them as a real release path is wrong. The compiler is silent only because the callees
      are DECLARED `throws`. Neither helper reads its `download: DownloadedGallery` parameter, and
      `writeSettledPauseRecord` repeats the same three mutations `writeInitialPauseRecord` already
      performed with nothing explaining what the awaited cancelled task can have undone.

      IN-05 compounds it: `releaseScheduling` (`DownloadClient+Manager.swift:601-616`) documents an
      unmatched release as "a contract violation rather than a tolerated no-op" and then tolerates it
      with `logger.error` and a return. With two counted release sites unreachable, an imbalance
      introduced by a future edit would surface only in a device log and never in the suite that
      guards G-15-8.
    suggested_fix: "Drop `throws` and the unused parameter from both helpers, delete the two dead catch arms (or keep one explicitly marked defensive) and correct the comment that counts them. Either delete `writeSettledPauseRecord` or document which mutation it re-establishes. Report the release imbalance where tests can see it — `reportIssue(...)` alongside the existing `logger.error`, production behavior unchanged — so the convergence invariant is assertable."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift"
  - id: G-15-17
    severity: warning
    source: "15-REVIEW.md WR-06 and WR-07 (post-round-11 review); the spy's hard-coded success and the single-assertion regression confirmed verbatim"
    introduced_by: "15-03 / 15-06 (the store's suites) and 15-26 (the WR-01 regression)"
    truth_violated: "SC3's refusal half is unexercised by any automated case, and SC2's cancel half is claimed by a doc comment its case never drives. Promoted under this project's standing mandate for contract-faithful doubles, which is how G-15-3, G-15-4 and G-15-5 all shipped green."
    summary: "`ContinuedTaskSchedulingSpy` hard-codes registration success and a non-throwing submit, so none of the three `.unavailable` producers in `ContinuedProcessingSession.start` and neither arm of `handleLaunch`'s nil-task path is ever executed; and the WR-01 regression asserts one subtitle while its own doc claims a `pauseAllSchedulable` consequence it never calls."
    detail: |
      `ContinuedTaskSchedulingSpy.scheduling` (`ContinuedProcessingSessionTests.swift:74-94`) returns
      `true` from `register` unconditionally and never throws from `submit`, with a comment claiming
      "the refusal path is the store's early-unavailable branch". Consequently the missing-bundle-id
      arm (`ContinuedProcessingSession.swift:116-120`), the refused-registration arm (`:134-138`) and
      the throwing-submission arm (`:143-147`) never run, and no case calls `spy.launch(identifier, with: nil)`,
      so `handleLaunch`'s nil-task arm and its `pendingIdentifier == identifier` identity gate
      (`:195-205`) never execute either — while `BackgroundProcessingClient`'s own doc asserts "the
      client tests exercise that behavior for every endpoint". This is more than coverage: the
      coordinator treats any non-nil handle as success and learns of unavailability only through a
      stream event, so the `.unavailable` yield plus self-finish is the sole mechanism that releases
      `hasLiveContinuedSession` on a refused submission. The coordinator SIDE of that contract is
      covered (`DownloadContinuedSessionExpirationTests` drives a client double that yields
      `.unavailable`); the production translation from a real scheduler refusal into that event is not.

      WR-07: `testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt`
      (`DownloadContinuedSessionBasisTests.swift:266-314`) documents two consequences of the pre-fix
      scoping bug — a frozen retirement value and `pauseAllSchedulable(expiring:)` skipping the one
      gallery consuming resources, the SC2 cancel half — and asserts only
      `spy.startSubtitles.last`. Neither named consequence is exercised.
    suggested_fix: "Give the scheduling spy controllable outcomes (`refusesNextRegistration`, `nextSubmissionError`) and add one case per `.unavailable` producer asserting the session yields exactly `[.unavailable]`, finishes its stream, cancels nothing and leaves the store willing to grant the next start; add a stale `spy.launch(identifier, with: nil)` case proving a stale nil launch cannot end a live session. For WR-07, drive `testingPauseAllSchedulable(expiring:)` under the same lag staging and assert the running gallery is among the paused set, so the doc's SC2 claim is the assertion rather than prose."
    files:
      - "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
      - "AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift"
  - id: G-15-18
    severity: warning
    source: "15-REVIEW.md WR-08, WR-09, IN-01, IN-02, IN-03, IN-04 (post-round-11 review); each confirmed in source by this verification, with WR-08's reachability CORRECTED downward and WR-09's mechanism corrected upward"
    introduced_by: "mixed — the session store's ordering predates round 11; IN-02 is the residue G-15-11's closure deliberately left"
    truth_violated: "None directly. Grouped because this project's bar treats nitpicks as blocking and because two of these are safety arguments stated in terms the code cannot observe."
    summary: "Six confirmed hygiene items: a request identity established after the request is handed over, a background session start defended by unobservable scheduler behavior, a nil-vs-empty distinction discarded one call later, nine pieces of session state still public, an expiration fired against a deleted fixture, and a raw `Error` logged public in the one file exempt from the privacy invariant."
    detail: |
      - **WR-08** — `ContinuedProcessingSession.start` sets `pendingIdentifier` and `isAwaitingTask`
        AFTER `scheduling.submit` (`ContinuedProcessingSession.swift:140-151`), so a launch delivered
        during `submit` would be turned away by `adopt`'s identity gate and then waited for forever.
        CORRECTION to the review: this is unreachable in production — the type is `@MainActor`, the
        system delivers launches on the main queue, and `submit` therefore cannot reenter it. It stands
        as ordering hygiene on a seam whose whole purpose is to be driven by injected doubles, and the
        `endSession` paragraph claiming the early-unavailable paths "all run before `pendingIdentifier`
        is set" would need updating with the fix.
      - **WR-09** — the `.superseded` arm of `pause(gid:expiration:)`
        (`DownloadClient+Scheduling.swift:169-186`) calls `ensureContinuedSession()`, and that arm is
        reached from `pauseAllSchedulable(expiring:)`, which runs inside the session-event consuming
        task while the app is backgrounded. CORRECTION upward: the review says the call "almost always
        no-ops on the liveness guard", but the `.expired` handler calls `markContinuedSessionEnded`
        BEFORE `pauseAllSchedulable` (`DownloadClient+ContinuedSession.swift:299-302`), so the liveness
        guard is already false and does not stop it. What actually bounds the damage is
        `ownsExpirationPause` (`+Scheduling.swift:266-273`): reaching `.superseded` requires the gid's
        queue-intent generation to have advanced, which only a queue-mobilizing user action does, and
        every such action already ensures its own session. The safety argument in the comment is
        nonetheless stated in terms of unobservable scheduler behavior ("the scheduler's own foreground
        validation makes a late ensure inert"), which is not a property the coordinator can check.
      - **IN-01** — `existingAssetFileURL(folderURL:prefix:)` (`DownloadStore.swift:400-407`) collapses
        the new optional with `?? []`, so `localCoverURL`, `existingCoverRelativePath` and
        `existingPageFileURL` again cannot tell a failed listing from an empty folder. Correct today
        only because none of those consumers acts irreversibly — the exact property that stopped
        holding and produced G-15-9.
      - **IN-02** — nine pieces of continued-session state (`hasLiveContinuedSession`,
        `continuedSessionID`, `continuedClientSessionID`, `continuedSessionNeedsReconciliation`,
        `continuedSessionTask`, `lastPushedCompletedPageCount`, `retiredSessionPages`,
        `observedSchedulablePages`, `observedIncompleteSessionGIDs`) are still `public var`
        (`DownloadClient+Manager.swift:407-495`) after 15-28 moved the mutators internal, and
        `DownloadContinuedSessionExpirationTests` reads `continuedSessionTask` directly rather than
        through the DEBUG seam, bypassing the boundary that closure drew. Actor isolation prevents
        external writes, so this is exposure rather than a mutation hazard.
      - **IN-03** — `DownloadOwnershipConvergenceTests.swift:31,51` registers `defer { clientSpy.expire() }`
        before the fixture removal, so LIFO runs the expiration against a deleted directory, unawaited,
        after the case returned, and nothing asserts the result.
      - **IN-04** — `logger.error("\(error, privacy: .public)")` (`ContinuedProcessingSession.swift:144`)
        writes a scheduler error verbatim into the public log field, in the one file the module's
        privacy invariant excludes by directory. Accurate today by a point-in-time audit with no
        mechanism behind it.
    suggested_fix: "WR-08: establish `pendingIdentifier`/`isAwaitingTask` before `submit` and update the `endSession` paragraph. WR-09: drop the `ensureContinuedSession()` call from the `.superseded` arm (the superseding user action owns its own ensure) or restate the safety argument in terms of `ownsExpirationPause`'s generation check, which the coordinator can observe. IN-01: thread the optional through, or state the invariant its consumers must keep. IN-02: make the session-scoped storage internal and add a `testingContinuedSessionTask()` forwarder. IN-03: drop the `expire()` defer or move it above the removal and await the session task. IN-04: log the error's type rather than its value, or extend the invariant scan to `BackgroundProcessingClient` with a line-level exemption."
    files:
      - "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift"
deferred: []
behavior_unverified_items:
  - truth: "SC2 — the system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving state consistent with an in-app cancel."
    test: "On a physical iOS 26 device, queue at least three galleries of clearly different sizes, start in the foreground, background the app, and watch the system card across the FIRST gallery's completion and then across a manual pause of one remaining gallery. Then cancel from the card, foreground, and compare queue state against pausing each gallery by hand. Since plan 15-25 this item also carries the repair route: stage a gallery that resolves `.repair` (a record with page files missing) inside a multi-gallery queue and watch whether the card climbs across its run. Since round 10 it also carries the redownload route: stage an ERRORED gallery with some pages already downloaded and tap retry (which resolves `.redownload`), and watch whether the card advances from its first push or sits at the pre-wipe numerator."
    expected: "The card's completed count keeps climbing past the first gallery's completion instead of pinning at 100%; the total does not shrink; the subtitle keeps naming the remaining galleries; the remaining galleries keep downloading; a pause leaves the card still able to reach completion; card-cancel leaves the same state as the in-app per-gallery pause; a repair's card climbs rather than pinning; and a redownload's card climbs rather than freezing at the pre-wipe count."
    why_human: "This is the exact behavior the device UAT found broken (15-UAT.md test 2, result `issue`). The fixes are changes to pushed arithmetic, proven deterministically by DownloadContinuedSessionLedgerTests and DownloadContinuedSessionBasisTests, but the card is rendered by system UI outside the app and neither it nor the scheduler's stall-detection response exists in the simulator. The UAT record has not been re-run since any of the fixes landed. NOTE: this item is a SEPARATE axis from gap G-15-13 (round 11; it supersedes G-15-7, which is closed), which independently defeats the same criterion in code — a green device run would not close G-15-13, and closing G-15-13 would not close this item."
human_verification:
  - test: "Re-run 15-UAT.md test 2 on a physical iOS 26 device with a multi-gallery queue, watching the card across the first gallery's completion and across a mid-queue pause, then cancelling from the card. Include a `.repair` gallery and an errored gallery retried as `.redownload` in the queue."
    expected: "Counts advance past the first completion, the total holds, the subtitle names the remaining galleries, the queue keeps downloading, a repair's and a redownload's card climb rather than pinning or freezing, and card-cancel matches the in-app per-gallery pause baseline."
    why_human: "The reported defect was device-observed; the card and the scheduler's stall handling do not exist in the simulator, and the UAT record still reads `result: issue`. Run this only after G-15-13 and G-15-14 are closed, or the run will observe a known-defective blanking path."
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just
started keeps running when the app is backgrounded, surfaced by the system-provided progress UI,
instead of being cut short by the short grace period that bounded the previous behavior.

**Verified:** 2026-08-04T17:10:00Z
**Status:** `human_needed`
**Re-verification:** Yes — after gap-closure plans 15-20 and 15-21, and after the device UAT that
produced gap G-15-2.

**Canonical next action:** Re-run UAT test 2 on a physical iOS 26 device.
**Canonical next command:** `/gsd:verify-work 15`

Every claim below was re-derived from current source before any SUMMARY was read. Build and full
suite results were supplied by the orchestrator at this HEAD (`d246b1a3`, working tree clean):
`BUILD SUCCEEDED`, and `** TEST SUCCEEDED **` for 656 tests across 11 targets. Per the one-run
rule no test was re-run in isolation; that single run is the execution evidence for every named
case below.

## Goal Achievement

### Observable Truths

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue large enough to outlast the old grace period | ✓ VERIFIED | Device UAT test 1 recorded `result: pass` on physical iOS 26 hardware: pages kept landing well past the deleted `beginBackgroundTask` window, none lost or duplicated. The code path is complete and unblocked — `ensureContinuedSession()` fires from `enqueue` (`+PublicAPI.swift:98`), the `.inactive` resume branch (`+PublicAPI.swift:174`), `retry` and `retryPages` (`+RetryHelpers.swift:18, 70`) and the superseded-pause tail (`+Scheduling.swift:184`); the plist permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`. Two coverage asymmetries are recorded as warnings below; neither falsifies the criterion |
| SC2 | System UI shows real progress and card cancel matches an in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The half that device UAT tested and accepted (one neutral card, monotonic counts, card-cancel parity) passed. The half it rejected — multi-gallery progress across a gallery completion — is now fixed in code by the retirement ledger and pinned by a non-vacuous regression suite, but has **never been re-observed on a device**. `15-UAT.md` test 2 still reads `result: issue` |
| SC3 | Best-effort refusal/queue/expiration: no fallback tier, no loss, no duplication, no visible error | ✓ VERIFIED | Device UAT test 3 recorded `result: pass` — refusal, expiration and force-quit relaunch produced no crash, no visible error, no lost or duplicated pages, and work resumed on foreground. The deletion half is independently proven: no source in `App/`, `AppPackage/` or `ShareExtension/` names `BGProcessingTask`, `beginBackgroundTask`, `BackgroundTaskClient` or `runQueueUntilIdle` (grep, excluding the invariant test that pins them), and `BackgroundExecutionInvariantTests` enforces it permanently |
| SC4 | A testable session seam in `BackgroundProcessingClient` exposing start/update/complete with a self-finishing event stream, unimplemented default, no direct scheduler access | ✓ VERIFIED | `BackgroundProcessingClient.swift` declares exactly three `@DependencyClient` endpoints returning/consuming an identified `BackgroundProcessingSession`; `import BackgroundTasks` occurs in exactly one file in the whole tree (`ContinuedTaskScheduling.swift`); `testUnimplementedClientReportsAnIssueForEveryEndpoint` covers the macro-generated unimplemented value |

**Score:** 3/4 roadmap truths verified (1 present, behavior-unverified)

The next milestone phase is Phase 16 (Dynamic Type Accessibility), which covers none of this work.
Nothing is deferred.

## Gap G-15-2 — Re-verified in Source — ✓ CLOSED

The device report was: with multiple galleries queued, one finishing early made the card report
completion and collapse its description to "1 gallery", leaving the rest apparently stalled.

Root cause confirmed in the pre-fix shape: progress was summed over the *currently schedulable*
set alone, so a finished gallery's pages left the numerator and the denominator together, the
`max()` floor held the numerator at its pre-shrink value, and the total clamp lifted the
denominator to meet that floor — pinning the fraction at exactly 1.0.

The fix is a session-scoped retirement ledger, traced end to end:

- `DownloadClient+Manager.swift:421-435` declares `retiredSessionPages` (per-gallery, not a
  scalar — a scalar could not be corrected on rejoin) and `observedSchedulablePages`, both cleared
  on session start (`+ContinuedSession.swift:132-134`) and on teardown (`:237-238`).
- `schedulableSnapshot()` (`:62-79`) yields the summed progress and the per-gallery finished counts
  from **one** index read, so the ledger cannot disagree with the sums it corrects.
- `reconcileRetiredSessionPages(finishedPages:)` (`:323-350`) applies D-G2-01: rejoiners are
  released first (`retiredSessionPages[gid] = nil`), departures are then valued from the
  authoritative record (`min(max(completed, 0), pageCount)`), falling back to the last observation
  only when the record is gone (deleted outright), and the observed map is replaced so each
  departure is detected exactly once.
- `pushContinuedSessionProgress` (`:385-420`) adds the retired total to the **raw** pair before the
  single display clamp, which is what stops `displayPageCount`'s one-page floor from contributing a
  phantom page and making a drained queue unable to report exactly 1.0.

Independent arithmetic check against the reported scenario: gallery A (10 pages, 6 done) plus
gallery B (4 pages, 0 done) opens at 6/14. A completes and `settleCompletedDownload` removes it
from the queue store; the next push retires A at 10 and reports 10/14 · 1 gallery — the count
advances, the total holds, and the fraction stays strictly below one. That is `testACompleted
GalleryHoldsTheTotalAndAdvancesTheCount`'s exact assertion.

**The sweep is at the membership level, not on the reported branch.** This is the one place the
phase's recurring failure mode (a fix scoped to the branch a report named) was explicitly avoided,
and the code says so at `:312-315`: membership is swept at the single point that already reads the
schedulable set, so completion, pause, delete, queued-work-item cancel, the expiration pause-all and
a scheduling block all retire through one formula with no call site classifying *why* a gallery left.
I verified there is no departure-reason parameter anywhere in the production path.

**The defect is no longer encoded in the suite.** All three committed expectations that asserted the
shrinking basis were re-derived rather than supplemented (`git show --stat 425b5a8b`:
`DownloadContinuedSessionTests.swift` 90 lines changed, insertions *and* deletions):
`"6 / 14 pages · 2 galleries"` → `"10 / 14 pages · 1 gallery"` (the regression case),
`"2 / 6 pages"` → `"6 / 6 pages · 0 galleries"` (the honest drain), and
`"4 / 8 pages · 2 galleries"` → `"4 / 8 pages · 1 gallery"` (an already-complete gallery retiring
its three pages to both sides).

**Non-vacuity independently reasoned, not just claimed.** Mentally removing `retiredPageCount` from
the push makes `testPausedGalleryRetiresOnlyItsFinishedPages` report `6 / 6 pages · 1 gallery`
against its expected `6 / 10` — the case fails. The executor's recorded deliberate-break run (8 of
33 cases failing with the ledger contribution removed, tree restored before commit) is consistent
with that. Recorded in `15-21-SUMMARY.md` rather than in code, which is weaker pinning than a
committed canary but is a genuine observation.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `App/Info.plist` | One bundle-scoped continued wildcard | ✓ VERIFIED | Single `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` entry; `processing` background mode retained with a written justification at lines 160-165 |
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Identified start/update/finish seam | ✓ VERIFIED | Three `@DependencyClient` endpoints; `.live` composed directly, injected at `DownloadClient.swift:77` |
| `.../ContinuedProcessingSession.swift` | Main-actor task/session store | ✓ VERIFIED | Single-session guard evaluated and written in one synchronous run (85-98); real seed from the caller's snapshot (97-98); identity-gated `updateProgress`/`finish` (170, 186); per-session UUID identifier (125) |
| `.../ContinuedTaskScheduling.swift` | Sole scheduler adapter | ✓ VERIFIED | The only file in `App/`, `AppPackage/` and `ShareExtension/` importing `BackgroundTasks` |
| `.../DownloadClient+ContinuedSession.swift` | Session lifecycle + retirement ledger | ✓ VERIFIED | `schedulableSnapshot`, `reconcileRetiredSessionPages`, ledger summed into the raw pair before one clamp; ownership re-checked after each of the two suspensions in the push |
| `.../DownloadClient+Manager.swift` | Ledger state and its rationale | ✓ VERIFIED | `retiredSessionPages` / `observedSchedulablePages` declared and documented; ACTIVE-OWNERSHIP CONVERGENCE invariant stated at 345 |
| `.../DownloadClient+PendingWork.swift` | Single schedulable-work authority | ✓ VERIFIED | `hasPendingWork` and `schedulableDownloads` remain the one selection path shared by scheduler, gate and card |
| `.../DownloadClient+PublicAPI.swift` | User actions converge scheduling/session state | ✓ VERIFIED | All three ownership-clearing exits of `delete` converge (196-223) |
| `.../DownloadClient+Folders.swift` | Second removal entry point converges | ✓ VERIFIED for `deleteFolder` (both catch branches, 116-135); see WR-01 for `moveDownload` |
| `AppPackage/Tests/.../DownloadContinuedSessionLedgerTests.swift` | Ledger regression suite | ✓ VERIFIED | 418 lines, 6 cases: sequential completions holding the denominator, order-independence, an emptied live sum, pause departure, delete departure, rejoin; plus reusable monotonicity and fraction-reaches-one-only-at-drain helpers |
| `AppPackage/Tests/.../DownloadContinuedSessionTests.swift` | Re-derived expectations | ✓ VERIFIED | The three defect-encoding literals replaced, not supplemented |
| `AppPackage/Tests/.../BackgroundExecutionInvariantTests.swift` | Permanent topology guard | ✓ VERIFIED | 266 lines; scans app, package sources, package tests, extension and the plist |
| `AppPackage/Tests/.../DownloadLogPrivacyInvariantTests.swift` | Permanent privacy scan | ✓ VERIFIED | 158 lines, two non-vacuous tests; device UAT test 4 confirmed the collected-archive half |
| `.../BackgroundProcessingClient/.swiftlint.yml` | New-module lint inheritance | ✓ VERIFIED | `parent_config: ../../../.swiftlint.yml` |

## Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| Plist wildcard | Runtime identifiers | Bundle prefix plus `.continued.<UUID>` | ✓ WIRED |
| Live client closures | Session store | Main-actor `start`/`updateProgress`/`finish` | ✓ WIRED |
| Session store | System scheduler | `ContinuedTaskScheduling.live` | ✓ WIRED |
| `settleCompletedDownload` (queue-store removal) | Retirement ledger | Departure observed on the next push's membership sweep | ✓ WIRED |
| Throttled page flush | Card | `flushDownloadProgress` → `pushContinuedSessionProgress` under session identity | ✓ WIRED |
| `pause` / `delete` | Retirement ledger | Both converge on `scheduleNextIfNeeded` → `reconcileContinuedSession` → push | ✓ WIRED |
| User taps (enqueue, resume, retry ×2, superseded-pause) | `ensureContinuedSession()` | Success-path calls | ⚠️ PARTIAL — `refreshDownloads` is a sixth queue-mobilizing entry point that does not call it (CR-01) |
| Ownership-clearing exits | Queue convergence | Block release, `notifyObservers()`, `scheduleNextIfNeeded()` | ⚠️ PARTIAL — `moveDownload` takes a scheduling block across three suspensions and converges on no exit (WR-01) |

## Data-Flow Trace

| Data | Source | Sink | Status |
|---|---|---|---|
| Live completed/total counts | One schedulable index read (`schedulableSnapshot`) | Raw pair, then one display clamp | ✓ FLOWING |
| Retired pages | Per-gallery membership difference against the authoritative record | Both sides of every later push | ✓ FLOWING — was the defect |
| Subtitle gallery count | Live schedulable count only | System card subtitle | ✓ FLOWING (D-06/D-10 preserved) |
| Card text | Localized integer-only builder | System title/subtitle | ✓ FLOWING, no gallery identity |
| Operational log identity | Gallery gid | Hash-masked private field | ✓ NON-DISCLOSING (device archive confirmed, UAT test 4) |

## Behavioral Spot-Checks

| Behavior | Evidence | Status |
|---|---|---|
| A completed gallery holds the total and advances the count | `testACompletedGalleryHoldsTheTotalAndAdvancesTheCount` passed in the suite run | ✓ PASS |
| Three sequential completions hold the denominator, in both completion orders | `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount`, `testReportedTotalsDoNotDependOnCompletionOrder` passed | ✓ PASS |
| A pause and a delete retire identically (one shared expected pair) | `testPausedGalleryRetiresOnlyItsFinishedPages`, `testDeletedGalleryRetiresTheSamePagesAsAPause` passed | ✓ PASS |
| A rejoining gallery is counted once, not twice | `testResumedGalleryIsCountedOnce` passed | ✓ PASS |
| The fraction reaches one only at the drain; the numerator never rewinds | `expectTheFractionReachesOneOnlyAtTheDrain`, `expectTheCompletedSeriesNeverRewinds` over whole update series | ✓ PASS |
| Card cancel leaves the per-gallery in-app pause baseline | `testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState`, `testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes` passed | ✓ PASS |
| Drain during an in-flight start defers reconciliation and keeps coverage | `testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage` passed | ✓ PASS |
| Failed removal still converges the queue (both entry points, both error shapes) | `testAFailedRemovalStillConvergesTheQueue`, 4 cases, passed | ✓ PASS |
| Unimplemented client reports an issue on every endpoint | `testUnimplementedClientReportsAnIssueForEveryEndpoint` passed | ✓ PASS |
| No public log interpolation exposes gallery identity | `testNoDownloadLogPublishesGalleryIdentity`, `testDownloadIdentityLogsStayHashMasked` passed | ✓ PASS |
| No deleted background-execution spelling survives | `BackgroundExecutionInvariantTests` passed; independently reproduced by grep | ✓ PASS |
| Multi-gallery card rendering after the ledger fix | Requires physical iOS 26 hardware | ? DEVICE BACKSTOP |

## Probe Execution

No phase-declared or conventional `probe-*.sh` scripts exist in this repository.

## Requirements Coverage

`.planning/REQUIREMENTS.md` maps no requirement IDs to Phase 15 and contains no Phase 15 orphan.
The scope contract is the four roadmap success criteria. All 21 plans declare `requirements:` drawn
only from `SC1`–`SC4`, and every one of the four is claimed by at least one plan.

| Contract | Source plans | Status |
|---|---|---|
| SC1 | 15-05..15-13, 15-17..15-21 (and 15-06, 15-07) | ✓ SATISFIED — device-confirmed, with two recorded warnings |
| SC2 | 15-04, 15-06, 15-07, 15-12..15-15, 15-17, 15-19, 15-20, 15-21 | ⚠️ NEEDS HUMAN — fix present, wired and deterministically tested; device re-check outstanding |
| SC3 | 15-01, 15-02, 15-06, 15-07, 15-14, 15-15 | ✓ SATISFIED — device-confirmed |
| SC4 | 15-01, 15-03, 15-04, 15-07, 15-16 | ✓ SATISFIED |

## Anti-Patterns Found

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK` or `PLACEHOLDER` marker exists anywhere in
`AppPackage/Sources/DownloadClient`, `AppPackage/Sources/BackgroundProcessingClient`,
`AppPackage/Tests/DownloadsFeatureTests` or `App/Info.plist`. The debt-marker gate reads zero.

No `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` or SwiftLint suppression exists
in phase source or tests.

## Prohibitions

| Prohibition (plans 15-20, 15-21) | Status | Evidence |
|---|---|---|
| Must NOT reopen D-06 / D-10 — one queue-wide session, one summed page fraction | ✓ VERIFIED | Session end condition remains `hasPendingWork() == false`; no per-gallery completion predicate exists; `testSecondMobilizingActionDuringLiveSessionStartsNoSecondSession` passes |
| Must NOT change the subtitle's gallery count away from the remaining schedulable count | ✓ VERIFIED | `pushed.galleryCount` is taken raw from the live snapshot (`:412`); the ledger never touches it |
| Must NOT remove `settleCompletedDownload`'s queue-store removal | ✓ VERIFIED | Present and used as the staging step in the ledger suite |
| Must NOT retire a departed gallery's unfinished pages into the denominator | ✓ VERIFIED | `min(max(record.completedPageCount, 0), record.pageCount)` — finished pages only; `testPausedGalleryRetiresOnlyItsFinishedPages` asserts the total drops from 14 to 10 |
| Must NOT count a rejoining gallery in both the ledger and the live sum | ✓ VERIFIED | Rejoiners released before departures are computed (`:326-328`); `testResumedGalleryIsCountedOnce` asserts `[6, 6, 6]` / `[14, 10, 14]` |
| Must NOT special-case the departure reason in production code | ✓ VERIFIED by inspection | `reconcileRetiredSessionPages` has no reason parameter and no branch on how a gallery left; one formula, swept from membership |
| Must NOT supplement the defect-encoding cases while leaving old expectations in place | ✓ VERIFIED by inspection and by diff | All three literals replaced |
| Must NOT introduce a second background-execution tier | ✓ VERIFIED | Grep plus `BackgroundExecutionInvariantTests` |
| Must NOT put content identity into system-card strings | ✓ VERIFIED | `continuedSessionSubtitle(for:)` accepts only integers; `testEveryPushedSubtitleCarriesNoGalleryIdentity` passes |
| Must NOT reach for a concurrency or lint escape hatch | ✓ VERIFIED | Grep clean; suite ran with zero lint warnings |
| Must NOT weaken or delete an existing continued-session case to make the new suite pass | ✓ VERIFIED | 15-21's two commits are insertions into one test file only (`151+/8-`, `56+/0-`); the 8 deletions are the shared-constant refactor inside the new file |

## Independent Judgment on the Code Review's Findings

The review (`15-REVIEW.md`, 1 Critical / 10 Warning / 5 Info) was read only after the truths above
were decided from source. Each finding was re-derived and judged against the four success criteria
rather than inherited at its assigned severity.

### CR-01 (reviewer: Critical) — pull-to-refresh mobilizes the queue without ensuring a session

**Independently confirmed as a fact.** `refreshDownloads()` (`+PublicAPI.swift:27-29`) calls
`syncDownloadsState(scheduleNext: true)` → `scheduleNextIfNeeded()` and does not call
`ensureContinuedSession()`, while five sibling entry points do. It reaches the coordinator
synchronously from a foreground user gesture (`DownloadsView.swift:145` `.refreshable`), so it would
qualify for submission.

**Judged NOT a blocker for SC1.** Three independent reasons, checked in source:

1. **The state it fails to rescue is one the phase explicitly accepts.** D-07 (`15-CONTEXT.md:81-85`)
   decides that work becoming schedulable without a qualifying tap "runs foreground-only until the
   next qualifying tap; that is accepted", and enumerates the qualifying set as start / resume /
   retry / update. `DownloadClient.swift:85-86` already calls `reconcileDownloads()` then
   `resumeQueue()` at cold launch — the queue auto-resumes *uncovered by design*. Pull-to-refresh
   does not create that uncovered state; it merely does not lift it.
2. **The reviewer's concrete narrative does not hold as written.** In its crash-relaunch scenario
   both normalizations are no-ops in a fresh process (`normalizeInterruptedDownloads` only nulls a
   stale `activeGalleryID`, which is nil after relaunch; `normalizeNeedsAttentionDownloads` only
   clears in-memory `downloadErrors`, which is empty), and `resumeQueue()` has already scheduled.
   Refresh's real contribution on that path is a second `scheduleNextIfNeeded()`.
3. **Clearing a cancellation-like error does not by itself mobilize.** It moves `displayStatus` from
   `.error` to `.inactive` (`+Persistence.swift:110-113`), and `shouldSchedule` requires `.inactive`
   *plus* a non-empty `queuedPageSelections` entry (`+Scheduling.swift:130-134`). So refresh does not
   silently make error-state galleries schedulable.

SC1 as written covers "a download started in the foreground". Every path by which a user *starts*
work does ensure a session, and device UAT test 1 confirmed continuation. **Classified WARNING.**

That said, this is the phase's recurring failure mode showing again — five branches fixed, a sixth
sibling left — and the asymmetry is **undocumented at the refresh site**, so it reads as an omission
rather than a decision. The honest remedy is either the one-line ensure the reviewer proposes or a
comment at `refreshDownloads` stating why refresh is deliberately excluded while
`reconcileDownloads` is. Recommended before shipping; not a gate.

### WR-01 (reviewer: Warning) — `moveDownload` releases its scheduling block without converging

**Independently confirmed.** `+Folders.swift:163-206` inserts `gid` into
`schedulingBlockedGalleryIDs` with a function-scoped `defer`, suspends three times
(`fetchDownload`, `moveItem`, `reloadDownloadRecord`), and returns on six exits without ever calling
`scheduleNextIfNeeded()`. Its siblings `delete`, `deleteFolder` and `commitPause` all converge — the
first two fixed in this very phase.

**Judged NOT a blocker.** The stated ACTIVE-OWNERSHIP CONVERGENCE invariant
(`+Manager.swift:345-360`) binds paths that *clear* `activeGalleryID`/`activeTask`; `moveDownload`
clears neither (it fails with `.downloadStoreDownloadBusy` when the gallery is active). The real
hazard is narrower and phase-introduced: `isSchedulableDownload` excludes blocked gids, so if the
moved gallery is the only schedulable work and a concurrent `scheduleNextIfNeeded()` (for example the
`Task` spawned by `finishActiveTaskIfOwned`) lands inside the block window, `reconcileContinuedSession`
reads `hasPendingWork() == false` and *completes the live session* — the card goes down while the
gallery is milliseconds from being schedulable again, and no path restarts a session without a fresh
tap. It requires two concurrent coordinator operations and a single-item queue. **Classified WARNING**
— but it is the same branch-scoped-fix pattern as CR-01, on the invariant this phase spent three
rounds installing, so it deserves closing in the same pass.

### Remaining findings

| Finding | Confirmed? | Blocks an SC? |
|---|---|---|
| WR-02: expiration pause-all starts then immediately cancels the next gallery per iteration | Yes — `commitPause` reaches `scheduleNextIfNeeded()` (`:230`) while only the current gid is blocked | No. Spurious gallery-detail requests against a quota-limited backend on the card-cancel path. Real waste, no state corruption |
| WR-03: the single-session guard is not atomic across `await hasPendingWork()` | Yes — `:128` awaits before setting the flag; correctness rests on `queueStore.gids` being a synchronous `Shared` read | No. Correct on current code, and the code admits the dependency at `:152-154`. Latent: one `await` added downstream silently reopens the double-start window |
| WR-04: both `catch` arms in `commitPause` are unreachable | Yes — neither `writeInitialPauseRecord` nor `writeSettledPauseRecord` contains a throwing call | No. If nothing throws, `commitPause` always settles and always converges. Dead convergence, not missing convergence |
| WR-05: pause helpers take an unused `download` and a vestigial `throws` | Yes | No. Dead parameter, false contract |
| WR-06: `schedulingBlockedGalleryIDs` is an uncounted `Set`, so overlapping blocks release early | Yes — four `insert` + `defer remove` sites, all suspending, on a reentrant actor | No. Requires two concurrent operations on one gid. Predates the phase in shape; WR-02's proposed fix depends on this being addressed first |
| WR-07: session-lifecycle mutators are `public` only for a cross-module test target | Yes — nine symbols with no production caller outside `DownloadClient` | No. Real API-surface hazard (any linking module can call `markContinuedSessionEnded`), and the module already has the `#if DEBUG` pattern to fix it |
| WR-08: the client spy consumes `refuseNextStart` on refusals it did not cause | Yes | No. A test-double fidelity flaw. The Gap-A regression asserts `startCount == 1`, decided by the *coordinator's* guard, so it does not inherit the weakness |
| WR-09: the `.superseded` arm returns `.success(())` for work it abandoned | Yes | No. Its only caller discards the result today |
| WR-10: every session attempt permanently registers a launch handler, including failed ones | Yes — registration precedes submission and can never be undone | No. Identifiers are per-session UUIDs so the app-terminating hazard is unreachable; the cost is unbounded per-process growth, worst on the `.superseded` path that submits from a background context |
| IN-01..IN-05 | Yes, all five | No. IN-05's "N / N pages · 0 galleries" pair is now the *honest* drain value under the ledger and is pinned as such |

None of the sixteen falsifies a success criterion. CR-01, WR-01 and WR-07 are the three worth acting
on before this area is edited again: the first two are the same incomplete-sweep pattern this phase
has now hit four times, and the third publishes session-teardown mutators to seven modules.

## Human Verification Required

### 1. Multi-gallery card behavior on a physical iOS 26 device (re-run of UAT test 2)

**Test:** Queue at least three galleries of clearly different sizes, start in the foreground, and
background the app. Watch the system card across the **first gallery's completion**, then pause one
of the remaining galleries from the app and watch the card again. Finally cancel from the card,
foreground, and compare queue and manifest state against the state left by pausing each gallery by
hand.

**Expected:** The completed count keeps climbing past the first gallery's completion instead of
pinning at 100%; the total does not shrink; the subtitle keeps naming the *remaining* galleries; the
remaining galleries keep downloading in the background; after a pause the card can still reach
completion rather than being pinned below one; card-cancel leaves the same state as the in-app
per-gallery pause.

**Why human:** This is the exact behavior the device found broken (`15-UAT.md` test 2,
`result: issue`). The fix changes pushed arithmetic and is proven deterministically by
`DownloadContinuedSessionLedgerTests`, but the card is rendered by system UI outside the app and the
scheduler's stall-detection response exists only on hardware. `15-UAT.md` has not been re-run since
the fix landed, so its record still reports the defect.

## Summary

Gap G-15-2 is closed in the code, not merely in the summaries. The retirement ledger is a
membership-level sweep rather than a hook on the completion path the device report happened to name,
and I verified in source that no departure reason is classified anywhere in the production formula —
completion, pause, delete, cancel and a scheduling block all retire through the same line. The three
committed expectations that had encoded the defect were re-derived, not supplemented, and the suite
is non-vacuous by construction as well as by the executor's recorded break run.

SC1, SC3 and SC4 are verified outright, the first two with physical-device evidence from the UAT.
SC2 is the one remaining item and it is honestly unverified rather than failed: everything the
criterion needs is present, wired and deterministically tested, but the half of it the device
rejected has never been re-observed on the device. Shipping without that re-check would be trusting
a unit test to speak for a system-rendered card that has already surprised this phase once.

Two of the sixteen review findings — the missing `ensureContinuedSession()` on `refreshDownloads`
and the missing convergence in `moveDownload` — are the phase's recurring incomplete-sweep pattern
appearing for the fourth and fifth time. Neither falsifies a success criterion on my reading, and
both are recorded here as warnings rather than gaps, but they are the two most worth closing before
this area is touched again.

---

## Amendment — 2026-08-04, after gap-closure plan 15-22

Everything above this heading was written at HEAD `d246b1a3`, **before** plan 15-22 landed. It has
not been re-derived at the new HEAD; treat it as the record of the previous round.

Plan 15-22 closed G-15-2B by adding a terminal progress push to the drain branch of
`reconcileContinuedSession`. The full suite is green at that HEAD (827 tests across 22 targets,
`** TEST SUCCEEDED **`). The post-15-22 code review (`15-REVIEW.md`, commit `7b8513d2`) then raised
two blocker-severity findings, both of which the orchestrator confirmed directly against source
rather than accepting on the reviewer's account:

| Gap | Origin | What it breaks |
|-----|--------|----------------|
| **G-15-3** | Introduced by 15-22 | The drain branch's tail is now reentrant across a main-actor hop, so a session can be torn down over work that arrived after the drain was observed. The mitigation 15-22 shipped guards session identity, which cannot change in that window, instead of drain-ness, which can. |
| **G-15-4** | Pre-existing | A complete gallery queued for update/redownload opens the card at 100%, and the monotonic floor pins it there — the G-15-2 symptom reached by a different route. |

The full reasoning for each, including why the 15-22 suite could not have caught G-15-3, is in the
`gaps:` block of this file's frontmatter and in `15-REVIEW.md`.

**SC2 is unaffected by this amendment and remains behaviourally unverified.** Closing G-15-3 and
G-15-4 does not discharge the physical-device UAT item; `15-UAT.md` test 2 still has to be re-run on
hardware after the gap round.

---

## Amendment — 2026-08-05, round 9: after gap-closure plan 15-25

Everything above this heading belongs to earlier rounds and was **not** re-derived here. This
section was written at HEAD `6fc528f1` (working tree clean), after plan 15-25 landed
(`06763885`, `7b0fa678`) and after the post-15-25 code review (`15-REVIEW.md`, same commit,
1 blocker / 3 warnings / 3 info).

The orchestrator supplied one execution result for this HEAD: the full `FeatureTests` plan on
`platform=iOS Simulator,name=iPhone Air` reported `** TEST SUCCEEDED **` with no failures. Per the
one-run rule nothing was re-run. That run is evidence for G-15-5's closure and is explicitly **not**
evidence against G-15-6, whose whole content is that no case covers the interaction.

### Roadmap truths at this HEAD

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding | ✓ VERIFIED (unchanged) | Device UAT test 1 `result: pass`; the session-start call sites and the plist wildcard were verified in the original body and 15-25 touched none of them (`git diff --name-only` over both commits lists exactly `+ContinuedSession.swift`, `+ExecutionPerform.swift`, `+ExecutionSupport.swift` and three test files) |
| SC2 | System UI shows real progress and card cancel matches an in-app cancel | ✗ **FAILED** — G-15-6 | The monotonic floor now absorbs a coordinator-caused downward correction of the counted basis, so the card can hold a stale numerator across real work. Re-derived in source, chain in the `gaps:` frontmatter. **Separately** still behaviourally unverified: `15-UAT.md` test 2 reads `result: issue` and has never been re-run on hardware |
| SC3 | Best-effort refusal/queue/expiration, no fallback tier, no loss, no duplication, no visible error | ✓ VERIFIED (unchanged) | Device UAT test 3 `result: pass`; `BackgroundExecutionInvariantTests` passed in this HEAD's run and 15-25 introduced no `BGTaskScheduler` / `BGContinuedProcessingTask` occurrence |
| SC4 | A testable session seam with an unimplemented default and no direct scheduler access | ✓ VERIFIED (unchanged) | `BackgroundProcessingClient` untouched by 15-25; the invariant suite that pins the single `import BackgroundTasks` site passed |

**Score: 3/4.** SC2 carries two independent open items — a code defect (G-15-6) and a device
observation (UAT test 2). Neither discharges the other.

### G-15-5 — re-derived in source — ✓ CLOSED

All three claimed mechanisms exist and are wired; none was taken from the summary.

1. **The reconciliation is at the convergence point.**
   `reconcileWorkingManifestAgainstPageFiles` is declared at `+ExecutionSupport.swift:321-340` and
   called at `:232-236`, between the `existingPages` read and the `WorkingSeed` construction inside
   `prepareWorkingSeed` — so it is reached by every start mode's run, not by the branch the report
   named. It blanks a hash only when the page is claimed and its file is absent, writes the manifest
   and re-indexes **only** when something changed (`guard didBlankAnyPage else { return manifest }`),
   which is what preserves D-G4-01's ceiling guarantee for an honest complete record. Its body
   contains no suspension point, and `prepareWorkingSeed` keeps its non-`async` signature.
2. **The announcement is production-wired.** `prepareWorkingSeedAnnouncingProgress`
   (`:273-287`) pushes when a session is live and the seed manifest reads incomplete, and
   `DownloadClient+ExecutionPerform.swift:29` is the production call — confirmed by grep to be the
   only non-test call site of either preparation function.
3. **The seed merges.** `+ContinuedSession.swift:241-245` is
   `observedSchedulablePages.merge(_, uniquingKeysWith: { observed, _ in observed })` plus
   `observedIncompleteSessionGIDs.formUnion(...)`, behind the unchanged ownership guard.

The route the gap named holds end to end: `resumeMode` resolves `.repair`
(`+SchedulingHelpers.swift:44-55`), `shouldReuseWorkingFolder` returns `true` for `.repair`
(`+ExecutionSupport.swift:379-380`), the reused manifest is returned verbatim by
`ensureWorkingManifest` (`:345-355`), and the reconciliation is what finally lowers the count that
`isIncomplete` and the session basis both read. Test E pins the K=1 arc on production-issued
pushes, and the executor recorded the verbatim pre-fix reading (`0 / 1 page · 0 galleries`) from a
temporary revert. The prohibition that the scheduling authority stay untouched holds by diff:
`+Scheduling.swift`, `+SchedulingHelpers.swift`, `+PendingWork.swift` and `+Manager.swift` appear
in neither commit.

### The two reported deviations — both verified, both legitimate

- **`holdNextStart()` / `releaseHeldStart()` not added.** Confirmed: `armStartGate()` already
  exists at `DownloadFeatureTestSupportTypes.swift:187`, is used at
  `DownloadContinuedSessionIdentityTests.swift:105`, and Test F uses it at
  `DownloadContinuedSessionLedgerTests.swift:725`. `DownloadFeatureTestSupportTypes.swift` appears
  in neither 15-25 commit. So the plan's artifact grep `contains: holdNextStart` does not match,
  and it should not: adding a second spelling of a sufficient existing API is the thin wrapper the
  project's CLAUDE.md forbids. The plan's behavioural requirement — the client-start hop can be
  held open deterministically and the interleaved-start regression is expressible — is met.
  **Accepted; no override entry is needed because the must-have is satisfied by a different
  artifact, not waived.**
- **Table 1 row 4 under-enumerates `queuedMode`.** Confirmed: `+SchedulingHelpers.swift:15-35`
  has five branches, and the row omits `.inactive → resumeMode(for:)`. Documentation only; that
  branch's mechanisms are row 3's, which was confirmed independently. No code impact.

### G-15-6 — the review's CR-01, independently re-derived — ✗ CONFIRMED (blocker)

The finding holds. Every link was checked in source rather than accepted on the reviewer's
account, and the full chain, the invalidated doc-comment premise and the fix constraints are in the
`gaps:` frontmatter above so that `/gsd-plan-phase 15 --gaps` can see it — a blocker recorded only
in `15-REVIEW.md` is invisible to that command.

**One correction to the review, which matters for how the fix is tested.** The review's step 5 has
a second gallery's progress masked concurrently for 99 pages. The queue is serial —
`scheduleNextIfNeededCore` returns at `guard activeTask == nil` (`+Scheduling.swift:44`) — so
nothing else downloads during the repair, and in the pure-serial case where the repair re-earns
every blanked page the card is frozen for the same span it was frozen for before 15-25. That case
is a wash. The reachable regression is narrower and still a blocker: it is the case where the
blanked pages are **not** all re-earned by the gallery that lost them — a repair paused, expired,
failed or deleted part-way departs and is retired at its honest lowered count while the floor still
holds the pre-blanking total, so the next gallery's pages are invisible until the queue climbs back
over it; or a second reconciliation in the same session depresses the sum further below a floor
that never comes down. A regression test that merely stages two galleries and blanks K pages of one
would be **vacuous** in a serial queue; it has to make the reconciled gallery depart without
re-earning them.

### Independent judgment on the review's three warnings — none promoted to a gap

| Finding | Confirmed in source? | Promoted? |
|---|---|---|
| **WR-01** `schedulableDownloads()` can exclude the running gallery | Yes. `+PendingWork.swift:21-27` scopes the index read by `queueStore.gids` when non-empty, while `shouldSchedule` accepts `displayStatus == .active` independently (`+Scheduling.swift:124-126`). The two removal sites are real (`+Execution.swift:213`, `+Persistence.swift:180`), and `nextUnqueuedSchedulableDownload` deliberately schedules a gallery the persisted queue has not caught up with | **No — WARNING.** The queue scoping predates the phase; `bb3657a1` (15-13) extracted it into the shared authority rather than introducing it. It self-heals on the next enqueue or task settle, and the retirement ledger keeps the pushed pair internally consistent while it lasts. But its second consequence touches SC2's cancel half directly (an expiration selecting through the same call would skip pausing the gallery actually running), and it is the same incomplete-sweep pattern this phase has now hit six times. **Close it in the same pass as G-15-6** |
| **WR-02** nothing pins `performDownload` to the announcing wrapper | Yes. `+ExecutionPerform.swift:29` is the sole production call site, both preparations are `public` with near-identical signatures, and both ledger cases (`:642`, `:733`) call the announcing variant directly, so reverting that line leaves the suite green | **No — WARNING.** The wiring is correct today and was verified by grep, so no must-have fails. It is a durability hole on exactly the phase's stated dominant failure mode, and the cheapest closure (make the silent variant non-`public` behind the existing `#if DEBUG` seam) should ride along with G-15-6 |
| **WR-03** `storage.validate` now answers `.valid` for a blanked page | Yes. `validatePage` returns `nil` on an empty expected hash (`DownloadStore+Operations.swift:295-297`), and D-G5-01 blanks exactly those, so the inspector's integrity check and `loadManifest`'s `.missingFiles` gate both change answers | **No — WARNING.** Outside the SC1–SC4 contract, and the consequence was reasoned in `15-25-SUMMARY.md`. But it is reasoned only there: the deliberate-consequence paragraph on the reconciliation names `displayStatus` and `resumeMode` and stops, so a later reader cannot tell whether `validate` was considered — which is precisely the "intentional design reads as a bug" failure the surrounding docs exist to prevent, and the project's own convention is to document the WHY of a non-obvious deliberate design. **Documentation fix, cheap, worth folding into the same pass** |

IN-01 (the near-dead `resumeMode` validate branch), IN-02 (the privacy invariant cannot see a URL
leak) and IN-03 (the magic `maskedCount >= 8` threshold) were read and are all real; none touches a
success criterion.

### Anti-patterns and prohibitions at this HEAD

The 15-25 diff carries no `swiftlint:disable`, `@unchecked Sendable`, `nonisolated(unsafe)` or
`@preconcurrency`, and no `TBD` / `FIXME` / `XXX` / `TODO` / `HACK` / `PLACEHOLDER` marker exists
anywhere in `AppPackage/Sources/DownloadClient`,
`AppPackage/Sources/BackgroundProcessingClient` or `AppPackage/Tests/DownloadsFeatureTests`. The
debt-marker gate reads zero. Plan 15-25's six prohibitions were checked by diff and hold, including
the two that matter most: the schedulable-work authority is untouched, and the only edited site of
`observedIncompleteSessionGIDs` is the seed, whose semantics changed from overwrite to merge as the
one recorded exception.

### Requirements coverage

`.planning/REQUIREMENTS.md` still maps no requirement IDs to Phase 15 and lists no Phase 15 orphan;
the scope contract remains SC1–SC4. All 25 plans declare `requirements:` drawn only from those four
labels, and 15-25 declares `[SC2, SC1]`. Every SC is claimed by at least one plan, and every SC is
accounted for in the truths table above — SC2 as failed-and-unverified, the other three as verified.

### Where this leaves the phase

G-15-5 is genuinely closed, and 15-25's fix is the first of this phase's gap rounds whose scope was
argued at the invariant level rather than at the reported branch — the reconciliation sits where
every start mode converges, and the sweep tables were checked against source rather than asserted.
That is the right shape.

It nonetheless produced G-15-6, and the reason is worth naming because it will recur: the fix made
a quantity honest that a *different* mechanism, written three rounds earlier, had assumed could
only move one way. The monotonic floor's premise was written down as a comment and was true when
written; nothing re-checked it when the basis gained a new downward mover. A gap round that changes
what a number can do must sweep the consumers that already reason about that number, not only the
call sites it edits.

SC2 now needs two separate things and they do not substitute for each other: G-15-6 closed in code,
and `15-UAT.md` test 2 re-run on physical iOS 26 hardware, in that order.

---

_Verified: 2026-08-04T17:10:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-04 by the execute-phase orchestrator — gaps G-15-3 / G-15-4 recorded from 15-REVIEW.md and confirmed in source._
_Amended: 2026-08-05 by Claude (gsd-verifier) — round 9: G-15-5 verified closed in source, blocker G-15-6 recorded from 15-REVIEW.md CR-01 and independently re-derived, three warnings judged and not promoted._

---

## Amendment — 2026-08-05, round 10: after gap-closure plan 15-26

Written at HEAD `829b55d8` by a fresh verifier, after plan 15-26 landed and after the standard-depth
code review committed at that same HEAD (`15-REVIEW.md`, 1 critical / 7 warnings / 5 info). Nothing
above this heading was re-derived; everything below was derived from source at this HEAD.

The stance for this round was adversarial by instruction: assume the phase goal was NOT achieved
until codebase evidence proves it, and treat 15-26-SUMMARY.md's claims as claims. Two of its
statements were falsified — see G-15-7.

### Roadmap truths at this HEAD

| # | Success criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue outlasting the `beginBackgroundTask` grace period | ✗ FAILED (downgraded this round) | The core arc is device-verified (`15-UAT.md` test 1, `result: pass`) and the mechanism is intact. It is defeated on two reachable routes: G-15-7's frozen numerator is the maximally stalled reading D-11's policy force-expires first, and `handleContinuedSessionEvent`'s `.expired` arm (`+ContinuedSession.swift:299-302`) pauses EVERY schedulable download; and G-15-8 lets `moveDownload` hide the only schedulable work across three suspensions, so a convergence completes the session and no exit reschedules the gallery. |
| SC2 | The system card reflects real progress and its cancel matches an in-app cancel | ✗ FAILED, and separately behaviour-unverified on hardware | G-15-7 freezes the pushed numerator for C pages of real work on the `.redownload` route; G-15-9 can move it for a correction that never happened. `15-UAT.md` test 2 still reads `result: issue` and has not been re-run since any fix landed. Two independent axes; neither discharges the other. |
| SC3 | Best-effort submission, no fallback tier, no lost or duplicated work, no user-visible error | ✓ VERIFIED | `grep` over `App/`, `ShareExtension/` and `AppPackage/Sources` finds no `beginBackgroundTask`, no `BGProcessingTaskRequest` and no `performExpiringActivity`; the single `isDiscretionary` hit is a `URLSessionConfiguration` in `DownloadPageDownloader.swift:283`, unrelated. `Info.plist` keeps `UIBackgroundModes: [processing]` (with the recorded rationale for keeping it) and its permitted identifier is the bundle-scoped wildcard `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`. Refusal, unavailability and expiration all have silent-by-contract handlers. Device-verified: `15-UAT.md` test 3, `result: pass`. |
| SC4 | A testable client seam exposing a continued-processing session — start, update-progress, complete, events on a self-finishing stream, `testValue` unimplemented, no reducer or coordinator touching the scheduler | ✓ VERIFIED | `BackgroundProcessingClient` is a `@DependencyClient` struct with exactly `start` / `updateProgress` / `finish` and a `BackgroundProcessingSession` handle carrying `AsyncStream<BackgroundProcessingEvent>`; the macro leaves every endpoint unimplemented, and the seam is constructor-injected (`DownloadClient.swift:77` passes `.live`; the coordinator's default is `.noop`). `import BackgroundTasks` appears at exactly one site in the whole workspace, `BackgroundProcessingClient/ContinuedTaskScheduling.swift:1`. The store finishes its own stream (`endSession(yielding:success:)`). Caveat recorded as G-15-11: nine coordinator-side session mutators are `public` with zero external callers, which weakens the seam's exclusivity without breaking it. |

**Score: 2/4 truths verified** (1 present-but-behaviour-unverified, tracked separately from the
failures because it is a device axis nothing in source can discharge).

SC1's downgrade is the substantive change from round 9. It was carried as verified on the strength
of the device UAT; this round found two reachable routes that defeat it, one of them
(`moveDownload`) never swept by any of the five convergence rounds.

### G-15-6 — the round-9 blocker — ✓ CLOSED IN MECHANISM, invariant NOT restored

Re-derived in source rather than accepted from `15-26-SUMMARY.md`:

- The withdrawal exists at `+ExecutionSupport.swift:396-400`, is read off the PRE-blanking manifest,
  and its counted-basis test (`manifest.completedPageCount < manifest.pageCount ||
  observedIncompleteSessionGIDs.contains(manifest.gid)`) mirrors `isSessionWork`'s first disjunct
  exactly, so an untrusted complete-reading record withdraws nothing and D-G4-01's ceiling
  guarantee is preserved.
- The correction really is atomic: `prepareWorkingSeed` is non-`async`, and `writeManifest`,
  `updateDownloadIndex` and the floor write are same-actor synchronous, so no interleaved push can
  observe a lowered basis under an un-lowered floor.
- The session-start seed merges additively (`+ContinuedSession.swift:236-239`,
  `max(snapshot + lastPushedCompletedPageCount, 0)`), so a withdrawal landing inside the client-start
  main-actor hop is folded in rather than discarded, and the unclamped subtraction that makes the
  scalar temporarily negative inside that hop is the intended input to that merge.
- Its regressions are real and non-vacuous: `DownloadContinuedSessionBasisTests` stages a blanked
  gallery that departs part-way and asserts the SURVIVOR's next pushes advance (`:48`), a withdrawal
  inside the client-start hop (`:170`), and the WR-01 active-gallery union (`:267`).
- The three carried warnings 15-26 undertook to close are closed: `schedulableDownloads()` unions
  `activeGalleryID` (`+PendingWork.swift:41-43`), `prepareWorkingSeed` is now `private` with the
  compile-error rationale written on it (`+ExecutionSupport.swift:205-216`), and the
  `storage.validate` consequence is documented (`:325-336`).

What is NOT closed is the invariant the fix states. That is G-15-7 below, and it is the fourth
consecutive round in which a fix scoped to a named mechanism left its siblings open.

### G-15-7 — the review's CR-01, independently re-derived — ✗ CONFIRMED (blocker)

Every mechanical link was checked in source and holds; the full chain is in the `gaps:` frontmatter
and is not repeated here. Three things this verification contributes beyond the review:

**1. The reachability staging is settled, and it is worse than the review argued.** The open
question was whether a live-session case is genuinely reachable, given that `retry(gid:mode:)` calls
`performRetry` — which spawns the run — BEFORE the trailing `await ensureContinuedSession()`, so a
wipe preceding the floor seed would be harmless. It cannot realistically precede it. The seed is
taken from same-actor and queue-store reads issued immediately after the spawn, while the spawned run
cannot reach `prepareWorkingSeed` without first completing a network `GalleryDetailRequest`
(`processDownload` → `fetchNormalizeAndDownload` → `fetchLatestPayload` → `performDownload`). For the
wipe to win that race a full gallery-detail round trip would have to complete inside a handful of
actor-local reads; and in the interleaving where it somehow did, the snapshot would read 0 and seed
the floor at 0 — the harmless direction. So the SINGLE-gallery `.redownload` of an errored gallery
with C downloaded pages is by itself a reachable freeze of exactly C pages, and the multi-gallery
case the orchestrator proposed is a second, strictly worse one in which the survivor's real progress
is masked too. The review's step 6 reading — `"6 / 10 pages · 1 gallery"` repeated across six real
page downloads — is correct.

**2. The suite is green against it for the reason G-15-6 was.** The only `.redownload` staging in the
ledger suite (`DownloadContinuedSessionLedgerTests.swift:486`, and the same shape at `:541`) uses
`completedPageCount: 6` of `pageCount: 6` — a complete-reading, therefore UNTRUSTED record whose
floor contribution is zero. The wipe moves a basis that was already zero, so the floor never engages.
That is the identical vacuity that let G-15-6 through: staging the population the defect cannot
reach.

**3. The disposition should be a sweep, not a third site.** This is the judgment the orchestrator
asked for, and it is worth more than the per-site verdict. 15-26 attached the withdrawal to the
blanking LOOP and wrote the invariant "exactly one deliberate downward mover" into two doc comments.
Source has at least four deliberate downward movers, three of which converge inside the very function
the withdrawal lives in: `setupWorkingFolder`'s deletion, `ensureWorkingManifest`'s fresh-manifest
write plus `updateDownloadIndex`, the blanking itself, and — outside the file — `writeInitialManifest`'s
fresh-manifest branch on the enqueue route. Enumerating movers is what failed; the enumeration was
wrong the moment it was written. The fix must be keyed to the BASIS MOVEMENT: read the index record
(the value the numerator is actually summed from) before any mover runs and again after the whole
preparation, evaluate the counted-basis predicate against the pre-image, and withdraw the delta. That
makes "whoever lowers the basis withdraws" true by construction for movers nobody has enumerated yet,
and it subsumes WR-05, whose whole content is that the withdrawal's amount is measured from a
manifest the numerator is not summed from. The plan should state the sweep as an invariant over
`downloadIndex[gid]` writers a live session can observe, and should explicitly exempt deletions,
which the retirement ledger already values on departure and which must not withdraw twice.

Two paragraphs asserting the false premise must be corrected as part of the fix
(`+ExecutionSupport.swift:338-351`, `+ContinuedSession.swift:537-548`). A wrong written premise
produced G-15-3 (which named the wrong suspension) and produced this gap; leaving it in place would
be the third instance.

### Independent judgment on the review's seven warnings and five info items

| Finding | Verdict | Disposition |
|---------|---------|-------------|
| WR-01 — destructive blanking driven by an error-swallowing probe | ✗ CONFIRMED, promoted | **G-15-9.** All three swallow sites verified (`DownloadStore.swift:374-391`, `:176`, `:561-584`, `:608-616`). `existingPages` is computed once and shared, so ONE failed directory enumeration blanks every claimed page, rewrites the manifest, publishes a 0-of-N record and withdraws the full count from the floor — unlogged. Phase-introduced by D-G5-01, and it runs on the ordinary `.initial` resume. Under this project's rule that an error is never swallowed into a destructive action, blocking. |
| WR-02 — `moveDownload` converges on none of its six exits | ✗ CONFIRMED, promoted | **G-15-8.** Verified against its two swept siblings, which carry the phase's own ACTIVE-OWNERSHIP CONVERGENCE comment. The teardown window is produced by the ordinary completion path (`finishActiveTaskIfOwned` nulls ownership synchronously, then awaits before rescheduling). Additional consequence the review missed: the success path never schedules either, so the moved gallery is left queued and idle. Defeats SC1. |
| WR-03 — `schedulingBlockedGalleryIDs` is an uncounted `Set` released by `defer` across suspensions | ✗ CONFIRMED, NOT promoted to its own gap | Real, and verified at all four insert sites. Predates this phase (the set arrives with the module extraction of 2026-06-27) and defeats no success criterion, so promoting it would widen phase scope. Recorded instead as a RECOMMENDED BUNDLE inside G-15-8, whose fix touches the same call sites; a reference count removes the class rather than the instance. |
| WR-04 — nine `public` session mutators with no external caller | ✗ CONFIRMED, promoted (warning) | **G-15-11.** The zero-external-caller claim was verified by grep over `App/`, `ShareExtension/` and every non-`DownloadClient` module: nothing. Any linking module can end or cancel the live session. The module already carries the correct `#if DEBUG` pattern, and 15-26 accepted this exact finding class one round ago. |
| WR-05 — the withdrawal's amount is read from a manifest the numerator is not summed from | ✗ CONFIRMED, folded into G-15-7 | Correct, and the review is right that CR-01's structural fix subsumes it. Recorded inside G-15-7 rather than separately so a partial fix cannot close one and leave the other. |
| WR-06 — `resolveSource` force-unwraps `galleryURL` while the same file falls back for it | ✗ CONFIRMED mechanically, harm claim CORRECTED, promoted (warning) | **G-15-12.** `Optional.forceUnwrapped` does log and return nil, and a nil would trap at the non-optional parameter — but the reviewer's "a crash the user sees as the card vanishing" does not hold at this HEAD: the only producer of a payload reaching `resolveSource` is `fetchLatestPayload`, which already guards the optional and assigns a non-optional value. It stands as a dead force-unwrap and an inconsistency with its sibling 300 lines away, not as a reachable crash. Recorded with that correction attached. |
| WR-07 — the client spy consumes a one-shot refusal it did not cause | ✗ CONFIRMED, promoted | **G-15-10.** Verified verbatim at `DownloadFeatureTestSupportTypes.swift:264-268`. No success criterion, but test-double infidelity is the documented mechanism by which G-15-3, G-15-4 and G-15-5 all shipped green, and the owner's standing mandate for this phase is contract-faithful doubles. Blocking. |
| IN-01, IN-02, IN-03, IN-04, IN-05 | ✗ CONFIRMED, grouped and promoted (warning) | **G-15-12.** IN-04 was re-derived and the review is right that the stated rationale is impossible (`downloadIndex` is keyed by gid, and `downloads(from:)` deduplicates again) — a wrong written reason is this phase's signature failure. IN-05's build fragility was measured: `DownloadContinuedSessionTests.swift` is 999 lines against a `file_length` ERROR gate of 1000. IN-01/02/03 are carried forward from the previous review, which left them open; all three still hold. |

### Artifacts, key links, anti-patterns and prohibitions at this HEAD

The four SC-bearing artifacts all exist, are substantive and are wired: `App/Info.plist` (wildcard
identifier + retained background mode with its rationale comment),
`AppPackage/Sources/BackgroundProcessingClient/` (client, `@MainActor` session store, scheduling
seam, logger), `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` (the
coordinator's whole session lifecycle) and the eleven `DownloadsFeatureTests` suites the review
enumerated. Key links verified by reading both ends: coordinator → client (`start` / `updateProgress`
/ `finish` at `+ContinuedSession.swift:203`, `:222`, `:434`, `:594`), client → system
(`ContinuedTaskScheduling.swift`, the only `BackgroundTasks` importer), UI tap → session
(`DetailView.swift:264` → `retryDownloadButtonTapped` → `retry(gid:mode:)` →
`ensureContinuedSession()`), and run → card (`performDownload` →
`prepareWorkingSeedAnnouncingProgress` → `pushContinuedSessionProgress`).

Debt-marker scan over `AppPackage/Sources/DownloadClient`,
`AppPackage/Sources/BackgroundProcessingClient`, `AppPackage/Tests/DownloadsFeatureTests` and
`App/Info.plist` for `TBD` / `FIXME` / `XXX` / `TODO` / `HACK` / `PLACEHOLDER`: zero hits. No
`swiftlint:disable`, `@unchecked Sendable`, `nonisolated(unsafe)` or `@preconcurrency` in the
reviewed set. The phase's prohibitions hold with one measured caveat, recorded in G-15-12: the
`file_length` error gate has one line of headroom in the largest session suite.

### Behavioural spot-checks

No `xcodebuild` invocation was made. This machine's recorded constraint is that test invocations must
never overlap, and a full-suite run would have produced no new evidence here: the suite is green at
this HEAD by 15-26-SUMMARY.md's own account, and greenness is precisely what is NOT evidence about
G-15-7 — the staging that would fail is the staging no case performs. Test EXISTENCE was proven by
enumeration instead (`grep -n "func test"`), which is what identified the two vacuous `.redownload`
cases. The behaviour that remains genuinely unproven is the device axis, carried in
`behavior_unverified_items`.

### Requirements coverage

`.planning/REQUIREMENTS.md` still maps no requirement IDs to Phase 15 and lists no Phase 15 orphan;
the scope contract remains SC1–SC4, each claimed by at least one plan and each accounted for in the
truths table above.

### Where this leaves the phase

Nine gap rounds have now produced the same shape five times: a fix is scoped to the branch, mechanism
or call site a report named, its correctness is written down as an invariant, and the invariant is
either false when written or made false by the next round. G-15-3 guarded an identity that could not
change instead of the drain-ness that could. G-15-6 was created by a fix that made a quantity honest
without sweeping the consumer that assumed it could only rise. G-15-7 is that consumer's fix,
attached to one of four movers and asserting there is one. G-15-8 is the sixth member of a
convergence family the phase has swept five times and never finished.

The recommendation is therefore procedural as much as technical: the closure plan for G-15-7 should
be gated on stating its invariant over the QUANTITY (`downloadIndex[gid]`, the value the numerator is
summed from) and enumerating its writers from source as evidence that the invariant covers them —
not on patching the two movers this report names. The same gate applies to G-15-8: sweep the
`schedulingBlockedGalleryIDs` insert set, do not fix `moveDownload`.

SC2 continues to need two independent things that do not substitute for each other: the gaps closed
in code, and `15-UAT.md` test 2 re-run on physical iOS 26 hardware, in that order. SC1 now needs the
same.

---

_Verified: 2026-08-05T04:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-05 by Claude (gsd-verifier) — round 10: G-15-6 verified closed in mechanism, SC1 downgraded to failed, six gaps G-15-7..G-15-12 recorded from 15-REVIEW.md and independently re-derived, WR-03 judged and deliberately not promoted, WR-06's reachability corrected downward._

---

## Amendment — 2026-08-05, round 11: after gap-closure plans 15-27..15-32

**Derived at HEAD `4e7608be`.** Everything below was re-derived in source at that HEAD. No closure
claim was accepted from a SUMMARY: each of the six gaps recorded in round 10 was re-checked against
the mechanism it named, and all 16 findings of the post-round-11 code review (15-REVIEW.md, same
commit) were assessed independently rather than imported.

### Evidence base

| Evidence | Result |
| --- | --- |
| Full `FeatureTests` test plan, single invocation at HEAD (established by the executor, cited not re-run) | `** TEST SUCCEEDED ** [102.786 sec]`, 0 compile errors, 0 failures |
| SwiftLint `--strict` over `AppPackage/Sources/DownloadClient/` and `AppPackage/Tests/DownloadsFeatureTests/` | clean; no file over the 1000-line gate, no line over 120 columns |
| `wc -l` over the module's test files | largest `DownloadCoordinatorStorageTests.swift` at 994, `DownloadContinuedSessionLedgerTests.swift` at 812 — the G-15-12 headroom item is closed |
| `grep 'public func'` over the nine session mutators | zero hits — G-15-11 closed |
| `grep forceUnwrapped` over `AppPackage/Sources/DownloadClient/` | zero hits — the G-15-12 WR-06 item is closed |
| Scheduler-symbol grep (`BGTaskScheduler`, `BGContinuedProcessingTask`, `BGProcessingTaskRequest`, `beginBackgroundTask`, `endBackgroundTask`) over `App/`, `ShareExtension/`, `AppPackage/Sources/` excluding the client module | zero hits — SC3/SC4 topology holds |

No `xcodebuild` invocation was issued by this verification.

### Gap closures re-derived in source

| Gap | Closing plan | Verdict |
| --- | --- | --- |
| G-15-7 | 15-29 (`46bf72de`) | ✓ CLOSED — the withdrawal is now a bracket around the whole preparation, keyed on the index-record delta, with one implementation shared by both call sites. It is no longer attached to an enumerated mover. |
| G-15-8 | 15-31 (`b1973e17`, `dab4a285`) | ✓ CLOSED — all six `moveDownload` exits release and converge, and the block became a reference count so overlapping operations no longer unblock on the first completion. |
| G-15-9 | 15-30 (`0cf7d1b1`) | ⚠️ PARTIAL — the total-scan case is guarded; the mass-partial case is not. Carried forward as **G-15-13**. |
| G-15-10 | 15-27 (`dc9ca42e`) | ✓ CLOSED — the spy's liveness guard and its armed refusal are separate guards, and only the refusal branch consumes the arm. |
| G-15-11 | 15-28 (`7a37e40b`) | ✓ CLOSED for the mutators; the state's `public var` residue is carried as part of G-15-18. |
| G-15-12 | 15-32 (`2c71852a`, `30e3473f`) | ✓ CLOSED — rename, named privacy-count map, active-gallery-union case, dead force-unwrap gone, file-length headroom restored. |

### Success criteria at this HEAD

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| SC1 | Foreground-started download continues after backgrounding, past the old grace window | ✓ VERIFIED | Device UAT test 1 `result: pass`; the round-10 defeat (G-15-8's hidden-gallery drain and unscheduled move) is closed in source with three regressions in `DownloadOwnershipConvergenceTests`. Residual risk from G-15-14 is an anomalous-input trap, not a failure of the continuation mechanism. |
| SC2 | System card reflects real progress; card-cancel matches the in-app cancel | ✗ FAILED | **G-15-13**: a mass partial probe failure still destroys up to N-1 recorded hashes and withdraws the same count from the monotonic floor for a movement that never happened. Separately still behaviour-unverified on hardware — 15-UAT.md test 2 reads `result: issue` and has not been re-run since the terminal push landed. |
| SC3 | Best-effort submission, no fallback tier, discretionary path and execution assertion deleted outright | ✓ VERIFIED | Device UAT test 3 `result: pass`; `BackgroundExecutionInvariantTests` bans all six deleted spellings, assembles each token at run time so the scan cannot self-match, keeps `App/Info.plist` fully in the forbidden-token scan and confines the scheduler name to the client module with one paid-for exemption; the `.unavailable` arm is silent by contract with no error surface. Warnings G-15-17 (the store's refusal branch is unexercised) and G-15-18 do not defeat it. |
| SC4 | One testable client seam exposing a continued-processing session API, `testValue` unimplemented, no reducer or coordinator touching the scheduler | ✓ VERIFIED | `BackgroundProcessingClient` exposes `start` / `updateProgress` / `finish` over a `BackgroundProcessingSession` whose `AsyncStream` self-finishes after `expired`, `unavailable` or `finish`; `@DependencyClient` leaves every endpoint unimplemented and `DownloadContinuedSessionTests:14` consumes that value; `.live` is wired at `DownloadClient.swift:77`; the scheduler-symbol grep is zero outside the module; all nine session mutators are module-internal since 15-28. Residual exposure of the session STATE is recorded in G-15-18. |

**Score: 3/4.** SC1 is restored from the round-10 downgrade. SC2 remains failed, now on G-15-13
rather than G-15-7.

### Two review findings judged and NOT promoted

- **WR-05 (the app still declares `UIBackgroundModes: [processing]`).** Confirmed present at
  `App/Info.plist:160-169` with an inline justification. It is not a gap: ROADMAP.md's Phase 15
  section records, under **Resolved in discuss-phase**, that `Info.plist` keeps its background-modes
  declaration and swaps only its permitted-identifier entry. That is a settled decision of this
  phase, not an oversight, and re-opening it would need the device-verified experiment the inline
  comment describes. The review's secondary suggestion — adding the key to
  `BackgroundExecutionInvariantTests` as a named exemption so it cannot be forgotten — is reasonable
  polish and is recorded here rather than as a gap. Note that the exemption the suite already
  carries is for `BGTaskSchedulerPermittedIdentifiers`, which is genuinely required; the two keys are
  not the same thing and the suite's comment is accurate about the one it names.
- **WR-08's stated harm (a synchronous launch wedging the session).** The ordering is real and is
  recorded inside G-15-18, but the harm is unreachable in production: `ContinuedProcessingSession`
  is `@MainActor`, the system delivers launches on the main queue, and `submit` therefore cannot
  reenter `start`. Recorded as hygiene on a seam built to be driven by doubles, not as a defect.

### The recurring failure mode, fifth occurrence

Round 10 recorded that G-15-7 was "the fourth consecutive round in which a fix scoped to a named
mechanism left its siblings open". Round 11 makes it five: 15-30 implemented G-15-9's
positive-signal requirement for the case its regression stages (a total scan failure) and left the
case its own doc comment claims to cover (per-file probe failure en masse) unguarded. The shape is
identical to G-15-6 → G-15-7: the fix is attached to the case, and the written rationale is broader
than the code.

The same shape appears three more times in documentation only, grouped as G-15-15: a recovery
mechanism claimed for four branches that exists on one, two functions in one file asserting opposite
things about whether the same chain suspends, and a "four writers, and no others" list that source
answers with five. G-15-3 and G-15-7 both trace to a wrong written premise, so these are recorded
rather than waived.

**Gate for the next round.** G-15-13's plan must state its invariant over the SIGNAL (no page may be
blanked on a non-answer) rather than over a threshold, and its regression must stage the partial
case — a directory listing that succeeds with per-file probes failing for most-but-not-all pages —
alongside a genuine-partial case that must still blank exactly the missing pages. A fix that only
raises the refusal threshold satisfies neither.

### Human verification, unchanged and independent

15-UAT.md test 2 still reads `result: issue` and its narrowed gap G-15-2B's terminal push has never
been observed on hardware. This is a separate axis from G-15-13: a green device run would not close
G-15-13, and closing G-15-13 would not discharge the device item. Run the device test after the
blockers close, or it will observe a known-defective blanking path.

---

_Verified: 2026-08-05T04:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-05 by Claude (gsd-verifier) — round 11: G-15-7, G-15-8, G-15-10, G-15-11 and G-15-12 verified closed in source; G-15-9 found only partially closed and carried forward as G-15-13; SC1 restored to verified; six gaps G-15-13..G-15-18 recorded; WR-05 and WR-08's stated harm judged and deliberately not promoted._
