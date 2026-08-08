---
phase: 15-continued-background-downloads
plan: 55
subsystem: downloads
tags: [continued-session, gallery-count, coverage-basis, gap-closure, os-render-race, d-g2c-01]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-54's RunProgressBasis measured numerator, which this plan leaves untouched by contract"
  - phase: 15-continued-background-downloads
    provides: "D-G2-01's retirement ledger — the departed-gallery pages this count now reads"
  - phase: 15-continued-background-downloads
    provides: "15-22's terminal push and 15-23's D-G3-01 drain re-check, kept as defence"
  - phase: 15-continued-background-downloads
    provides: "The G-15-2C diagnosis (.planning/debug/continued-session-gallery-count-basis.md) proving the OS does not repaint a push issued immediately before setTaskCompleted"
provides:
  - "D-G2C-01: the pushed gallery count is the denominator's coverage — live schedulable galleries plus every departed gallery whose retirement is greater than zero"
  - "coverageGalleryCount: one shared derivation both subtitle writers call, making a second count basis structurally impossible"
  - "The rewritten count contract, with the mixed-basis acceptance G-15-2B recorded now obsolete"
  - "The zero-retirement boundary pinned from both sides on production-path drains"
  - "A third literal category — SYNCHRONIZATION PREDICATE — and the run-proof waits rekeyed to a facet the new basis still moves"
affects: [continued-session card, 15-UAT test 2 device retest]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "When a displayed number's truthfulness depends on the OS rendering one specific frame, change the number's basis so every frame is truthful — remove the race rather than racing it harder"
    - "Two numbers shown side by side must answer for the same set; a cumulative fraction beside a live-only count is a mixed basis, not a detail"
    - "A test barrier keyed on a displayed value must key on a facet the basis still moves; when a fix holds a facet constant, the barrier silently stops observing and the case hangs"
    - "File ownership in a task must close over suite membership, because -only-testing filters by suite and this tree splits suites across files via extension"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift

key-decisions:
  - "D-G2C-01: the pushed galleryCount is the denominator's coverage — live snapshot galleries plus retiredSessionPages entries greater than zero — computed after reconcileRetiredSessionPages by one shared helper."
  - "DEC-B: SchedulableSnapshot.sessionProgress.galleryCount stays the live schedulable count. It is the live half of the coverage sum and the summed-from-one-read identity's input, never a pushed contract."
  - "A zero-page retirement is not counted: nothing of that gallery is represented by Y, so nothing of it is named."
  - "The 15-22 terminal push stays as defence. Under the coverage basis it pushes the same count as every earlier frame, so no displayed value depends on the OS rendering it."
  - "ExecutionSupport's line-546 doc literal keeps its 0 galleries: it describes an UNTRUSTED departure retiring zero, which the coverage rule also counts as zero. The plan's update instruction was conditional and the condition is false."
  - "The run-proof departure/rejoin barriers key on the denominator (16 → 12 → 16) rather than the gallery count, which the coverage basis holds constant across that departure."

patterns-established:
  - "Coverage basis: a count displayed beside a fraction names the galleries that fraction's denominator is made of"
  - "Third literal category (synchronization predicate) alongside coordinator-computed pin and pass-through fixture"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "The pushed gallery count is the denominator's coverage, shared by both subtitle writers, so no frame of a multi-gallery run can report a count describing only the live set"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testACompletedGalleryHoldsTheTotalAndAdvancesTheCount"
        status: pass
    human_judgment: false
  - id: D2
    description: "The zero-retirement boundary is pinned from both sides on production-path drains"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testDrainingTheQueueCompletesTheSessionWithSuccess"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift#testCancellingTheLastQueuedWorkItemCompletesTheSession"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift#testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain"
        status: pass
    human_judgment: false
  - id: D3
    description: "The documented count contract is rewritten to the coverage basis and the mixed-basis acceptance is gone"
    requirement: SC2
    verification:
      - kind: other
        ref: "grep -c 'D-G2C-01' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift == 7"
        status: pass
    human_judgment: false
  - id: D4
    description: "On a physical iOS 26 device, a backgrounded multi-gallery queue reads a gallery count equal to the denominator's coverage on every observed frame — a two-gallery run reads 2 galleries mid-run and at drain"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "The defect is an OS render-pipeline behaviour on the system-owned continued-processing card. No simulator test observes what the card actually paints; only the 15-UAT test 2 device retest can confirm the user-visible outcome."

