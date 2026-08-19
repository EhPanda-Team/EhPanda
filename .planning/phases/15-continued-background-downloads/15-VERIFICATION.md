---
phase: 15-continued-background-downloads
verified: 2026-08-19T10:35:00Z
re_verified_after_device_round: 2026-08-19T12:55:00Z
re_verified_after_fix_round: 2026-08-19T13:15:00Z
status: passed
score: 9/9 must-haves verified
behavior_unverified: 0
overrides_applied: 0
head: f5b3519f
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  previous_verified: 2026-08-10T10:32:45Z
  scope: |
    The previous report was written against a tree three substantial rounds behind this HEAD
    (13cad7d9, 764c5958, f7e65497, plus plan 15-77 and the pin b0d2d57e). Every item in its
    `gaps`, `gaps_remaining` and `regressions` lists was re-derived against source at f9892824
    rather than carried forward. The roadmap's four Success Criteria — which the previous report
    did not enumerate as its truths — were verified independently as the phase's scope contract.
  gaps_closed:
    - "GAP 1 — user folders the app lists were un-deletable and un-renamable from inside the app. Closed at the root: `confinedDirectUserFolderURL` (DownloadStore+Operations.swift:507-527) no longer carries the `normalizedUserFolderName(rawName) == rawName` clause, and every structural refusal the previous report demanded be kept IS kept (non-empty, not `.`/`..`, single path component, no control characters, not gallery-shaped, standardized parent == root, symlink-resolved parent == root). Minting sites still normalize (Folders.swift:23 create, :58 rename's new name). `removeFolder(relativePath:)` — the dead public reproduction of the unconfined construction — is gone (0 hits). The missing POSITIVE half of the catalog now exists as its own suite: DownloadFolderAdmissionTests stages `Art  Books`, ` Photos`, `Manga\\Vol1` and `Misc etc.` as folders whose OWN on-disk name is non-normalized. Device-confirmed: 15-UAT test 15 passed on a physical iPhone 11 / iOS 26.6 with all three fixtures created through the real Files app — list, delete, rename and move-into all succeeded and no near-duplicate `Art Books` was minted."
    - "GAP 2 — `materializeRepairSeed` deleted source-folder page files while reconciling nothing. Closed by REMOVAL, not by patching: `materializeRepairSeed`, `repairSeed(for:payload:)`, `RepairSeed`, `RepairSeedContext` and `linkOrCopyReadableAsset` are all 0-hit across Sources and Tests at this HEAD (retired in f7e65497 with the completion sweep they existed to feed). The `discardingRejected: true` census is now exactly ONE production site — DownloadClient+ExecutionSupport.swift:504, the cover resolution, entitled on the stated test because a cover carries no recorded hash — and that count is pinned by `DownloadSourceInventoryTests` (`expectedDiscardingRejectedTotal = 1`, line 448), so a fourth unentitled site cannot be added silently."
    - "GAP 3 — the seed route copied the validate route's ordering and dropped its compensation. Closed at the root by SHARING the compensation rather than re-implementing it: all three post-removal exits now reach `recoveredBlanking`, the validate route's own implementation — exit 3 (thrown manifest write) at ExecutionSupport.swift:475-483 recovers then propagates as a `Result` rather than throwing past the bracket, and exits 1/2 at :485-495 recover through the single `claimsAnyPage` predicate. `recoveredBlanking` logs at `error` with the removed page indices and a hash-masked gid (PersistenceNormalize.swift:438-445). The over-reporting half is closed too: `inheritedPages` subtracts the pages this pass removed before the pessimistic branch runs (`presumedDonePages = probedDonePages.subtracting(workingSeed.removedPages)`, SeedReconciliation.swift:166), so a post-removal rescan failure can no longer inflate the announced basis."
    - "GAP 4 — `toggleDownloadPauseDone(.failure)` was a silent no-op. Closed, and swept rather than branch-fixed: DownloadInspectorReducer.swift:242-250 sets `state.toast = error.actionFailureToast` (the helper was renamed off `retryFailureToast` as the previous report required), and the reducer's type doc now carries the COMPLETE enumeration of outcome-carrying actions with a disposition each (lines 10-27), naming `observeDownloadsDone` as outside the policy rather than an exception to it."
    - "GAP 5 (partial) — unowned invariants. All four residuals resolved. (a) The bracket-nesting rule is now DETECTED, not merely documented: a depth guard around `movement()` reports through `reportIssue` (ExecutionSupport.swift:347-352) rather than crashing, and the doc at :321-333 states honestly that nothing refuses a nest at compile time. (b) `downloadsTestFiles(in:)` is deleted (0 hits) so the inventory suite no longer contradicts itself. (c) The localized-key spelling split is closed: 19 `String(localized: .RLocalizable.…)` call sites and 0 bare ones in DownloadClient. (d) `waitForTaskValue`'s 10s default survives as an OWNER-RATIFIED decision, not an inherited default — 15-74 DEC-E declined the 1s bound on the repo's own recorded 13.2s contended wall time, and 15-UAT test 13 ratified the refusal on 2026-08-17, routing the sentinel-fence alternative (which needs no production change) to deferred-items.md."
  gaps_remaining: []
  regressions_recheck:
    - "BLOCKER (delete/rename confinement predicate refusing listed folders) — RESOLVED. See gaps_closed item 1; verified against source and by device UAT 15."
    - "prepareWorkingSeed's authorized removal dropped its post-removal recovery — RESOLVED. See gaps_closed item 3; all three exits reach the shared `recoveredBlanking`."
    - "toggleDownloadPauseDone(.failure) un-swept sibling — RESOLVED in the inspector. The DownloadsReducer sibling is deliberately still silent, but it is now a DISPOSITIONED deferral, not a silent branch: stated in the reducer's type doc (DownloadsReducer.swift:36-41), restated at the case (:387-393), and logged in deferred-items.md with the reason (the list reducer owns no toast surface; `alert` is `AppAlertState<Alert>` and the toast factories are constrained to `Action == Never`, so reporting it is a presentation addition rather than a branch fix)."
    - "WR-02 / WR-04 (fourth code review) — RESOLVED in 421719a6 and cf8a0748; `moveDownload` now admits a picked destination as written and licenses minting on its own terms (Folders.swift:214-248), with `testMoveDownloadRecreatesAListedFolderTheAppWouldNotMint` as the counterpart that fails if the guard is ever tightened back into a rewrite."
    - "WR-01 / WR-02 / WR-03 (LogsDirectoryMigration) — MOOT. The owner deleted `LogsDirectoryMigration` outright on 2026-08-17 (81a2b6d5); 0 hits across Sources and Tests. UAT tests 10 and 11 are `obsolete` rather than pass/issue for the same reason, which is the honest count."
    - "WR-05 (dialog placement) — RESOLVED by owner decision taking option (a): the CLAUDE.md placement rule was AMENDED (5ce35665) to keep a per-row destructive dialog on the row, with the device observation on iPhone 11 and iPad mini 6 recorded in the rule itself. DownloadsView.swift:227 attaches the dialog to the row, matching the amended rule; UAT test 8 device-verified both halves."
    - "Swipe-delete vanish/reappear regression — RESOLVED (9421b7bb, 8277ded7, 15afbde4). The trailing swipe Delete drops `role: .destructive` and takes `.tint(.red)` (DownloadsView.swift:214-225) while the context-menu Delete keeps its role (:352). UAT test 7 passed on device."
    - "IN-01 (waitForTaskValue 10s) — DECLINED with a written derivation by 15-74 DEC-E and RATIFIED by the owner at UAT test 13. Not a gap."
    - "IN-02 (localized-key spelling split) — RESOLVED by 15-75; census re-derived at this HEAD as 19/0."
