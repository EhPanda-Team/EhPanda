---
phase: 15-continued-background-downloads
verified: 2026-08-06T03:00:00Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
amended: 2026-08-06T12:00:00Z
amendment_note: "This file is written in rounds and each part records the HEAD it was derived at; nothing is re-derived retroactively. The body above the FIRST amendment heading was written at HEAD d246b1a3, BEFORE gap-closure plan 15-22 landed. Gaps G-15-3 and G-15-4 were added afterwards from the post-15-22 code review (15-REVIEW.md, commit 7b8513d2) and confirmed against source by the execute-phase orchestrator; both were CLOSED by plans 15-23 and 15-24. Gap G-15-5 was added on top from the post-15-24 re-review (15-REVIEW.md, commit 613270a7), confirmed against source, and was CLOSED by plan 15-25. The SECOND amendment heading is round 9, written at HEAD 6fc528f1 after 15-25 landed: it verifies G-15-5's closure in source and records the new blocker G-15-6, re-derived independently from the post-15-25 review. The THIRD amendment heading is round 10, written at HEAD 829b55d8 after 15-26 landed: it verifies G-15-6's mechanism closed in source, records six new gaps G-15-7..G-15-12 re-derived independently from the post-15-26 review, and downgrades SC1 from verified to failed. The FOURTH amendment heading is round 11, written at HEAD 4e7608be after plans 15-27..15-32 landed: it verifies G-15-7, G-15-8, G-15-10, G-15-11 and G-15-12 closed in source, finds G-15-9 only PARTIALLY closed, restores SC1 to verified, and records six new gaps G-15-13..G-15-18 re-derived independently from the post-round-11 review (15-REVIEW.md, commit 4e7608be), with WR-05 judged and deliberately NOT promoted. The FIFTH amendment heading is round 12, written at HEAD 47d23e1c after plans 15-33..15-38 landed: it verifies G-15-13, G-15-14, G-15-15, G-15-16, G-15-17 and G-15-18 all closed in source, judges the three executor deviations of that round legitimate, restores SC2's code side while leaving it behaviour-unverified on hardware, downgrades SC3 to failed, and records three new gaps G-15-19..G-15-21 re-derived independently from the post-round-12 review (15-REVIEW.md, commit 47d23e1c), with WR-05 (the one-second deadlines) and IN-05 (doc-comment mass) judged and deliberately NOT promoted. The SIXTH amendment heading is round 13, written at HEAD 803c404a after plans 15-39, 15-40 and 15-41 landed: it verifies G-15-19 and G-15-21 closed in source and G-15-20 only PARTIALLY closed, independently adjudicates all seven findings of the post-round-13 review (15-REVIEW.md, commit 803c404a) — CONFIRMING CR-01, CR-02, WR-01, WR-03, WR-04 and WR-05 and REFUTING WR-02's asserted runtime concern against the device UAT record — downgrades SC2 from behaviour-unverified to FAILED on its code side, holds SC3 at failed, and records four new gaps G-15-22..G-15-25. The SEVENTH amendment heading is round 15, written at HEAD 6a0059d4 after plans 15-42..15-45 landed: it verifies G-15-22, G-15-24 and G-15-25 closed in source, finds G-15-23 only PARTIALLY closed, independently adjudicates all six findings of the post-round-14 review (15-REVIEW.md, commit 6a0059d4) — CONFIRMING every one of them against source — restores SC3 to verified, holds SC2 at failed, and records four new gaps G-15-26..G-15-29. The EIGHTH amendment heading is round 16, written at HEAD 3961698c after plans 15-46..15-49 landed: it verifies all four of G-15-26, G-15-27, G-15-28 and G-15-29 CLOSED in source before any SUMMARY was read — including the run-scoped proof's retirement points, checked against `processDownload`'s `defer` and BOTH settle paths as the seventh amendment's judgement (2) required — judges this round's three executor deviations legitimate, independently adjudicates all five findings of the post-round-15 review (15-REVIEW.md, commit 3961698c) and CONFIRMS every one of them, holds SC2 at failed on the inverse of the defect the last four rounds chased, and records four new gaps G-15-30..G-15-33."
next_action: "Close blocker G-15-30 (the run's proof of page work is a BOOLEAN, but membership in `observedIncompleteSessionGIDs` unlocks the record's FULL `completedPageCount` — and for the refusal family that count is precisely the work the run has NOT done, so the card opens at 100% before a byte is fetched, the numerator is frozen for the whole re-download, and any mid-run departure retires the ceiling into both sides of the fraction: the over-retirement `reconcileRetiredSessionPages`'s own doc names as `the defect`. It is the inverse of the pinned-ZERO defect rounds 12..15 chased, reached through the fix for it). Then the three warnings: G-15-31 (every session mints and registers a fresh `BGTaskScheduler` identifier whose handler can never be unregistered), G-15-32 (the `.unavailable` client double is atomic at all three endpoints, breaking the timing rule its sibling spy documents — the phase's recorded generator in its double-faithfulness form) and the hygiene pair G-15-33. Re-run 15-UAT.md test 2 on a physical iOS 26 device AFTERWARDS; that item is an independent axis and closing these gaps does not discharge it."
next_command: "/gsd-plan-phase 15 --gaps"
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "G-15-26 — CLOSED by plan 15-48 (commits 4acc408b, 8d769b40, 51fba0ad), re-derived in source at HEAD 3961698c before any SUMMARY was read. The proof is now owned by the RUN: `provenPageWorkRunGIDs` (`DownloadClient+Manager.swift:595`) is written unconditionally at the preparation (`+ExecutionSupport.swift:496`, outside the `if let continuedSessionID`), and every session start seeds the session trust set from it — `observedIncompleteSessionGIDs = provenPageWorkRunGIDs` (`+ContinuedSession.swift:246`) — inside the synchronous reset, ahead of the `schedulableSnapshot()` at `:248` the opening subtitle is built from. `markContinuedSessionEnded` still clears only the session set (`:401`), and its doc states at `:374` that the run-scoped set is deliberately not cleared there. **The retirement points were verified against `processDownload`'s `defer` and both settle paths, as the seventh amendment's judgement (2) demanded, and they hold.** `retireProvenPageWork` runs from the `defer` at `+Execution.swift:18`, placed AHEAD of `finishActiveTaskIfOwned` so an owning run does not read itself as superseded. Both settle paths were independently enumerated: `settleCompletedDownload` has exactly ONE production call site (`+Execution.swift:72`, the success path) and `settleDownloadFailure` has three (`+BackgroundDownloads.swift:110`, `:144`, `+Persistence.swift:171`), none of which the pre-fetch early return, the mid-run `guard !Task.isCancelled` or a suppressed-persistence failure arm reaches — so the `defer` is the only universal point, exactly as its own doc (`:278-302`) derives. `performDownload` has one production caller (`+Execution.swift:158`, inside `processDownload`), so no run reaches the preparation outside that `defer`'s reach. The other-side risk is guarded: `isSupersededByALiveRun` keeps a superseded predecessor from dropping a live successor's proof, and `testAProofDoesNotOutliveItsRunIntoALaterRedo` pins it — with its vacuous-pre-fix hazard stated in its own doc and its sensitivity recorded as observed."
    - "G-15-27 — CLOSED by plan 15-47 (commits 8d07e9f1, 54b6dd79), re-derived in source. `prepareWorkingSeedAnnouncingProgress` gates on the run's own pending page list (`+ExecutionSupport.swift:490-495`), which reads `payload.pageSelection` first, and hands that ONE evaluation onward via `PreparedWorkingRun` — `performDownload` consumes `preparedRun.pendingPageIndices` (`+ExecutionPerform.swift:47`) rather than recomputing it, and the comment at `:29-32` records why. The census is owned rather than asserted: `pendingPageIndices(` appears exactly once as a call in Sources (`+ExecutionSupport.swift:490`, the declaration at `:851` excluded), pinned by `DownloadSourceInventoryTests.testPendingPageListEvaluationsMatchTheRecordedCensus` (`:293`). The regression exists and discriminates: `testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero` (`DownloadContinuedSessionLedgerRefusalTests.swift:309`) asserts non-vacuity FIRST (five existing pages against a six-page manifest, page 3 present) and then the outcome by ABSENCE — every recorded update reads the queued window's zero."
    - "G-15-28 — CLOSED by plan 15-46 (commits b384b7fc, 0ce01ed0). `makeRetriedPagesPayload` (`DownloadFeatureTestHelpers.swift:560-576`) builds the payload through BOTH production steps in production order — the selection is placed on the payload and then refined by the production `normalizeFetchedPayload` — and applies `retryPages`' own dedupe-and-sort transform, so the double carries what the route stores rather than a literal. Every case that drives `retryPages` now uses it (`…LedgerRefusalTests.swift:117`, `:234`, `:351`, `:436` and `…LedgerTests.swift:645`), and `makeRepairPayload`'s doc now states that its nil selection is the FAITHFUL value for the routes that store none. The binding is owned by `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores` (`:400`), which drives `retryPages(pageIndices: [4, 2, 2])`, reads back `queuedPageSelections` and asserts `payload.pageSelection == Set(stored)`."
    - "G-15-29 — CLOSED by plan 15-49 (commits 23a27799, fc7b27ae), all three items verified by fresh greps at this HEAD. WR-03: a grep for the three retired phrasings over `Sources/DownloadClient` AND `Tests/DownloadsFeatureTests` returns ZERO, and the claim is now owned rather than corrected — `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority` (`DownloadSourceInventoryTests.swift:376`) reads whole files over a walk widened to `scannedDirectories = [clientModuleDirectory, downloadsTestDirectory]` (`:59`), with the detection tokens assembled from fragments (`:83-85`) so a repository grep cannot match the check itself. The widening hazard was handled rather than ignored: `clientModuleFiles(in:)` (`:471`) re-scopes every pre-existing census to the client module explicitly. WR-04: `completedCount` (word-bounded, excluding `completedPageCount` / `displayCompletedPageCount` / `completedUnitCount`) returns ZERO in `Sources/DownloadClient`. WR-05: `inFlightProgressUpdate` returns ZERO across the whole test target."
  gaps_remaining: []
  regressions:
    - "G-15-30 — a NEW over-report introduced by this round's own G-15-26/G-15-27 remedy, and the exact INVERSE of the pinned-ZERO defect rounds 12..15 chased. The proof is a boolean membership, but `schedulableSnapshot` unlocks the record's FULL `completedPageCount` on that membership (`+ContinuedSession.swift:159-162`) — and for the refusal family the record's count is by construction the ceiling the run has NOT yet earned, because `reconcileWorkingManifestAgainstPageFiles` returns the manifest verbatim on all three refusal exits and the flush path is monotone upward. So the family that used to report a pinned `0 / N` now reports a pinned `N / N`, and a mid-run departure retires `N` into BOTH sides of the fraction (`:603`, `:683-686`). Both new run-proof cases pin the 100% opening as the EXPECTED reading (`DownloadContinuedSessionRunProofTests.swift:129`, `:212`)."
  verification_scope_note: "Round 16 re-derived all four closure claims in source at HEAD 3961698c BEFORE any SUMMARY was read, and independently adjudicated all five findings of the post-round-15 review rather than adopting them. ALL FIVE ARE CONFIRMED (CR-01 -> G-15-30, WR-01 -> G-15-31, WR-02 -> G-15-32, WR-03 and WR-04 -> G-15-33); none was refuted. The seventh amendment's two do-not-relitigate judgements were honored: judgement (1) is moot because G-15-27 closed, and judgement (2) was DISCHARGED rather than assumed — the run-scoped proof's retirement was verified against `processDownload`'s `defer` and both settle paths by enumerating every settle call site in Sources and every exit of `processDownload`, and the outliving risk it warned about is separately guarded by `isSupersededByALiveRun` and pinned by a named case. CR-01 was checked in both directions: its mechanical half was re-derived (the boolean admission at `+ExecutionSupport.swift:495-501`, the full-count unlock at `+ContinuedSession.swift:159-162`, the retirement at `:603` and the both-sides addition at `:683-686`), its three consequences were each traced to source rather than accepted, and the reviewer's own falsification test was re-run and did NOT falsify it. Its ordinary-route reachability was verified independently too: downloads live under `.documentsDirectory` (`AppTools/FileUtil.swift:7-11`) and BOTH `UIFileSharingEnabled` (`App/Info.plist:170`) and `LSSupportsOpeningDocumentsInPlace` (`:145`) are true, so deleting a gallery's page files through the Files app and tapping resume is an ordinary user route into the refusal family. One judgement is recorded so the next round does not relitigate it: the harm that makes G-15-30 a BLOCKER rather than a display nitpick is consequence 3, not consequence 1 — a departure retires the ceiling into both sides and, when the departing gallery is the session's last, `reconcileContinuedSession`'s drain branch pushes `N / N pages · 0 galleries` and calls `finish(clientSessionID, true)` (`:508`, `:521`), so a PAUSED or expiration-swept repair is reported to the user as a fully successful N-page completion. `pauseAllSchedulable` makes D-11's expiration sweep one of those departures, so this is on the phase's own best-effort path rather than an exotic one. A fix must derive the numerator from the run's own shortfall in a way that reopens NEITHER G-15-26 (the proof must stay run-scoped and session-seeded) NOR G-15-27 (it must stay the same single `pendingPageIndices` evaluation); the reviewer's `provenPageWorkRunShortfalls` shape satisfies both by construction, but its decrement point must be derived rather than copied."
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
    closed_by: "15-33 (commits 86a41d6b, 8cff745a) — re-derived in source at HEAD 47d23e1c and verified closed in the round-12 amendment below. SCOPE RESIDUE: the per-file signal is honoured only within one folder scan; the repair-seed route is carried forward as G-15-19."
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
    closed_by: "15-34 (commits 7fde8793, 59bf406c) — verified closed by a module-wide sweep of every `1...` site plus both entrance dispositions. Residue: `captureCachedPage`'s `max(pageCount, 1)` widening, carried as part of G-15-21."
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
    closed_by: "15-35 (commit 55118093) — all three corrected premises re-checked against the code they describe."
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
    closed_by: "15-36 (commits b5f71242, 88f4eeab, 64df3d8f, fc0ffd11) — dead arms gone, `throws` and the unread parameter dropped, `reportIssue` added; `writeSettledPauseRecord` deliberately RESTORED rather than deleted, judged correct in the round-12 amendment below."
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
    closed_by: "15-38 (commits acc2f41a, 84522e08) — every `.unavailable` producer and both nil-launch arms executed, WR-07 driven rather than narrated."
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
    closed_by: "15-37 (commits 929ee241, 441ca960) — all six items verified in source; WR-09 landed as the gap record's SECOND authorized remedy, judged correct in the round-12 amendment below."
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
  - id: G-15-19
    closed_by: "15-39 — verified closed in source at HEAD 803c404a in the round-13 amendment below"
    severity: blocker
    source: "15-REVIEW.md CR-01 (post-round-12 review, commit 47d23e1c), every link independently re-derived in source by this verification; BOTH the stated harm and the reachability are NARROWED below and correct the review"
    introduced_by: "15-33 — the G-15-13 fix, by scoping. The laundering itself is older: `materializeRepairSeed` has always selected through the collapsed scan, and 15-25's D-G5-01 is what made the destination consumer destructive."
    truth_violated: "SC3's no-lost-or-duplicated-work clause — up to N-1 recorded content hashes are destroyed irreversibly and the same pages are re-downloaded, both on a probe's non-answer. D-G13-01, stated as absolute ('a non-answer is never authority to destroy a recorded hash'), does not survive the seed copy."
    summary: "The repair-seed materialization converts a per-file non-answer in the SOURCE folder into a positive absence in the DESTINATION folder. `unprobedPages` never crosses the copy, so round 12's defence sees a clean scan and blanks the page."
    detail: |
      Re-derived verbatim at HEAD 47d23e1c, and the chain holds:

      1. `setupWorkingFolder` (`DownloadClient+ExecutionSupport.swift:560-589`) reaches
         `storage.materializeRepairSeed(from:manifest:to:)` when the computed working folder does not
         exist and `repairSeed(for:payload:)` answers non-nil.
      2. `materializeRepairSeed` (`DownloadStore+Operations.swift:37-74`) copies the manifest WHOLE
         (`:47-50`), then selects pages through `existingPageRelativePaths(...)`, which is
         `pageFileScan(...).pages` and DISCARDS `unprobedPages` (`DownloadStore.swift:196-198`), and
         re-probes each with `sanitizeAssetFileIfNeeded` (`:72`), whose `Bool` forward is false for
         `.unprobeable` exactly as it is for `.rejected`. An unprobeable source page is not copied.
      3. `ensureWorkingManifest` finds the copied manifest valid at the destination (gid and
         `pageCount` both match) and returns it verbatim (`+ExecutionSupport.swift:517-527`).
      4. `storage.pageFileScan(folderURL: destination, manifest:)` lists a folder that genuinely does
         not hold that file: `scanSucceeded == true`, `unprobedPages` empty. Both new lines of the
         defence pass it through.
      5. `reconcileWorkingManifestAgainstPageFiles` blanks the hash (`:489`), writes the manifest
         (`:498`) and re-indexes (`:499`). The all-or-nothing residual does not catch the
         many-but-not-all population it was never meant to.

      The doc that classifies this route as safe is the artefact that hid it: `:402-404` lists "the
      repair-seed materialization, which copies only the pages whose source files existed and passed
      sanitization" among the modes the reconciliation handles — and "passed sanitization" is exactly
      where `.unprobeable` and `.rejected` are collapsed back together, one layer below the fix.
      `PageFileScan`'s own doc (`DownloadStore.swift:58-63`) licenses every non-destructive caller to
      collapse both pairs; `materializeRepairSeed` is treated as such a caller and is not one,
      because its output feeds a destructive decision one step later.

      **Harm, narrowed from the review.** The review says the floor withdrawal fires "for a movement
      that never physically happened". Traced, it does not: the destination folder really is missing
      the page, so the record's drop is honest and D-G7-01's withdrawal is accounting-correct. What
      is real, and is the whole of G-15-13's consequence, remains: recorded content hashes destroyed
      irreversibly on a non-answer, and the same pages re-downloaded. The card stays truthful about
      remaining work, so SC2's code side is not defeated here — it steps backwards by the blanked
      count, which is a liveness input to D-11's stall policy rather than a false reading.

      **Reachability, narrowed from the review.** This needs a CONJUNCTION, not a single condition:
      the mode must be `.repair` (`repairSeed` returns nil for every other mode), the existing
      download folder must exist, and the payload's computed folder path must NOT — the upstream
      title-change re-slot, which `DownloadCoordinatorRepairSeedTests
      .testRepairSeedReusesCompletedFilesWhenPageCountMatches` already exercises with fully probeable
      files — on top of the per-file probe failure G-15-13 was narrowed to. Narrower than G-15-13,
      identical in consequence, so it is recorded at the same severity.

      **Sweep that makes this scope derivable.** Every consumer of `pageFileScan` and
      `existingPageRelativePaths` in `AppPackage/Sources` was enumerated (11 call sites across
      `DownloadStore`, `DownloadStore+Operations`, `+ExecutionSupport`, `+ExecutionPerform`,
      `+PageDownload`, `+PersistenceHelpers`, `+BackgroundDownloads`, `+PublicAPI`). Exactly one
      destructive consumer exists — `reconcileWorkingManifestAgainstPageFiles` — and exactly one
      route can hand it a folder whose contents were derived from a DIFFERENT folder's probe:
      `materializeRepairSeed`. `addingCurrentFileHashes` throws `downloadStorePageMissing` on a
      non-answer (a failed download, recoverable) and `validatePage` returns `.missingFiles` (a
      re-fetch); neither destroys recorded state. `.redownload`/`.update` delete the folder and
      arrive at a fresh all-empty manifest, so the reconciliation is a no-op for them.
    why_tests_missed_it: "`testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing` stages its repair against the SAME folder the fixture wrote (`makeRepairPayload` keeps the title), so `shouldReuseWorkingFolder` returns true and the materialization branch is never taken. `DownloadCoordinatorRepairSeedTests.testRepairSeedReusesCompletedFilesWhenPageCountMatches` does take that branch, but with every source file fully probeable. No case crosses the two."
    suggested_fix: |
      State the invariant over the SIGNAL and over the whole route: a page the SOURCE probe could not
      answer for must never become a positive absence at the destination. Carry the source scan's
      `unprobedPages` across the copy — e.g. have `materializeRepairSeed` return the set (or have
      `setupWorkingFolder` hand it back through `RepairSeedContext`) and union it into the
      destination `PageFileScan` before `reconcileWorkingManifestAgainstPageFiles` consumes it, so
      the existing line-2 refusal covers the laundered pages with no new refusal mechanism.

      DO NOT take the review's suggested remedy verbatim. It proposes throwing from
      `materializeRepairSeed` and treating the refusal as "no seed" — but `setupWorkingFolder` then
      falls through to `createDirectory(at: folderURL)`, `ensureWorkingManifest` finds no manifest at
      the empty destination and writes a fresh all-empty one, and `updateDownloadIndex` republishes
      the record at 0-of-N. That converts a K-page hash loss into an N-page hash loss and a full
      D-G7-01 withdrawal: strictly worse than the defect it closes.

      Correct the doc at `+ExecutionSupport.swift:402-404` in the same change — "copies only the
      pages whose source files existed and passed sanitization" is the sentence that classified this
      route as safe, and a wrong written premise is what produced G-15-3, G-15-7, G-15-13 and this.

      The regression must cross the two stagings: `PartialProbeFailureFileManager` plus real `0o000`
      modes on most-but-not-all SOURCE page files, with a `.repair` payload whose title differs from
      the fixture folder so `setupWorkingFolder` takes the materialization branch. Assert no hash is
      blanked at the destination, no `updateDownloadIndex` fires and no withdrawal is taken. Keep a
      companion in which the source files are genuinely absent, so the fix cannot be satisfied by
      disabling destination blanking after a seed. Note `DownloadContinuedSessionBasisTests.swift` is
      at 996 lines against the 1000-line `file_length` error gate, so the new cases need a new file.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift"
  - id: G-15-20
    closed_by: "15-40 — PARTIALLY closed; the WR-01 residue is carried forward as G-15-24, see the round-13 amendment below"
    severity: warning
    source: "15-REVIEW.md WR-01, WR-02, WR-03, WR-04 and IN-01 (post-round-12 review); all five confirmed in source by this verification, WR-01 and WR-02 by enumerating the exits and the writers"
    introduced_by: "15-36 (WR-01, WR-02), 15-33 (WR-03, WR-04), 15-35 (IN-01) — every one of them written by this round's own doc corrections"
    truth_violated: "None directly at this HEAD. Recorded because it is the fourth consecutive round in which a load-bearing comment states an invariant source does not satisfy, and that shape has already produced G-15-3, G-15-7, G-15-13 and G-15-19."
    summary: "Five doc claims contradicted by the code they sit on: a convergence rule that names the wrong owner, a three-item writer list source answers with four, an existence-guard rationale false for seven of its nine callers, an all-or-nothing premise the round-12 fix invalidated, and a positional count that is wrong."
    detail: |
      - **WR-01** — `schedulingBlockedGalleryCounts`'s doc (`+Manager.swift:401-406`) says
        "`commitPause` is the one site whose convergence its callers own on every path instead".
        Source: of `commitPause`'s five exits, three converge INLINE — the vanished-record exit
        (`+Scheduling.swift:229-236`), the wrong-status exit (`:246-251`) and the settled-success
        exit (`:262-268`) each call `notifyObservers()` then `scheduleNextIfNeeded()` — and only the
        two `.superseded` exits (`:239-243`, `:257-260`) delegate one frame up. `commitPause`'s own
        inline comments say so ("The release comes first on every exit below"), so the file
        contradicts itself. A reader adding a sixth exit and trusting the stated rule reproduces
        G-15-8 at the one site the rule was written to describe.
      - **WR-02** — `writeSettledPauseRecord`'s doc (`+Scheduling.swift:311-319`) enumerates the
        writers it re-clears as `performRetry`, `performRetryPages` and `resume(gid:)`.
        `enqueue(payload:)` is a fourth: it takes no scheduling block (the only `blockScheduling`
        call sites are `commitPause`, `delete`, `deleteFolder`, `moveDownload` and the DEBUG
        forwarder), calls `advanceQueueIntentGeneration` and `await queueStore.enqueue(...)`
        (`+PublicAPI.swift:99-100`), and is reachable from a user tap while a pause is parked on
        `await taskToCancel?.value`. Behaviour is correct — it is re-cleared exactly like the other
        three — but a three-item list source answers with four is the recorded shape of G-15-7.
      - **WR-03** — `probeAssetFile`'s guard comment (`DownloadStore.swift:692-695`) justifies
        `.unprobeable` on a failed `fileExists` with "the callers hand this a file a directory
        listing just produced". True for `pageFileScan` and `existingAssetFileURL(in:prefix:)`, and
        false for the seven `sanitizeAssetFileIfNeeded` call sites in `DownloadStore+Operations.swift`
        (`:11, 58, 72, 242, 249, 258, 301`), which pass URLs built from a manifest relative path. For
        those a missing file is a POSITIVE absence and is classified as the one outcome the enum
        exists to mark as never-authority-to-destroy. Collapsed today by the `Bool` forward, so no
        behaviour differs — but the enum's own stated purpose ("a new exit cannot default into
        'positively absent': it has to be named") is inverted, and G-15-19 is the first consumer to
        inherit it.
      - **WR-04** — the residual guard's comment (`+ExecutionSupport.swift:493`) still reads "Only
        claimed pages are blanked above, so equality here means every one of them would go". The
        round-12 loop also excludes `unprobedPages` (`:487`), so the maximum reachable
        `blankedPageCount` is `completedPageCount − |unprobed ∩ claimed|`: with even one unprobed
        claimed page the equality is structurally unreachable and line 3 of the documented
        three-line defence is silently disabled for exactly the mixed population. The resulting
        behaviour is the correct one, so this is a stated-invariant defect, not a wrong outcome.
      - **IN-01** — `continuedSessionTask`'s doc (`+Manager.swift:434`) says "like the eight above";
        four of the nine session-state declarations precede it (`:408, 416, 422, 430`) and four
        follow (`:469, 483, 492, 510`). Small alone, misleading next to the five-writer inventory
        directly below it, which IS load-bearing and IS correct.
    suggested_fix: "WR-01: state the actual split — `commitPause` converges inline on every `.settled` exit and hands convergence up on its two `.superseded` exits. WR-02: add `enqueue(payload:)`, or better, replace the enumeration with the invariant it stands for (every queue-mobilizing entry point takes no scheduling block, so any of them can land inside the wait). WR-03: either restate the comment to say the classification is meaningful only for listing-derived URLs, or split the probe so a caller with a constructed path gets `.rejected` for a missing file — decide which, since G-15-19's fix touches the same seam. WR-04: compare against the blankable population rather than the claimed one and correct the sentence. IN-01: 'like the other eight'. Where an inventory is genuinely load-bearing, prefer a test that fails when it drifts — the pattern `DownloadLogPrivacyInvariantTests.expectedHashMaskedCounts` already establishes — over a comment asking the reader to re-run a grep. That is IN-05's actionable half, folded in here."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Sources/DownloadClient/DownloadStore.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
  - id: G-15-21
    closed_by: "15-41 — verified closed in source at HEAD 803c404a in the round-13 amendment below"
    severity: warning
    source: "15-REVIEW.md WR-06, IN-02, IN-03, IN-04 (post-round-12 review); each confirmed verbatim in source by this verification, plus one file-length headroom item this verification found itself"
    introduced_by: "mixed — WR-06 and IN-02 predate the phase; IN-03 is the one page-count site the G-15-14 sweep widened rather than guarded"
    truth_violated: "None directly. Grouped because this project's bar treats nitpicks as blocking."
    detail: |
      - **WR-06** — `normalizeNeedsAttentionDownloads` (`+PersistenceNormalize.swift:32-48`) guards on
        `displayStatus == .error || shouldClearCancellationError` and then acts only under
        `shouldClearCancellationError`, so the first disjunct admits an iteration whose body does
        nothing. The function is exactly equivalent to the `if` alone. Dead code shaped like a lost
        branch invites a future edit to "restore" behaviour that never existed, and the name promises
        an `.error` normalization the body does not perform.
      - **IN-02** — `buildInspectionPages` (`+PublicAPIHelpers.swift:34-42`): the
        `if let failedPage` arm's `return .init(…)` is indented four spaces deeper than its two
        sibling arms, so a single three-way selection does not line up. No lint rule catches it
        (`indentation_width` is not opt-in here), which is why it survived.
      - **IN-03** — `captureCachedPage` (`+PublicAPI.swift:286-289`) bounds its index with
        `index <= max(download.pageCount, 1)`, ADMITTING index 1 for a zero-page record. It is the
        one page-count site the G-15-14 sweep widened rather than guarded; every other site now
        refuses zero. Reachability is closed upstream (`enqueue` refuses a zero-page payload and
        `validateDecodedManifest` rejects an empty page dictionary), so it is latent — but it would
        write a page file no manifest claims, invisible to `pageFileScan` and skipped by
        `refreshManifestPageFileHashes`.
      - **IN-04** — `payload.pageSelection.map(Set.init)` (`+ExecutionSupport.swift:695`) rebuilds a
        `Set` from a value already declared `Set<Int>?`
        (`AppModels/Download/DownloadedGallery+Extensions.swift:30`). Harmless; it reads as a
        conversion and invites the reader to look for an `[Int]` that is not there.
      - **File-length headroom (found by this verification, not in the review).**
        `DownloadContinuedSessionBasisTests.swift` is at 996 lines against the project's 1000-line
        `file_length` ERROR gate. G-15-12 restored this headroom one round ago and round 12 consumed
        it. G-15-19's regression cannot go in this file.
    suggested_fix: "WR-06: delete the dead disjunct (or rename the function to match what it does). IN-02: re-indent to match the sibling arms. IN-03: `guard download.pageCount > 0, index >= 1, index <= download.pageCount else { return }`, with a one-line comment tying it to the same class as the seven range sites. IN-04: `let selectedIndices = payload.pageSelection`. Headroom: split `DownloadContinuedSessionBasisTests.swift` before adding G-15-19's cases."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
  - id: G-15-22
    severity: blocker
    closed_by: "15-42 (commits 5cee098c, 92a5707b) — re-derived in source at HEAD 6a0059d4 and verified CLOSED in the round-15 amendment below"
    source: "15-REVIEW.md CR-01 (post-round-13 review, commit 803c404a); every link independently re-derived in source by this verification, and the reachability window is NARROWED below to the one interleaving that actually escapes the two guards already present"
    introduced_by: "15-23 — the G-15-3 fix, which introduced `ExpirationPauseOwnership` and the per-iteration generation read. The doc written with it claims the broader coverage the code does not implement."
    truth_violated: "SC3 — an expiration must leave download state consistent with an in-app cancel and lose no work. A gallery the user has just mobilized is instead silently paused away, and the session that tap requested is never started, so the tap produces nothing at all. SC1 is reached through the same door for that gallery."
    summary: "`pauseAllSchedulable` snapshots the gid list once but reads each gallery's queue-intent generation at the top of that gallery's OWN iteration, so the ownership comparison can only detect a mobilizing tap that lands DURING that gallery's pause. A tap landing after the snapshot and before the iteration advances the generation first; the loop then records the already-advanced value and the stale expiration pause succeeds."
    detail: |
      Verbatim at HEAD 803c404a (`DownloadClient+ContinuedSession.swift:356-366`):

          func pauseAllSchedulable(expiring sessionID: UUID) async {
              let gids = await schedulableDownloads().map(\.gid)      // snapshot taken ONCE
              for gid in gids {
                  guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
                  let expiration = ExpirationPauseOwnership(
                      sessionID: sessionID,
                      queueIntentGeneration: queueIntentGeneration(for: gid)   // read PER ITERATION
                  )
                  _ = await pause(gid: gid, expiration: expiration)
              }
          }

      `ownsExpirationPause` (`+Scheduling.swift:271-278`) compares `queueIntentGeneration(for: gid)`
      against `expiration.queueIntentGeneration`. Because the expected value is read inside the
      gallery's own iteration, a tap that already advanced that gallery's generation is recorded as
      the expectation, the comparison succeeds, and the pause settles over the user's action.

      The two guards that DO exist were traced, and the window is what neither covers:

      - **Loop-level session guard.** The `.expired` arm calls `markContinuedSessionEnded` BEFORE
        `pauseAllSchedulable` (`:305-308`), so `continuedSessionID` is `nil` at loop entry. If a
        mobilizing tap runs to completion — including its trailing `ensureContinuedSession()` — and
        that ensure MINTS a successor, then `continuedSessionID` is a third value and the guard fails
        on the next iteration, returning. So the fully-completed-tap case IS covered.
      - **Per-gallery generation guard.** A tap landing INSIDE gallery B's own pause (across
        `fetchDownload`, `writeInitialPauseRecord`'s queue-store and background-task hops, the
        unbounded `await taskToCancel?.value`, `notifyObservers` or `scheduleNextIfNeeded`) advances
        the generation after it was read, so `ownsExpirationPause` fails, `commitPause` returns
        `.superseded`, and `pause`'s `.superseded` arm re-converges AND re-ensures. Covered.

      **The uncovered window is exactly `[advanceQueueIntentGeneration, ensureContinuedSession)` of a
      mobilizing entry point, intersected with the start of that gallery's loop iteration.** Every
      mobilizer advances the generation several suspensions before it ensures, verified by
      enumerating all four callers of `advanceQueueIntentGeneration(for:)` in
      `AppPackage/Sources/DownloadClient`: `enqueue` (`+PublicAPI.swift:99`, then `await
      queueStore.enqueue` / `await notifyObservers` / `await scheduleNextIfNeeded`, ensure at `:107`),
      `resume` (`+Scheduling.swift:360`, ensure one frame up in `togglePause` at
      `+PublicAPI.swift:194`), `performRetry` (`+RetryHelpers.swift:37`, ensure at `:18`) and
      `performRetryPages` (`:89`, ensure at `:70`). `queueStore.enqueue` awaits a `Shared`
      `.fileStorage` save and `notifyObservers` hops to `observerHub`, so those are real suspensions
      on a reentrant actor, not notional ones.

      Inside that window the loop's session guard passes (`continuedSessionID` is still `nil`), the
      generation read returns the ALREADY-ADVANCED value, `commitPause`'s
      `[.queued, .active].contains(displayStatus)` gate admits the freshly enqueued gallery, and the
      pause settles.

      **The design's own compensation is bypassed, which is what makes this a defect rather than a
      race with a benign outcome.** `pause`'s `.superseded` arm documents at `+Scheduling.swift:190-200`
      that a mobilizing tap's own ensure is expected to be inert — "THIS pause still held the
      gallery's scheduling block when it ran: `isSchedulableDownload` rejects a blocked gid, so
      `hasPendingWork()` answered false and the action's own ensure returned at its first guard" —
      and that the `.superseded` re-ensure is what rescues it. On this branch the pause does NOT go
      superseded, so that re-ensure never runs. The tap's own ensure then finds the gallery blocked
      by the very pause that is undoing it, `hasPendingWork()` answers false, and no session starts.
      Net user-visible result: the download the user just started is not running and no card appears.

      **What would falsify this:** a mobilizing entry point that stamps `continuedSessionID` before
      it advances the generation. The four-caller enumeration above is exhaustive and none does.
    why_tests_missed_it: "`DownloadContinuedSessionInterleaveTests.testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` (`:22`) stages ONE gallery and lands the retry inside that gallery's own cancellation hold — precisely the case the per-iteration read does cover. `DownloadContinuedSessionExpirationTests.testExpirationResultIsIndependentOfEnqueueOrder` (`:79`) runs three galleries but mobilizes nothing mid-loop. No case crosses multi-gallery with a mid-loop mobilization."
    suggested_fix: |
      Capture every gallery's generation in the SAME synchronous stretch that captures the gid list,
      so a tap landing anywhere after the expiration advances a generation the loop has already
      RECORDED rather than one it is about to read. The hoist is sound because `schedulableDownloads()`
      performs no suspending call today — `queueStore.gids` is a synchronous property read and
      `indexedDownloads(gids:)` awaits nothing internally — which is the identical justification
      `ensureContinuedSession` (`:177-182`) and `pushContinuedSessionProgress` (`:569-573`) already
      record for their own guards, so the three stay consistent and the same re-validation note
      applies if an `await` is ever introduced there.

      Use a labelled tuple or a small named struct (`labeled_tuple_elements` is an error-severity rule
      here). Do NOT widen `ownsExpirationPause` itself: the user-pause side deliberately has no
      generation guard, and `testAUserPauseIsNeverAbandonedByAnInterleavingRetry` pins that asymmetry.

      The regression must be multi-gallery and must land the tap BEFORE the target gallery's
      iteration, not inside its pause — the existing interleave case already covers the latter, and a
      fix cannot be proven by it. Stage at least two schedulable galleries, expire, hold the FIRST
      gallery's pause, mobilize the SECOND from inside that hold, release, and assert the second
      gallery is still queued with its intent intact and that a session was started for it. Also
      assert the loop did not simply return early, or the case passes for the wrong reason.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift"
  - id: G-15-23
    severity: blocker
    closed_by: "15-43 (commits 1a201867, 8570cd5b) — PARTIALLY closed. The real-page-work gate and the explicit trust insert landed and are verified in source, but the proof they record is SESSION-scoped while the fact is a property of the RUN, so two production orderings still produce this gap's zero-progress card. The residue is carried forward as G-15-26."
    source: "15-REVIEW.md CR-02 (post-round-13 review, commit 803c404a); every link independently re-derived in source by this verification, with the reachability BROADENED from the review's single staging to the whole refusal family and the harm re-stated"
    introduced_by: "15-25 — D-G5-01, whose announcement gate is `!workingSeed.manifest.isComplete`. Every refusal line added since (G-15-9 in 15-29, D-G13-01 in 15-33, the G-15-19 carry in 15-39) widened the population that reaches the gate with a still-complete manifest."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress. A full N-page re-download reports zero session progress for its entire run and the session finishes on a terminal `0 / 1 page · 0 galleries`. SC1 follows through D-11: the scheduler force-expires the tasks reporting least progress, and an expiration here pauses every schedulable download."
    summary: "When `reconcileWorkingManifestAgainstPageFiles` REFUSES over a record whose manifest reads complete, the manifest comes back complete, `prepareWorkingSeedAnnouncingProgress` skips its announcement, the gid never enters `observedIncompleteSessionGIDs`, and D-G4-01's basis counts zero for the gallery from its first push to its untrusted departure. That is G-15-5's exact shape, surviving inside the branches the positive-signal defence created."
    detail: |
      Re-derived at HEAD 803c404a, link by link:

      1. `reconcileWorkingManifestAgainstPageFiles` (`+ExecutionSupport.swift:504-547`) has THREE
         refusal exits that all `return manifest` unchanged: `guard pageFileScan.scanSucceeded`
         (`:509`), the per-file `unprobedPages` skip leaving `blankedPageCount == 0` (`:516, :521`),
         and the all-or-nothing residual `guard blankedPageCount < manifest.completedPageCount`
         (`:530`). Over a record whose manifest claims all N pages, the third fires exactly when all
         N page files are absent, and the first fires on any failed directory enumeration.
      2. A refusal writes no manifest and calls no `updateDownloadIndex`, so the index record the
         numerator is summed from still reads complete.
      3. `prepareWorkingSeedAnnouncingProgress` (`:379-393`) gates its announcement on
         `!workingSeed.manifest.isComplete`, which is now FALSE. No push is issued.
      4. `schedulableSnapshot`'s D-G4-01 basis is `download.isIncomplete ||
         observedIncompleteSessionGIDs.contains(download.gid)` (`+ContinuedSession.swift:127-128`).
         The trust set is only ever GROWN from `snapshot.incompleteGalleryIDs`: grepping every
         occurrence of `observedIncompleteSessionGIDs` in `AppPackage/Sources` gives one declaration
         (`+Manager.swift:522`), two resets to empty (`+ContinuedSession.swift:205, :340`), two reads
         (`:128`, `+ExecutionSupport.swift:275`), one read in the departure gate (`:509`) and exactly
         TWO additive writers, both `formUnion(snapshot.incompleteGalleryIDs)` (`:264, :529`) — and
         `incompleteGalleryIDs` is `Set(downloads.filter(\.isIncomplete).map(\.gid))` (`:142`), which
         by construction cannot contain a complete-reading record. There is no `insert`. So the gid
         contributes 0 to the numerator and N to the denominator for the whole run.
      5. The record never becomes honest during the run. `flushManifestPageProgress` reaches
         `refreshManifestPageFileHashes` (`DownloadStore+Operations.swift:179-208`), which only ever
         assigns `pages[page] = try hashReadableAsset(...)` — a non-empty string, since
         `hashReadableAsset` throws rather than returning empty (`:290-301`). `completedPageCount`
         counts non-empty hashes, so it can only rise or hold; `isIncomplete` can never become true.
         The sibling writers were checked the same way: `addingCurrentFileHashes` fills empty hashes
         only (`:120-146`), `ensureWorkingManifest`/`writeInitialManifest` write fresh manifests and
         are not taken for a `.repair` holding a valid stored manifest, and
         `reconcileWorkingManifestAgainstPageFiles` is the branch that just refused.
      6. At departure `reconcileRetiredSessionPages` finds the gid outside the trust set and retires
         `observedSchedulablePages[gid] ?? 0` = 0 (`+ContinuedSession.swift:509-513`), added to BOTH
         sides, so the gallery leaves the fraction entirely. A single-gallery session drains to
         `DownloadProgress(0, 0)`, whose `displayPageCount` floors at one: the terminal push reads
         `0 / 1 page · 0 galleries` over a completed N-page re-download.

      **The written premise that hid it.** The D-G5-01 doc closes with "A genuinely all-pages-vanished
      repair is no longer reconciled: it falls back to the pre-D-G5-01 arc, where the seed's empty
      `existingPages` makes the run re-fetch every page and **the record's honesty catches up at flush
      time**" (`:496-503`). Step 5 is the refutation: the record was claiming MORE than the disk held,
      and the flush path is monotone upward, so nothing about that record ever reads incomplete and
      the trust set is never reachable. The sentence describes the cost as bounded when the cost is
      exactly the liveness hazard D-G5-01 was created to remove.

      **Reachability, broadened from the review rather than narrowed.** The review stages "every page
      file gone" via the residual guard. That is one member of the family; the directory-level refusal
      (`scanSucceeded == false`, one transient `contentsOfDirectory` failure) produces the identical
      run. Two production routes put a complete-reading record into `.repair`, both re-derived:
        (a) `queuedMode`'s interrupted-work branch. `queuedModes` is in-memory while
            `DownloadQueueStore` persists its gids through `Shared(.fileStorage)`
            (`DownloadQueueStore.swift:11-13`), so after a relaunch a gid restored into the queue has
            no mode, `displayStatus` is `.queued`, `shouldSchedule` admits it, and
            `queuedMode` -> `interruptedWorkMode` returns `.repair` for any record with
            `completedPageCount > 0` (`+SchedulingHelpers.swift:30-34, :75-79`).
        (b) `retryPages` -> `resumeMode` -> the `storage.validate` `.missingFiles` branch
            (`+RetryHelpers.swift:52`, `+SchedulingHelpers.swift:62-67`). This is not theoretical:
            `DownloadContinuedSessionLedgerTests.testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`
            drives exactly this route in production shape and asserts `resumeMode == .repair` for a
            complete-reading record before calling `retryPages`.
      `resumeMode`'s own doc names the refusal as one of exactly two states that still arrive there —
      "(a) the reconciliation REFUSED its destructive half" (`+SchedulingHelpers.swift:50-61`) — so the
      module already asserts this loop exists. Once a refusal happens the state is self-sustaining:
      the record stays complete, the next run resolves `.repair` again, and reports zero again.
    why_tests_missed_it: "`DownloadContinuedSessionLedgerTests.testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` (`:597`) covers K = 1 missing page of 6 — `writePageFiles(..., indices: [1, 2, 4, 5, 6])` — where the reconciliation PROCEEDS (`1 < 6`), the manifest comes back incomplete, and the announcement fires. Nothing stages K = N, and nothing stages a refusal over a complete-reading record at all. The three reconciliation-refusal cases in `DownloadContinuedSessionReconciliationTests` assert that nothing is blanked, written or withdrawn — the correct assertions for D-G13-01 — but none of them asserts what the SESSION then reports for the run that follows, which is where this defect lives. `DownloadRepairSeedSignalPropagationTests` covers the seed copy, not the announcement gate."
    suggested_fix: |
      The announcement basis must follow "this run has real page work to do over this record", not
      "the manifest now reads incomplete". The working seed already knows: `workingSeed.existingPages`
      is short of `workingSeed.manifest.pageCount` exactly when the folder cannot supply the pages the
      manifest claims, and that is true on every refusal branch as well as on the proceeding one.

      Admitting the gid to `observedIncompleteSessionGIDs` explicitly is required IN ADDITION to
      issuing the push: the push's own trust admission is a `formUnion` sourced from
      `snapshot.incompleteGalleryIDs`, which by construction cannot contain a complete-reading record,
      so an announcement alone changes nothing on this branch. Verify that claim against source before
      taking the fix, and do not assume it from this record.

      Two constraints the fix must not break, both of them earlier gaps:
        - D-G4-01's ceiling guarantee (G-15-4): a complete record merely QUEUED for an update,
          redownload or bare re-enqueue must still open the card at zero, not at its own ceiling. The
          new trust must be granted at the run's own preparation, never at queue time.
        - D-G7-01's withdrawal accounting (G-15-6/G-15-7): admitting a gid to the trust set changes
          `withdrawingCountedBasisMovement`'s `wasCountedBasis` test (`+ExecutionSupport.swift:274-275`).
          Check the ordering of the insert relative to the enclosing bracket and state which side it
          lands on and why.

      Regression: a ledger case at K = N (fixture manifest complete, NO page files staged) driven
      through the production `retryPages` route, asserting the drain reports `N / N pages · 0
      galleries` rather than `0 / 1 page · 0 galleries`; plus a companion staging the DIRECTORY-level
      refusal (`scanSucceeded == false`) over the same complete-reading record, so the fix cannot be
      satisfied by handling only the all-or-nothing residual. Keep the existing K = 1 case unchanged —
      it pins the side the fix must not move. `DownloadContinuedSessionLedgerTests.swift` is at 812
      lines against the 1000-line `file_length` error gate.
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
  - id: G-15-24
    severity: warning
    closed_by: "15-44 (commits dd9fc9ec, 8a909db6) — re-derived in source at HEAD 6a0059d4 and verified CLOSED in the round-15 amendment below. Its Sources half is closed; the same retired sentence surviving in the TEST suite is a new finding, carried as G-15-29."
    source: "15-REVIEW.md WR-01 and WR-02 (post-round-13 review); WR-01 confirmed by enumerating the call sites, WR-02 REFUTED as an asserted runtime concern and folded in here as the documentation item it actually is"
    introduced_by: "15-40 — this round's own doc-correction plan preserved the false half of the sentence it rewrote. The sibling claim in `+PendingWork.swift` predates it and was never in any round's scope."
    truth_violated: "None directly at this HEAD. Recorded because this is the FIFTH consecutive round in which a load-bearing comment states an invariant source does not satisfy — the generator that produced G-15-3, G-15-7, G-15-13, G-15-19 and the five items of G-15-20 — and the second round in a row in which the false sentence was written by the previous round's own correction work."
    summary: "`schedulableDownloads()` is documented in two places as the read authority the SCHEDULER uses. It is not: the scheduler performs its own scoped index read and shares only the predicate. Plus one genuinely open contract question about post-launch `BGTaskScheduler.register` that now has device evidence and deserves the note the reviewer asked for."
    detail: |
      - **WR-01 — the "one authority" claim, confirmed by enumeration.** Grepping
        `schedulableDownloads()` across `AppPackage/Sources` gives the declaration
        (`+PendingWork.swift:42`), three call sites — `schedulableSnapshot()`
        (`+ContinuedSession.swift:122`), `pauseAllSchedulable` (`:357`) and `hasPendingWork()`
        (`+PendingWork.swift:14`) — and five doc-comment mentions. `scheduleNextIfNeededCore`
        (`+Scheduling.swift:38-53`) is NOT among the call sites: it takes `queueStore.gids`, performs
        its own `indexedDownloads(gids: queuedGIDs)` and applies `isSchedulableDownload` through
        `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`. Two docs assert otherwise:
        `+PendingWork.swift:17-20` ("Scheduling, the pending-work gate and the continued-session card
        all select through this function") and `+Manager.swift:387-388` ("the single authority the
        card, the pending-work gate and the scheduler all read"), the latter written by THIS ROUND's
        WR-01 correction.
        What is genuinely shared is the PREDICATE, not the read scope, and the divergence is real
        rather than notional: the active-gallery union added at `+PendingWork.swift:44-47` is exactly
        what the scheduler's scoped read does not carry. It is inert today only because
        `scheduleNextIfNeededCore` returns at `guard activeTask == nil` (`:44`) whenever an active
        gallery exists. The correction must state the split, name where the scheduler's own read
        lives, and record why the divergence is currently inert — and, on the pattern this round
        established for the other two censuses, pair it with a `schedulableDownloads()` call-site
        entry in `DownloadSourceInventoryTests` so the claim is owned rather than merely corrected.
      - **WR-02 — post-launch registration, REFUTED as a defect and kept as a note.** The mechanical
        half is true and was re-derived: `BGTaskScheduler` appears in exactly one file
        (`ContinuedTaskScheduling.swift`), its `register` closure is reached only from
        `ContinuedProcessingSession.start` (`:141-147`), and `AppDelegate`
        (`AppDelegateReducer.swift:60-79`) registers nothing. But the concern — that a registration
        after `didFinishLaunchingWithOptions` may not be honoured — is answered by evidence already in
        this phase's record: 15-UAT.md test 1 reads `result: pass` on physical iOS 26 hardware, with
        pages continuing to land well past the deleted `beginBackgroundTask` window. That outcome
        requires the task to have launched, which requires the registration to have been accepted. The
        design is therefore device-proven. What remains is the reviewer's own remedy: a device-verified
        note beside `ContinuedTaskScheduling.live.register`, in the shape of the existing
        `App/Info.plist:160-165` note, recording that a per-session UUID identifier under the
        `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` wildcard makes pre-launch registration structurally
        impossible, that post-launch registration was accepted on device, and which UAT run showed it.
        Without that note the next reader re-opens the same question from the same absence.
    suggested_fix: "Correct both 'one authority' sites to state what is actually shared (the predicate) and where the scheduler's own read lives, with the `guard activeTask == nil` reason the divergence is inert; add a `schedulableDownloads()` call-site census to `DownloadSourceInventoryTests` on the pattern that file already establishes. Add the device-verified registration note. Derive every corrected sentence from a fresh enumeration of the source it describes and quote that enumeration — this gap exists because the previous round's correction was written without one."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift"
  - id: G-15-25
    severity: warning
    closed_by: "15-45 (commits 3f896c6d, a87cd1ba) — all four items re-derived in source at HEAD 6a0059d4 and verified CLOSED in the round-15 amendment below. The `prefix` removal left `PageDownloadProgress.completedCount` with no reader; that residue is a new finding, carried as G-15-29."
    source: "15-REVIEW.md WR-03, WR-04 and WR-05 (post-round-13 review), each confirmed verbatim in source by this verification, plus the dead-public-API item round 13 found itself and deliberately deferred"
    introduced_by: "mixed — WR-03 and WR-05 predate the phase; WR-04 is residue from the round-by-round edits; the dead API predates the phase and was surfaced by 15-40's WR-03 enumeration"
    truth_violated: "None directly. Grouped because this project's bar treats nitpicks as blocking."
    detail: |
      - **WR-03 — a `prefix` that is always the whole array.** `restoredIndices`
        (`+PageDownload.swift:42-46`) computes
        `Set(progress.results.prefix(progress.completedCount).map(\.index))`.
        `progress.completedCount` is assigned `progress.results.count` at `:97`, inside
        `initializePageDownloadState`, immediately before this runs; the only other writer is
        `progress.completedCount += 1` at `:254` in `applyPageTaskOutcome`, which runs later. The
        `prefix` therefore always returns the entire array. It reads as a deliberate bound and is not
        one. Fix: `Set(progress.results.map(\.index))`.
      - **WR-04 — stray trailing blank line before a closing brace**, at
        `+ContinuedSession.swift:625` and `+Scheduling.swift:370`. Confirmed present in both, and
        confirmed unlintable here: `vertical_whitespace_closing_braces` is opt-in and the root
        `.swiftlint.yml` `opt_in_rules` list is `force_try`, `force_unwrapping`,
        `multiline_function_chains`, `sorted_imports` only. No other file in the module does this.
      - **WR-05 — unintended trailing comma in a parameter list.**
        `clearSelectedFailedPages(gid:selectedPageIndices:)` (`+PublicAPIHelpers.swift:54-57`) ends
        its parameter list with `selectedPageIndices: [Int],`. Swift accepts it and `trailing_comma`
        is not configured for parameter lists, so it compiles and lints clean; it is the only
        occurrence in `Sources/DownloadClient` and reads as an unfinished edit.
      - **Public dead API, adopted from 15-40's and 15-41's out-of-scope note rather than left in a
        summary.** `validPageCount(folderURL:manifest:)` (`DownloadStore+Operations.swift:271`) has
        NO caller in `AppPackage/Sources` or `AppPackage/Tests`; `isReadableAssetFile(at:)` (`:286`)
        has none in Sources and exactly one in Tests (`DownloadStoreTests.swift:311`). Verified by
        grepping both symbols across `App/`, `AppPackage/Sources` and `AppPackage/Tests`. Both were
        correctly out of scope for a doc-correction plan; they are recorded here so the decision is
        made deliberately (delete, or keep with a stated reason) rather than deferred a third time.
    suggested_fix: "WR-03: drop the `prefix`. WR-04: delete both blank lines. WR-05: delete the trailing comma. Dead API: decide delete-or-justify for `validPageCount` and `isReadableAssetFile`, and if either is kept, record why a public symbol with no production caller stays."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift"
      - "AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift"
  - id: G-15-26
    severity: blocker
    closed_by: "15-48 (commits 4acc408b, 8d769b40, 51fba0ad) — re-derived in source at HEAD 3961698c and verified CLOSED in the round-16 amendment below. The proof is now run-scoped (`provenPageWorkRunGIDs`), seeded into the session trust set inside `ensureContinuedSession`'s synchronous reset ahead of the opening snapshot, and retired at `processDownload`'s `defer`. The seventh amendment's judgement (2) was discharged rather than assumed: the retirement was checked against that `defer` AND both settle paths. What the remedy did NOT address is that membership unlocks the record's FULL page count — a new finding carried as G-15-30."
    source: "15-REVIEW.md CR-01 (post-round-14 review, commit 6a0059d4). Independently re-derived in source at HEAD 6a0059d4 by this verification, in BOTH directions as the round instruction required: the mechanical half was re-derived from a fresh symbol enumeration, and the reviewer's own falsification test was run against source and did not falsify it."
    introduced_by: "15-43 — the G-15-23 fix, by SCOPE. The zero-progress outcome itself is G-15-5's and G-15-23's; 15-43 closed the ordering it was written for and declared the family closed."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress. A gallery whose run proved real page work contributes 0 to the numerator and its full pageCount to the denominator for a whole N-page re-download, and departs untrusted, retiring 0. SC1 follows through D-11: a numerator that does not move is the maximally stalled reading the scheduler force-expires first, and `handleContinuedSessionEvent`'s `.expired` arm pauses EVERY schedulable download."
    summary: "The proof `prepareWorkingSeedAnnouncingProgress` records — this run's working folder cannot supply the pages its manifest claims — is a fact about the RUN, but it is written only when a session is already live and into a SESSION-scoped set that both session start and session teardown clear. Two production orderings therefore still produce G-15-23's zero-progress card, and a run whose proof was discarded can never regain it."
    detail: |
      **The mechanism, re-derived at HEAD 6a0059d4.**

          let hasRealPageWork = workingSeed.existingPages.count < workingSeed.manifest.pageCount
          if let continuedSessionID, hasRealPageWork {
              observedIncompleteSessionGIDs.insert(payload.gallery.gid)
              await pushContinuedSessionProgress(sessionID: continuedSessionID)
          }

      (`DownloadClient+ExecutionSupport.swift:445-449`). Grepping every occurrence of
      `observedIncompleteSessionGIDs` across `AppPackage/Sources` gives exactly six lines: the
      declaration (`+Manager.swift:534`), two reads (`+ExecutionSupport.swift:275`,
      `+ContinuedSession.swift:151`), two clears (`+ContinuedSession.swift:228` in
      `ensureContinuedSession` and `:363` in `markContinuedSessionEnded`), two additive
      `formUnion(snapshot.incompleteGalleryIDs)` (`:287`, `:573`), one gate (`:553`) and this insert.
      Both `formUnion`s are sourced from `schedulableSnapshot`'s
      `incompleteGalleryIDs = Set(downloads.filter(\.isIncomplete).map(\.gid))` (`:165`), which by
      construction cannot contain a complete-reading record. So the insert is the ONLY admission this
      family can ever reach, and it fires only under `if let continuedSessionID`.

      The proof is also produced exactly once per run: `prepareWorkingSeedAnnouncingProgress` has one
      production call site (`+ExecutionPerform.swift:29`) plus one testing forwarder.

      **Ordering 1 — `.unavailable` teardown with the queue still running.** The `.unavailable` arm
      (`+ContinuedSession.swift:332-337`) calls `markContinuedSessionEnded` and NOTHING else; its own
      doc says the queue runs foreground-only. So the in-flight `.repair` keeps running with its trust
      erased. This is not an exotic arm: `ContinuedProcessingSession` yields `.unavailable` from FOUR
      places (`ContinuedProcessingSession.swift:132`, `:151`, `:182`, `:236`), three of them inside
      `start` itself — a missing bundle identifier, a refused registration, a throwing submission — so
      any scheduler refusal ends the session while the queue continues. The next qualifying tap mints
      session 2, whose start snapshot re-reads the same complete-reading record: `isIncomplete` is
      false, the trust set was just cleared, so the gallery contributes 0 for the whole of session 2
      and `reconcileRetiredSessionPages` retires `observedSchedulablePages[gid] ?? 0` = 0 (`:556`).

      **Ordering 2 — a run that started before any session existed.** `DownloadClient.live` resumes
      the persisted queue at launch (`DownloadClient.swift:83-87`: `reconcileDownloads()` then
      `resumeQueue()`), and D-07 forbids that path from starting a session — confirmed by enumerating
      every `ensureContinuedSession()` call site in Sources: `+PublicAPI.swift:107` (enqueue) and
      `:194` (togglePause's `.inactive` branch), `+RetryHelpers.swift:18` (retry) and `:70`
      (retryPages), `+Scheduling.swift:210` (the superseded-pause tail), plus `+Testing.swift:74`.
      `resumeQueue` is not among them. A persisted-queue gid whose record reads complete while its
      files are gone resolves `.repair` through `queuedMode`'s `.queued` → `interruptedWorkMode`
      branch (`+SchedulingHelpers.swift:30-34`, `:75-79`, `completedPageCount == 0 ? .initial :
      .repair`). Its preparation runs with `continuedSessionID == nil`, so NO insert happens at all,
      and the next tap's session covers a gallery it can never credit.

      **The falsification test was run and failed to falsify.** Nothing in the module makes a
      complete-reading record honest mid-run: `reconcileWorkingManifestAgainstPageFiles` refuses on
      this branch by construction and returns the manifest verbatim;
      `refreshManifestPageFileHash(es)` assigns only hashes produced by `hashReadableAsset`, which
      throws rather than blanking (`DownloadStore+Operations.swift:180-205`); `addingCurrentFileHashes`
      fills empty hashes only (`:120-145`); `ensureWorkingManifest` and `writeInitialManifest` write
      fresh manifests, which `.repair` over a valid stored manifest does not take.

      **Both written premises state the rule without its condition.** `+ExecutionSupport.swift:369-374`
      — "Trust is admitted where the session can OBSERVE incompleteness or PROVE page work … Written
      as that rule rather than as a count of sites, because a count is a number that goes stale the
      moment a writer is added." `+Manager.swift:524-530` — "Membership is granted where the session
      can OBSERVE incompleteness or PROVE page work, never at queue time … The second rule exists
      because the first structurally cannot reach one family." Source admits it only where the session
      can prove page work AND a session is already live at that instant, and on these orderings the
      second rule does not reach that family either. This is the SIXTH consecutive round in which a
      load-bearing comment states an invariant source does not satisfy.
    why_tests_missed_it: "Both cases in `DownloadContinuedSessionLedgerRefusalTests` start their session BEFORE invoking `testingPrepareWorkingSeedAnnouncingProgress` (`:91` and `:190` relative to their `retryPages` calls at `:90` and `:189`), which is precisely the ordering the fix does cover. No case drives a preparation with no live session, and no case drives `.unavailable` and then starts a second session."
    suggested_fix: "Make the proof outlive the session, because the run does: hold it in a RUN-scoped coordinator set and seed the session's trust set from it inside `ensureContinuedSession`'s synchronous reset. The reviewer's shape is sound, but its retirement points must be DERIVED rather than copied — the entry has to be dropped where the run ends (`settleCompletedDownload(gid:)`, `settleDownloadFailure(gid:)` and `processDownload`'s cancellation `defer`), or a proof outliving its run re-credits a LATER redo of the same gid and reopens D-G4-01's ceiling from the other side. Then correct both doc sentences to the rule source implements, and add two regression cases: (a) prepare the seed with NO live session, then `testingEnsureContinuedSession()`, asserting the first pushed pair credits the record's pages rather than zero; (b) drive `.unavailable` through the spy, then start a second session, asserting the same."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift"
  - id: G-15-27
    severity: blocker
    closed_by: "15-47 (commits 8d07e9f1, 54b6dd79) — re-derived in source at HEAD 3961698c and verified CLOSED in the round-16 amendment below. The gate is now the run's own pending page list, evaluated exactly once and handed onward through `PreparedWorkingRun`, with the one-evaluation rule pinned by a census test and the regression `testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero` observed RED before it."
    source: "15-REVIEW.md WR-01 (post-round-14 review, commit 6a0059d4), classified WARNING by the reviewer and RAISED to blocker here — the outcome is a gallery reporting its full page count for work it never does, which is G-15-4's pinned-ceiling defect reached through the gate that replaced it. Every link re-derived in source."
    introduced_by: "15-43 — the G-15-23 fix. The gate it installed is the folder's shortfall; the work the run will actually do is a strictly smaller set."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress. Trust is granted to a run that may fetch a subset of the shortfall, or nothing at all, and `schedulableSnapshot` then counts the record's FULL `completedPageCount` — for a complete-reading record, N of N. The card opens at or near its own ceiling and the run departs trusted, retiring N into both sides of the fraction."
    summary: "`hasRealPageWork` is `existingPages.count < manifest.pageCount`, and its doc justifies that as equivalent to 'this run has pages to fetch'. It is not: `pendingPageIndices` intersects the missing pages with `payload.pageSelection`, which survives normalization on every mode but `.update` — including the `retryPages` → `.repair` route this phase treats as canonical."
    detail: |
      Re-derived at HEAD 6a0059d4:

      - `pendingPageIndices` (`+ExecutionSupport.swift:796-824`) opens with
        `let selectedIndices = payload.pageSelection` and drops any page outside it before it ever
        tests the file's existence.
      - `normalizeFetchedPayload` (`+ExecutionFetch.swift:155-172`) keeps a non-empty, in-range
        selection for every mode except `.update`.
      - `performRetryPages` (`+RetryHelpers.swift:80-94`) stores `queuedPageSelections[gid] =
        selectedPageIndices` with `mode: .repair`, so the selection is live on exactly that route.
      - The gate's doc (`+ExecutionSupport.swift:387-397`) asserts the opposite: "`pendingPageIndices`
        fetches exactly the pages missing from it, so `existingPages.count < manifest.pageCount` is
        precisely 'this run has pages to fetch'."

      **The behaviour behind it.** Take a complete-reading record (the refusal family this gate exists
      for) with two pages missing, and a user who retries only one of them from the inspector — or the
      reviewer's sharper staging, a retry of a page whose file exists while a different page is gone,
      reachable because `performCacheCapture` refreshes a hash and clears only `lastError`
      (`+PublicAPI.swift:313-351`, `sanitizeLocalFilesIfNeeded(gid:clearingLastError: true)`), so a
      page can be offered as failed while its file is present. The gate is true either way, trust is
      granted, and `schedulableSnapshot` (`+ContinuedSession.swift:152`) enters
      `download.completedPageCount` — N for a complete-reading record — into the numerator for a run
      that will fetch one page or none. In the fetch-nothing case the run then fails at
      `missingFinalizedPageIndices` and departs TRUSTED, so `reconcileRetiredSessionPages` retires
      `record.completedPageCount` (`:565`) into both sides. That is the over-report D-G4-01's own doc
      calls "the defect", reached through the gate that replaced it.
    why_tests_missed_it: "The two refusal cases that exercise this gate hand-build a selection-free payload — see G-15-28 — so the suite never runs the gate against a payload that carries the selection the route it claims to model actually stores."
    suggested_fix: "Gate on the work this run will actually do rather than on the folder's shortfall — compute `pendingPageIndices(payload:folderURL:existingPageRelativePaths:)` once and use its emptiness — and replace the false equivalence in the doc with the reason the two differ. `performDownload` already computes that list one line later (`+ExecutionPerform.swift:34-38`), so computing it once and handing it to the announcement is the cleaner shape. Add a ledger case staging a selection that excludes every missing page and assert the gallery stays at zero. Any change here must not reopen G-15-26: the run-scoped proof and this gate are the same predicate and must be derived from one expression."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift"
  - id: G-15-28
    severity: warning
    closed_by: "15-46 (commits b384b7fc, 0ce01ed0) — re-derived in source at HEAD 3961698c and verified CLOSED in the round-16 amendment below. `makeRetriedPagesPayload` threads the route's stored selection through both production payload steps, the family was swept past the two cited cases, and the binding to the route is owned by a named case."
    source: "15-REVIEW.md WR-02 (post-round-14 review, commit 6a0059d4), confirmed verbatim in source"
    introduced_by: "15-43 — the two regression cases it added"
    truth_violated: "None directly. Recorded because it is this phase's recorded generator — a test double that is not faithful to the contract of the route it claims to model — and because it is the specific reason G-15-27 shipped green."
    summary: "Both new refusal cases drive the production `retryPages` route (which stores a page selection) and then prepare the seed from `makeRepairPayload(for:)`, which forwards to `makeStartPayload(for:mode:)` and passes NO `pageSelection` at all."
    detail: |
      `DownloadContinuedSessionLedgerRefusalTests` calls
      `retryPages(gid: unlisted.gid, pageIndices: [3])` (`:190`) and
      `retryPages(gid: vanished.gid, pageIndices: [1, 2, 3, 4, 5, 6])` (`:90`), then hands
      `makeRepairPayload(for:)` to `testingPrepareWorkingSeedAnnouncingProgress` (`:103-107`,
      `:202-206`). `makeRepairPayload` is `makeStartPayload(for: gallery, mode: .repair)`
      (`DownloadFeatureTestHelpers.swift:517-519`), whose payload literal ends
      `host: .ehentai, folderName: "Folder", mode: mode` — no selection.

      With the real selection threaded through, the `[3]` case's run fetches ONE page while the
      announcement credits six, which is exactly G-15-27. The file's own header states the opposite
      discipline: "every push asserted is production-issued: the session ensure inside `retryPages`,
      its convergence pushes, the preparation's own announcement, and the drain's." The preparation
      here is issued by the suite, over a payload the suite built.
    suggested_fix: "Build the payload from the same inputs the route stores — thread `pageSelection: Set<Int>? = nil` through `makeStartPayload` and pass `[3]` and `Set(1...6)` respectively — or, better, let the production run reach the preparation instead of forwarding to it, so the choreography is production's rather than the suite's. Whichever is chosen, the assertion that discriminates G-15-27 must fail before the G-15-27 fix and pass after it."
    files:
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift"
  - id: G-15-29
    severity: warning
    closed_by: "15-49 (commits 23a27799, fc7b27ae) — all three items re-derived by fresh greps at HEAD 3961698c and verified CLOSED in the round-16 amendment below. The retired sentence is gone from BOTH trees and is now owned by a widened-walk prose assertion; the dead page counter and the unreadable spy field are deleted. NOT closed by it, and outside its scope: the widened scanner still walks its own file, which is a new finding carried in G-15-33."
    source: "15-REVIEW.md WR-03, WR-04 and WR-05 (post-round-14 review, commit 6a0059d4), all three confirmed verbatim in source"
    introduced_by: "mixed — WR-03's sentence predates the phase and survived 15-44's correction because that plan's scope was Sources; WR-04 is residue left by 15-45's own `prefix` removal; WR-05 predates the phase."
    truth_violated: "None directly. Grouped because this project's bar treats nitpicks as blocking, and because WR-03 is the same doc-vs-source generator that has now produced a finding in six consecutive rounds."
    detail: |
      - **WR-03 — the retired single-authority sentence survives in the test suite, where the new
        census cannot see it.** `DownloadContinuedSessionBasisTests.swift:257` still reads
        "`schedulableDownloads()` is the one authority for selecting work the scheduler can run", and
        `DownloadPendingWorkTests.swift:26` echoes "The one authority's active-gallery union" — both
        verified verbatim. Source disagrees for the same reason it disagreed in the two files 15-44
        corrected: `scheduleNextIfNeededCore` performs its own `indexedDownloads(gids:)` read and
        never calls `schedulableDownloads()`. The new guard structurally cannot catch either:
        `DownloadSourceInventoryTests.clientModuleDirectory` is the single path
        `"AppPackage/Sources/DownloadClient"` (`:36`) and its `executableLines` filter drops every
        line beginning `//`.
      - **WR-04 — `PageDownloadProgress.completedCount` became dead state when 15-45 removed its last
        reader.** Grepping `completedCount` over `Sources/DownloadClient` (excluding
        `completedPageCount`, `displayCompletedPageCount` and `completedUnitCount`) returns exactly
        four lines: the declaration (`+PageDownload.swift:12`), `progress.completedCount =
        progress.results.count` (`:93`), `guard progress.completedCount > 0` (`:94`, one line later)
        and `progress.completedCount += 1` (`:250`). Nothing reads the incremented value, so `:250`
        is a pure dead write and the guard is a restatement of `progress.results.isEmpty == false`.
        The 15-45 plan reasoned about both writers to justify dropping the `prefix` and then left
        behind the state that made the `prefix` misleading.
      - **WR-05 — the client spy records an in-flight progress update no assertion can read.**
        `inFlightProgressUpdate` has exactly three occurrences in the whole test target
        (`DownloadFeatureTestSupportTypes.swift:168` declaration, `:313` write, `:326` clear) and no
        accessor. `armProgressGate`'s doc says the call "records its complete argument set before
        signaling `entered`", which is what the field is for; with no reader, a case parked on the
        gate cannot in fact inspect the parked arguments.
    suggested_fix: "WR-03: rewrite both test doc comments to the shape 15-44 landed in `+PendingWork.swift:17-41`, and — so the claim is owned rather than corrected a third time — widen `DownloadSourceInventoryTests.clientModuleDirectory` into a list that also covers `AppPackage/Tests/DownloadsFeatureTests`, with a prose assertion that the retired phrase appears nowhere, assembled from fragments like every other token in that file. WR-04: delete the property and its increment and phrase the guard on `progress.results.isEmpty`. WR-05: either expose the field and assert on it in the drain-race case that already arms the gate, or delete the field, its two writes and the 'records its complete argument set' clause from the gate's doc."
    files:
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
  - id: G-15-30
    severity: blocker
    source: "15-REVIEW.md CR-01 (post-round-15 review, commit 3961698c). Independently re-derived in source at HEAD 3961698c by this verification — every mechanical link, all three asserted consequences, the reviewer's own falsification test, and the ordinary-route reachability, each checked against source rather than adopted."
    introduced_by: "15-43, sharpened by 15-48. The zero-progress defect those plans closed was real; the remedy they chose grants trust as a MEMBERSHIP, and the basis that membership unlocks is the record's ceiling rather than the run's work."
    truth_violated: "SC2 — the system-provided progress UI reflects real download progress. For the whole refusal family the card now opens at 100% before a byte is fetched, holds that numerator for the entire re-download, and on any mid-run departure retires the record's full count into BOTH sides of the fraction — which, when the departing gallery is the session's last, reports a paused or expiration-swept repair to the user as a fully successful N-page completion."
    summary: "The proof is a boolean, but the basis it unlocks is `download.completedPageCount` in full. For a `.repair` whose reconciliation REFUSED, that count is by construction the untouched ceiling the run has not yet earned — so the family that used to report a pinned `0 / N` now reports a pinned `N / N`. It is the exact inverse of the defect rounds 12..15 chased, reached through the fix for it."
    detail: |
      **The mechanism, re-derived at HEAD 3961698c.** The admission records a bare membership
      (`+ExecutionSupport.swift:495-501`):

          if !pendingPages.isEmpty {
              provenPageWorkRunGIDs.insert(payload.gallery.gid)
              if let continuedSessionID {
                  observedIncompleteSessionGIDs.insert(payload.gallery.gid)
                  await pushContinuedSessionProgress(sessionID: continuedSessionID)
              }
          }

      and membership makes the record authoritative IN FULL (`+ContinuedSession.swift:159-162`):

          let isSessionWork = download.isIncomplete
              || observedIncompleteSessionGIDs.contains(download.gid)
          pages[download.gid] = isSessionWork ? download.completedPageCount : 0

      For the refusal family those two quantities are opposites. `completedPageCount` is
      `pages.values.filter({ !$0.isEmpty }).count` (`DownloadedGallery+Manifest.swift:67-69`), and
      the refusal returns the manifest verbatim on all three exits — the scan-failure guard
      (`+ExecutionSupport.swift:634`), the nothing-blanked guard (`:646`) and the all-or-nothing
      residual `blankedPageCount < manifest.completedPageCount` (`:655`) — so the record reads N of N
      at the announcement. The flush path is monotone upward, so it reads N at every push until the
      run ends.

      **Consequence 1, verified: the card opens and stays at 100%.** Both new run-proof cases assert
      exactly that string as the EXPECTED opening —
      `#expect(spy.startSubtitles.last == "6 / 6 pages · 1 gallery")` at
      `DownloadContinuedSessionRunProofTests.swift:129` and `:212` — against a fixture whose folder
      holds no page file at all (`:118` asserts `existingPages.isEmpty`, `:119` asserts the run's
      pending work is all six pages). The same file records at `:185` that the pre-preparation
      opening was `"0 / 6 pages · 1 gallery"`, so the six pages are credited by the announcement and
      by nothing else.

      **Consequence 2, verified: the numerator is frozen for the run.** `pushContinuedSessionProgress`
      exists for liveness — the scheduler "forcibly expires tasks that appear stalled, and prioritises
      terminating the ones reporting the least progress"
      (`ContinuedProcessingSession.swift:194-196`). For this family the pre-fix constant was 0 and the
      post-fix constant is N; in neither case does the pushed numerator move while N pages actually
      download. The fix moved the constant, not the stall.

      **Consequence 3, verified — and this is the provable harm.** Pause a 100-page refusal repair
      after five pages. `shouldSchedule` (`+Scheduling.swift:125-135`) fails for a paused,
      complete-reading record (not active, not a queued work item, `isIncomplete` false), so the gid
      departs the schedulable set. It IS in `observedIncompleteSessionGIDs`, and its record survives,
      so `reconcileRetiredSessionPages` takes the trusted branch:
      `retiredSessionPages[gid] = min(max(record.completedPageCount, 0), record.pageCount)` = 100
      (`+ContinuedSession.swift:603`). The retired total is then added to BOTH sides of the fraction
      (`:683-686`). If it was the session's only gallery, `reconcileContinuedSession`'s drain branch
      pushes `100 / 100 pages · 0 galleries` and calls `finish(clientSessionID, true)` (`:508`,
      `:521`). A paused download is reported as a successful 100-page completion over five pages of
      work.

      `reconcileRetiredSessionPages`'s own doc forbids exactly that and names the guard meant to
      prevent it (`:557-564`), closing with the direction rule this change reverses (`:571-574`):
      "under-retiring keeps the fraction at or below truth, while over-retiring is the defect."
      Putting the refusal family inside the trust set means the guard no longer holds it out.
      `pauseAllSchedulable` makes D-11's expiration sweep one of those departures, so this is on the
      phase's own best-effort path.

      **The written acknowledgement does not cover it.**
      `DownloadContinuedSessionLedgerRefusalTests.swift:59-66` argues the ceiling is honest "BY
      DESIGN". That argument is sound for the COMPLETED case its own staging drives, where the
      terminal N/N happens to be true; it says nothing about the paused, deleted, cancelled or
      expiration-swept departures, which reach the same retirement through the same line and are not
      honest.

      **Trust also outlives the run inside one session.** `retireProvenPageWork` removes the entry
      from `provenPageWorkRunGIDs` but nothing removes it from `observedIncompleteSessionGIDs`, whose
      only clears are `ensureContinuedSession`'s re-seed (`:246`) and `markContinuedSessionEnded`
      (`:401`). So after a FAILED refusal repair the gid keeps contributing its full
      `completedPageCount` while merely queued — the queued-window zero D-G4-01 guarantees, lost for
      the rest of that session.

      **The reachability is an ordinary route, verified independently.** Downloads live under
      `.documentsDirectory` (`AppTools/FileUtil.swift:7-11`), and `App/Info.plist` sets
      `UIFileSharingEnabled` (`:170`) and `LSSupportsOpeningDocumentsInPlace` (`:145`) both true. A
      user who deletes a downloaded gallery's page files through the Files app and taps resume
      reaches `.repair` through `resumeMode`'s missing-files branch and lands in the residual refusal.

      **The reviewer's falsification test was run and did not falsify it.** No production route lowers
      a refused record's `completedPageCount` during the run: the reconciliation returns the manifest
      verbatim on all three refusal exits, `refreshManifestPageFileHash(es)` assigns only hashes from
      `hashReadableAsset` (which throws rather than blanking,
      `DownloadStore+Operations.swift:180-205`), `addingCurrentFileHashes` fills empty hashes only,
      and `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
      (`+ExecutionSupport.swift:711-712`), so no fresh manifest is written over it.
    why_tests_missed_it: "The suite does not merely fail to express this — it PINS it. Both run-proof cases assert the 100% opening as the expected reading (`:129`, `:212`), and no case anywhere drives a mid-run departure of a trusted complete-reading record. The 880-test green run is therefore not evidence against this gap; two of its cases encode it."
    suggested_fix: "Make the proof carry the run's SHORTFALL rather than a boolean, so the basis is the work this run has finished rather than the record's ceiling. The number is already in hand and already travels with the seed (`PreparedWorkingRun.pendingPageIndices`), and the reviewer's `provenPageWorkRunShortfalls` shape satisfies both standing constraints by construction — it stays run-scoped (G-15-26) and stays the same single `pendingPageIndices` evaluation (G-15-27). Two points must be DERIVED rather than copied: where the shortfall is decremented as pages actually land (the reviewer proposes `flushDownloadProgress`, which already holds the resolved pages — confirm it is the one point every landed page passes, exactly as 15-48 had to derive the `defer`), and the matching `max(record.completedPageCount - shortfall, 0)` clamp in `reconcileRetiredSessionPages`, without which the departure half stays broken. Then correct `+ContinuedSession.swift:557-564` and `DownloadContinuedSessionLedgerRefusalTests.swift:59-66` to the rule source implements, and add two cases: a refusal repair PAUSED after K of N pages whose terminal pair is `K / K` rather than `N / N`, and a refusal repair whose intermediate pushes strictly increase across the re-download."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      - "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift"
  - id: G-15-31
    severity: warning
    source: "15-REVIEW.md WR-01 (post-round-15 review, commit 3961698c), confirmed in source by this verification, including the two arms the reviewer did not separate."
    introduced_by: "pre-existing — the per-session identifier predates the gap rounds and was reasoned about in 15-44's registration note without the repetition cost being addressed."
    truth_violated: "None of the four criteria directly. SC3's no-lost-work and no-visible-error guarantees are intact, and SC4's seam shape is unaffected — this is inside the seam's live implementation. Recorded because it is unbounded resource accumulation and because it inverts the API's intended registration pattern."
    summary: "Every `start(...)` mints a fresh `BGTaskScheduler` identifier and registers a launch handler that can never be unregistered, while sessions end at every drain, every expiration and every `.unavailable` — so one app run with a dozen download bursts leaves a dozen permanent handlers."
    detail: |
      `ContinuedProcessingSession.start` mints `"\(bundleIdentifier).continued.\(UUID().uuidString)"`
      per call (`ContinuedProcessingSession.swift:136-138`) and passes it to `scheduling.register`
      (`:140-146`), which reaches `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:)`
      (`ContinuedTaskScheduling.swift:84-98`). The file's own doc states the constraint that makes
      this unbounded — a handler can never be unregistered and a second registration of one
      identifier kills the app — which is why the identifier must be UNIQUE. It does not have to be
      FRESH, and the current code conflates the two.

      The two failure arms differ and both were checked. On the refused-registration arm
      (`guard registered else`, `:147-150`) no handler is added. On the THROWING-SUBMIT arm
      (`:165-180`, the `notPermitted` case the reviewer names) the handler WAS registered
      successfully, so every retry against a persistently refusing device adds another permanent
      handler that no launch can ever adopt.

      `endSession` takes the pending request back (`:297`, `:306-308`) but has no way to unregister,
      so nothing bounds the set. The `ContinuedTaskScheduling.live` note (`:66-83`) answers a
      different question: its device evidence establishes that post-launch registration is HONOURED,
      and its asymmetry argument ("moving registration earlier is structurally impossible under a
      per-session identifier") is a consequence of the per-session choice rather than a defence of it.
    why_tests_missed_it: "No case drives two sequential sessions over one scheduling double and asserts on the count of distinct registered identifiers; the suite asserts registration happened, never how many times."
    suggested_fix: "Mint the identifier ONCE per process and re-submit it per session. The stated requirement is only that one identifier is never registered twice, which a process-scoped identifier satisfies exactly as a per-session one does, and `endSession` already takes the pending request back so the same identifier is free for the next session. Register on first use, guard subsequent starts on the stored identifier, keep `didCancelStaleRequests` as-is for previous-build leftovers, and rewrite the `live` note so it states the uniqueness rule rather than the freshness one. Add a lifecycle case driving two sequential sessions over one spy and asserting one distinct registered identifier against two submissions."
    files:
      - "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
      - "AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift"
  - id: G-15-32
    severity: warning
    source: "15-REVIEW.md WR-02 (post-round-15 review, commit 3961698c), confirmed verbatim in source by this verification."
    introduced_by: "pre-existing as a double; newly load-bearing because 15-48 corrected the SPY's terminal contract for `.unavailable` while leaving this sibling double's TIMING untouched."
    truth_violated: "None directly. Recorded because it is this phase's recorded generator in its double-faithfulness form — a double that is atomic where the seam suspends certifies reentrancy races as impossible — and because the `.unavailable` family is the one least able to afford it."
    summary: "The `.unavailable` client double is synchronous at all three endpoints, breaking the timing rule its sibling spy documents and enforces."
    detail: |
      `BackgroundProcessingClientSpy`'s header states the contract every double at this seam must
      honour (`DownloadFeatureTestSupportTypes.swift:81-85`): the live value is main-actor-confined,
      so every endpoint hops off the calling actor, and "a double that is atomic where the seam
      suspends certifies reentrancy races as impossible, which is how a drain suite can be green
      against a tail that interleaves in production." Its own three closures each open with
      `await Task.yield()` (verified at the `start` and `updateProgress` closures).

      `BackgroundProcessingClient.unavailable`
      (`DownloadContinuedSessionExpirationTests.swift:406-416`) has no `await Task.yield()` anywhere:
      `start` builds and finishes the stream synchronously, and `updateProgress` and `finish` are
      empty closures. `ensureContinuedSession`'s ownership re-check (`+ContinuedSession.swift:268`),
      its additive floor seed (`:283`) and its merged trust seed (`:313`) all exist specifically to
      survive the client start's main-actor hop, and every case running this double drives that path
      with the hop removed. Per `DownloadContinuedSessionRunProofTests.swift:26-29` the `.unavailable`
      outcome is "the ordinary outcome rather than an exotic one" — three of the four arms that yield
      it fire inside `start` itself.
    why_tests_missed_it: "Nothing polices double timing; the rule is written in one file's header and honoured only there. A census over `await Task.yield()` at this seam would have caught it, and none exists."
    suggested_fix: "Open each of the three closures with `await Task.yield()`, exactly as the spy's three do, and state the reason in the double's own doc rather than leaving a reader to compare it against a sibling in another file. Consider owning the rule the way this round owned the retired sentence — a census or prose assertion over every `BackgroundProcessingClient` double in the target — so the next hand-built double cannot ship atomic."
    files:
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
  - id: G-15-33
    severity: warning
    source: "15-REVIEW.md WR-03 and WR-04 (post-round-15 review, commit 3961698c), both confirmed verbatim in source by this verification."
    introduced_by: "WR-03 predates the phase; WR-04 is residue left by 15-49's own widened scan."
    truth_violated: "None directly. Grouped because this project's bar treats nitpicks as blocking, and because both are the same generator one layer down — an invariant reached by omission rather than written."
    detail: |
      - **WR-03 — `isSupersededByALiveRun` encodes its nil-generation policy in an implicit
        promotion.** `DownloadClient+Execution.swift:308-314` reads
        `guard activeTask != nil, activeGalleryID == gid else { return false }` then
        `return generation != activeTaskGeneration`, where `generation` is `Int?` and
        `activeTaskGeneration` is `Int`. The comparison promotes, so `nil` compares unequal to every
        generation and a generation-less run is treated as superseded — a real policy, reached by
        type promotion rather than by a written branch. `processDownload(gid:generation:)` is
        `public` with `generation` defaulting to `nil` (`:9-12`), so the arm is reachable from
        outside the module, and the sibling predicate directly below handles the same input with an
        explicit `if let generation` branch (`:316-326`). In a module that pins five source censuses
        precisely because unwritten invariants rot, leaving this one to an optional promotion is the
        same failure mode: a reader cannot tell whether `nil` was considered or merely fell out of
        the types.
      - **WR-04 — the source-inventory scanner walks its own file, where its own template excludes
        itself.** `DownloadLogPrivacyInvariantTests.scannedFiles()` removes itself by path and states
        why — a second line of defence behind the assembled tokens, so a future edit spelling one out
        is not read back as a violation of itself (`:254`, `:270-272`).
        `DownloadSourceInventoryTests.scannedFiles()` (`:442-462`) has no such filter, so
        `testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority` polices its own prose. It
        passes today only because the three retired phrasings live there as assembled run-time
        fragments (`:83-85`), never as prose — which means the one file whose job is to explain what
        the retired claim IS cannot spell it out, and the first plainly-worded maintenance edit fails
        it. The gap is asymmetric with the suite's own reasoning: its censuses exclude comment lines
        (`executableLines`, `:427-432`) so a doc describing an inventory does not become part of it,
        while the prose test deliberately reads whole files and then includes the file that must
        describe the prose rule.
    suggested_fix: "WR-03: state the policy in a branch — `guard let generation else { return true }` — with the direction recorded (leaving the entry to the run that owns the slot costs one stale proof until that run exits, while dropping a live successor's proof is the G-15-26 card). WR-04: apply the sibling's `invariantFilePath` exclusion in `DownloadSourceInventoryTests.scannedFiles()` and record the same reason; `knownMembers` is unaffected because neither named member is that file. Keep the assembled fragments as the first line of defence."
    files:
      - "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
      - "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift"
deferred: []
human_verification:
  - test: "Re-run 15-UAT.md test 2 on a physical iOS 26 device with a multi-gallery queue, watching the card across the first gallery's completion and across a mid-queue pause, then cancelling from the card. Include a `.repair` gallery (a record with page files missing) and an errored gallery retried as `.redownload` in the queue."
    expected: "Counts advance past the first completion, the total holds, the subtitle names the remaining galleries, the queue keeps downloading, a repair's and a redownload's card climb rather than pinning or freezing, and card-cancel matches the in-app per-gallery pause baseline."
    why_human: "The reported defect was device-observed; the card and the scheduler's stall handling do not exist in the simulator, and the UAT record still reads `result: issue` — it has not been re-run since any fix landed, and no plan in 15-33..15-45 claimed it. Round 13 gated it on G-15-23 landing; 15-43 has now landed that mechanism, so the run is no longer blocked on it, but the two orderings carried as G-15-26 remain known-defective — a repair whose session was torn down mid-run, or one resumed at launch, will still read zero, so record WHICH ordering any zero-progress observation belongs to rather than treating it as new information. RETAINED DELIBERATELY under `status: gaps_found` so it is not lost: it is an independent axis from the open gaps and neither discharges the other."
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

---

## Amendment — 2026-08-05, round 12: after gap-closure plans 15-33..15-38

**Derived at HEAD `47d23e1c`.** Everything below was re-derived in source at that HEAD. No closure
claim was accepted from a SUMMARY: each of the six gaps recorded in round 11 was re-checked against
the mechanism it named, the three executor deviations were judged independently against source
rather than against the reasons recorded for them, and all 12 findings of the post-round-12 code
review (15-REVIEW.md, same commit) were assessed independently rather than imported.

### Evidence base

| Evidence | Result |
| --- | --- |
| Full `FeatureTests` test plan, single invocation at HEAD (established by the orchestrator, cited not re-run) | 863 tests, 856 passed, 0 failed, 7 expected failures, result Passed, clean tree |
| The 7 expected failures, inspected rather than assumed | All are `withKnownIssue` canaries that fail when their body records NO issue: the six `BackgroundProcessingClient` unimplemented-endpoint pins (`DownloadContinuedSessionTests:16-22`, SC4's own proof) and `testAnUnmatchedSchedulingReleaseReportsAnIssue` (G-15-16's new `reportIssue`). None masks a real failure. |
| Scheduler-symbol sweep (`BGTaskScheduler`, `BGContinuedProcessingTask`, `BGProcessingTaskRequest`, `beginBackgroundTask`, `endBackgroundTask`) over `App/`, `ShareExtension/`, `AppPackage/Sources/` excluding the client module | one hit, `App/Info.plist`'s `BGTaskSchedulerPermittedIdentifiers` — SC3/SC4 topology holds |
| Debt-marker scan (`TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`) over both source modules and the test suite | zero hits |
| `file_length` / line-length gates over the same set | no file over 1000 lines, no line over 120 columns — but `DownloadContinuedSessionBasisTests.swift` is at **996**, the headroom G-15-12 restored one round ago, and it is now consumed |
| `15-SECURITY.md` | status verified, `threats_open: 0` |
| Schema-drift gate / UI safety gate | no drift; no UI files |

No `xcodebuild` invocation was issued by this verification.

### Gap closures re-derived in source

| Gap | Closing plan | Verdict |
| --- | --- | --- |
| G-15-13 | 15-33 (`86a41d6b`, `8cff745a`) | ✓ CLOSED — the conflation is separated at the probe, `unprobedPages` reaches the destructive consumer, and the refusal sits ahead of every mutation. The regression stages the mass-partial case with a real `attributesOfItem` throw plus real `0o000` modes, and the genuine-partial companion pins the side the fix must not move. **Within one folder scan only** — see G-15-19. |
| G-15-14 | 15-34 (`7fde8793`, `59bf406c`) | ✓ CLOSED — swept module-wide (seven sites, five beyond the plan's two), both entrances decide the degenerate parse, `DownloadZeroPagePayloadTests` covers all four. One widened site remains, carried in G-15-21. |
| G-15-15 | 15-35 (`55118093`) | ✓ CLOSED — all three premises now match the code they sit on. |
| G-15-16 | 15-36 (`b5f71242`, `88f4eeab`, `64df3d8f`, `fc0ffd11`) | ✓ CLOSED — dead arms gone, `throws` and the unread parameter dropped, `reportIssue` added and pinned. `writeSettledPauseRecord` restored; judged correct below. |
| G-15-17 | 15-38 (`acc2f41a`, `84522e08`) | ✓ CLOSED — every `.unavailable` producer and both nil-launch arms executed; WR-07 driven rather than narrated. |
| G-15-18 | 15-37 (`929ee241`, `441ca960`) | ✓ CLOSED — all six items verified. WR-09 landed as the second authorized remedy; judged correct below. |

### The three deviations — all three verified, all three legitimate

**1. `writeSettledPauseRecord` restored after 15-36 ordered it deleted.** Correct, and the plan was
wrong. The helper's load is not what the cancelled run writes on its way out; it is what a
concurrent action writes while `commitPause` is parked on `await taskToCancel?.value`. The only
`blockScheduling` call sites in the module are `commitPause`, `delete`, `deleteFolder`,
`moveDownload` and the DEBUG forwarder — so `resume(gid:)` (`+Scheduling.swift:349-363`,
`advanceQueueIntentGeneration` → `queuedModes[gid]` → `await queueStore.enqueue(gid)`),
`performRetry` and `performRetryPages` all take NO block and are free to land inside that wait. The
re-clear is what makes an explicit user pause win against them, which is exactly what
`testAUserPauseIsNeverAbandonedByAnInterleavingRetry` broke on. Deleting it was a real production
regression, caught by a test rather than by the plan.

**2. `ensureContinuedSession()` kept in the `.superseded` pause arm after 15-37 ordered it removed.**
Correct, and the gap record's own second remedy is the better one. The removal is provably wrong:
reaching `.superseded` requires the gid's queue-intent generation to have advanced, and while the
expiration pause still holds the gallery's scheduling block `isSchedulableDownload` rejects that
gid, so the mobilizing action's own `ensureContinuedSession()` returned at its first guard —
`releaseScheduling` on the line above is the first moment the mobilized gallery is visible to that
predicate. Dropping the call leaves a successful tap with running work and no session, which is what
`DownloadContinuedSessionInterleaveTests` reported as `startCount 1 != 2`. The landed comment
(`+Scheduling.swift:169-208`) also does what the gap actually asked: it restates the safety argument
in terms of `ownsExpirationPause`'s generation check and `hasLiveContinuedSession`, both observable
on this side, and explicitly retracts the two unobservable claims it replaced (the scheduler's
foreground validation, and the liveness guard — which is false, since the `.expired` handler calls
`markContinuedSessionEnded` BEFORE `pauseAllSchedulable`).

**3. The throwing-submission case asserts a take-back rather than "cancels nothing".** Correct, and
it follows necessarily from deviation-free source: 15-37's WR-08 reorder puts `pendingIdentifier`
in place before `scheduling.submit`, so the throwing arm reaches `endSession` holding an identifier
while the other two arms still reach it holding none. `endSession`'s doc records the same reasoning
and defends the take-back as deliberate (a throw is exactly the case where the store cannot know how
far the submission got). The case asserts `cancelledIdentifiers == [failedIdentifier]`, and the two
sibling cases assert `[]`. Source and test agree; the expectation in the gap record was written
before the reorder existed.

### Success criteria at this HEAD

| # | Criterion | Status | Evidence |
| --- | --- | --- | --- |
| SC1 | Foreground-started download continues after backgrounding, past the old grace window | ✓ VERIFIED | Device UAT test 1 `result: pass`. G-15-14's process trap is closed at every `1...` site in the module and at both entrances, so the anomalous-input hazard round 11 recorded as residual is gone. G-15-19 does not touch the continuation mechanism; its only SC1 contact is that a `.repair` re-slot can step the card down, which is a D-11 stall input rather than a break in continuation. |
| SC2 | System card reflects real progress; card-cancel matches the in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The code-side defeat is LIFTED: G-15-13 is closed at the signal rather than at a threshold, and no open gap makes the card lie (G-15-19's blanking leaves the record honest about the destination folder, so the pushed numerator and D-G7-01's withdrawal both stay correct). What remains is behavioural: 15-UAT.md test 2 still reads `result: issue`, it has not been re-run since any fix landed, and no plan in 15-33..15-38 claimed it. The card and the scheduler's stall response do not exist in the simulator, so no automated evidence can close this. |
| SC3 | Best-effort submission, no fallback tier, discretionary path and execution assertion deleted outright | ✗ FAILED | The topology half holds — scheduler-symbol sweep is one `Info.plist` key, `BackgroundExecutionInvariantTests` bans all six deleted spellings, the `.unavailable` arm is silent by contract and, since 15-38, every one of its three producers is executed by a case. The **no-lost-or-duplicated-work** half is defeated by **G-15-19**: a `.repair` that re-slots to a new folder path launders a source-side per-file non-answer into a destination absence, destroying up to N-1 recorded content hashes irreversibly and re-downloading those pages. This is the same clause round 11 read G-15-13 against, applied consistently. |
| SC4 | One testable client seam exposing a continued-processing session API, `testValue` unimplemented, no reducer or coordinator touching the scheduler | ✓ VERIFIED | `BackgroundProcessingClient` exposes `start` / `updateProgress` / `finish` over a `BackgroundProcessingSession` whose `AsyncStream` self-finishes after `expired`, `unavailable` or `finish`; `@DependencyClient` leaves every endpoint unimplemented and the six `withKnownIssue` canaries in `DownloadContinuedSessionTests` prove it at run time; the scheduler-symbol sweep is zero outside the module; all nine session mutators are module-internal, and since 15-37 all nine pieces of session STATE are too, with `testingContinuedSessionTask()` as the suites' route. The seam's own contract is now driven end to end rather than asserted: `ContinuedTaskSchedulingSpy` can refuse registration and throw from submit, and every `.unavailable` producer, both nil-launch arms and the stray-adoption gate have cases. |

**Score: 2/4 verified, 1 behaviour-unverified, 1 failed.** SC2 moves out of failed and into
behaviour-unverified — the first time this phase's card criterion has had no code defect against it.
SC3 moves the other way on G-15-19. The headline number is lower than round 11's 3/4 and the tree is
in better shape than it was; the two facts are not in tension, because round 11's 3/4 counted SC3 as
verified while this route was already open and undetected.

### Independent judgment on the code review's 12 findings

**CR-01 — CONFIRMED, promoted as blocker G-15-19, with both the harm and the reachability
narrowed.** Every link of the chain was re-derived: `setupWorkingFolder`'s `!fileExists` branch
(`+ExecutionSupport.swift:576-589`) → `materializeRepairSeed`'s collapsed selection and `Bool`
re-probe (`DownloadStore+Operations.swift:63-73`) with the manifest copied whole (`:47-50`) →
`ensureWorkingManifest` returning it verbatim → a destination scan that reports a **positive**
absence → the blanking loop. D-G13-01 is stated as absolute and does not survive the copy.

Two corrections to the review, both material to the next plan:

- **The floor-withdrawal harm does not survive tracing.** The review says the withdrawal fires "for
  a movement that never physically happened". It did happen: the destination folder really lacks the
  page, so the record's drop is honest and D-G7-01's withdrawal is accounting-correct. The real harm
  is the whole of the rest of G-15-13's — recorded hashes destroyed irreversibly on a non-answer,
  and the same pages re-downloaded. That is why this lands on SC3 and not on SC2.
- **The suggested fix is worse than the defect and must not be taken verbatim.** Throwing from
  `materializeRepairSeed` and treating the refusal as "no seed" drops `setupWorkingFolder` into
  `createDirectory(at: folderURL)`; `ensureWorkingManifest` then finds no manifest at the empty
  destination, writes a fresh all-empty one and re-indexes, so the record goes to 0-of-N. That
  converts a K-page hash loss into an N-page loss and a full withdrawal. The fix must carry the
  source scan's `unprobedPages` across the copy instead.

Reachability is a CONJUNCTION, narrower than the review implies: `.repair` (the only mode
`repairSeed` answers for), an existing source folder, a computed destination path that does not
exist (the upstream title-change re-slot), AND the per-file probe failure. Recorded at blocker
severity anyway, because the consequence is identical to G-15-13's and irreversible.

**WR-01, WR-02, WR-03, WR-04 and IN-01 — all five CONFIRMED, promoted as G-15-20.** Enumerated
rather than read: `commitPause` has five exits and three of them converge inline, so the
`schedulingBlockedGalleryCounts` doc names the wrong owner and contradicts `commitPause`'s own inline
comments; `enqueue(payload:)` takes no scheduling block and re-enqueues inside the pause's wait, so
the three-writer list is a four-writer list; seven of the nine `sanitizeAssetFileIfNeeded` callers
pass constructed paths, so the existence-guard rationale is false for them and a genuine absence
defaults into `.unprobeable`; the round-12 `unprobedPages` exclusion makes the all-or-nothing
equality structurally unreachable for the mixed population its comment claims to cover; and four of
nine state declarations precede `continuedSessionTask`, not eight. None changes behaviour today.
All five are promoted because a wrong written premise is this phase's single most productive defect
source — it produced G-15-3, G-15-7, G-15-13 and now G-15-19 — and because three of the five were
written by this very round's doc-correction work.

**WR-06, IN-02, IN-03, IN-04 — CONFIRMED, promoted as G-15-21**, together with one item this
verification found that the review did not: `DownloadContinuedSessionBasisTests.swift` is at 996
lines against the 1000-line error gate, so G-15-19's regression cannot be added to it. IN-03 is the
one that matters beyond hygiene — it is the single page-count site the G-15-14 sweep widened
(`max(pageCount, 1)`) rather than guarded, which is the sweep's own shape breaking at one site.

**WR-05 — judged and deliberately NOT promoted.** The finding is that
`DownloadOwnershipConvergenceTests:92` and `DownloadDeleteConvergenceTests:115` use
`waitForTaskValue(timeout: .seconds(1))` against a recorded CI lesson. The claim that these are "the
outliers" does not survive a sweep: `waitForTaskValue`'s own DEFAULT is `.seconds(1)`
(`DownloadFeatureTestHelpers.swift:98`) and five further call sites use it, three of them in
`DownloadObserverBatchTests`, which predates this phase. The ten-second lesson is recorded on
`waitUntil`, a polling helper whose default already is ten seconds and which returns as soon as its
condition holds. The flake concern is legitimate — a timeout here throws rather than retries — but it
is neither phase-scoped nor branch-fixable, and raising two call sites while five keep the old
default is precisely the branch-scoped shape this phase has lost five rounds to. If it is taken, it
must be taken at the helper's default, in one place, for all seven.

**IN-05 — judged and deliberately NOT promoted as written.** That five findings live inside
oversized doc comments is an accurate diagnosis, but "move the narrative out" is a style judgement
against a standing project convention to document deliberate designs, and a bulk doc refactor at
this point in the phase would itself be unreviewable. Its actionable half is folded into G-15-20's
fix instead: where an inventory is genuinely load-bearing, prefer a test that fails when it drifts —
the pattern `DownloadLogPrivacyInvariantTests.expectedHashMaskedCounts` already establishes — over a
comment that asks the reader to re-run a grep.

### The recurring failure mode, sixth occurrence — and the sweep that would have caught it

Round 11 recorded the fifth. Round 12 makes six, and this time the fix that under-scoped is the one
written specifically to end the pattern: `AssetFileProbeOutcome`'s own doc says it is an exhaustive
enum "for SCOPE, and the scope is the point… a new exit cannot default into 'positively absent'".
That reasoning was applied to the probe's exits and not to the probe's *consumers*, one of which
re-derives an absence in a different folder.

The sweep that makes G-15-19's scope derivable, and that any G-15-19 plan must repeat: enumerate
every consumer of `pageFileScan` and `existingPageRelativePaths` in `AppPackage/Sources` — eleven
call sites — then ask of each not "does it blank?" but "can its output become the INPUT of something
that blanks, in a different folder?". Exactly one answers yes. `addingCurrentFileHashes` throws on a
non-answer (a recoverable failed download) and `validatePage` reports `.missingFiles` (a re-fetch);
neither destroys recorded state. `.redownload`/`.update` delete the folder and arrive at a fresh
all-empty manifest, so the reconciliation is a no-op for them.

**Gate for the next round.** G-15-19's plan must state its invariant across the COPY — a page the
source probe could not answer for must never become a positive absence at the destination — not
inside `materializeRepairSeed`. Its regression must cross the two stagings that exist separately
today (`PartialProbeFailureFileManager` + real `0o000` modes, with a `.repair` payload whose title
differs from the fixture folder so the materialization branch is taken), in a NEW file, since
`DownloadContinuedSessionBasisTests.swift` has four lines of headroom left. A fix that refuses the
seed and falls through to a fresh all-empty manifest fails the gate: it destroys more than it saves.

### Human verification, unchanged and now the only thing between SC2 and verified

15-UAT.md test 2 still reads `result: issue`. It has not been re-run since any fix landed, and no
plan in 15-33..15-38 claimed it. Its axis is independent of gap closure in both directions: a green
device run would not close G-15-19, and closing G-15-19 would not discharge this item. Run it after
G-15-19 closes — a `.repair` that re-slots to a new folder is one of the routes the test now covers,
and running it first would observe a known-defective seed path. One symptom was added to watch for:
under G-15-19 a repair's card can legitimately step BACKWARDS by the blanked count, so a card that
drops mid-run should be reported rather than dismissed as a rendering glitch.

---

_Verified: 2026-08-05T04:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-05 by Claude (gsd-verifier) — round 12: G-15-13 through G-15-18 all verified closed in source; the three executor deviations independently judged and all found correct; SC2 restored to behaviour-unverified and SC3 downgraded to failed; three gaps G-15-19..G-15-21 recorded from an independent re-derivation of the post-round-12 review; WR-05 and IN-05 judged and deliberately not promoted._


---

# AMENDMENT — Round 13 (HEAD `803c404a`, after plans 15-39, 15-40 and 15-41)

**Verified:** 2026-08-05T23:30:00Z
**Status:** `gaps_found`
**Score:** 2/4 roadmap truths verified

Everything below was re-derived from current source before any SUMMARY was read. Build and full
suite results were supplied by the orchestrator at this HEAD (working tree clean): `BUILD
SUCCEEDED` with 0 errors and 0 warnings — the SwiftLint build plugin runs in that build, so
warning-free implies lint-clean — and `** TEST SUCCEEDED **` for 868 tests across 11 targets with
0 failures. Per the one-run rule no test was re-run in isolation.

## Truth table at this HEAD

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, past the old grace window | VERIFIED | Device UAT test 1 reads `result: pass` on physical iOS 26 hardware. The code path is intact and unblocked at this HEAD: `ensureContinuedSession()` is reached from `enqueue` (`+PublicAPI.swift:107`), `togglePause`'s `.inactive` branch (`:194`), `retry` (`+RetryHelpers.swift:18`), `retryPages` (`:70`) and the superseded-pause tail (`+Scheduling.swift:210`); `App/Info.plist` permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`. G-15-22 and G-15-23 both reach SC1 indirectly rather than defeating it, and are recorded against SC3 and SC2 respectively |
| SC2 | System UI shows real progress, and card cancel matches an in-app cancel | FAILED | G-15-23. A REFUSED working-manifest reconciliation over a complete-reading record leaves `workingSeed.manifest.isComplete == true`, so `prepareWorkingSeedAnnouncingProgress` (`+ExecutionSupport.swift:389`) issues no announcement, the gid can never enter `observedIncompleteSessionGIDs` (two additive writers, both `formUnion(snapshot.incompleteGalleryIDs)`, enumerated), and D-G4-01 counts zero for the gallery for its whole run. A full N-page re-download reports `0 / 1 page · 0 galleries`. This is a CODE-side defeat and is separate from the device axis below, which also remains open |
| SC3 | Best-effort refusal/queue/expiration: no fallback tier, no loss, no duplication, no visible error | FAILED | G-15-22. `pauseAllSchedulable` (`+ContinuedSession.swift:356-366`) reads each gallery's queue-intent generation inside that gallery's own iteration, so a mobilizing tap landing in the window between a mobilizer's `advanceQueueIntentGeneration` and its `ensureContinuedSession` is recorded as the expected generation, the stale expiration pause succeeds, and the tap produces neither running work nor a session. The DELETION half of SC3 remains independently proven: no source in `App/`, `AppPackage/` or `ShareExtension/` names `BGProcessingTask`, `beginBackgroundTask`, `endBackgroundTask`, `BackgroundTaskClient` or `runQueueUntilIdle` (grep at this HEAD, zero hits), `import BackgroundTasks` occurs in exactly one file, and `BackgroundExecutionInvariantTests` enforces both permanently. Device UAT test 3 reads `result: pass` |
| SC4 | A testable session seam in `BackgroundProcessingClient` exposing start/update/complete with a self-finishing stream, unimplemented default, no direct scheduler access | VERIFIED | `BackgroundProcessingClient` is a `@DependencyClient` struct with exactly three endpoints returning/consuming an identified `BackgroundProcessingSession` carrying `AsyncStream<BackgroundProcessingEvent>`; the macro-synthesized `BackgroundProcessingClient()` leaves every endpoint unimplemented and `testUnimplementedClientReportsAnIssueForEveryEndpoint` calls all three. `endSession` finishes the continuation on every terminal path (`ContinuedProcessingSession.swift:292-314`), so the stream self-finishes after `expired`, `unavailable` and `finish` alike. `BGTaskScheduler` is named in exactly one file and reached only through the injected `ContinuedTaskScheduling` seam; no reducer and no coordinator touches it. `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` exists and carries `parent_config: ../../../.swiftlint.yml` |