# Metrics
duration: ~95 min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 55: The coverage gallery count (G-15-2C)

**The card's gallery count now names the galleries its denominator is made of, so every painted frame is truthful and nothing depends on the OS repainting the frame issued microseconds before task completion.**

## Performance

- **Duration:** ~95 min (including two plan-correction checkpoint rounds)
- **Tasks:** 2
- **Files modified:** 8 (1 source, 7 test)
- **Commits:** 2 task commits + this metadata commit

## Accomplishments

- `coverageGalleryCount` — one derivation on `DownloadCoordinator`, read after `reconcileRetiredSessionPages`, returning the live snapshot count plus `retiredSessionPages.values.count(where: { $0 > 0 })`. Both subtitle writers (`pushContinuedSessionProgress` and `ensureContinuedSession`'s start submission) call it, so a second count basis is structurally impossible rather than merely absent.
- The G-15-2C truth holds on every frame: a two-gallery run reads `2 galleries` from its opening push through its final forced flush and its drain. The render race is removed, not raced harder.
- The zero-retirement boundary is pinned from both sides on production-path drains, and one interleave case now crosses it in a single series.
- The count contract is rewritten rather than annotated across seven doc sites, including DEC-B's explicit statement that the snapshot-internal value stays live-only.
- A third literal category was discovered and closed: a `waitUntil` barrier keyed on the gallery count stopped observing anything under the new basis. It is rekeyed to the denominator, which the same production push still moves.

## Task Commits

1. **Task 1: coverage basis — contract, implementation, boundary-owning suites** — `8211abd9` (fix)
2. **Task 2: the invariant sweep** — `53d05928` (test)

## D-G2C-01, as implemented

```
coverage = snapshot.sessionProgress.galleryCount
         + retiredSessionPages.values.count(where: { $0 > 0 })
```

| Clause | Why it is load-bearing |
|---|---|
| Live snapshot galleries count | each contributes its whole `pageCount` to Y |
| Positive retirements count | D-G2-01 puts a departed gallery's finished pages back on both sides of Y, so its pages are in Y |
| Zero retirements do not | a gallery that finished nothing left nothing in Y; the letter of the owner's truth |
| Read after the reconcile | the rejoin dedupe has already dropped a returning gallery's ledger entry, so it counts once |
| One shared helper | the diagnosis's writer census found two subtitle writers; a single definition is the guard |

## Falsifiability evidence (acceptance criterion 4)

### Step 1 (RED) — recomputed pins against live-only production

16 failures. Every reported actual is exactly the live-only value the old basis predicts, derived before it was observed:

| Site | Reported actual (live-only) | Rewritten to |
|---|---|---|
| LedgerTests:115 series | `["0 / 20 · 3", "10 / 20 · 2", "16 / 20 · 1", "20 / 20 · 0"]` | `3` on all four frames |
| LedgerTests:123, :168 `drainedPair` | `20 / 20 pages · 0 galleries` | `· 3 galleries` |
| LedgerTests:257, :258 `pausedPair` | `6 / 10 pages · 1 gallery` | `· 2 galleries` |
| LedgerTests:303, :304 `deletedPair` | `6 / 10 pages · 1 gallery` | `· 2 galleries` |
| LedgerTests:353, :604, :726, :820 terminals | `6 / 6 pages · 0 galleries` (×4) | `· 1 gallery` |
| LedgerTests:410 rejoin series | `["6 / 14 · 2", "6 / 10 · 1", "6 / 14 · 2"]` | middle frame `· 2 galleries` |
| ExpirationTests:264 | `1 / 1 page · 0 galleries` | `· 1 gallery` |
| ExpirationTests:283 two-session series | `["1 / 1 page · 0 galleries", …]` (×2) | `· 1 gallery` ×2 |
| ContinuedSessionTests:412 | `["6 / 14 · 2 galleries", "10 / 14 · 1 gallery"]` | second frame `· 2 galleries` |
| ContinuedSessionTests:506 | `["2 / 6 · 1 gallery", "6 / 6 · 0 galleries"]` | terminal `· 1 gallery` |

**Pins the derivation left unchanged, which passed untouched in Step 1** (no edit, no failure): LedgerTests 204-205, 245, 296, 346, 459, 467, 492, 503, 540, 554, 595, 674, 697; ContinuedSessionTests 179, 237, 286, 315, 344-345, 439, 525-526. Every one matches a row the derivation table calls unchanged — no case passed that the derivation expected to fail, and none failed that it expected to hold. The three `withKnownIssue` unimplemented-client cases are the run's only other issues and are intentional.

### The newly-scoped files (Refusal, RunProof)

These entered scope after the second checkpoint, once the helper was already installed, so their evidence is the inverse direction and is stronger rather than weaker: the OLD pins were observed failing against the NEW production, and every reported actual equals the independently derived coverage value.

| Site | Old pin | Observed actual against new production | Derived |
|---|---|---|---|
| LedgerRefusalTests:190 | `6 / 6 pages · 0 galleries` | `6 / 6 pages · 1 gallery` | `1` — six retired pages are the whole of Y |
| LedgerRefusalTests:312 | `6 / 6 pages · 0 galleries` | `6 / 6 pages · 1 gallery` | `1` — same rule, directory-level refusal |
| LedgerRefusalTests:528 | `2 / 2 pages · 0 galleries` | `2 / 2 pages · 1 gallery` | `1` — the pause retired 2, the other 4 left Y |
| RunProofTests:843 departure barrier | `waitUntil hasSuffix("· 1 gallery")` | **timed out after 11.1s** (`waitUntil` deadline 10s) | the count never crosses; the barrier cannot fire |

Each derivation was taken from its own fixture before the actual was read. No observed value was copied into an expectation.

## Deviations from Plan

None — the plan executed exactly as written. Two instructions could not be followed exactly as originally written; per the standing instruction both were returned as DECISION CHECKPOINTs and the plan was corrected before any code was written, so neither became a silent deviation.

### Checkpoint round 1 — the cancel-drain pin's file (plan fix `4de9057a`)

Task 1's acceptance criterion located the cancel-drain boundary pin in `DownloadContinuedSessionTests.swift`. That file contains no cancel case at all; `testCancellingTheLastQueuedWorkItemCompletesTheSession` lives in `DownloadContinuedSessionExpirationTests.swift`, which the plan declared in neither task. The plan added it to Task 1's `<files>`, `files_modified` and verify command, and restated the criterion across both files. Its two-session series (three literals total, not one) was confirmed to change on both drains.

### Checkpoint round 2 — suite topology and the synchronization predicate (plan fix `4b8eb704`)

Two findings from the first green run:

1. **`-only-testing` filters by suite, and this tree splits suites across files.** `DownloadContinuedSessionLedgerRefusalTests.swift` and `DownloadContinuedSessionRunProofTests.swift` are `extension DownloadContinuedSessionLedgerTests`, so Task 1's gate necessarily ran them while they were declared Task-2 scope — making "the targeted command exits 0" unsatisfiable within Task 1's files. (`DownloadContinuedSessionReconciliationTests.swift` extends `DownloadContinuedSessionBasisTests` the same way.) Both files moved into Task 1, and the plan now carries a Suite↔file map with the rule that a task's file ownership must close over its gate's suites.
2. **A subtitle literal used as a barrier, not a pin.** `testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued` waited on the gallery count crossing to one to observe a departure. Under the coverage basis the abandoned gallery retires a frozen 2-page credit — a positive retirement — so the count holds at two straight through, and the barrier could never fire; the case hung to its 10s deadline. The plan added a third literal category and both waits are rekeyed to the denominator: the same production push (the first `pushContinuedSessionProgress` after the failed run exits, whose membership sweep retires the credit and drops the gallery's four unfetched pages) moves Y from 16 to 12, and the rejoin restores it to 16. Y = 2 retired + the keeper's 10.

## Per-file census (Task 2 acceptance criterion 1)

| File | Disposition | Literals changed |
|---|---|---|
| `DownloadContinuedSessionLedgerTests.swift` | recomputed (Task 1) | 10 of 30 |
| `DownloadContinuedSessionTests.swift` | recomputed (Task 1) | 2 of 22 |
| `DownloadContinuedSessionExpirationTests.swift` | recomputed (Task 1) | 3 of 3 |
| `DownloadContinuedSessionLedgerRefusalTests.swift` | recomputed (Task 1) | 3 of 11 |
| `DownloadContinuedSessionRunProofTests.swift` | synchronization predicates rekeyed (Task 1) | 2 of 9 (both barriers; the 7 pins unchanged) |
| `DownloadContinuedSessionBasisTests.swift` | recomputed (Task 2) | 8 of 26 |
| `DownloadContinuedSessionInterleaveTests.swift` | recomputed (Task 2) | 4 of 4 |
| `DownloadContinuedSessionReconciliationTests.swift` | unchanged by rule — single-gallery mid-run frames, no departure | 0 of 6 |
| `DownloadRepairSeedSignalPropagationTests.swift` | unchanged by rule — same shape | 0 of 4 |
| `DownloadProgressSeriesGuardTests.swift` | classified pass-through — synthetic `PushedPair` from `makeSeries` | 0 of 1 |
| `ContinuedProcessingSessionTests.swift` | classified pass-through — literals handed INTO the client, which forwards and never computes (the file constructs no coordinator) | 0 of 32, untouched |
| `DownloadClient+ExecutionSupport.swift` | unchanged by derivation — see below | 0 of 1 |

`ContinuedProcessingSessionTests.swift` does not appear in either task commit, as required.

**ExecutionSupport:546.** The plan directed re-deriving this doc literal and updating it "if and only if the described reading is stale". It is not stale. The sentence describes a *terminal* card after an **untrusted** departure — a gallery whose record read complete throughout, which D-G4-01 credited zero and which therefore retires zero. A zero retirement is not counted and the live set is empty at that drain, so `0 / N pages · 0 galleries` remains exactly right under the coverage rule. Left byte-identical; the conditional resolved cleanly rather than conflicting.

## Verification

- **Task 1 gate:** the targeted 3-suite command exits `0` — 52 tests, 3 suites, 3 intentional known issues.
- **Task 2 gate:** full `FeatureTests` plan `** TEST SUCCEEDED **`, 0 failures. Downloads target **379 tests in 68 suites**; **893 tests across all targets**.
- **Two consecutive green full runs** (108.8s and 106.8s), no flake in either — including the presentation-order transient this phase has on record.
- `DownloadLogPrivacyInvariantTests` green in the same run, as the plan requires.
- **Clean app-scheme build `** BUILD SUCCEEDED **`, zero SwiftLint violations** (0 `file:line:col:` diagnostics). The FeatureTests build lints `Tests/` too and also reported 0, so both sides of the known app-scheme lint gap are covered.
- Acceptance greps: `coverageGalleryCount` 5 (≥3), `D-G2C-01` 7 (≥2), `20 / 20 pages · 3 galleries` 2 (≥1), `6 / 10 pages · 2 galleries` 4 (≥1).
- One `xcodebuild` invocation at a time throughout.

## Changed device expectation for 15-UAT.md test 2

The final subtitle now reads `N / N pages · K galleries`, where **K is the number of galleries that contributed pages to N** — not zero. For the reported two-gallery run: **`2 galleries` on every observed frame**, mid-run and at drain, including the final forced flush. A frame reading `1 gallery` while both galleries' pages are in the denominator is now the failure signal. A count of `0 galleries` is correct only when the queue drained having finished nothing at all.

## Issues Encountered

None beyond the two plan conflicts above, both surfaced as checkpoints and resolved by plan correction before implementation.

## Next Phase Readiness

- G-15-2C is closed in code and docs; the remaining half is the **15-UAT.md test 2 physical-device iOS 26 retest**, whose expected observation is recorded above.
- Still open independently of this plan: 15-48's overlapping-run gating owned by no test; the reused-identifier second submission (15-51) has no device observation; G-15-33's historical record still carries the round-16 false-premise quotation (historical, left as such).
- The Suite↔file map added to the plan is worth carrying into later phase-15 plans that use `-only-testing:` filters.

## Self-Check: PASSED

- Both task commits found in `git log`: `8211abd9`, `53d05928`.
- All 8 asserted-modified files exist on disk and appear in those commits.
- `ContinuedProcessingSessionTests.swift` confirmed absent from the plan's commits.
- Full suite re-run green twice after the final commit.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
