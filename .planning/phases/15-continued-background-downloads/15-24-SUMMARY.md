---
phase: 15-continued-background-downloads
plan: 24
subsystem: download-client
tags: [swift, continued-processing, gap-closure, progress-accounting, regression-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G2-01's retirement ledger and its `observedSchedulablePages` membership map, which this plan gates rather than reopens"
  - phase: 15-continued-background-downloads
    provides: "`shouldSchedule`'s `isQueuedWorkItem` short-circuit, which keeps a queued redo schedulable and is deliberately left untouched"
  - phase: 15-continued-background-downloads
    provides: "15-23's always-suspending `BackgroundProcessingClientSpy` and the drain-ness re-check the new drains run behind"
provides:
  - "D-G4-01: a schedulable gallery's session-completed page count is its record's count when the record reads incomplete or this session already observed it incomplete, and zero otherwise"
  - "`DownloadCoordinator.observedIncompleteSessionGIDs`, one session-scoped trust set shared by the numerator's opening rule and the retirement's departure rule"
  - "`SchedulableSnapshot.incompleteGalleryIDs`, so the basis and the trust it grants come from the same single index read"
  - "A trust-gated `reconcileRetiredSessionPages(snapshot:)`: a never-started redo retires nothing instead of its whole manifest"
  - "Four production-path ledger regressions, each watched to fail before the arithmetic landed"
affects: [continued-background-downloads, download-client, system-progress-card, background-scheduling]

tech-stack:
  added: []
  patterns:
    - "Schedulability and progress answer different questions: a predicate that decides whether work runs must not be reused to decide whether work was done"
    - "Trust is earned from observation, not asserted from state: a record is authoritative about the manifest always, and about the session only once the session has watched that record doing work"
    - "The basis and the membership it grants are read once together, so an opening rule and a departure rule keyed on the same fact cannot drift apart"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "The gap record's option 1 was rejected against source. Ordering the completeness check ahead of `shouldSchedule`'s work-item short-circuit would make every queued redo unschedulable — `nextQueuedDownload` selects through `isSchedulableDownload` — so the update feature would simply never run. The schedulability is not the bug; the counting is."
  - "The basis is record-and-trust keyed, not mode-keyed. `queuedModes` stays set for a whole active run, so it would have masked the redo's real mid-run progress at zero, and it is never set at all on the bare enqueue that reuses a complete manifest, so that route would have stayed open."
  - "The numerator is summed from the same per-gallery map the ledger observes rather than from a second pass over the download array, so the pushed numerator and the values a departure is measured against cannot come apart."
  - "Tests B and D stage the queued complete manifest by enqueueing it rather than through `retry`. That is the second, `queuedModes`-free route into the same defect, and it is the route with no scheduling in it — which is what makes their drains single, unraced terminal pushes rather than assertions racing a convergence task."
  - "`patchManifest(of:completedPageCount:in:)` was extracted and `completeManifest` now delegates to it, rather than a second near-copy of the index-seam write being added for the mid-run patch."

patterns-established:
  - "A new regression case that passes before the fix is a finding about its staging, never a baseline: all four were run against the unmodified arithmetic first and their observed pairs recorded verbatim."
  - "A blast-radius catalog is verified in both directions — the one case predicted to change did, and every case predicted not to change was left byte-for-byte alone."

requirements-completed: [SC2, SC1]

coverage:
  - id: D1
    description: "A complete gallery queued for an update opens the card at zero session progress, on the `retry` route"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testACompleteGalleryQueuedForUpdateOpensTheCardAtZero"
        status: pass
    human_judgment: false
  - id: D2
    description: "A never-started redo departs retiring nothing, so a cancelled update cannot report a finished session"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testCancellingANeverStartedUpdateRetiresNothing"
        status: pass
    human_judgment: false
  - id: D3
    description: "A never-started redo cancelled mid-queue does not inflate the survivors' fraction, and no push ever reports the pre-session pages"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testAMidQueueUpdateCancelDoesNotInflateTheSurvivors"
        status: pass
    human_judgment: false
  - id: D4
    description: "Mid-run progress is never masked, and a redo the session watched running keeps its record authoritative at departure"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testARedoObservedRunningEarnsItsRecordBackAtTheDrain"
        status: pass
    human_judgment: false
  - id: D5
    description: "The pinned card that the scheduler reads as a stall — and that D-11 turns into a pause of every schedulable download — cannot be produced by a queued redo"
    requirement: SC1
    verification:
      - kind: unit
        ref: "DownloadsFeatureTests (318 tests, 62 suites)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The G-15-2 ledger's behavior survives the new basis: every pre-existing literal outside the one catalogued case is unchanged"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionLedgerTests (7 pre-existing cases), DownloadContinuedSessionTests, DownloadContinuedSessionIdentityTests, DownloadContinuedSessionInterleaveTests, DownloadDeleteConvergenceTests"
        status: pass
    human_judgment: false
  - id: D7
    description: "On a physical iOS 26 device, the system progress card renders real progress — now including that a queued update no longer opens it at 100% — and its cancel matches the in-app pause baseline"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "15-UAT.md test 2 is a standing physical-device item; the card is system-rendered and the simulator neither renders it nor fires its cancel. Nothing in this plan closes it."

duration: 35min
completed: 2026-08-04
status: complete
---

# Phase 15 Plan 24: The Session Basis for a Queued Redo Summary

**G-15-4 closed: a gallery whose record is already complete no longer contributes its manifest's finished pages to the session's numerator until this session has watched it doing real work, so an update, a redownload, a repair on a complete record or a bare re-enqueue can never open the card at its own ceiling — and a redo that never ran retires nothing when it is cancelled.**

## What Was Built

### The defect, stated precisely

`shouldSchedule` returns `true` on `download.isQueuedWorkItem` before it ever consults `isIncomplete`. That is correct — the redo has to run — but the session's arithmetic then read the manifest's N finished pages as N of N session pages. `ensureContinuedSession` submitted `start(…, N, N)`, `lastPushedCompletedPageCount` latched at N, and the monotonic floor pinned the card at 100% for the whole session: the pinned-card failure the G-15-2 retirement ledger was built to eliminate, reached through a different door. Per D-11 the scheduler force-expires the tasks reporting the least progress and that expiration pauses every schedulable download, so the defect attacked SC1's liveness as well as SC2's honesty.

The retirement had the mirror of the same problem. D-G2-01 makes a departed gallery's record authoritative, which is what lets a gallery completing between two pushes retire its full count — but for a redo the session never watched, that record speaks for the *manifest*, not for the session. A cancelled never-started update retired N pages the session never downloaded onto both sides of the fraction and reported a finished session.

### D-G4-01, the rule that landed

```swift
let sessionCompletedPages = downloads.reduce(into: [String: Int]()) { pages, download in
    let isSessionWork = download.isIncomplete
        || observedIncompleteSessionGIDs.contains(download.gid)
    pages[download.gid] = isSessionWork ? download.completedPageCount : 0
}
```

The executable predicate reads the record and the trust set and nothing else — no read of `queuedModes` anywhere in `schedulableSnapshot()`. Each half earns its place:

- **`isIncomplete`** is the common case and the anti-masking half: the instant a redo's own manifest writes make the record incomplete, its finished pages count raw, with no dependence on trust having caught up.
- **`observedIncompleteSessionGIDs`** covers the completion flush, where a gallery the session watched doing real work reports its full count while its record already reads complete again and it is still inside its own schedulable set. Without it the cadence suite's pinned `[8, 16, 20]` series would regress to a floored final value.
- **The zero branch** is the gap case: a complete-reading record this session has never seen incomplete. Those pages are the redo's *target*.

The per-gallery `pageCount` denominator and the schedulable `galleryCount` are untouched; only the numerator's basis moved. The numerator is now summed from the very map the ledger observes (`sessionCompletedPages.values.reduce(0, +)`), so the pushed pair and the per-gallery values a departure is measured against cannot come apart.

### The same set gates the retirement

```swift
for gid in departedGIDs {
    guard observedIncompleteSessionGIDs.contains(gid) else {
        // Never watched doing work, so its record speaks for the manifest rather than
        // for this session: retire what was observed, which the basis made zero.
        retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0
        continue
    }
    guard let record = departedRecords[gid] else { … }
    retiredSessionPages[gid] = min(max(record.completedPageCount, 0), record.pageCount)
}
```

This is **not** a departure-reason branch. The formula still takes no reason parameter, no call site classifies why a gallery left, and completion, pause, delete, cancel and expiration are treated identically; the gate reads only what this session observed while the gallery was present. `reconcileRetiredSessionPages` now takes the whole `SchedulableSnapshot` rather than the bare map, and accumulates `observedIncompleteSessionGIDs.formUnion(snapshot.incompleteGalleryIDs)` beside the map replacement — from the same read the basis was computed from, so the opening rule and the departure rule can never disagree about a gallery.

The accepted residual is documented at the site: a never-trusted redo that starts *and* finishes entirely between two observations retires at its observed basis of zero. That is the module's existing unobserved-work convention reached from one observation further out, and the direction is deliberate — under-retiring keeps the fraction at or below truth, over-retiring is the defect.

### The trust set's lifecycle

`observedIncompleteSessionGIDs` is declared in `DownloadClient+Manager.swift` beside `retiredSessionPages` and `observedSchedulablePages`, with the same session-scoped discipline, all three sites complete by inspection:

| Site | What happens |
|---|---|
| `ensureContinuedSession`, synchronous reset block | cleared with its two siblings, before the first suspension |
| `ensureContinuedSession`, after the ownership re-check | seeded `= snapshot.incompleteGalleryIDs` beside `observedSchedulablePages`, so a superseded start grants no trust just as it seeds no membership |
| `markContinuedSessionEnded` | cleared, so no trust survives into the next session |
| `reconcileRetiredSessionPages` | accumulated by `formUnion` from each reconciled snapshot |

`SchedulableSnapshot` gained a third stored field `incompleteGalleryIDs: Set<String>` and the matching initializer parameter (the type has no constructor outside that file — verified: one construction site). `finishedPages` is re-documented as *session-completed* pages, and the struct doc gains the paragraph on why the basis and the membership come from one read.

### `shouldSchedule` was not touched

Confirmed by diff: neither commit lists `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift`. `isSchedulableDownload`, `settleCompletedDownload`'s queue-store removal, the display clamps' single application point, D-G2B-01's terminal-push ordering and 15-23's drain-ness re-check are all unedited. A queued redo stays schedulable; the card still selects through the scheduler's own predicate.

## Falsifiability: the pre-fix readings

The four cases were written first and the ledger suite run against the unmodified arithmetic. All four failed; the seven pre-existing cases in the same run passed. Quoted verbatim from that run's result bundle:

| Case | Derived | Pre-fix observed |
|---|---|---|
| A — opening pair | `start` at 0 of 6, `"0 / 6 pages · 1 gallery"` | `(spy.startCompletedUnitCounts.last → 6) == 0`; `(spy.startSubtitles.last → "6 / 6 pages · 1 gallery")`; the direct push repeated it: `(openingPair.completedUnitCount → 6) == 0` |
| B — never-started cancel | terminal `"0 / 1 page · 0 galleries"` | `(spy.startSubtitles → ["6 / 6 pages · 1 gallery"])`; `(terminalPair.completedUnitCount → 6) == 0`, `(terminalPair.totalUnitCount → 6) == 1`, `(terminalPair.subtitle → "6 / 6 pages · 0 galleries")` — the never-started redo retired its whole manifest and the session reported itself finished |
| C — mid-queue cancel | opens `"3 / 14 pages · 2 galleries"`, leaves `"3 / 8 pages · 1 gallery"` | `(spy.startSubtitles.last → "9 / 14 pages · 2 galleries")`; `(survivingPair.subtitle → "9 / 14 pages · 1 gallery")`; `(spy.startCompletedUnitCounts → [9]) == [3]`; every recorded push read 9 of 14 |
| D — mid-run trust | `"2 / 6 pages · 1 gallery"` then a `"6 / 6 pages · 0 galleries"` drain | `(midRunPair.completedUnitCount → 6) == 2`, `(midRunPair.subtitle → "6 / 6 pages · 1 gallery")` — mid-run progress masked at the ceiling — plus two pre-drain updates already at their own total: `(update.completedUnitCount → 6) < (update.totalUnitCount → 6)`, twice |

Note C's pre-fix reading is one step worse than the plan predicted: the departed redo not only opened at nine, it also retired its six pages, so the total stayed at fourteen after it left (`"9 / 14 pages · 1 gallery"` where the derivation expected the old basis to at least shed the denominator). Both halves of D-G4-01 are visible in that one string.

The fix was then installed and the suite re-run green — 11 tests, 0 issues. The tree at commit `0c0f3995` carries the fix; no reverted state was committed.

## Blast-radius catalog, verified in both directions

| Suite | Case | Predicted | Observed |
|---|---|---|---|
| Ledger | all 7 pre-existing (sequential, order-independence, outliving-work, pause, delete, rejoin, delete-to-empty) | unchanged | **unchanged** — every literal survives verbatim; the whole suite passed pre-fix and post-fix with no edit to any existing case |
| ContinuedSession | `testACompletedGalleryHoldsTheTotalAndAdvancesTheCount` | unchanged | **unchanged** — `10 / 14 pages · 1 gallery` still present exactly once, untouched |
| ContinuedSession | `testProgressIsPushedOnTheThrottledPageFlushCadence` | unchanged | **unchanged** — the `[8, 16, 20]` series is still pinned once and the case passes; the gid earns trust at the first flush, so the complete-reading forced flush still counts 20 |
| ContinuedSession | `testZeroPageGalleryStillPushesAPositiveTotal` | unchanged | **unchanged** — the zero basis equals its raw zero |
| ContinuedSession | `testCancellingTheLastQueuedWorkItemCompletesTheSession` | unchanged | **unchanged** — its 1-of-5 gallery is incomplete, so the basis is raw and the departure record read still retires 1; both `1 / 1 page · 0 galleries` terminals intact |
| ContinuedSession | `testEveryPushedSubtitleCarriesNoGalleryIdentity` | **re-derived** | **re-derived**, and only this one — see below |
| Identity / Interleave / Delete-convergence | all | unchanged | **unchanged** — every fixture gallery is incomplete; all three suites green |

Nothing changed outside the catalog, and nothing inside it failed to change. `git show` for the second commit is `1 file changed, 4 insertions(+), 4 deletions(-)`: two literals and a two-line comment, line-neutral.

## The one re-derived case

`testEveryPushedSubtitleCarriesNoGalleryIdentity` seeds a 1-of-5 gallery beside a 3-of-3 complete one and queues both — exactly the G-15-4 shape. Under D-G4-01 the complete gallery counts zero while present, and its never-trusted departure retires zero, so the total shrinks with it:

- `"4 / 8 pages · 2 galleries"` → `"1 / 8 pages · 2 galleries"`
- `"4 / 8 pages · 1 gallery"` → `"1 / 5 pages · 1 gallery"`

The old comment — *"its three finished pages retire to both sides: the total holds at eight while the count stands"* — was this defect speaking, and it was replaced rather than annotated:

```swift
// The second gallery's record was complete before the session began, so its three pages are
// the redo's target rather than session work: it counts zero, and retires zero (D-G4-01).
```

The case's actual subject is untouched and still asserted over every recorded string:

```swift
for recorded in spy.startSubtitles + spy.progressUpdates.map(\.subtitle) {
    #expect(!recorded.contains(firstTitle))
    #expect(!recorded.contains(secondTitle))
    #expect(!recorded.contains(firstGID))
    #expect(!recorded.contains(secondGID))
}
```

`grep -c '4 / 8 pages'` on the post-edit file returns `0`: replaced, not supplemented. The file-length remedy 15-22 validated was not needed — the swaps were line-neutral and the comment fit its predecessor's two lines, so `testEmptySchedulableSetStillPushesAPositiveTotal` stayed where it is and no assertion was dropped or shortened.

## Deviations from Plan

### 1. [Rule 1 — Determinism of the pinned assertion] Tests B and D stage the queued complete manifest by enqueueing it, not through `retry`

- **Found during:** Task 1, Step 1, while deriving the staging.
- **Issue:** `retry` schedules before it ensures the session, and with the inert runner the scheduled task's completion tail (`finishActiveTaskIfOwned(schedulesNext: false)`) spawns a convergence that suspends on the observer hub and then calls `reconcileContinuedSession()`. For a case that ends at a *drain*, that convergence can re-enter the drain branch concurrently with the case's own drive. 15-22's post-push ownership guard makes a double *completion* impossible — the loser bails at `guard continuedSessionID == sessionID` behind its push — but the loser's push can still be accepted before the winner's teardown, which would append a second terminal-valued update and break `expectTheFractionReachesOneOnlyAtTheDrain`. The assertion would have been timing-dependent.
- **Fix:** B and D stage the same state by enqueueing the complete manifest through the fixture, which schedules nothing, so their drains are single unraced terminal pushes. This is not weaker coverage: the bare enqueue is the *second* route into G-15-4 that the plan's own D-G4-01 section names — it never touches `queuedModes` at all, so it is precisely the route a mode-keyed basis would have missed. A and C keep the `retry` route (`.update` and `.redownload`), and C is safe with it because C never drains: a survivor remains, so the convergence's extra pushes carry the identical value the case pins.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift`
- **Commit:** `0c0f3995`

### 2. [Rule 2 — Duplication] `patchManifest(of:completedPageCount:in:)` extracted rather than copied

- **Found during:** Task 1, Step 1.
- **Issue:** Test D needs a mid-run record patch (2 of 6) through the same index seam `completeManifest` writes through. Adding a second near-copy of that eight-line write would have duplicated the folder-path construction and the `SessionGallery` rebuild.
- **Fix:** The general helper was extracted and `completeManifest` now delegates to it with `completedPageCount: gallery.pageCount`. Every existing call site is unchanged.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift`
- **Commit:** `0c0f3995`

### 3. [Recorded, no change] One stale doc reference repaired

`DownloadClient+Manager.swift`'s `retiredSessionPages` doc pointed at `reconcileRetiredSessionPages(finishedPages:)`, whose signature this plan changes. Updated to `(snapshot:)` in the same commit rather than left dangling.

## Validation notes

- **Full plan green in one invocation:** `DownloadsFeatureTests` — **318 tests in 62 suites, 0 failures, 3 known issues** (the pre-existing `withKnownIssue` assertions for the unimplemented client's three endpoints), 12.2s of testing inside a 52s build-and-run. 314 → 318 is exactly the four new cases. `DownloadSchedulingTests` and `DownloadLogPrivacyInvariantTests` are green by name in that run; `DownloadSchedulingTests` passing is load-bearing, since a failure there is a real regression rather than flake.
- **No overlapping invocations:** three `xcodebuild` runs total (pre-fix targeted, post-fix targeted, full plan), strictly one at a time, none killed. The pre-fix run's 616s wall time is `IDETestOperationsObserverDebug: Failure collecting diagnostics from simulator: Timed out after 600.0 seconds` — a post-run diagnostics collection stall, not the tests, which took 0.43s.
- **Lint:** zero violations from `swiftlint --strict` over `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension` (`AppPackage/.build` removed first). No suppression, no `swiftlint:disable`, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `@preconcurrency` anywhere in this change.
- **File lengths:** `DownloadContinuedSessionTests.swift` 999 (unchanged), `DownloadContinuedSessionLedgerTests.swift` 675, `DownloadClient+ContinuedSession.swift` 551 — all under the 1000-line gate.
- **COVERAGE.md validated, not extended:** `git show 0c0f3995 8fae19f1 | grep -c 'BGTaskScheduler\|BGContinuedProcessingTask'` returns 0. This round changes the arithmetic feeding `updateProgress`, not the `BackgroundTasks` seam.
- **Schema gate:** no persisted schema change — the trust set is in-memory session state, like the ledger beside it.
- **Privacy gate:** no new log statement; card strings remain integer-only through `continuedSessionSubtitle(for:)`, and `DownloadLogPrivacyInvariantTests` ran green in the full plan.
- **Localization gate:** no catalog entry touched; a zero count renders through the existing plural `other` category.
- **Package legitimacy:** no package-manager installs; the phase audit records zero entries.
- **Standing device item, unchanged and now carrying one more observation:** `15-UAT.md` test 2 remains a physical-device re-run on iOS 26 hardware. It is now also the observational check that a queued update no longer opens the card at 100%. Nothing in this plan closes it.
- **Out of scope, untouched:** review warnings WR-03..WR-11, including the denominator floor rewind (WR-04) and the session state's public visibility (WR-07).

## Acceptance greps

| Check | Required | Observed |
|---|---|---|
| `observedIncompleteSessionGIDs` in `+ContinuedSession.swift` | ≥ 3 | 7 |
| `observedIncompleteSessionGIDs` in `+Manager.swift` | ≥ 1 | 1 |
| both files summed | ≥ 6 | 8 |
| `incompleteGalleryIDs` in `+ContinuedSession.swift` | ≥ 3 | 6 |
| the four new test names | 4 | 4 |
| `0 / 6 pages · 1 gallery` | ≥ 1 | 4 |
| `3 / 14 pages · 2 galleries` | ≥ 1 | 1 |
| `3 / 8 pages · 1 gallery` | ≥ 1 | 1 |
| `6 / 6 pages · 0 galleries` | ≥ 2 | 2 |
| `retry(gid:` in the ledger suite | ≥ 2 | 2 |
| `cancelQueuedWorkItem` in the ledger suite | ≥ 2 | 2 |
| `1 / 8 pages · 2 galleries` | 1 | 1 |
| `1 / 5 pages · 1 gallery` | ≥ 1 | 1 |
| `4 / 8 pages` | 0 | 0 |
| `8, 16, 20` | 1 | 1 |
| `10 / 14 pages · 1 gallery` | 1 | 1 |
| `1 / 1 page · 0 galleries` | ≥ 2 | 3 |
| `DownloadClient+Scheduling.swift` in this plan's diff | absent | absent |

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND, contains `incompleteGalleryIDs`
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND, contains `observedIncompleteSessionGIDs`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` — FOUND, contains `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` — FOUND, contains `1 / 5 pages · 1 gallery`
- Commit `0c0f3995` — FOUND in `git log`
- Commit `8fae19f1` — FOUND in `git log`