gaps: []

gaps_closed_after_this_report:
  - truth: "SC2 — with no airplane mode and a healthy network, a continued-processing session does not end while its queue still has work."
    status: CLOSED
    closed: "2026-08-19, 15-UAT round 8, on the test iPhone at build f5b3519f"
    closure: |
      Root cause (1) below was the real one, and the owner took both remedies. Quick task 260819-lq3
      landed them: `pageTransferAbandonThreshold = 60` makes the heartbeat sweep ABANDON a transfer
      that has produced no bytes for a minute, cancelling it into the page's existing retry path
      (2a2c5982); and `ContinuedProgressNudge` gives the card a bounded way to say "still working,
      nothing to add" — one sub-unit per stalled liveness report, capped at 30 consecutive, cleared
      by any change in the measurement (d6079878).

      Device-verified at round 8 on the SAME gallery this gap was found on (`[Patreon] Crowns18`,
      resumed at 575/951 with 376 pages outstanding), with the app genuinely backgrounded for
      ~23 minutes — the half round 7 could not observe. The session was granted at 12:14:12 and ran
      unbroken to `Continued-processing session drained, terminal progress pushed` at 12:46:07:
      31m55s, 105 heartbeats, NO `Continued-processing session expired`, and no fall-back in the
      numerator. Three transfers starved and each was abandoned at 64.7 s / 61.5 s / 63.6 s and
      retried within 3 s, the numerator resuming within 15 s every time. The nudge peaked at
      `nudge 7 of 30` — 7 sub-units against a 1,057,000 sub-unit total.

      The card's cancel was also exercised for the first time in any round and matched the in-app
      per-gallery pause baseline exactly: both routes left every gallery paused with its page count
      preserved. Full trace in 15-UAT.md under test 2, `retest_round_8_reported`.
    superseded_finding_below: "The FAILING record is kept as written, because the two candidate root causes it named are what the owner decided between."
    found: "2026-08-19, on the device round this report asked for (15-UAT round 7, gap G-15-2I)"
    evidence: |
      The prescribed SC2 round was run on the test iPhone against this HEAD and the session was
      reclaimed with 376 of 1542 pages outstanding. From Logs/ehpanda-20260819-120659-2.jsonl:
      23 consecutive heartbeats at a byte-identical `1166 / 1542 pages, 0 in-flight subunits`
      spanning 676 s, then "Continued-processing session expired, pausing schedulable downloads"
      with "environment at expiry: network wifi, low power false, thermal fair". One transfer
      (page 576) was reported starved at 12.6 s without bytes by `sweepStarvedPageTransfers` and was
      then never completed, failed or retried — `InFlightPageTransfer.stallLogged` suppresses the
      repeat, and nothing else acts on the detection.
    two_candidate_root_causes: |
      (1) The starved transfer is detected and not acted on. `pageTransferStallThreshold` is 10 s and
          the sweep fires, but its only effect is a log line, so real progress never resumes.
      (2) `updateProgress` has no way to express "still working, nothing to add". It publishes
          `completedUnitCount * 1000 + inFlightSubunitCount` (ContinuedProcessingSession.swift:268-286);
          both terms were frozen, and republishing an identical count is not an advance. The
          heartbeat already computes this condition at
          DownloadClient+ContinuedSessionHeartbeat.swift:96 but uses it only to suppress a log line.
      Owner decision needed on which to take, and on the bound each carries.
    not_a_regression_from: "f7e65497 — that commit does not touch DownloadClient+ContinuedSession.swift. This is the pre-existing stall-detector exposure round 6 happened not to hit."
    bound: "The app was in the FOREGROUND throughout (agent-device `home` reported success without landing), so the backgrounded half of the SC2 procedure is still unobserved at this build. A foreground expiry is at least as severe."
    owner_ruling_it_violates: "2026-08-17 — a session ending with downloads incomplete is unacceptable absent airplane mode or a network fault. The expiry probe recorded `network wifi`, so the precondition held."