**Score:** 2/4 truths verified.

## SC-label coverage (no REQUIREMENTS.md IDs are mapped to this phase)

`ROADMAP.md` records **Requirements: None mapped** for Phase 15; the scope contract is the four
success criteria, referenced by plans as SC-labels. Every `requirements:` field across all 41 plans
was enumerated and every value is one of `SC1`, `SC2`, `SC3`, `SC4` — no label outside the four, and
all four are claimed. Distribution: SC1 in 24 plans, SC2 in 26, SC3 in 10, SC4 in 6. Nothing is
orphaned and nothing is unclaimed.

## Gap closures verified in source

### G-15-19 — CLOSED

The invariant is now stated and enforced over the SIGNAL across its whole route, exactly as the gap
required. `materializeRepairSeed` returns `Set<Int>`, seeded from the SOURCE scan's `unprobedPages`
and grown by any page the per-page copy guard skipped; it selects through the full `pageFileScan`
rather than the collapsed `existingPageRelativePaths`. `setupWorkingFolder` carries the set back and
returns `[]` on every non-materialization path by construction. `prepareWorkingSeed` unions it into
the destination scan before the single destructive consumer reads it, so the existing per-file
refusal line covers the laundered pages with no new refusal mechanism, and `existingPages` still
reports only what the destination folder holds.

