---
phase: 15-continued-background-downloads
plan: 35
subsystem: DownloadClient continued-processing session
tags: [gap-closure, documentation, invariants, G-15-15]
status: complete
requires:
  - "15-33 (AssetFileProbeOutcome reshape) and 15-34 (zero-page guards) landed first; the rewritten comments describe source as it stands after both"
provides:
  - "Three load-bearing doc sites in the session lifecycle whose premises match traced source"
  - "A grep-verified five-writer inventory on lastPushedCompletedPageCount"
affects:
  - "Future fixes to session liveness and progress arithmetic, which reason from these comments"
tech-stack:
  added: []
  patterns:
    - "One canonical non-suspension wording reused verbatim wherever the same call chain is claimed about"
    - "Writer inventories carry an exhaustiveness label plus the grep that established it"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
decisions:
  - "WR-01 decided toward stating the truth rather than setting the debt flag: production choreography unchanged, the drop-and-repaint rationale recorded"
  - "WR-02 decided toward one canonical wording applied at every site claiming about the same chain, including a fourth site the plan did not enumerate"
  - "WR-04 decided toward naming all five writers plus the session-scoped rule rather than dropping the count"
metrics:
  duration: 22min
  completed: 2026-08-05
---

# Phase 15 Plan 35: Correct the Contradicted Session-Lifecycle Premises Summary

Three load-bearing doc comments in the continued-processing session now say only what source
supports: the nil-client skip states that a start-window push is dropped rather than replayed, one
canonical non-suspension wording covers every claim about the same call chain, and the monotonic
floor's writer inventory names all five writers with the grep that proves it exhaustive. Zero
executable lines changed.

## What Was Built

**Commit:** `45b092b4` — `docs(15-35): correct three contradicted invariant comments`

### WR-01 — the nil-client skip now states the truth

`pushContinuedSessionProgress`'s skip comment previously claimed "The deferred reconcile after
start re-reads schedulable work and pushes fresh counts, so this update is recovered." A grep over
the module shows `continuedSessionNeedsReconciliation` is SET in exactly one place — the drain
branch of `reconcileContinuedSession` — so every non-drain push landing in the start window
returned with no debt recorded and no replay. The decision was to state the truth and record why
the flag is deliberately not set here (production behavior untouched). The rewritten comment:

> Read the client identity only after the ownership re-check, so the ordering survives an `await`
> introduced into the reads above: a capture taken ahead of them could present a predecessor's id
> after a successor took over.
>
> SKIPPED: nil means there is no card to paint yet, and this update is DROPPED rather than
> replayed. Reconciliation debt is recorded in exactly one place — the drain branch of
> `reconcileContinuedSession` — so every other push landing in the start window returns here
> recording nothing: the flush push, the run-start announcement (D-G5-01) and the non-drain
> convergence tail alike. That asymmetry is deliberate. A dropped TERMINAL word is the one loss no
> later push can repaint, which is why the drain branch defers; a dropped live push is repainted by
> the next flush or convergence push, each of which recomputes the whole pair from the
> authoritative snapshot rather than carrying this one forward. Setting the debt flag here instead
> would discharge a deferred reconcile for every start-window push, running repair work for windows
> that need none and changing production choreography for no observable defect.

The four production push sites named there were confirmed by grep:
`DownloadClient+Persistence.swift:224` (flush push), `DownloadClient+ExecutionSupport.swift:378`
(run-start announcement inside `prepareWorkingSeedAnnouncingProgress`), and
`DownloadClient+ContinuedSession.swift` drain-terminal and non-drain-tail pushes.

### WR-02 — one canonical wording at every site claiming about the same chain

The chain was re-traced in source before writing: `hasPendingWork()` reads `activeTask` then
`schedulableDownloads()`, which reads `queueStore.gids` (a `@Shared` value on a struct) and calls
`indexedDownloads(gids:)` → `downloads(from:)` — an actor-local filter, map and sort with no
`await` inside. `schedulableSnapshot()` and `reconcileRetiredSessionPages` route through the same
functions. Nothing in either chain suspends today; the sole real suspension on the push path is
`updateProgress` crossing the client seam's main-actor hop.