deferred:
  - truth: "The downloads list reports why a refused Pause/Resume did nothing (the inspector's WR-05 refusal seen from the list)."
    addressed_in: "deferred-items.md — routed as a presentation addition (new @Presents toast value, action case, .ifLet, view modifier), outside plan 15-73's stated no-behavior-change scope."
    evidence: "DownloadsReducer.swift:36-41 and :387-393 state the disposition in source; deferred-items.md carries the full reasoning."
  - truth: "`fetchDownloads` / `fetchFolders` throws have somewhere to go."
    addressed_in: "deferred-items.md"
    evidence: "DownloadsReducer.swift:251-255 and :288-292 `try await` inside `.run { }` with no `catch:`; neither action is result-carrying, which is why the failure has no channel. Logged out of scope during the 15-73 sweep."
  - truth: "`AppPackage/Package.swift` is within the 1000-line `file_length` ERROR limit."
    addressed_in: "deferred-items.md"
    evidence: "1128 lines at this HEAD. Pre-existing (1129 before 15-75 removed one line) and outside this phase's subject."
  - truth: "The eight download error-message keys are bridge-checked at compile time rather than hand-typed."
    addressed_in: "deferred-items.md — routed as a Resources-module change (forward the 43 hand-written accessors to the already-generated STRING_CATALOG symbols)."
    evidence: "15-UAT test 14, owner-closed 2026-08-17 with the question reframed from copy-pinning to bridge integrity."
behavior_unverified_items_resolved_2026_08_19: |
  The single item below was ANSWERED by the device round on 2026-08-19 and did NOT hold: see gaps
  above (G-15-2I). It is kept for the procedure it specifies, which the round followed.
behavior_unverified_items_original:
  - truth: "SC2 — the system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving download state consistent with an in-app cancel."
    test: "On a physical iOS 26 device, on a build containing f7e65497: queue at least two galleries INCLUDING a `.repair` of a gallery whose files were deleted outside the app, start in the foreground, background the app, and watch the system card. Then cancel from the card, foreground, and compare queue state against pausing each gallery by hand."
    expected: "The card's numerator never exceeds work actually done and never falls back within a reporting regime; the subtitle's gallery count holds steady across a gallery's completion; the repair climbs from its announce rather than freezing at the record's stale claim; card-cancel state matches the in-app per-gallery pause baseline. Additionally, on completion the gallery's folder is the one the record points at and no second folder was removed."
    why_human: "The announced basis this card renders is exactly what f7e65497 changed — `WorkingSeed` lost `existingDownload` and `carriedUnprobedPages`, `authorizedReconciliationScan` now answers with the rescan directly, and `prepareWorkingSeed` hands the destination scan through unrebuilt. The only device evidence for SC2 is 15-UAT round 6, taken 2026-08-18 against build 260818-ek3, and the UAT was marked `complete` at 2026-08-18T12:30Z — both BEFORE f7e65497 existed (2026-08-19T01:24). The phase's own standard, recorded in 15-UAT under the G-15-2D precedent, is that a fix is not closed until a device shows it; that standard was applied to 13cad7d9 and 764c5958 and has not yet been applied to the phase's largest production delta. The system's grant, its card and process suspension do not occur in the simulator, so the 997-test suite cannot substitute."