Three things the gap specifically demanded were checked and are present: the review's remedy was NOT
taken and its rejection is recorded with its reasoning on the function itself; the false
"copies only the pages whose source files existed and passed sanitization" sentence is gone and
replaced by a paragraph naming the carry; and the crossed regression lives in a NEW file
(`DownloadRepairSeedSignalPropagationTests`), with a genuine-absence companion so the fix cannot be
satisfied by disabling destination blanking after a seed.

### G-15-21 — CLOSED

All four hygiene items are closed at their roots, and the file-length headroom is restored.
`clearCancellationLikeDownloadErrors` has a single-condition guard and a name matching its body, with
no caller anywhere still naming the old symbol; `buildInspectionPages`'s three return arms are at
sibling indentation; `captureCachedPage` refuses a zero-page record with the G-15-14 guard shape
rather than the `max(pageCount, 1)` bound that admitted index 1; the redundant `Set` rebuild is gone.
`DownloadContinuedSessionBasisTests.swift` is 692 lines and the moved family is an `extension` of the
same suite type in `DownloadContinuedSessionReconciliationTests.swift`, preserving suite membership,
traits and test identity.

### G-15-20 — PARTIALLY CLOSED

Four of five items closed, and the round's best structural contribution landed with them: the
`blockScheduling` call-site census and the `lastPushedCompletedPageCount` writer census are now
pinned by `DownloadSourceInventoryTests`, with known-member guards against a vacuous walk,
fragment-assembled detection tokens, and a per-file table asserted alongside a separately-counted
joined total. The floor's doc no longer asks the reader to re-run a grep; it names that test.

