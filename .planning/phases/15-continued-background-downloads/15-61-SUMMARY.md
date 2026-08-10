---
phase: 15-continued-background-downloads
plan: 61
subsystem: downloads
tags: [download-client, continued-processing, background-tasks, swift-testing, tca]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "D-G4-01's credited-pages definition, the measured RunProgressBasis (15-54) and the queue-intent generation stamp (G-15-22)"
provides:
  - "Generation-scoped incomplete-observation state: observedIncompleteSessionGenerations replaces the gid-only observation set"
  - "SchedulableSnapshot.incompleteGalleryGenerations, stamped in the same actor-isolated read that computes the sums"
  - "A production-shaped two-gallery regression proving a same-session redo inherits no predecessor credit"
affects: [continued-processing progress accounting, session retirement ledger, future redo/requeue work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Session observation state is keyed by (gallery, queue-intent generation), so invalidation is a mismatch rather than a per-path clear"
    - "Dictionary merges over observation state resolve conflicts by keeping the greater (newer) generation"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift

key-decisions:
  - "CR-02: incomplete-record observation is evidence about one queue-intent generation, not a durable property of a gallery identifier"
  - "Generation mismatch is the SINGLE invalidation mechanism — no retry path gains a clear, because a per-path clear would be one more incomplete census"
  - "Both observation merges keep the GREATER generation, so a pre-hop snapshot cannot resurrect an observation an in-hop queue intent invalidated"
  - "The retirement guard reuses the credited-pages equality verbatim, so the numerator rule and the departure rule cannot disagree about a re-queued gallery"

patterns-established:
  - "Observation-versus-identity: any session-scoped evidence about a gallery must carry the intent generation it was gathered under"
  - "A regression whose honest value sits under the monotonic floor must lift a SECOND gallery's work clear of the floor to become discriminating"

requirements-completed: []

coverage:
  - id: D1
    description: "A gallery re-queued inside a live queue-wide session receives zero predecessor observation credit until its successor run announces a basis"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testARequeuedGalleryInheritsNoPredecessorObservationCredit"
        status: pass
    human_judgment: false
  - id: D2
    description: "The queue-wide session identity and the client start count are unchanged across the re-queue, so the fix cannot pass by replacing the session (D-06)"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testARequeuedGalleryInheritsNoPredecessorObservationCredit"
        status: pass
    human_judgment: false
  - id: D3
    description: "Same-generation completed work, live RunProgressBasis credit, and the retirement ledger keep their existing behaviour"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (926 tests, 0 failures; downloads target 407 in 71 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 55min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 61: Generation-Scoped Session Observation Summary

**CR-02 closed: the session's incomplete-record observation is now keyed by `(gallery, queue-intent generation)`, so a same-session re-queue inherits zero predecessor credit while the queue-wide session, the retirement ledger and every live `RunProgressBasis` are untouched.**

## Performance

- **Duration:** ~55 min
- **Started:** 2026-08-10T00:33Z
- **Completed:** 2026-08-10T01:28Z
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 5

## Accomplishments

- **The defect, stated as a property.** `observedIncompleteSessionGIDs` was a gid-keyed set living for a whole session, so once a session had watched a record read incomplete, `sessionCreditedPages` credited ANY later complete record for that gid at its full recorded count. A gallery can complete, retire and be re-queued without the session ever ending — D-06 forbids minting a successor while a keeper gallery holds the queue non-empty — so the predecessor's observation was still standing when the successor's untouched complete manifest was read. It took the raw branch and opened the card at the redo's own TARGET, which is exactly the ceiling D-G4-01's queued-window zero exists to hold.
- **The fix is a key change, not a new mechanism.** `observedIncompleteSessionGenerations: [String: Int]` records, for each gallery this session watched reading incomplete, the queue-intent generation that observation belongs to. Regime 2 of the credited-pages definition now requires `observedIncompleteSessionGenerations[gid] == queueIntentGeneration(for: gid)` before a COMPLETE record counts raw. Every queue-mobilizing entry point (`performRetry`, `performRetryPages`, `resume`, `enqueue`) already advances the generation before its snapshot is taken, so the mismatch invalidates the predecessor observation by construction — atomically from the actor's perspective, touching no other gallery and no ledger entry.
- **No per-path clear was added, deliberately.** The plan's instruction and the phase's own history agree: a clear on each retry path is one more inventory that must stay exhaustive, and this phase has already lost rounds to enumerations that source quietly answered with one more entry. Generation mismatch is the single invalidation mechanism, and it covers a path nobody remembered to instrument.
- **The evidence is stamped where it is gathered.** `SchedulableSnapshot.incompleteGalleryIDs` becomes `incompleteGalleryGenerations: [String: Int]`, built from `queueIntentGeneration(for:)` inside the SAME actor-isolated read that computes the sums — the same reason `finishedPages` rides along. Read from a second point, a queue intent advancing in between would stamp an observation with a generation that never saw the record it describes. `reduce(into:)` rather than `Dictionary(uniqueKeysWithValues:)`, inheriting the sibling's no-trap-on-duplicate-folder rule.
- **Both merges keep the GREATER generation.** `ensureContinuedSession`'s post-hop seed and `reconcileRetiredSessionPages`' accumulation both use `uniquingKeysWith: { max($0, $1) }`. This is the existing "an in-hop observation outranks the pre-hop snapshot" rule expressed over a value that orders: a queue intent advancing inside the client start's main-actor hop is a real user action, and taking the snapshot's older stamp would resurrect the very observation the advance invalidated.
- **The retirement guard reuses the same equality.** `reconcileRetiredSessionPages`' departure branch now asks the identical question the numerator asks, so a re-queued gallery's departure and its live contribution cannot answer differently — the same "one definition, no two readers disagree" rule the file already states for `sessionCreditedPages`.
- **Consultation order is preserved exactly.** Live `runProgressBases[gid]` first, an incomplete record next, a complete record only under generation equality, otherwise zero. The clears remain session start and session end alone; nothing was added to `markContinuedSessionEnded` that would conflate a session boundary with a run boundary (G-15-26).

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — prove a same-session redo inherits predecessor observation credit** - `c6f39632` (test)
2. **Task 2: GREEN — generation-scope incomplete observation without weakening run credit** - `708ea586` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - `observedIncompleteSessionGIDs` replaced by `observedIncompleteSessionGenerations: [String: Int]`; its doc rewritten to state that observation is evidence about one queue intent rather than a durable property of a gallery id, with CR-02's reachable sequence and the no-per-path-clear rationale recorded on the declaration.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - `SchedulableSnapshot.incompleteGalleryGenerations` (type, init, doc); `schedulableSnapshot()` stamps the generation in its own read; `sessionCreditedPages`' regime-2 equality guard plus the paragraph deriving it; session-start clear; the seed merge; the teardown clear; the retirement guard and its trailing merge.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - new `testARequeuedGalleryInheritsNoPredecessorObservationCredit`, 201 lines including the derivation of why the keeper is the blocker and why the discriminating frame is the one after the keeper's pages land.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift` - one doc line re-pointed at the renamed snapshot member (comment only).
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` - one doc line re-pointed at the renamed snapshot member (comment only).

## Decisions Made

- **DEC-A: generation equality, not a per-path clear.** The plan offered both ("at minimum, every fresh queue intent must remove the prior observation"). The equality was chosen because it is total over routes that do not exist yet, and because the alternative reintroduces the census-shaped failure mode this phase has repeatedly hit.
- **DEC-B: the merge conflict rule is `max`, not last-writer-wins.** Generations order, so "newer wins" is expressible; the existing sibling merge (`{ observed, _ in observed }`) could only express "in-hop wins" because its value does not order. Both express the same rule.
- **DEC-C: the regression's discriminator is the frame AFTER the keeper's six pages land, not the re-queue's own push.** The monotonic floor sits at the four pages gallery A really did finish, so the re-queue frame reads `4 / 24` on both sides of the fix and discriminates nothing. Landing six of the keeper's pages lifts the honest numerator clear of that floor: post-fix the card reads the keeper's own six, pre-fix it reads ten. A's record is asserted still claiming four pages at that exact frame, so the difference is the credit rule rather than anything a manifest did.
- **DEC-D: the keeper is the BLOCKER, and that is load-bearing twice.** It holds the queue non-empty so the session survives A's completion (D-06: no second session), and it parks on `BlockingRunnerControl.park()`'s named suspension point so `scheduleNextIfNeededCore`'s `activeTask == nil` guard refuses every later promotion. Every convergence then pushes synchronously inside the call that issued it, so no detached run tail can land between two assertions — the recorded series is a fact about the accounting rather than about scheduling. This is 15-56/15-57's blocker idiom applied to a progress-series case.
- **DEC-E: the re-queue is `retry(gid:mode:.repair)`, a real product tap.** It resolves the mode, advances the generation, enqueues, schedules and only then ensures the session. Nothing in the case installs an observation, a retirement or a basis through a testing setter; the only forwarder used is `testingPrepareWorkingSeedAnnouncingProgress`, which every sibling run-proof case already uses to reach the production preparation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two test-file doc comments named the renamed snapshot member**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadContinuedSessionRunProofTests.swift:57` and `DownloadContinuedSessionLedgerRefusalTests.swift:46` both reason from `snapshot.incompleteGalleryIDs`, a symbol this plan deletes. Left alone they would point at nothing — a documentation defect introduced BY this change rather than a pre-existing one, so it is inside the task's scope boundary.
- **Fix:** Re-pointed both at `incompleteGalleryGenerations` / `snapshot.incompleteGalleryGenerations`; "observation set" became "observation map" in the second. No claim in either sentence changed — both still argue that the snapshot-sourced admission cannot reach a complete-reading refusal record, which remains true under the generation key.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift`, `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`
- **Verification:** `rg -n 'observedIncompleteSessionGIDs|incompleteGalleryIDs' AppPackage/Sources AppPackage/Tests` returns nothing; both suites green in the full run; SwiftLint clean over both files.
- **Committed in:** `708ea586` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — a stale symbol reference this change created)
**Impact on plan:** Comment-only, two lines, no assertion or behaviour touched. No scope creep; no undeclared production file was modified.

## Banked Falsifiability

The RED case failed against pre-fix production with **2 verbatim issues**, both at the queued window:

| Site | Pre-fix (recorded) | Post-fix (expected) |
|---|---|---|
| `DownloadContinuedSessionTests.swift:761` | `completedUnitCount: 10`, `subtitle: "10 / 24 pages · 2 galleries"` | `completedUnitCount: 6`, `subtitle: "6 / 24 pages · 2 galleries"` |
| `DownloadContinuedSessionTests.swift:809` | `(measuredPair.completedUnitCount → 9) > (queuedWindowPair.completedUnitCount → 10)` failed | `9 > 6` holds |

Queue-intent generation observed moving `0 → 1` across `retry(gid:mode:.repair)`, with the session id and `spy.startCount == 1` unchanged on both sides.

The frames AFTER the successor announcement (`7 / 24`, then `9 / 24`) passed pre-fix as well, and that is expected rather than a weak pin: `prepareWorkingSeed`'s own D-G7-01 bracket withdraws the stale credit at the record movement, so both sides converge from the announcement onward. Those two frames are the "measured credit after the basis" half of the boundary — they refuse a fix that makes a re-queued gallery contribute nothing forever — not the discriminator.

## Issues Encountered

- **The monotonic floor initially masked the whole defect.** The first staging (re-queue, then read the very next push) produced `4 / 24` on both sides: dropping A's retirement lowers the honest numerator by exactly what A's live credit used to supply, and `lastPushedCompletedPageCount` floors the difference away. Resolved by DEC-C — a second gallery's landings lift the honest value clear of the floor, which is the only way a below-floor quantity becomes observable at the card.
- **Determinism around the inert run tail.** With a `.skippedOperation` runner, every `scheduleNextIfNeeded` spawns a task whose `finishActiveTaskIfOwned` issues a DETACHED convergence push, so a barrier keyed on `testingHasActiveTask() == false` would not guarantee the tail had landed, and no value-crossing barrier exists here (the denominator and the gallery count are constant across the re-queue by construction). Resolved by DEC-D: the parked blocker makes `activeTask` permanently non-nil after the first schedule, so no task is ever spawned again and every push is synchronous.

## Verification Evidence

Run one xcodebuild invocation at a time, `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` — **TEST SUCCEEDED**.
2. Full `FeatureTests` — **TEST SUCCEEDED**, 926 tests / 0 failures across all targets; downloads target 407 tests in 71 suites (+1 case). Re-run from scratch after the final formatting change, green both times.
3. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1561DerivedData build` — **BUILD SUCCEEDED**, **0 warnings** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
4. Standalone SwiftLint `--strict` over all 5 touched files (the app scheme does not lint `Tests/`) — **0 violations, 0 serious**.

Acceptance greps:

- `rg -n 'observedIncompleteSessionGIDs' AppPackage/Sources/DownloadClient` → no hit.
- `rg -n 'observedIncompleteSessionGenerations' …+ContinuedSession.swift …+Manager.swift` → 7 sites: the declaration, the equality guard, the session-start clear, the seed merge, the teardown clear, the retirement guard, the retirement merge.
- `rg -n 'observedIncompleteSessionGenerations.*queueIntentGeneration' …+ContinuedSession.swift` → 2 sites (numerator and retirement), both single-line.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` — FOUND
- Commit `c6f39632` — FOUND
- Commit `708ea586` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced; every symbol the plan declared has a live production consumer.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-02 is closed at its root. The remaining `15-REVIEW.md` blockers (CR-01 destructive validate-time scan, CR-03 folder-rename traversal, CR-04 unvalidated page selection) are independent and untouched by this plan.
- Open, non-blocking, carried forward from earlier plans and unchanged here: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01; `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not declare.
- `DownloadFeatureTestHelpers.swift` remains at 970 of the 1000-line limit (15-60's note). This plan added nothing there — the new case reuses `SessionGallery`, `makeQueuedCoordinator`, `galleryFolderURL`, `writePageFiles`, `pageResults`, `makeRepairPayload`, `lastPushedPair`, `PushedPair` and `BlockingRunnerControl` unchanged — but the next addition to that file still needs a split.
- No new census entry is owed: `DownloadSourceInventoryTests` counts scheduling blocks, floor writers, bracket callers, queue entrances, schedulable reads, pending-list evaluations, run-proof sites and client-double sites, and none of those tables covers the renamed observation state or `queueIntentGeneration`. Verified by inspection of all eight tables rather than assumed.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