human_verification:
  - test: "RUN 2026-08-19 — outcome recorded in gaps above. The round staged the prescribed fixture (a `.repair` of a gallery whose files were deleted outside the app, alongside two other galleries) and reached a confirmed defect before the card clauses could be judged."
    expected: "SC2's card clauses hold as they did at round 6, and the run leaves the record's folder authoritative with no user folder removed."
    result: "FAILED on session lifetime (G-15-2I). The parts that were reached PASSED: the wholesale guard refused as designed, the 27-page from-zero repair completed, the other gallery completed at 564 pages, and the subtitle's gallery count tracked the queue across three enqueues (denominator 564 -> 591 -> 1542)."
  - test: "After an owner decision on G-15-2I and a fix, re-run the SC2 procedure BACKGROUNDED, including the card cancel, which round 7 never reached."
    expected: "The session survives a zero-byte stretch or the stalled transfer is retried so the numerator moves; the queue drains; card-cancel state matches the in-app per-gallery pause baseline."
    why_human: "Simulator neither grants continued-processing tasks nor renders the system card."
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the short grace period that bounded the previous behavior.

**Verified:** 2026-08-19T10:35:00Z at `f9892824` (branch `feature/gsd-phase-15`, working tree clean)
**Status:** gaps_found — one criterion (SC2) is FAILING after the 2026-08-19 device round
**Re-verification:** Yes — the 2026-08-10 report is superseded in full.

## What changed since the previous report

The previous report (`status: gaps_found`, `score: 2/4`) was written against a tree that no longer
exists. Between it and this HEAD:

| Commit | Effect |
|---|---|
| `13cad7d9` | Froze the gallery folder leaf (G-15-2H); parent stays the caller's so an in-app move still relocates |
| `764c5958` | Published a live run's credited page set on the row, badge and page states (G-15-2F) |
| `8277ded7`, `15afbde4`, `9421b7bb` | Plan 15-77 — per-row delete confirmation and the swipe-delete choreography |
| `421719a6`, `cf8a0748` | Fourth-review WR-02 and WR-04 |
| `f7e65497` | **1260 deletions across 27 files** — retired the completion sweep `removeSupersededFolders` AND the whole repair-seed materialization |
| `b0d2d57e` | Pinned that a full run leaves another folder of the same gallery untouched |

`f7e65497` also changes what "correct" MEANS here. `CLAUDE.md` gained the principle *"Download
folders are user-owned; guard one invariant, do not chase edge cases"* on 2026-08-19. The single
invariant is that the download client never deletes a gallery folder it did not itself create in
the same run; everything else about external Files-app mutation is best-effort by owner decision,
and a rename-plus-stale-index leaving TWO folders is the accepted consequence rather than a defect.
Every judgment below is made against that line.

## Goal Achievement

### Observable Truths — the roadmap's scope contract

ROADMAP.md maps no requirement IDs to this phase: *"the scope contract is this phase's four
success criteria, referenced by plans as SC-labels."* These four are therefore the must-haves.