The WR-01 item did not close. Its convergence-ownership half was correctly rewritten as a rule over
exit categories — verified against `commitPause`'s five exits, three inline `.settled` convergences
and two delegated `.superseded` ones — but the SAME sentence still asserts that
`schedulableDownloads()` is "the single authority the card, the pending-work gate and the scheduler
all read". Enumeration says three call sites and the scheduler is not one of them. Carried as
G-15-24.

## The post-round-13 review, adjudicated independently

Seven findings. Six confirmed, one refuted.

### CR-01 — CONFIRMED, promoted to G-15-22, reachability narrowed

The mechanism is exactly as reported: `pauseAllSchedulable` snapshots the gid list once but reads
each gallery's queue-intent generation inside that gallery's iteration, so `ownsExpirationPause` can
only detect a tap that lands during that gallery's own pause.

Two guards were traced before promoting it, and the finding survives both. The loop-level session
guard covers the case where the tap's `ensureContinuedSession()` completes and mints a successor —
the loop then returns. The per-gallery generation guard covers a tap landing inside the gallery's own
pause, which goes `.superseded`. What neither covers is the window
`[advanceQueueIntentGeneration, ensureContinuedSession)` of a mobilizing entry point, which every one
of the four mobilizers holds open across at least two real suspensions (all four callers of
`advanceQueueIntentGeneration(for:)` were enumerated). Inside it the session id is still `nil`, the
generation read returns the already-advanced value, and the pause settles.

