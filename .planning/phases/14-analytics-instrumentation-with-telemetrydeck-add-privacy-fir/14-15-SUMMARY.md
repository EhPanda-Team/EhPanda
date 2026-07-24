---
phase: 14-analytics-instrumentation
plan: 15
completed: 2026-07-25
tasks_completed: 3
tasks_total: 3
requirements-completed: []
---

# 14-15 Summary: DownloadsFeature instrumentation

**Download completion and failure are edge-triggered out of a full-snapshot stream, so a finished download is counted once rather than once per observation tick and a cold start reports nothing — plus delete, move and the downloads-list gallery-detail push. Thirteen cases prove the edge semantics at both the pure-function and store levels.**

## The problem this plan exists for

The downloads list learns about progress through a stream of **full snapshots**, not events. The obvious instrumentation — emit whenever a download reads as completed — reports one finished download again on every tick, hundreds of times per session. Worse, on the first observation after launch the previous snapshot is empty, so every already-finished download in the library looks like a completion that just happened: a phantom burst on every cold start, proportional to how much the user has downloaded.

`DownloadsReducer.outcomeTransitions(from:to:)` is the fix, modeled on the transition-diff technique already used by this repository's haptics reducer extension. It compares each gallery against its **own** previous status and emits only on a change into a terminal one, and it excludes galleries absent from the previous snapshot entirely.

It is a pure function of its two arguments — no state, no dependencies — specifically so the edge semantics can be covered exhaustively without a store. It is called **before** the incoming snapshot is assigned, because `state.downloads` is the only copy of the previous snapshot that exists. The case's existing early-return guard is untouched.

## Emission sites

| Site | Signal | Placement |
|------|--------|-----------|
| Snapshot stream | `downloadStateChanged(.completed)` / `(.failed)` | Edge-triggered diff, before the state assignment |
| Delete | `downloadStateChanged(.deleted)` | `deleteDownloadDone` success arm |
| Move | `downloadStateChanged(.moved)` | `moveDownloadDone` success arm |
| Gallery-detail push | `galleryDetailOpened(category:tagNamespaces:)` | `pushGalleryDetail`, from the download's gallery projection |

The move signal carries the outcome alone — the destination folder name is user-authored text and never crosses the boundary. Failure arms are silent: a failed move is not a move. A gallery leaving the snapshot emits nothing there; removal is owned by the explicit delete action.

## Verified inventory: two more outcome-bearing cases

The plan asked for the inventory to be verified by search rather than recited, and to raise anything beyond delete and move rather than instrument it silently. Searching the action enum found nine completion cases. Two are outcome-bearing and are **not** instrumented:

1. **`toggleDownloadPauseDone`** — a **second** pause/resume site, in addition to the one plan 14-13 found in `DetailReducer`. This matters for **D-20**, which the owner approved after 14-13 raised it: D-20 as written names only the `DetailFeature` site. **Plan 14-17 must instrument both**, or pause/resume will be measured from the detail screen and silently missed from the downloads list — a half-measured metric, which is worse than an unmeasured one.
2. **`updateDownloadDone`** — updating a download (re-fetching a gallery flagged `updateAvailable`). `DownloadOutcome` has no case able to express it, exactly as pause had none before D-20. Raised rather than instrumented; it needs an owner decision on whether an `updated` outcome should exist.

The remaining completion cases carry no user-visible download outcome: `fetchDownloadsDone`/`observeDownloadsDone` (the snapshot stream itself), `refreshDownloadsDone`, `fetchFoldersDone`, `openReadingDone`.

## Tests

`DownloadsFeatureTests/AnalyticsEmissionTests` → **13 tests, TEST SUCCEEDED**. Full default plan → **752 tests, TEST SUCCEEDED**, zero warnings.

**Layer 1 — the pure diff**, seven cases: the cold-start empty-previous snapshot (the single most important assertion here), a completion edge, an error edge, five successive identical snapshots, an intermediate status change, two simultaneous transitions asserted in deterministic order, and a gallery disappearing.

**Layer 2 — wired into the reducer**, six cases. The one that earns its keep sends an active snapshot followed by three identical finished ones and requires exactly one recorded signal: if the diff were taken *after* the state assignment rather than before, both snapshots would be identical and it would record nothing. The sentinel reflection assertion covers the **folder name** as well as the title and tag text, since a move signal's most plausible leak is the destination folder.

## A regression this plan surfaced in 14-14

Running this target **serially** exposed nine failing tests that the parallel full-suite runs had also been failing — all of them reader-presentation paths, none of them related to downloads analytics.

Cause: plan 14-14 made `ReadingReducer.onPresented` read `date.now` to stamp the session start. Every test that presents the reader without overriding the `date` dependency began tripping TCA's unoverridden-dependency guard. The affected paths are in `DetailFeature` and `DownloadsFeature`, not `ReadingFeature`.

It escaped 14-14's verification because that plan ran only its own target's suite — its stated assumption was that new state fields could only break same-target assertions. A dependency newly read on a cross-module presentation path breaks *callers* instead, and only a full-suite run surfaces that. Fixed in commit `ac0096c9` by supplying the dependency at the nine affected stores; no assertion or behavioral expectation was changed.

**Process note for the remaining plans:** run the full suite after every plan that adds a dependency read to a presentation path, not just the plan's own target.

## Deviations from plan

1. `outcomeTransitions` is `static` and internal rather than `private`, so the pure-function layer of tests can drive it directly — which the plan's own Task 3 requires ("Test the diff helper directly as well as through the store"). A `private` helper is unreachable from the test target.
2. `deleteDownloadDone` previously discarded its `Result`; the case now binds it to emit on the success arm only.
3. The gallery-detail store in the new suite overrides `date`, because that push seeds a `DetailFeature` screen which reads it.

## Notes

- `ANALYTICS-01` remains `[ ]` — 14-17 closes it out.
- The pre-existing `DownloadObserverBatchTests` parallel-execution flake (logged in `deferred-items.md`) passed in every run during this plan.