| # | Truth | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue large enough to outlast the `beginBackgroundTask` grace period | ✓ VERIFIED | `BGContinuedProcessingTaskRequest` submitted at `ContinuedTaskScheduling.swift:102-110` behind a handler registered at `:87`; the coordinator starts its session at `DownloadClient+ContinuedSession.swift:430` with `.live` injected at `DownloadClient.swift:84`. `beginBackgroundTask` / `endBackgroundTask` = **0 hits** across `AppPackage/Sources`, `App`, `ShareExtension`, so the grace window it bounded is gone rather than fallen back to. Device: 15-UAT test 1 `result: pass` (physical iPhone, ≥3 galleries / ≥300 pages, >60 s backgrounded, no page lost or duplicated). Suite green at HEAD (see Behavioral Spot-Checks). |
| SC2 | The system progress UI reflects real progress and its cancel affordance stops the queue, leaving state consistent with an in-app cancel | ❌ FAILING | The device round this report asked for was run 2026-08-19 at this HEAD and the session was reclaimed with 376 of 1542 pages outstanding, on `network wifi` with no airplane mode, after 676 s of a byte-identical numerator — one transfer starved at 12.6 s without bytes and was never retried. Filed as 15-UAT gap **G-15-2I**; the card's own clauses were never reached. The wiring itself is present and correct (`updateProgress` pushed at `ContinuedSession.swift:982`; the `.expired` arm calls `pauseAllSchedulable(expiring:)` at `:540-544`), and everything else the round exercised passed. Not a regression from `f7e65497`, which does not touch `DownloadClient+ContinuedSession.swift`. |
| SC3 | Submission is best-effort with **no fallback tier**; refusal, indefinite queuing and expiration suspend and resume with no lost or duplicated work and no user-visible error; the discretionary processing-task path and the UIKit execution assertion are deleted outright | ✓ VERIFIED | `beginBackgroundTask`, `endBackgroundTask`, `BGProcessingTaskRequest` = **0 hits** repo-wide — deleted, not demoted. The `.unavailable` arm is silent by contract and logs only (`ContinuedSession.swift:545-549`), its doc stating the reason: *"nothing user-visible may follow, because no fallback tier exists."* `App/Info.plist` keeps `UIBackgroundModes: processing` as a documented deliberate retention (lines 162-165) and carries `BGTaskSchedulerPermittedIdentifiers = $(PRODUCT_BUNDLE_IDENTIFIER).continued.*` — the edit, not a new capability, exactly as discuss-phase resolved. Device: 15-UAT test 3 `result: pass` (refusal, expiration, force-quit; duplicates structurally precluded by index-keyed page filenames, losses checked through the inspector's hash-verifying Validate). |
| SC4 | The capability is reached through a testable client seam in `BackgroundProcessingClient` exposing a continued-processing **session** API — start, update-progress, complete, with events on a self-finishing stream — with an unimplemented test value, so no reducer **or coordinator** touches the system task scheduler directly | ✓ VERIFIED (with a recorded owner deviation) | `@DependencyClient public struct BackgroundProcessingClient` exposes exactly `start` / `updateProgress` / `finish` (`BackgroundProcessingClient.swift:44`, `:60`, `:71`); `BackgroundProcessingSession` carries `events: AsyncStream<BackgroundProcessingEvent>` (`:10`) documented to finish itself after `expired`, `unavailable` or `finish`, so a consuming effect needs no external cancellation. `BGTaskScheduler` appears in **exactly one file repo-wide** — `BackgroundProcessingClient/ContinuedTaskScheduling.swift` — so no reducer and no coordinator reaches the scheduler. The unimplemented value is the macro-synthesized `BackgroundProcessingClient()`, proven by `testUnimplementedClientReportsAnIssueForEveryEndpoint` (`DownloadContinuedSessionTests.swift:13`). **Deviation:** SC4's literal wording says `testValue`; the owner selected option-b on 2026-07-29 (plan 15-16) to REMOVE the unread `DependencyKey` registration rather than preserve a false composition affordance, so the seam is direct constructor injection with `.noop` as the default and `.live` at the one composition root. Intent met; mechanism owner-changed and recorded. |

### Observable Truths — carried forward from the previous report

These five are the truths the 2026-08-10 report failed or partially failed. Each was re-derived
against source at this HEAD, not read from a SUMMARY.

| # | Truth | Status | Evidence |
|---|---|---|---|
| CF1 | Every user folder the app lists is mutable from inside the app, and a destructive user-folder operation still cannot reach a filesystem target the caller did not name | ✓ VERIFIED | `confinedDirectUserFolderURL` (`DownloadStore+Operations.swift:507-527`) admits a source as written; all seven structural refusals kept; minting sites still normalize. `removeFolder(relativePath:)` = 0 hits. Positive half staged by `DownloadFolderAdmissionTests` (`Art  Books`, ` Photos`, `Manga\Vol1`, `Misc etc.`). Device: 15-UAT test 15 pass with fixtures made in the real Files app. |
| CF2 | No act of the app destroys a page file without the same act durably reconciling the record that claims it | ✓ VERIFIED | The offending site is gone with its whole subsystem (`materializeRepairSeed`, `repairSeed`, `RepairSeed`, `RepairSeedContext`, `linkOrCopyReadableAsset` = 0 hits). One production `discardingRejected: true` remains (`ExecutionSupport.swift:504`, the cover — no recorded hash to diverge from), pinned at `expectedDiscardingRejectedTotal = 1`. |
| CF3 | An authorized destructive reconciliation either completes durably or compensates and leaves a trail; the announced progress basis never over-reports | ✓ VERIFIED | Three post-removal exits all reach the shared `recoveredBlanking` (`ExecutionSupport.swift:475-495`); it logs the removed indices at `error` with a hash-masked gid (`PersistenceNormalize.swift:438-445`). `inheritedPages` subtracts `workingSeed.removedPages` before the pessimistic branch (`SeedReconciliation.swift:166`), closing the over-reporting direction. |
| CF4 | Every failing inspector action the user can tap reports why it failed | ✓ VERIFIED | `retryPagesDone` and `toggleDownloadPauseDone` both set `state.toast` through the renamed shared `actionFailureToast` (`DownloadInspectorReducer.swift:214`, `:250`); the type doc carries the complete disposition census (`:10-27`). The list-reducer sibling is a dispositioned deferral, not a silent branch (see Deferred Items). |
| CF5 | A load-bearing invariant this phase relies on is either enforced by construction or detected by a test — never left to a doc sentence that is false or unowned | ✓ VERIFIED | Bracket nesting is now DETECTED via a depth guard + `reportIssue` (`ExecutionSupport.swift:347-352`) with the doc corrected to say the type system refuses nothing (`:321-333`); `downloadsTestFiles(in:)` deleted; localized-key spelling 19 prefixed / 0 bare in `DownloadClient`; the 10 s `waitForTaskValue` bound is owner-ratified (15-UAT test 13, 2026-08-17) rather than inherited. |

**Score:** 8/9 truths verified (1 present, behavior-unverified). No truth FAILED.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|---|---|---|
| 1 | `DownloadsReducer.toggleDownloadPauseDone(.failure)` reports nothing | deferred-items.md | Disposition stated in source at `DownloadsReducer.swift:36-41` and `:387-393`; closing it needs a toast surface the list reducer does not own |
| 2 | `fetchDownloads` / `fetchFolders` throw into a `.run { }` with no `catch:` | deferred-items.md | `DownloadsReducer.swift:251-255`, `:288-292`; neither action carries a `Result` |
| 3 | `AppPackage/Package.swift` is 1128 lines against a 1000-line `file_length` ERROR | deferred-items.md | Pre-existing (1129 before 15-75); outside this phase's subject |
| 4 | Localized-key bridge integrity (43 hand-typed accessors) | deferred-items.md | 15-UAT test 14, owner-closed 2026-08-17 with the question reframed to a build-time fix |
| 5 | Sentinel-fence replacement for the 10 s hang-detector wait | deferred-items.md | 15-UAT test 13 `follow_up` — needs no production change; ten seconds is "a settlement, not a resolution" |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | The session seam — start / updateProgress / finish, unimplemented default | ✓ VERIFIED | `@DependencyClient`; `.live` forwards to `ContinuedProcessingSession.shared`; `.noop` yields at every endpoint deliberately (G-15-36) so a double cannot certify the reentrancy window as impossible |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | Session store + the three-case event enum on a self-finishing stream | ✓ VERIFIED | `BackgroundProcessingEvent` = `granted` / `expired` / `unavailable`, each with its contract documented |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` | The only file touching `BGTaskScheduler` | ✓ VERIFIED | Sole `BGTaskScheduler` / `BGContinuedProcessingTask` site repo-wide |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | Coordinator side — start, heartbeat, expiry→pause, teardown | ✓ VERIFIED | `:430` start, `:982` updateProgress, `:450` / `:720` finish, `:540-549` expiry and unavailability arms |
| `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` | `removeGalleryFolders` as the delete route's sole whole-gallery removal | ✓ VERIFIED | `:105-110`; the invariant and the retired sweep's history are on the declaration; one production caller (`PublicAPI.swift:241`, the user's own delete) |
| `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` | Source-vs-destination admission split | ✓ VERIFIED | `confinedDirectUserFolderURL:507`, `mutatingConfinedUserFolder:449`, re-resolution inside the lock at `:457` |
| `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` | Role-less red-tinted swipe delete; per-row confirmation anchor | ✓ VERIFIED | `.tint(.red)` at `:225` with the reason at `:214`; `.confirmationDialog` on the row at `:227`; context-menu Delete keeps `role: .destructive` at `:352` |
| `App/Info.plist` | Continued-processing permitted-identifier wildcard | ✓ VERIFIED | `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`; `UIBackgroundModes: processing` retained with the asymmetric-failure argument written at lines 162-165 |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadProcessTests.swift` | The deletion-invariant pin | ✓ VERIFIED | `testAFullRunLeavesAnotherFolderOfTheSameGalleryUntouched:183` |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift` | The positive half of the folder catalog | ✓ VERIFIED | Non-normalized on-disk names staged and asserted to delete/rename |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` | Censuses that make a silent regression fail a build | ✓ VERIFIED | `expectedDiscardingRejectedSites:443`, `expectedDiscardingRejectedTotal = 1:448` |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `DownloadClient.swift:84` | `BackgroundProcessingClient.live` | `DownloadCoordinator(backgroundProcessingClient:)` | ✓ WIRED | The one composition root; default is `.noop`, so nothing reaches the system surface by accident |
| `DownloadClient+ContinuedSession.swift:430` | `ContinuedProcessingSession.start` | `backgroundProcessingClient.start(…)` | ✓ WIRED | Counts recorded before submission so an immediately-launched task adopts real progress |
| `DownloadClient+ContinuedSession.swift:982` | the system card | `backgroundProcessingClient.updateProgress(…)` | ✓ WIRED | Ownership-checked by `sessionID` so a caller that lost ownership cannot repaint a successor |
| `ContinuedProcessingSession` events | `pauseAllSchedulable(expiring:)` | `.expired` arm, `ContinuedSession.swift:540-544` | ✓ WIRED | Card cancel and system reclaim share one signal by SDK design |
| `DownloadClient+PublicAPI.swift:241` | `removeGalleryFolders` | user delete action only | ✓ WIRED | Sole caller; `keeping:` parameter gone with the sweep |
| `DownloadInspectorReducer.swift:214/250` | `state.toast` | `error.actionFailureToast` | ✓ WIRED | Rendered through `.ifLet(\.$toast, action: \.toast)` at `:273` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| System progress card | `completedUnitCount` / `totalUnitCount` | The run's credited basis, published through `liveRunProgressBasis` (764c5958) and folded with in-flight sub-unit credit | Yes — `DownloadRunProgress` carries the run's credited page set; the record is the fallback only when no run stands | ✓ FLOWING |
| Downloads row badge / inspector page states | `runProgress` on `DownloadedGallery` | Published at the announce, at every flush, and at every exit including one that no longer owns the active slot | Yes | ✓ FLOWING |
| `WorkingSeed.existingPages` / `unprobedPages` / `scanSucceeded` | the post-removal reconciliation scan | `authorizedReconciliationScan` → `reconciliationScan` | Yes — all three members follow the same scan, so credit and blanking cannot answer from different probes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full `AppPackage-Package` suite at HEAD | `xcrun xcresulttool get test-results summary` over the run bundle in `$HOME/Library/Developer/Xcode/DerivedData/AppPackage-*/Logs/Test/Test-AppPackage-Package-2026.08.19_08-49-41-+0900.xcresult` | `result: Passed`, `totalTestCount: 997`, `passedTests: 986`, `expectedFailures: 11`, `failedTests: 0`, `skippedTests: 0` on iPhone 17e / iOS 26.4.1. Run started 08:49:41, **after** HEAD `f9892824` was committed at 08:48:22, with a clean working tree — so this is a green run at this exact tree, re-derived from the result bundle rather than from a log tail or a SUMMARY claim. | ✓ PASS |
| Single named test (`testAFullRunLeavesAnotherFolderOfTheSameGalleryUntouched`) | `xcodebuild test -scheme AppPackage-Package -only-testing:…` | `** TEST SUCCEEDED **` but the result bundle reports `totalTestCount: 0` — `-only-testing:` does not filter through this package scheme. **The named-test path is unavailable in this project**; the full-suite bundle above is the substitute, and it contains the case. | ? SKIP |
| Retired-symbol sweep | `grep -rn` over `AppPackage/Sources`, `AppPackage/Tests`, `App` for `removeSupersededFolders`, `materializeRepairSeed`, `RepairSeedContext`, `linkOrCopyReadableAsset`, `repairSeed`, `RepairSeed`, `removeFolder(relativePath:`, `downloadsTestFiles`, `LogsDirectoryMigration` | 0 hits for every pattern (the only `RepairSeed` matches are test-local helper names such as `makeRepairSeedPayload`) | ✓ PASS |
| Fallback-tier sweep | `grep -rn "beginBackgroundTask\|endBackgroundTask\|BGProcessingTaskRequest"` over `AppPackage/Sources`, `App`, `ShareExtension` | 0 hits | ✓ PASS |
| Scheduler confinement | `grep -rn "BGTaskScheduler\|BGContinuedProcessingTask"` over `AppPackage/Sources`, `App` | Confined to `BackgroundProcessingClient/ContinuedTaskScheduling.swift` (plus the `Info.plist` key) | ✓ PASS |
| Localized-key spelling census | `grep` over `AppPackage/Sources/DownloadClient` | 19 `RLocalizable.`-prefixed, 0 bare | ✓ PASS |
| `discardingRejected: true` census | `grep -rn` over Sources | 1 production site (`ExecutionSupport.swift:504`) + 1 test site; matches `expectedDiscardingRejectedTotal = 1` | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist in this repository and no plan or summary in this phase
declares a probe. Step skipped as not applicable — the phase's runnable check is the package test
suite, executed above.

### Requirements Coverage

ROADMAP.md maps **no** requirement IDs to Phase 15 (*"Requirements: None mapped — the scope
contract is this phase's four success criteria"*), and no orphaned Phase-15 rows appear in
`REQUIREMENTS.md`. Coverage is therefore the SC table above.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| — | — | `TBD` / `FIXME` / `XXX` across `DownloadClient`, `DownloadsFeature`, `BackgroundProcessingClient`, `DownloadsFeatureTests` | — | **0 hits.** No unreferenced debt marker in any module this phase touched; the debt-marker gate does not fire. |
| — | — | `TODO` / `HACK` / `PLACEHOLDER` across the same modules | — | **0 hits.** |
| `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` | 721-735 vs 737-746 | Doc enumeration narrower than the behavior it describes | ⚠️ Warning | `setupWorkingFolder`'s doc says the wipe is licensed by *"the user's own start mode — `.redownload` and `.update` ask for the folder's contents to be replaced."* A third branch also produces `shouldReuse == false`: `.initial` where the folder exists and its manifest's gid/token/pageCount do not match the payload (`:705-713`). The wipe target is still the run's own working-folder path, so the CLAUDE.md invariant is not crossed, and the reachable shapes are external mutations the same principle explicitly declines to chase — but CF5's standard is that no doc sentence be narrower than the code, and this one is by one branch. Doc-only fix; no behavior change implied. |

### Human Verification Required

#### 1. Re-run the backgrounded queue and a repair on a build containing `f7e65497`

**Test:** On a physical iOS 26 device, on a build containing `f7e65497`: queue at least two
galleries **including** a `.repair` of a gallery whose files were deleted outside the app; start in
the foreground; background the app; watch the system card through both galleries. Then start
another queue and cancel from the card, foreground, and compare queue state against pausing each
gallery by hand.

**Expected:** The card's numerator never exceeds work actually done and never falls back within a
reporting regime; the subtitle's gallery count holds steady across a gallery's completion; the
repair climbs from its announce rather than freezing at the record's stale claim; card-cancel state
matches the in-app per-gallery pause baseline. On completion, the gallery's files are in the folder
the record points at and **no** folder was removed that this run did not create.

**Why human:** `f7e65497` is the phase's largest production delta (1260 deletions across 27 files)
and it lands squarely on the announced basis the card renders — `WorkingSeed` lost
`existingDownload` and `carriedUnprobedPages`, `authorizedReconciliationScan` now answers with the
rescan directly, and no classification crosses a folder boundary any more. The only device evidence
for SC2 is 15-UAT round 6 against build `260818-ek3`, and the UAT file was marked `complete` at
2026-08-18T12:30Z — both strictly before that commit existed. The phase set its own bar here: under
the G-15-2D precedent recorded in 15-UAT, *"a fix is not closed until a device shows it,"* and that
bar was honoured for `13cad7d9` and `764c5958` but not yet for `f7e65497`. The simulator neither
grants continued-processing tasks nor renders the system card, so the green 997-test suite cannot
stand in for this.

## Gaps Summary

**One gap, opened 2026-08-19 by the device round this report prescribed: G-15-2I, SC2 FAILING.**
A continued-processing session was reclaimed with 376 of 1542 pages outstanding, on `network wifi`
with no airplane mode — 23 heartbeats at a byte-identical `1166 / 1542` across 676 s, after one
transfer starved at 12.6 s without bytes and was never completed, failed or retried. It is not a
regression from any commit in this phase's recent rounds: `f7e65497` does not touch
`DownloadClient+ContinuedSession.swift`, and the exposure predates it. Two candidate root causes are
recorded in 15-UAT under G-15-2I — the unactioned starve detection, and the card's inability to
express "still working, nothing to add" — and an owner decision is needed before a fix. The rest of
the round passed, including the wholesale refusal, a 27-page from-zero repair, and the subtitle's
gallery count across three enqueues. Note also that the app was in the FOREGROUND throughout, so the
backgrounded half of the SC2 procedure remains unobserved at this build.

**No OTHER gaps.** Every item the 2026-08-10 report recorded — four failed truths, one partial
truth, three regressions and two carried residuals — is closed at this HEAD, and in each case at the
root rather than at the branch that was named:

- The user-folder confinement regression is closed by moving the CONSUMING predicate (which the
  previous report identified as the side that had to move), not by tightening the listing, and the
  missing positive half of the test catalog now exists as its own suite and was proved on a device
  with fixtures made in the real Files app.
- The unreconciled destructive site is closed by deleting the subsystem that contained it, and the
  census that would have caught a fourth such site is pinned at 1.
- The dropped compensation is closed by SHARING the validate route's implementation across both
  routes — the exact remedy the previous report asked for over re-implementation — and the
  over-reporting direction is closed by subtracting this pass's removals from the pessimistic
  branch.
- The silent inspector branch is closed with a full enumeration in the type doc rather than a second
  branch fix, which is the pattern the previous report said this phase had re-opened every round.
- All four unowned-invariant residuals are resolved, two of them (the 10 s wait bound, the
  error-text pinning question) by explicit owner ratification rather than by an agent's own call.

What remains is **not** a gap but a staleness of evidence: the phase's largest production delta
landed after its last device round and after its UAT was closed, so SC2 — whose only proof is a
device observation — is present, wired and suite-green at this HEAD but not behaviorally proven on
it. That is one device session's work, not a code change, and it is why this report reads
`human_needed` rather than `passed`.

Two documentation inconsistencies are worth correcting but block nothing and are not counted
against the score:

1. `ROADMAP.md` § Phase 15 reads **"Plans: 76/77 plans executed"** while the progress table row
   reads **77/77**. Plan 15-77 has commits on the branch (`8277ded7`, `15afbde4`) and a device-passed
   UAT checkpoint (test 7), but **no `15-77-SUMMARY.md`** — 15-UAT already flags this and carries the
   deliverable through the plan's own `must_haves` instead of a coverage block.
2. `deferred-items.md` still lists two ROADMAP staleness items (a missing Phase 16 progress row, an
   execution-order line that stops at 15) which remain true at this HEAD.

---

_Verified: 2026-08-19T10:35:00Z_
_Verifier: Claude (gsd-verifier)_