What makes it a defect rather than a benign race is that the design's own compensation is bypassed:
`pause`'s `.superseded` arm documents that a mobilizing tap's own ensure is expected to be inert
because this pause holds the gallery's scheduling block, and that the `.superseded` re-ensure is what
rescues the tap. On this branch the pause never goes superseded, so the re-ensure never runs, and the
tap's own ensure finds the gallery blocked by the pause that is undoing it.

The review's suggested remedy is CORRECT as written. Hoisting the generation reads into the same
synchronous stretch as the gid snapshot is sound because `schedulableDownloads()` performs no
suspending call today, which is the identical justification `ensureContinuedSession` and
`pushContinuedSessionProgress` already record for their own guards.

### CR-02 — CONFIRMED, promoted to G-15-23, reachability BROADENED and the harm re-stated

Every link holds. The decisive one was checked by enumeration rather than by reading the doc:
`observedIncompleteSessionGIDs` has exactly two additive writers, both
`formUnion(snapshot.incompleteGalleryIDs)`, and that set is `Set(downloads.filter(\.isIncomplete)...)`,
so a complete-reading record can never enter it. There is no `insert` anywhere.

The review's "the record's honesty catches up at flush time" refutation also holds:
`refreshManifestPageFileHashes` only ever assigns a non-empty hash (`hashReadableAsset` throws rather
than returning empty), so `completedPageCount` is monotone upward and `isIncomplete` can never become
true for such a record. The sibling manifest/index writers were dispositioned the same way.

