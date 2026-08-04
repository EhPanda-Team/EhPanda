---
phase: 15-continued-background-downloads
verified: 2026-08-05T00:30:00Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
amended: 2026-08-05T00:30:00Z
amendment_note: "This file is written in rounds and each part records the HEAD it was derived at; nothing is re-derived retroactively. The body above the FIRST amendment heading was written at HEAD d246b1a3, BEFORE gap-closure plan 15-22 landed. Gaps G-15-3 and G-15-4 were added afterwards from the post-15-22 code review (15-REVIEW.md, commit 7b8513d2) and confirmed against source by the execute-phase orchestrator; both were CLOSED by plans 15-23 and 15-24. Gap G-15-5 was added on top from the post-15-24 re-review (15-REVIEW.md, commit 613270a7), confirmed against source, and was CLOSED by plan 15-25. The SECOND amendment heading is round 9, written at HEAD 6fc528f1 after 15-25 landed: it verifies G-15-5's closure in source and records the new blocker G-15-6, re-derived independently from the post-15-25 review (15-REVIEW.md, commit 6fc528f1, CR-01)."
next_action: "Close gap G-15-6, then re-run UAT test 2 on a physical iOS 26 device. These are two independent axes: SC2 is now both defeated in code by G-15-6 AND still behaviourally unverified on hardware, and closing the gap does not discharge the device item."
next_command: "/gsd-plan-phase 15 --gaps"
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "G-15-2 — a gallery finishing mid-session collapsed the card to a 100% fraction and a shrinking gallery count, freezing the numerator the scheduler reads as a liveness signal."
    - "G-15-3 — closed by plan 15-23 (commit 60b660fb): the drain branch now re-validates drain-ness, not session identity, behind the terminal push, and the client-seam spy suspends on every endpoint so the race is expressible."
    - "G-15-4 — closed by plan 15-24 (commit 0c0f3995): a complete-reading record contributes zero session pages until this session observes it doing real work, gated on an `observedIncompleteSessionGIDs` trust set shared with the retirement path."
    - "G-15-5 — closed by plan 15-25 (commits 06763885, 7b0fa678): `reconcileWorkingManifestAgainstPageFiles` inside `prepareWorkingSeed` blanks the hash of every page whose file is gone, so a repair's record reads incomplete and D-G4-01's raw-counting half takes over; `prepareWorkingSeedAnnouncingProgress` (called from `performDownload`) makes the incomplete window's observation production-guaranteed at K=1; and the session-start seed merges instead of overwriting so the observation survives the client-start main-actor hop. Re-derived in source, all three mechanisms."
  gaps_remaining: [G-15-6]
  regressions:
    - "G-15-6 — introduced by the G-15-5 fix in plan 15-25. The reconciliation is the first mechanism in this phase that can LOWER an already-counted gallery's page count mid-session, and the session's monotonic floor is a single scalar over the whole-queue sum, so it absorbs the credit for the work that follows the correction. See the gaps list."
behavior_unverified_items:
  - truth: "SC2 — the system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving state consistent with an in-app cancel."
    test: "On a physical iOS 26 device, queue at least three galleries of clearly different sizes, start in the foreground, background the app, and watch the system card across the FIRST gallery's completion and then across a manual pause of one remaining gallery. Then cancel from the card, foreground, and compare queue state against pausing each gallery by hand. Since plan 15-25 this item also carries the repair route: stage a gallery that resolves `.repair` (a record with page files missing) inside a multi-gallery queue and watch whether the card climbs across its run."
    expected: "The card's completed count keeps climbing past the first gallery's completion instead of pinning at 100%; the total does not shrink; the subtitle keeps naming the remaining galleries; the remaining galleries keep downloading; a pause leaves the card still able to reach completion; card-cancel leaves the same state as the in-app per-gallery pause; and a repair's card climbs rather than pinning."
    why_human: "This is the exact behavior the device UAT found broken (15-UAT.md test 2, result `issue`). The fixes are changes to pushed arithmetic, proven deterministically by DownloadContinuedSessionLedgerTests, but the card is rendered by system UI outside the app and neither it nor the scheduler's stall-detection response exists in the simulator. The UAT record has not been re-run since any of the fixes landed. NOTE: this item is a SEPARATE axis from gap G-15-6, which independently defeats the same criterion in code — a green device run would not close G-15-6, and closing G-15-6 would not close this item."
human_verification:
  - test: "Re-run 15-UAT.md test 2 on a physical iOS 26 device with a multi-gallery queue, watching the card across the first gallery's completion and across a mid-queue pause, then cancelling from the card. Include a `.repair` gallery in the queue."
    expected: "Counts advance past the first completion, the total holds, the subtitle names the remaining galleries, the queue keeps downloading, a repair's card climbs rather than pinning, and card-cancel matches the in-app per-gallery pause baseline."
    why_human: "The reported defect was device-observed; the card and the scheduler's stall handling do not exist in the simulator, and the UAT record still reads `result: issue`. Run this only after G-15-6 is closed, or the run will observe a known-defective floor."
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
deferred: []
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