The canonical sentence — *"these are same-actor calls that do not suspend today; an `await`
introduced inside them reopens this window and needs its own re-validation"* — is now applied,
adapted to each subject, at **four** sites (the plan named three; the fourth is the body comment
inside `ensureContinuedSession` that already carried the claim in near-canonical form and was
aligned for verbatim consistency):

1. `reconcileContinuedSession`'s re-check paragraph — the TRUE instance the wording derives from,
   re-worded to the canonical form.
2. `pushContinuedSessionProgress`'s interleaving paragraph — the false "the snapshot read and the
   retirement reconcile can both suspend" is gone, replaced by the canonical wording plus the
   push's one real suspension.
3. `ensureContinuedSession`'s doc — the stamped-before-any-interleave claim is replaced by the
   truth, naming the awaited guard call:

   > The guard line below awaits `hasPendingWork()`, which reads `activeTask` and then the queue
   > store through `schedulableDownloads()`. These are same-actor calls that do not suspend today,
   > so the stretch from that guard through the id stamp admits no interleaving as written; an
   > `await` introduced inside them reopens the two-starters window this guard closes and needs its
   > own re-validation.

4. `ensureContinuedSession`'s post-hop body comment — aligned to the same phrasing.

Additionally, the D-G3-01 paragraph's "same-actor calls that do not suspend" gained the canonical
`today` marker so the whole file reads as one claim rather than several.

### WR-04 — five writers, labeled exhaustive by grep

`lastPushedCompletedPageCount`'s doc opened "Four writers, and no others" and closed with a
sentence describing a fifth. It now enumerates five as a numbered list — the start-time reset, the
additive seed merge, `markContinuedSessionEnded`'s teardown zero, the per-push re-latch, and the
D-G7-01 withdrawal (one implementation, two call sites) — labeled verified exhaustive at this HEAD
by grep, with the closing session-scoped rule rewritten to cite writers 1 and 3 by number so the
rule and the count check each other.

**Writer grep output** (`grep -rn "lastPushedCompletedPageCount" AppPackage/Sources/DownloadClient/`,
comment lines filtered out), taken at the committed HEAD:

```
AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:279:            lastPushedCompletedPageCount -= max(beforeCount - afterCount, 0)
AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:463:    public var lastPushedCompletedPageCount = 0
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:202:        lastPushedCompletedPageCount = 0
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:242:        lastPushedCompletedPageCount = max(
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:243:            snapshot.sessionProgress.progress.displayCompletedPageCount + lastPushedCompletedPageCount,
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:337:        lastPushedCompletedPageCount = 0
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:607:            lastPushedCompletedPageCount,
AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:610:        lastPushedCompletedPageCount = completedPageCount
```

Every assignment maps to one of the five named writers, and no sixth exists:

| Site | Writer |
|------|--------|
| `+ContinuedSession.swift:202` | 1 — `ensureContinuedSession`'s synchronous reset |
| `+ContinuedSession.swift:242` | 2 — the additive seed merge |
| `+ContinuedSession.swift:337` | 3 — `markContinuedSessionEnded`'s teardown zero |
| `+ContinuedSession.swift:610` | 4 — the per-push re-latch |
| `+ExecutionSupport.swift:279` | 5 — the D-G7-01 withdrawal |

The three remaining hits are not writers: `+Manager.swift:463` is the declaration, and
`+ContinuedSession.swift:243` and `:607` are reads inside the seed expression and the push's
`max()` respectively.

## Acceptance Criteria

| Criterion | Result |
|-----------|--------|
| `grep -c 'can both suspend'` (ContinuedSession) | `0` |
| `grep -c 'do not suspend today'` (ContinuedSession) | `4` (≥ 3 required) |
| `grep -c 'before the first point another caller could interleave'` | `0` |
| `grep -c 'this update is recovered'` | `0` |
| `grep -c 'Four writers, and no others'` (Manager) | `0` |
| Rewritten inventory names `markContinuedSessionEnded` | yes |
| Comment-only diff | verified, see below |
| Full FeatureTests single invocation | `** TEST SUCCEEDED ** [61.147 sec]` |