Two corrections to the review, both in the direction of MORE severity rather than less:

1. **The reachability is broader than "every page file gone."** That staging exercises the
   all-or-nothing residual, but the directory-level refusal (`scanSucceeded == false`, one transient
   `contentsOfDirectory` failure) produces the identical zero-progress run over the same
   complete-reading record, and so does an all-unprobed scan. The gate is
   `!workingSeed.manifest.isComplete`, which is a single point of failure for the whole refusal
   family the positive-signal defence created across G-15-9, G-15-13 and G-15-19.
2. **The route into `.repair` was verified in production shape rather than assumed.** Two exist:
   `queuedMode` -> `interruptedWorkMode` after a relaunch (the queue store persists its gids through
   `Shared(.fileStorage)` while `queuedModes` does not), and `retryPages` -> `resumeMode` -> the
   `storage.validate` `.missingFiles` branch. The second is not theoretical: the existing K = 1 ledger
   case drives exactly it and asserts `resumeMode == .repair` for a complete-reading record before
   calling `retryPages`. `resumeMode`'s own doc names the refusal as one of the two states that route
   such a record back there, so the module already asserts the loop exists — and once a refusal has
   happened the state is self-sustaining.

### WR-01 — CONFIRMED, promoted to G-15-24

Enumerated above. Two sites, one of them written by this round's own correction work.

### WR-02 — REFUTED as an asserted concern; its remedy retained as a doc item in G-15-24

The mechanical claim is true: registration happens at first session start, `AppDelegate` registers
nothing, and a per-session UUID identifier makes pre-launch registration structurally impossible.
But the concern the reviewer raises — whether a post-launch `register` is honoured for
`BGContinuedProcessingTask` — is answered by evidence already in this phase's record and not weighed
by the review: **15-UAT.md test 1 reads `result: pass` on physical iOS 26 hardware**, with pages
continuing to land well past the deleted `beginBackgroundTask` window. That is only reachable if the
task actually launched, which is only reachable if the registration was accepted. So the design is
device-proven rather than merely unfalsified, and this is not a defect.

Recorded here so the next round does not re-raise it. What survives is the reviewer's own remedy —
a device-verified note beside `ContinuedTaskScheduling.live.register`, in the shape of the existing
`App/Info.plist` note — which is folded into G-15-24 as documentation rather than raised as a gap of
its own.

### WR-03, WR-04, WR-05 — all three CONFIRMED verbatim, grouped as G-15-25

`restoredIndices`'s `prefix` is provably always the whole array (the only two writers of
`completedCount` were located and ordered); both trailing blank lines are present and both are
unlintable here, since `vertical_whitespace_closing_braces` is opt-in and the root `opt_in_rules`
list holds only `force_try`, `force_unwrapping`, `multiline_function_chains` and `sorted_imports`;
the trailing comma is present and is the only occurrence in the module.

One item the review did not raise is folded into the same group rather than left in a summary: round
13 itself found that `validPageCount(folderURL:manifest:)` has no caller anywhere and
`isReadableAssetFile(at:)` has none in Sources, and correctly judged both out of scope for a
doc-correction plan. Re-derived by grep here and recorded so the decision is made rather than
deferred a third time.

## Mechanical gates re-derived at this HEAD

- No debt marker (`TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`) appears anywhere in
  `Sources/DownloadClient`, `Sources/BackgroundProcessingClient` or `Tests/DownloadsFeatureTests`.
- No file in either source module exceeds the 1000-line `file_length` error gate (largest:
  `DownloadStore.swift` at 808). The largest test file is `DownloadCoordinatorStorageTests.swift` at
  994, which is pre-existing and outside this phase's families; both continued-session basis files
  now hold real headroom (692 and the new sibling).
- The deleted-tier grep returns zero hits for `BGProcessingTask`, `beginBackgroundTask`,
  `endBackgroundTask`, `BackgroundTaskClient` and `runQueueUntilIdle` across `App/`,
  `AppPackage/Sources` and `ShareExtension/`.
- `import BackgroundTasks` occurs in exactly one file in the whole tree.

## Human verification, unchanged and still open

15-UAT.md test 2 still reads `result: issue` and has not been re-run since any fix landed; no plan in
15-33..15-41 claimed it, and all three round-13 summaries say so explicitly. It is retained in the
frontmatter under `status: gaps_found` so it is not lost. Its axis is independent of gap closure in
both directions. Run it AFTER G-15-23 closes: until then a `.repair` whose reconciliation refuses is
a known-defective path, and a card that reports zero across a real re-download would be a known
symptom rather than new information.

---

_Verified: 2026-08-05T23:30:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-05 by Claude (gsd-verifier) — round 13: G-15-19 and G-15-21 verified closed in source at HEAD 803c404a and G-15-20 found only PARTIALLY closed; all seven findings of the post-round-13 review independently adjudicated (six confirmed, WR-02 refuted against the device UAT record and folded in as a documentation item); SC2 downgraded from behaviour-unverified to FAILED on its code side and SC3 held at failed; four gaps G-15-22..G-15-25 recorded; the device UAT test 2 item deliberately retained under gaps_found._

---

# AMENDMENT — Round 15 (HEAD `6a0059d4`, after plans 15-42, 15-43, 15-44 and 15-45)

**Verified:** 2026-08-06T03:00:00Z
**Status:** `gaps_found`
**Score:** 3/4 roadmap truths verified

Everything below was re-derived from current source at HEAD `6a0059d4` (working tree clean) before
any SUMMARY was read. Build and full-suite results were supplied by the orchestrator at this HEAD:
`FeatureTests` green, 872 tests, 0 failures. Per the one-run rule no test was re-run in isolation;
the new cases were proven to EXIST by enumeration instead.

The round instruction named two things to fold in. Both were checked independently rather than
adopted: 15-REVIEW.md's CR-01 was verified against source in both directions and is **CONFIRMED**,
and 15-UAT.md test 2 is carried as the phase's one human-verification item.

## Truth table at this HEAD

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, past the old grace window | VERIFIED | Device UAT test 1 reads `result: pass` on physical iOS 26 hardware, and the mechanism it exercised is unchanged at this HEAD: `App/Info.plist:5-8` permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, `BGTaskScheduler` is named in exactly one file, and `ensureContinuedSession()` is reached from all five queue-mobilizing sites (`+PublicAPI.swift:107`, `:194`, `+RetryHelpers.swift:18`, `:70`, `+Scheduling.swift:210`). G-15-22's closure restores the tap-produces-something rescue this criterion depends on. G-15-26 and G-15-27 reach SC1 only indirectly, through D-11's stall-expiration amplifier, and are recorded against SC2 |
| SC2 | System UI shows real progress, and card cancel matches an in-app cancel | FAILED | Two independent code-side defects. **G-15-26:** 15-43's proof of real page work is recorded into `observedIncompleteSessionGIDs`, which is session-scoped — written only under `if let continuedSessionID` and cleared at both `ensureContinuedSession` (`+ContinuedSession.swift:228`) and `markContinuedSessionEnded` (`:363`) — while the fact it proves belongs to the run. An `.unavailable` teardown mid-run, and any run started before a session existed (the launch-time `resumeQueue()`), both leave a complete-reading repair contributing 0 to the numerator and its full `pageCount` to the denominator for an entire N-page re-download. **G-15-27:** the same gate's stated equivalence ignores `payload.pageSelection`, so a selected-page retry can be short of its manifest while fetching a subset of that shortfall or nothing at all, and the record's FULL count enters the numerator anyway. The device axis (UAT test 2) also remains open and is separate from both |
| SC3 | Best-effort refusal/queue/expiration: no fallback tier, no loss, no duplication, no visible error | VERIFIED | G-15-22 — the round-13 blocker — is closed at its root: `pauseAllSchedulable` (`+ContinuedSession.swift:395-409`) now captures each target's queue-intent generation inside the same synchronous `schedulableDownloads().map { … }` that captures the gid list, so every recorded expectation is a pre-sweep one and a mobilizing tap landing anywhere after the sweep began forces `.superseded` and its re-converge-and-re-ensure rescue. The suspension-free premise was re-derived, not trusted (`DownloadQueueStore.swift:15-17`, `+Persistence.swift:36-57`). The DELETION half remains independently proven at this HEAD: grep across `App/`, `AppPackage/Sources`, `AppPackage/Tests` and `ShareExtension/` returns ZERO hits for `BGProcessingTask`, `beginBackgroundTask`, `endBackgroundTask`, `BackgroundTaskClient` and `runQueueUntilIdle`, and `import BackgroundTasks` occurs in exactly one file in the whole tree. Device UAT test 3 reads `result: pass` |
| SC4 | A testable session seam in `BackgroundProcessingClient` exposing start/update/complete with a self-finishing stream, unimplemented default, no direct scheduler access | VERIFIED | `BackgroundProcessingClient` is a `@DependencyClient` struct with exactly three endpoints over an identified `BackgroundProcessingSession` carrying `AsyncStream<BackgroundProcessingEvent>`; the macro-synthesized value leaves every endpoint unimplemented and `testUnimplementedClientReportsAnIssueForEveryEndpoint` calls all three. The stream self-finishes on `expired`, `unavailable` and `finish` alike. `BGTaskScheduler` is reached only through the injected `ContinuedTaskScheduling` seam; no reducer and no coordinator touches it |

**Score:** 3/4 truths verified. SC3 is restored from failed; SC2 is held at failed for the second
consecutive round, now on two defects rather than one.

## SC-label coverage

`ROADMAP.md` records **Requirements: None mapped** for Phase 15; the scope contract is the four
success criteria, referenced by plans as SC-labels. The four round-14 plans carry `SC3` (15-42),
`SC2`/`SC1` (15-43), documentation-only against the standing docs (15-44) and `SC2`/`SC3` (15-45).
No label outside the four appears, nothing is orphaned, nothing is unclaimed.

## Gap closures re-derived in source

### G-15-22 — CLOSED