## Comment-Only Diff Statement

`git diff --stat` for commit `45b092b4` shows exactly the two planned files (63 insertions, 33
deletions). Filtering the commit's unified diff to lines that are neither `///` nor `//` prefixed
and not blank returns **an empty set** — every changed line in both files is a comment line. No
executable line moved, no symbol was added or removed, and no production behavior changed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected a fourth contradicting suspension claim in the same file pair**

- **Found during:** Task 1, while applying the canonical wording
- **Issue:** `hasLiveContinuedSession`'s doc in `DownloadClient+Manager.swift` read
  "`ensureContinuedSession()` suspends twice after setting it". Counting syntactic `await`s gives
  two (`schedulableSnapshot()` and `backgroundProcessingClient.start`), but only the client start
  actually suspends today — the same false premise WR-02 exists to remove. Leaving it would have
  violated this plan's own prohibition on leaving a corrected sentence beside the old claim it
  contradicts, in the very file being corrected.
- **Fix:** Reworded to "suspends at the client start after setting it". The surrounding claim
  ("before that path's first suspension") was re-verified as true and left alone.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift`
- **Commit:** `45b092b4`

**2. [Rule 1 - Bug] Corrected the skip comment's own suspension premise**

- **Found during:** Task 1, WR-01
- **Issue:** The skip comment's ordering rationale said "Capturing it before the *suspending*
  progress read", which is the same false premise on the same chain. Correcting only the recovery
  sentence would have left both halves of the WR-02 contradiction standing three lines apart.
- **Fix:** Reworded to an if-a-suspension-is-ever-introduced justification, consistent with the
  canonical wording.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`
- **Commit:** `45b092b4`

### Scope Notes

The plan enumerated three canonical-wording sites; a fourth (the post-hop body comment in
`ensureContinuedSession`) already carried the claim in near-canonical form and was aligned rather
than left to drift. This is why the grep gate reports `4` where the criterion required at least
`3`.

## Test Flake Observed (not a regression)

The first full FeatureTests invocation failed one test:

```
DownloadCoordinatorStorageTests.testDownloadCoordinatorObserverInitialSnapshotUsesManifestIndex()
DownloadFeatureTestHelpers.swift:108: Caught error: Error Domain=DownloadFeatureReducerTests Code=1
"Timed out waiting for initial download observer snapshot"
```

This is a 4-second wait timing out, and the diff under test is comment-only — no executable line
exists through which it could be caused. The suite was re-run once in a single invocation and
passed end to end (`** TEST SUCCEEDED ** [61.147 sec]`). Recorded here so a future round sees that
this helper's observer wait has been observed flaky at least once, rather than rediscovering it as
a fresh finding. No overlapping `xcodebuild` invocations were run.

## Verification Performed

- SwiftLint over `AppPackage/Sources/DownloadClient/` with the root config: exit `0`, zero
  violations. No rule was suppressed or disabled.
- Longest line in either file: ≤ 120 characters (`line_length` error threshold). Both files remain
  under the 1000-line `file_length` limit.
- Full FeatureTests, single invocation, explicit simulator id (the `iPhone Air` destination name is
  ambiguous on this host): green.
- Post-commit deletion check: no tracked file deleted. No untracked files left behind.

## Threat Flags

None. The plan edits doc comments only — no new network endpoint, auth path, file access pattern
or schema change. T-15-35-01 (wrong written premises steering a future fix into guarding the wrong
invariant) is mitigated by the corrections themselves, each held by a grep gate that the false
phrases cannot survive.

## Known Stubs

None.

## Success Criteria

G-15-15 is closed. WR-01, WR-02 and WR-04 are each corrected in one decided direction, the false
phrases are gone by grep, the canonical wording is present at every suspension-claim site, the
five-writer inventory is grep-verified exhaustive, and the comment-only diff is proven by
inspection with a green full run.

## Self-Check: PASSED

Both modified source files and this summary exist on disk; commit `45b092b4` is present in
`git log`.