`pauseAllSchedulable` builds the whole `ExpirationPauseTarget` list — gid **and**
`queueIntentGeneration(for:)` — inside one `await schedulableDownloads().map { … }` expression
(`+ContinuedSession.swift:396-404`), and the loop consumes only recorded expectations (`:405-408`).
The gap's own falsification condition was re-checked rather than assumed: the stretch really is
suspension-free, because `queueStore.gids` is a synchronous `Shared` property read and
`indexedDownloads(gids:)` awaits nothing. The doc at `:377-394` now states the SNAPSHOT rule ("never
at that target's own iteration"), explains what the per-iteration read cost, and records the same
re-validation note the two sibling guards carry. The regression exists and discriminates:
`DownloadContinuedSessionInterleaveTests.testAMobilizationLandingBeforeItsOwnIterationSurvivesTheExpirationSweep`.

### G-15-24 — CLOSED (its Sources half; a new sibling is carried as G-15-29)

`+PendingWork.swift:17-41` no longer claims the scheduler reads `schedulableDownloads()`. It names
the three real call sites, states **"The scheduler is NOT one of those callers (G-15-24)"** as its
own heading, locates `scheduleNextIfNeededCore`'s own read and predicate route, and records why the
active-gallery divergence is inert today together with the two conditions that re-open it. The claim
is owned rather than merely corrected:
`DownloadSourceInventoryTests.testSchedulableDownloadsCallSitesMatchTheRecordedCensus` now sits
beside the two existing censuses. The device-verified registration note is present at
`ContinuedTaskScheduling.swift:65-83`, in the requested shape — per-session UUID identifiers under
the bundle-scoped wildcard make pre-launch registration structurally impossible, 15-UAT.md test 1 is
named as the run that accepted post-launch registration on hardware, and the asymmetry of the
failure modes is stated so the question is not re-opened from the same absence.

### G-15-25 — CLOSED

All four items verified in source. `restoredIndices` is `Set(progress.results.map(\.index))` with no
`prefix`. No file in either module ends an extension on a blank line. `clearSelectedFailedPages`
carries no trailing comma. And the dead public API was DECIDED rather than deferred a fourth time:
grepping `validPageCount` and `isReadableAssetFile` across `App/`, `AppPackage/` and
`ShareExtension/` returns **zero** hits — both were deleted outright — while the
`ThrowingAttributesFileManager` fallback pin survives in `DownloadStoreTests`.

### G-15-23 — PARTIALLY CLOSED

The mechanism landed and is right for the ordering it was written for.
`prepareWorkingSeedAnnouncingProgress` (`+ExecutionSupport.swift:435-451`) now gates on real page
work rather than on `!manifest.isComplete`, and admits the gid to `observedIncompleteSessionGIDs`
EXPLICITLY before pushing — which was the gap's central demand, since the push-side admission
provably cannot reach this family.

What did not close is scope, and it is the review's CR-01: the proof is a fact about the **run** and
it is stored in a **session-scoped** set. Carried forward as **G-15-26**.

## The post-round-14 review, adjudicated independently

All six findings were re-derived in source. **All six are CONFIRMED**; none was refuted. That is a
different outcome from round 13, where one finding was refuted against the device UAT record — and
it was reached the same way, by testing each claim against source rather than by counting.

### CR-01 — CONFIRMED, promoted to G-15-26 (blocker)

Verified in both directions, as the round instruction required.

**The mechanical half holds.** Grepping `observedIncompleteSessionGIDs` across `AppPackage/Sources`
gives every writer: two clears (`+ContinuedSession.swift:228`, `:363`), two
`formUnion(snapshot.incompleteGalleryIDs)` (`:287`, `:573`) and the one insert
(`+ExecutionSupport.swift:447`). `incompleteGalleryIDs` is
`Set(downloads.filter(\.isIncomplete).map(\.gid))` (`:165`), so by construction it can never contain
a complete-reading record — the insert is the only admission this family can reach, and it fires
only under `if let continuedSessionID`. The preparation itself runs exactly once per run: one
production call site (`+ExecutionPerform.swift:29`).

**Both orderings were traced to their entry points.** The `.unavailable` arm
(`+ContinuedSession.swift:332-337`) calls `markContinuedSessionEnded` and nothing else, so an
in-flight `.repair` keeps running with its trust erased — and this is the *expected* arm on any
scheduler refusal, since `ContinuedProcessingSession` yields `.unavailable` from four places
(`:132`, `:151`, `:182`, `:236`), three of them inside `start` itself. Separately,
`DownloadClient.live` resumes the persisted queue at launch (`DownloadClient.swift:83-87`) and
`resumeQueue` is not among the six `ensureContinuedSession()` call sites, so a launch-resumed
`.repair` prepares its seed with `continuedSessionID == nil` and inserts nothing at all.

**The reviewer's own falsification test was run and did not falsify it.** No production route makes
a complete-reading record honest mid-run: the reconciliation refuses on this branch by construction,
`refreshManifestPageFileHash(es)` assigns only hashes from `hashReadableAsset` (which throws rather
than blanking, `DownloadStore+Operations.swift:180-205`), `addingCurrentFileHashes` fills empty
hashes only (`:120-145`), and the fresh-manifest writers are not taken for a `.repair` over a valid
stored manifest.

**Two doc premises state the rule without its condition** (`+ExecutionSupport.swift:369-374`,
`+Manager.swift:524-530`). Sixth consecutive round of that generator.

### WR-01 — CONFIRMED, promoted to G-15-27, and RAISED to blocker

The reviewer classified it a warning. Every mechanical link was verified —
`pendingPageIndices` reads `let selectedIndices = payload.pageSelection` before it tests any file
(`+ExecutionSupport.swift:808-813`); `normalizeFetchedPayload` keeps a non-empty in-range selection
for every mode but `.update` (`+ExecutionFetch.swift:164-170`); `performRetryPages` stores one with
`mode: .repair` (`+RetryHelpers.swift:80-94`); and `performCacheCapture` clears only `lastError`
(`+PublicAPI.swift:348`), so a page can be offered as failed while its file exists. The severity is
raised here because the OUTCOME is a gallery entering the numerator at its full `completedPageCount`
(`+ContinuedSession.swift:152`) for work it never does, and departing trusted so
`reconcileRetiredSessionPages` retires that same count into both sides (`:565`). That is G-15-4's
pinned-ceiling defect — a blocker when it was found — reached through the gate that replaced it.
This project's bar does not let it pass as a caveat because of the label it arrived with.

### WR-02 — CONFIRMED, promoted to G-15-28

`makeRepairPayload` forwards to `makeStartPayload`, whose payload literal ends
`host: .ehentai, folderName: "Folder", mode: mode` — no `pageSelection`
(`DownloadFeatureTestHelpers.swift:517-519`). Both refusal cases drive `retryPages` with a real
selection and then prepare the seed from that selection-free payload
(`DownloadContinuedSessionLedgerRefusalTests.swift:103-107`, `:202-206`). This is the phase's
recorded generator in its choreography form, and it is the specific reason G-15-27 shipped green.

### WR-03, WR-04, WR-05 — all three CONFIRMED verbatim, grouped as G-15-29

The retired single-authority sentence survives at `DownloadContinuedSessionBasisTests.swift:257` and
its echo at `DownloadPendingWorkTests.swift:26`, in a directory `DownloadSourceInventoryTests` does
not walk (`clientModuleDirectory` is one path, `:36`). `completedCount` has four occurrences in
Sources, the increment at `+PageDownload.swift:250` is a pure dead write and the guard at `:94` a
restatement of `results.isEmpty == false`. `inFlightProgressUpdate` has three occurrences in the
test target, all declaration or write.

## Behavioural spot-checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| The mid-sweep mobilization regression exists | `grep -rn testAMobilizationLandingBeforeItsOwnIterationSurvivesTheExpirationSweep AppPackage/Tests` | `DownloadContinuedSessionInterleaveTests.swift:84` | PASS |
| Both refusal-family regressions exist | `grep -n 'func test' …LedgerRefusalTests.swift` | `:65` all-pages-gone, `:155` failed-enumeration | PASS |
| The three source censuses are pinned by tests | `grep -n 'func test' DownloadSourceInventoryTests.swift` | `:119`, `:147`, `:173` | PASS |
| A repair preparation with no live session credits its pages | — | no such case exists in the suite | FAIL (G-15-26) |
| A selected-page retry that fetches nothing stays at zero | — | no such case exists in the suite | FAIL (G-15-27) |

Full-suite execution was supplied once by the orchestrator (872 tests, 0 failures) and not re-run.
A green suite is not evidence against G-15-26 or G-15-27: neither has a case that could express it.

## Mechanical gates re-derived at this HEAD

- No debt marker (`TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`) appears anywhere in
  `Sources/DownloadClient`, `Sources/BackgroundProcessingClient` or `Tests/DownloadsFeatureTests`.
- No file in either source module exceeds the 1000-line `file_length` error gate; the largest is
  `DownloadClient+ExecutionSupport.swift` at 825.
- `awk 'length($0)>120'` over every Swift file in both source modules and the test target returns
  nothing.
- The deleted-tier grep returns zero hits across `App/`, `AppPackage/Sources`, `AppPackage/Tests` and
  `ShareExtension/`; `import BackgroundTasks` occurs in exactly one file in the whole tree.
- The dead public API `validPageCount` / `isReadableAssetFile` returns zero hits tree-wide.
- Working tree clean at `6a0059d4`.

## Human verification, still open and now runnable

15-UAT.md test 2 still reads `result: issue`. It has not been re-run since any fix landed, and no
plan in 15-42..15-45 claimed it — the round-14 summaries do not assert otherwise. Round 13 gated it
on G-15-23 landing; 15-43 has landed that mechanism, so the run is no longer blocked. It needs a
physical iOS 26 device, a multi-gallery queue containing a `.repair` gallery and an errored gallery
retried through the `.redownload` route, an observation across the first gallery's completion and a
mid-queue pause, and finally a cancel from the card compared against the in-app per-gallery pause
baseline.

One qualification, so the run yields information rather than a rediscovery: the two orderings carried
as G-15-26 are known-defective. A repair whose session was torn down mid-run, or one resumed at
launch before any tap, will still read zero. Record which ordering any zero-progress observation
belongs to.

The item is retained under `status: gaps_found` because its axis is independent of gap closure in
both directions — closing G-15-26..G-15-29 does not discharge it, and it cannot discharge them.

## Where this leaves the phase

Round 14 closed three of its four gaps cleanly and closed the fourth's mechanism. SC3 is restored.
What it did not do is close the *family* G-15-23 named: 15-43 fixed the ordering its regression cases
staged and wrote its doc as though it had fixed all of them, and the gate it installed introduced a
new over-report in the direction D-G4-01 exists to close. Both new blockers live in the same eight
lines, and both were invisible to the suite for the same reason — the cases that exercise those lines
stage a session first and hand-build a payload the production route would have filled in.

That is the shape this phase keeps producing: a fix scoped to the staging its own regression case can
express. The next round should close G-15-26 and G-15-27 together, from one derived predicate, and
close G-15-28 first so the regression it unblocks can fail before either fix lands.

---

_Verified: 2026-08-06T03:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-06 by Claude (gsd-verifier) — round 15: G-15-22, G-15-24 and G-15-25 verified closed in source at HEAD 6a0059d4 and G-15-23 found only PARTIALLY closed; all six findings of the post-round-14 review independently adjudicated and ALL SIX CONFIRMED, with WR-01 raised from warning to blocker on its outcome; SC3 restored to verified and SC2 held at failed on two defects; four gaps G-15-26..G-15-29 recorded; the device UAT test 2 item deliberately retained under gaps_found._

# AMENDMENT — Round 16 (HEAD `3961698c`, after plans 15-46, 15-47, 15-48 and 15-49)

**Verified:** 2026-08-06T12:00:00Z
**Status:** `gaps_found`
**Score:** 3/4 roadmap truths verified

Everything below was re-derived from current source at HEAD `3961698c` (working tree clean) before
any SUMMARY was read. Build and full-suite results were supplied by the orchestrator at this HEAD:
`** BUILD SUCCEEDED **`, and the whole `FeatureTests` plan across all 22 test targets green at 880
tests, 0 failures, in one invocation. Per the one-run rule no test was re-run in isolation; the new
cases were proven to EXIST by enumeration instead. The UI safety gate reads `block: false` — no UI
file changed.

The round instruction named two things to fold in, and both were checked independently rather than
adopted. The seventh amendment's judgement (2) — that a run-scoped proof's retirement points must be
verified against `processDownload`'s `defer` and both settle paths before the remedy is
accepted — was **DISCHARGED**, not assumed. And all five findings of 15-REVIEW.md were adjudicated
against source; **all five are CONFIRMED**.

## Truth table at this HEAD

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, past the old grace window | VERIFIED | Device UAT test 1 reads `result: pass` on physical iOS 26 hardware, and the mechanism it exercised is unchanged at this HEAD: `App/Info.plist:5-8` permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, `BGTaskScheduler` is named in exactly one file, and `ensureContinuedSession()` is still reached from every queue-mobilizing site. G-15-30 does NOT reach SC1 through D-11's stall-expiration amplifier the way its four predecessors did, and the direction matters: the scheduler force-expires the tasks reporting the LEAST progress, so a numerator pinned HIGH is protective where the pinned-zero one was lethal. The harm has moved entirely onto honesty, which is SC2's axis |
| SC2 | System UI shows real progress, and card cancel matches an in-app cancel | FAILED | Held at failed for the third consecutive round, now on the INVERSE of the defect the previous four chased. **G-15-30:** the run's proof is a boolean, but membership unlocks the record's FULL `completedPageCount` (`+ContinuedSession.swift:159-162`), and for the refusal family that count is by construction the ceiling the run has not yet earned. The card opens at `6 / 6` before a byte is fetched — both new run-proof cases assert that string as the EXPECTED opening (`DownloadContinuedSessionRunProofTests.swift:129`, `:212`) — the numerator is frozen for the whole re-download, and any mid-run departure retires the ceiling into both sides of the fraction (`:603`, `:683-686`), so a paused or expiration-swept 100-page repair terminates as `100 / 100 pages · 0 galleries` with `finish(success: true)` over five pages of work. The device axis (UAT test 2) also remains open and is separate from it |
| SC3 | Best-effort refusal/queue/expiration: no fallback tier, no loss, no duplication, no visible error | VERIFIED | Held from round 15 and re-derived at this HEAD. The DELETION half is independently proven: grep across `App/`, `AppPackage/Sources`, `AppPackage/Tests` and `ShareExtension/` returns ZERO hits for `BGProcessingTask`, `beginBackgroundTask`, `endBackgroundTask`, `BackgroundTaskClient` and `runQueueUntilIdle`, and `import BackgroundTasks` occurs in exactly one file in the whole tree. Device UAT test 3 reads `result: pass`. G-15-31 was weighed against this criterion and deliberately does NOT downgrade it: an accumulating launch handler loses no work, duplicates none, and surfaces no user-visible error — it is resource hygiene inside the seam, not a fallback tier |
| SC4 | A testable session seam in `BackgroundProcessingClient` exposing start/update/complete with a self-finishing stream, unimplemented default, no direct scheduler access | VERIFIED | `BackgroundProcessingClient` is still a `@DependencyClient` struct with exactly three endpoints over an identified `BackgroundProcessingSession` carrying `AsyncStream<BackgroundProcessingEvent>`; the macro-synthesized value leaves every endpoint unimplemented, and the stream self-finishes on `expired`, `unavailable` and `finish` alike through the single `endSession(yielding:success:)` path. `BGTaskScheduler` is reached only through the injected `ContinuedTaskScheduling` seam. G-15-31 lives in that seam's live IMPLEMENTATION rather than in its shape, and G-15-32 in a test double at the same seam; neither moves the criterion |

**Score:** 3/4 truths verified. Unchanged from round 15 in number, changed in substance: SC2's two
defects closed and were replaced by one that inverts them.

## SC-label coverage (no REQUIREMENTS.md IDs are mapped to this phase)

Confirmed rather than assumed, in both directions. `ROADMAP.md:805` records **Requirements: None
mapped — the scope contract is this phase's four success criteria**, and `grep -c "Phase 15"
.planning/REQUIREMENTS.md` returns **0**, so there is no requirement ID mapped to this phase for a
plan to orphan and none for REQUIREMENTS.md to expect back. The four round-16 plans carry `SC2`
(15-46), `SC1`/`SC2` (15-47), `SC1`/`SC2` (15-48) and `SC2`/`SC3` (15-49). No label outside the four
appears, nothing is orphaned, nothing is unclaimed.

## Gap closures re-derived in source

### G-15-26 — CLOSED

The proof is now owned by the thing it is a fact about. `provenPageWorkRunGIDs`
(`DownloadClient+Manager.swift:595`) is written **unconditionally** at the preparation
(`+ExecutionSupport.swift:496`), outside the `if let continuedSessionID` that gates the session
insert one line below — so both orderings the gap named now record it: a run whose session is torn
down mid-flight keeps its proof, and a run that starts with no session at all
(`resumeQueue()` at launch, where D-07 forbids one) records it anyway.

The seed lands where the FIRST push can see it. `ensureContinuedSession` assigns
`observedIncompleteSessionGIDs = provenPageWorkRunGIDs` at `+ContinuedSession.swift:246`, inside the
synchronous reset and **ahead of** the `schedulableSnapshot()` at `:248` that the opening subtitle is
built from — which was the gap's own derivation about why the post-start merge is structurally too
late. `markContinuedSessionEnded` still clears only the session set (`:401`), and the doc at `:374`
states in its own words that the run-scoped set is deliberately not cleared there.

**Judgement (2) discharged.** The seventh amendment refused to accept this remedy's shape until its
retirement points were verified against `processDownload`'s `defer` and both settle paths, because a
proof outliving its run would re-credit a LATER redo of the same gid and reopen D-G4-01's ceiling
from the other side. That verification was performed here rather than read out of the doc that claims
it:

- `retireProvenPageWork` runs from the `defer` at `+Execution.swift:18`, placed **ahead of**
  `finishActiveTaskIfOwned` (`:19-23`) so an owning run does not null its own ownership and then read
  itself as superseded.
- Both settle paths were enumerated by grep across Sources. `settleCompletedDownload` has exactly
  ONE production call site — `+Execution.swift:72`, the success path. `settleDownloadFailure` has
  three (`+BackgroundDownloads.swift:110`, `:144`, `+Persistence.swift:171`). Neither covers the
  pre-fetch early return (`+Execution.swift:26-28`), the mid-run `guard !Task.isCancelled`
  (`:41`), or the `catch is CancellationError` return (`:47-48`). The `defer` is the only universal
  point, exactly as its own doc derives at `:278-302`.
- The preparation cannot be reached outside that `defer`'s coverage: `performDownload` has one
  production caller (`+Execution.swift:158`, inside `fetchNormalizeAndDownload`, inside
  `processDownload`).
- The over-correction the judgement warned about is guarded rather than merely avoided.
  `isSupersededByALiveRun` (`:308-314`) keeps a superseded predecessor from dropping a live
  successor's entry, and `testAProofDoesNotOutliveItsRunIntoALaterRedo`
  (`DownloadContinuedSessionRunProofTests.swift:251`) pins it — with the case's own doc stating,
  unprompted, that its pre-fix green is VACUOUS and that its standing rests on an observed failure
  with the retirement removed.

### G-15-27 — CLOSED

`prepareWorkingSeedAnnouncingProgress` gates on the run's own pending page list
(`+ExecutionSupport.swift:490-495`) rather than the folder's shortfall, and that list reads
`payload.pageSelection` before it tests any file. The single-evaluation rule the gap made a condition
of the fix is real and owned: the preparation returns `PreparedWorkingRun`, `performDownload`
consumes `preparedRun.pendingPageIndices` (`+ExecutionPerform.swift:47`) instead of recomputing, and
`pendingPageIndices(` appears exactly once as a call in Sources — pinned by
`DownloadSourceInventoryTests.testPendingPageListEvaluationsMatchTheRecordedCensus` (`:293`), whose
failure message states the reason rather than the number. The regression exists and discriminates:
`testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero`
(`DownloadContinuedSessionLedgerRefusalTests.swift:309`) asserts non-vacuity first — five existing
pages against a six-page manifest, with page 3 present — and then reads the outcome by ABSENCE, which
is stronger than the pre-fix numeral the plan had predicted.

### G-15-28 — CLOSED

`makeRetriedPagesPayload` (`DownloadFeatureTestHelpers.swift:560-576`) builds the payload through
BOTH production steps in production order, and applies `retryPages`' own dedupe-and-sort transform,
so the double carries what the route stores rather than a literal a case typed. Every case that
drives `retryPages` now uses it (`…LedgerRefusalTests.swift:117`, `:234`, `:351`, `:436` and
`…LedgerTests.swift:645`), and `makeRepairPayload`'s doc now states that its nil selection is the
FAITHFUL value for the routes that store none — the distinction, not just the repair. The binding is
owned by `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores` (`:400`), which drives
`retryPages(pageIndices: [4, 2, 2])`, reads `queuedPageSelections` back and asserts
`payload.pageSelection == Set(stored)`.

### G-15-29 — CLOSED

All three items verified by fresh greps at this HEAD rather than read from the summary. The three
retired phrasings return **zero** hits across both `Sources/DownloadClient` and
`Tests/DownloadsFeatureTests`, and the claim is now OWNED:
`testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`
(`DownloadSourceInventoryTests.swift:376`) reads whole files over a walk widened to
`scannedDirectories = [clientModuleDirectory, downloadsTestDirectory]` (`:59`), with its detection
tokens assembled from fragments (`:83-85`) so a repository grep cannot match the check itself. The
widening hazard was handled rather than ignored — `clientModuleFiles(in:)` (`:471`) re-scopes every
pre-existing census to the client module explicitly, which is the seam that keeps a wider walk from
silently re-basing five tables. `completedCount` (word-bounded) returns zero in the client module and
`inFlightProgressUpdate` returns zero across the whole test target.

## The post-round-15 review, adjudicated independently

All five findings were re-derived in source. **All five are CONFIRMED**; none was refuted. The review
also claims every finding of the round-15 report is closed, and that claim was checked rather than
accepted — it holds, and the four closures are recorded above.

### CR-01 — CONFIRMED, promoted to G-15-30 (blocker)

Checked in both directions, and the finding survives both.

**The mechanical half holds.** The admission records a bare membership
(`+ExecutionSupport.swift:495-501`) and membership makes the record authoritative in full
(`+ContinuedSession.swift:159-162`). For the refusal family those are opposites:
`completedPageCount` is `pages.values.filter({ !$0.isEmpty }).count`
(`DownloadedGallery+Manifest.swift:67-69`), and the refusal returns the manifest verbatim on all
three exits — the scan-failure guard (`+ExecutionSupport.swift:634`), the nothing-blanked guard
(`:646`) and the all-or-nothing residual `blankedPageCount < manifest.completedPageCount` (`:655`).
The record therefore reads N of N at the announcement and N at every push until the run ends.

**All three consequences were traced to source rather than accepted.** (1) The card opens at 100%:
both run-proof cases assert `"6 / 6 pages · 1 gallery"` as the expected OPENING (`:129`, `:212`) over
a fixture whose folder holds no page file at all (`:118`, `:119`), and the same file records at
`:185` that the pre-preparation opening was `"0 / 6 pages · 1 gallery"` — so the six pages are
credited by the announcement and by nothing else. (2) The numerator is frozen: the push exists for
liveness (`ContinuedProcessingSession.swift:194-196`), and for this family the pre-fix constant was 0
and the post-fix constant is N. The fix moved the constant, not the stall. (3) The departure retires
the ceiling into both sides, and this is the provable harm: a paused complete-reading record fails
`shouldSchedule` (`+Scheduling.swift:125-135`) and departs; it IS in the trust set, so
`reconcileRetiredSessionPages` takes the trusted branch and retires
`min(max(record.completedPageCount, 0), record.pageCount)` (`:603`); the retired total is added to
BOTH sides (`:683-686`); and when it was the session's last gallery the drain branch pushes that pair
and calls `finish(clientSessionID, true)` (`:508`, `:521`).

**The written premise source now contradicts** is `reconcileRetiredSessionPages`'s own doc, which
names the guard meant to prevent exactly this (`:557-564`) and closes with the direction rule the
change reverses (`:571-574`): "under-retiring keeps the fraction at or below truth, while
over-retiring is the defect." Putting the refusal family inside the trust set means the guard no
longer holds it out. The `BY DESIGN` acknowledgement at
`DownloadContinuedSessionLedgerRefusalTests.swift:59-66` is sound for the COMPLETED case its own
staging drives, where the terminal N/N happens to be true; it does not cover the paused, deleted,
cancelled or expiration-swept departures, and `pauseAllSchedulable` makes D-11's expiration sweep one
of them.

**Reachability was verified independently, not taken from the reviewer.** Downloads live under
`.documentsDirectory` (`AppTools/FileUtil.swift:7-11`), and `App/Info.plist` sets
`UIFileSharingEnabled` (`:170`) and `LSSupportsOpeningDocumentsInPlace` (`:145`) both true, so
deleting a gallery's page files through the Files app and tapping resume is an ordinary user route
into the residual refusal.

**The reviewer's own falsification test was run and did not falsify it.** No production route lowers
a refused record's `completedPageCount` during the run: `refreshManifestPageFileHash(es)` assigns
only hashes from `hashReadableAsset`, which throws rather than blanking
(`DownloadStore+Operations.swift:180-205`); `addingCurrentFileHashes` fills empty hashes only; and
`shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
(`+ExecutionSupport.swift:711-712`), so no fresh manifest is written over it.

One thing separates this from a green-suite blind spot and is worth stating plainly: **the suite does
not merely fail to express G-15-30 — it PINS it.** Two of the 880 passing cases assert the 100%
opening as the correct reading. A green run is therefore not evidence against this gap.

### WR-01 — CONFIRMED, promoted to G-15-31 (warning, severity NOT raised)

Every link verified. The identifier is minted per `start(...)`
(`ContinuedProcessingSession.swift:136-138`) and registered through
`BGTaskScheduler.shared.register(forTaskWithIdentifier:using:)`
(`ContinuedTaskScheduling.swift:84-98`), and the file's own doc supplies the constraint that makes it
unbounded — a handler can never be unregistered. That constraint requires the identifier to be
UNIQUE; the code makes it FRESH, which is strictly stronger and pays for the difference forever. The
two failure arms were separated rather than lumped: on the refused-registration arm
(`:147-150`) no handler is added, but on the throwing-submit arm (`:165-180`) the handler was already
registered, so a persistently refusing device accumulates one per retry. `endSession` takes the
pending request back (`:297`, `:306-308`) but cannot unregister.

Severity was weighed and left at warning rather than raised the way round 15 raised its WR-01. The
distinction is outcome: that one produced a wrong number on the user's card, while this one loses no
work, duplicates none and surfaces no error — a stale handler's launch is turned away by
`handleLaunch`'s identity gate. It is unbounded resource accumulation and an inversion of the API's
intended registration pattern, which under this project's bar is blocking to SHIP but does not
downgrade a success criterion.

### WR-02 — CONFIRMED, promoted to G-15-32

`BackgroundProcessingClient.unavailable`
(`DownloadContinuedSessionExpirationTests.swift:406-416`) has no `await Task.yield()` at any of its
three endpoints, while the spy's header one file over states the rule
(`DownloadFeatureTestSupportTypes.swift:81-85`) and its own closures each open with one.
`ensureContinuedSession`'s ownership re-check (`+ContinuedSession.swift:268`), additive floor seed
(`:283`) and merged trust seed (`:313`) all exist to survive the client start's main-actor hop, and
every case running this double drives that path with the hop removed.

The finding is sharper than it looks because of what this round did: 15-48 corrected the SPY's
terminal contract for `.unavailable` — it now releases the held identity exactly as `.expired` does —
and left this sibling double's TIMING untouched. The same event, the same seam, two doubles, one
faithful and one not. That is this phase's recorded generator in its double-faithfulness form,
producing a finding for the third round running.

### WR-03 and WR-04 — both CONFIRMED verbatim, grouped as G-15-33

`isSupersededByALiveRun` (`+Execution.swift:308-314`) compares an `Int?` against an `Int`, so a
generation-less run is treated as superseded by type promotion rather than by a written branch, while
the sibling `isActiveTaskOwner` immediately below (`:316-326`) states the same case with an explicit
`if let generation`. `processDownload(gid:generation:)` is `public` with `generation` defaulting to
`nil` (`:9-12`), so the arm is reachable from outside the module.

`DownloadSourceInventoryTests.scannedFiles()` (`:442-462`) has no self-exclusion, while
`DownloadLogPrivacyInvariantTests.scannedFiles()` applies one by path and justifies it (`:254`,
`:270-272`). The prose test reads whole files, so it polices its own prose; it passes today only
because the three retired phrasings live in it as assembled run-time fragments (`:83-85`) and never
as prose. The asymmetry is with the suite's own reasoning, which excludes comment lines from every
census (`executableLines`, `:427-432`) so a doc describing an inventory does not become part of it.

## Executor deviations, judged

All three are **legitimate**, and each was checked against source rather than against its own
account.

1. **15-47 swept 7 forwarder suites where the plan named 3.** Verified: the forwarder has 23 call
   sites today across 8 suites, of which the 3 in `DownloadContinuedSessionRunProofTests` are
   15-48's — leaving exactly the 20 across 7 suites the executor recorded, with
   `DownloadContinuedSessionReconciliationTests` and `DownloadInterruptedResumeTests` genuinely
   absent from the plan's list. The plan's STOP instruction cannot govern here: the change makes
   `prepareWorkingSeedAnnouncingProgress` return `PreparedWorkingRun` instead of a seed, so every
   reading call site is a COMPILE error until swept. Stopping would have left the tree unbuildable.
   Recording the discrepancy and sweeping is the only available correct action.
2. **15-48 found 5 exits of `processDownload` where the plan enumerated 4.** Verified in source: the
   mid-run `guard !Task.isCancelled else { return }` (`+Execution.swift:41`) sits between
   `fetchNormalizeAndDownload` and `completeDownload` and reaches neither settle. The remedy's shape
   is exit-count independent — a `defer` covers five as readily as four — so the discrepancy changes
   the DOC and nothing else. Sweeping was right; stopping would have traded a correct fix for a
   round.
3. **15-49's `private` modifier and its exclusion-list correction.** Verified: `clientModuleFiles(in:)`
   is declared `private static func` at `:471` and returns `[ScannedFile]`, a private nested type, so
   the plan's own step path did not compile without it — a blocking compile error, not a design
   change. The exclusion-list correction is the better half: the plan named three symbols that
   contain no `completedCount` substring at all, while the real confounder was a plural test local
   (`completedCounts`, `DownloadContinuedSessionTests.swift:395-397`), which exists exactly as
   recorded. Re-deriving with a word-boundary grep and stating the discrepancy is the behaviour the
   plan asked for, applied against the plan itself.

## Behavioural spot-checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| The three run-lifetime regressions exist | `grep -n 'func test' …RunProofTests.swift` | `:73`, `:161`, `:251` | PASS |
| The selected-page-retry regression exists | `grep -n 'func test' …LedgerRefusalTests.swift` | `:309` (plus `:400` route pin) | PASS |
| The retired sentence is gone from BOTH trees | grep of the three phrasings over Sources and Tests | 0 hits | PASS |
| The dead counter and the unreadable spy field are gone | word-bounded greps | 0 hits each | PASS |
| A refusal repair PAUSED mid-run terminates at what it finished | — | no such case exists in the suite | FAIL (G-15-30) |
| A refusal repair's intermediate pushes strictly increase | — | no such case exists; two cases pin the opposite | FAIL (G-15-30) |
| Two sequential sessions register one identifier | — | no such case exists in the suite | FAIL (G-15-31) |

## Mechanical gates re-derived at this HEAD

- No debt marker (`TBD`, `FIXME`, `XXX`, `TODO`, `HACK`, `PLACEHOLDER`) appears anywhere in
  `Sources/DownloadClient`, `Sources/BackgroundProcessingClient` or `Tests/DownloadsFeatureTests`.
- `awk 'length($0)>120'` over every Swift file in both source modules and the test target returns
  nothing.
- No file in either module or the test target exceeds the 1000-line `file_length` error gate; the
  largest are `DownloadCoordinatorStorageTests.swift` at 994 and
  `DownloadClient+ExecutionSupport.swift` at 880.
- The deleted-tier grep returns zero hits across `App/`, `AppPackage/Sources`, `AppPackage/Tests` and
  `ShareExtension/`; `import BackgroundTasks` occurs in exactly one file in the whole tree.
- Working tree clean at `3961698c`.

## Human verification, still open and still independent

15-UAT.md reads `status: diagnosed` and its test 2 still reads `result: issue`. It has not been
re-run since any fix landed, and no plan in 15-46..15-49 claimed it. It is retained under
`status: gaps_found` because its axis is independent in both directions — closing G-15-30..G-15-33
does not discharge it, and it cannot discharge them.

One qualification carries forward in inverted form, so the run yields information rather than a
rediscovery. Round 15 warned that a repair torn down mid-run or resumed at launch would still read
ZERO; those orderings are now fixed. What replaces them is the opposite reading: a repair over a
complete-reading record will open the card at its FULL page count and hold there. Record any
pinned-at-100% observation as G-15-30 rather than treating it as new information, and note whether
the gallery was paused or swept before the queue drained — that is the shape that also produces the
false successful completion.

## Where this leaves the phase

Round 16 is the first round in five whose closures all held under re-derivation: four gaps targeted,
four closed, and the one that had resisted for two rounds closed at its root rather than at its
staging. The remedy is also the first to have been gated on a derivation the previous round demanded
in advance — judgement (2) named the retirement points, and 15-48 derived them, enumerated the five
exits its own plan had undercounted, and pinned the lifetime with a case whose doc admits its own
pre-fix vacuity. That is a different quality of work from the rounds that produced G-15-9, G-15-20
and G-15-23.

What it did not do is ask what the proof BUYS. Five rounds went into establishing that the refusal
family earns trust; none asked what trust unlocks, and the answer is the record's ceiling — which for
this family is exactly the work the run has not done. So the pinned `0 / N` became a pinned `N / N`,
and the departure that used to under-retire now over-retires into both sides of the fraction, which
the ledger's own doc names as the defect and the direction rule it closes with forbids. The generator
is no longer "a fix scoped to its own regression case"; it is narrower and more instructive — a fix
that corrects the PREDICATE and inherits the BASIS. The next round should change the basis: carry the
run's shortfall rather than a membership, derive the decrement point the way 15-48 derived the
`defer`, and clamp the retirement with the same number, so the numerator finally climbs page by page
instead of moving between two constants.

---

_Verified: 2026-08-06T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Amended: 2026-08-06 by Claude (gsd-verifier) — round 16: G-15-26, G-15-27, G-15-28 and G-15-29 all verified CLOSED in source at HEAD 3961698c before any SUMMARY was read, with the seventh amendment's judgement (2) discharged against `processDownload`'s `defer` and both settle paths; all five findings of the post-round-15 review independently adjudicated and ALL FIVE CONFIRMED; the three executor deviations judged legitimate; SC1, SC3 and SC4 held at verified and SC2 held at FAILED on the inverse of the defect the previous four rounds chased; four gaps G-15-30..G-15-33 recorded; the device UAT test 2 item deliberately retained under gaps_found._
