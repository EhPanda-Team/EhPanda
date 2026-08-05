---
phase: 15-continued-background-downloads
plan: 29
subsystem: downloads
tags: [continued-processing, background-downloads, accounting-basis, monotonic-floor, gap-closure, delta-keyed-invariant]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G4-01's counted basis (15-24), D-G5-01's reconciliation (15-25), D-G6-01's withdrawal + additive seed merge (15-26), and 15-28's testingPrepareWorkingSeedAnnouncingProgress forwarder"
provides:
  - "G-15-7 closed by construction: D-G7-01 withdraws every deliberate downward basis movement's counted portion, keyed on the pre/post downloadIndex[gid] delta"
  - "withdrawingCountedBasisMovement — one non-async bracket, two call sites (prepareWorkingSeed's whole preparation, writeInitialManifest's body), no per-mechanism patch anywhere"
  - "WR-05 subsumed: both bracket readings are on the INDEX record the numerator is summed from, so working-manifest/index divergence can no longer reach the floor"
  - "Three counted-record regressions (.redownload wipe, .update of a trusted gallery, validatedManifest page-count mismatch), each observed frozen before the fix"
  - "The writer sweep: all twelve downloadIndex writers dispositioned under the invariant with execution-time evidence, zero unmapped write sites"
affects: [continued-processing-session, background-downloads, download-basis-accounting]

tech-stack:
  added: []
  patterns:
    - "An invariant over a QUANTITY, not over an enumeration of mechanisms: read the quantity before, run the movement, read it after, act on the delta"
    - "A bracket wrapping a whole preparation covers movers nobody has enumerated yet, including ones a later round adds"
    - "A departure and a correction are different events: an absent after-reading defaults to the before-count so the retirement ledger keeps sole ownership of departures"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "The bracket is module-internal, not file-private: writeInitialManifest lives in DownloadClient+PublicAPI.swift, and one implementation is what stops the withdrawal rule forking between the run route and the enqueue route"
  - "An absent after-reading defaults to the before-count rather than to zero, so a record that vanished during a movement withdraws nothing — departures stay the retirement ledger's alone"
  - "Test K deliberately issues a push BEFORE the wipe, so its honest dip lands between two pushes; the never-rewinds series property is therefore asserted only in Tests J and L, where the dip precedes the first push"
  - "Task 2 produced zero source hunks: the sweep is verification, and its two structural notes (compounding, atomicity) were already written into the bracket's doc in Task 1"

metrics:
  duration: 70min
  completed: 2026-08-05
  tasks: 2
  files: 6

status: complete
---

# Phase 15 Plan 29: The Delta-Keyed Basis Withdrawal (D-G7-01) Summary

Every deliberate downward movement of the session accounting basis now withdraws its counted portion
from the monotonic floor, keyed on the pre/post `downloadIndex[gid]` delta rather than on any named
mechanism — so a `.redownload` of a counted gallery, an `.update` of a trusted one, and a fresh
manifest forced by a page-count mismatch all dip the card once, honestly, and advance again on the
very next page of real work.

## What Changed

**The bracket.** `withdrawingCountedBasisMovement<T>(gid:_:)` in
`DownloadClient+ExecutionSupport.swift` (line 265): non-async, generic over the closure's return,
`rethrows`. It reads `downloadIndex[gid]?.manifest` once before the movement (holding `beforeCount`
and the counted-basis flag), runs the movement, reads the record again, and — when
`continuedSessionID != nil` and the flag holds — subtracts `max(beforeCount - afterCount, 0)` from
`lastPushedCompletedPageCount`, unclamped.

```swift
    func withdrawingCountedBasisMovement<T>(
        gid: String,
        _ movement: () throws -> T
    ) rethrows -> T {
        let beforeManifest = downloadIndex[gid]?.manifest
        let beforeCount = beforeManifest?.completedPageCount ?? 0
        let wasCountedBasis = beforeCount < (beforeManifest?.pageCount ?? 0)
            || observedIncompleteSessionGIDs.contains(gid)
        let result = try movement()
        let afterCount = downloadIndex[gid]?.manifest.completedPageCount ?? beforeCount
        if continuedSessionID != nil, wasCountedBasis {
            lastPushedCompletedPageCount -= max(beforeCount - afterCount, 0)
        }
        return result
    }
```

Before-read → movement → after-read → conditional subtraction, in one synchronous body. `grep -c
await` over that body outputs `0`.

**The two call sites.** `prepareWorkingSeed`'s entire preparation (movers 1–3 by construction, plus
any future mover that converges there) and `writeInitialManifest`'s entire body (mover 4). Neither
signature changed; both stay synchronous.

**The relocation.** `reconcileWorkingManifestAgainstPageFiles` lost its counted-basis local and its
floor subtraction. Blank loop, early return, manifest write and `updateDownloadIndex` are all
retained byte-for-byte; its long doc keeps the D-G5-01 rationale, the deliberate-consequence
paragraphs and the WR-03 `storage.validate` paragraph, and its D-G6-01 section is replaced by a
pointer to the bracket naming G-15-7 as the defect per-mechanism placement caused.

**The corrected premises.** The push doc in `DownloadClient+ContinuedSession.swift` no longer claims
a single deliberate downward mover; it now states that movers exist wherever the coordinator rewrites
the index record, that enumerating them is the recorded four-round failure, and that the one movement
the floor still catches is one with no coordinator write behind it. The seed merge comment's
mechanism reference moved from D-G6-01 to D-G7-01 (mechanics sentence unchanged). The
`lastPushedCompletedPageCount` declaration doc in `DownloadClient+Manager.swift` names the bracket
and both call sites as its fourth writer; the negative-transient paragraph is verbatim.

**The regressions and the helper.** `makeStartPayload(for:mode:pageCountOverride:)` generalizes the
payload builder; `makeRepairPayload(for:)` is a one-line forward to it and its call spelling is
unchanged at every existing site. Three new cases in `DownloadContinuedSessionBasisTests.swift`.

## Falsifiability — the RED run, verbatim

Targeted command, single invocation, taken before any production change landed
(`exit=65`, 19 tests in 2 suites, 10 issues, all three new cases failing, all sixteen pre-existing
basis and ledger cases green):

| Case | Reading | Derived | Observed pre-fix |
|---|---|---|---|
| J `.redownload` | announcement | `0 / 6 pages · 1 gallery` | `(dipPair.completedUnitCount → 4) == 0`; `(dipPair.subtitle → "4 / 6 pages · 1 gallery")` |
| J `.redownload` | first flush push | `1 / 6 pages · 1 gallery` | `(firstPair.subtitle → "4 / 6 pages · 1 gallery")` |
| J `.redownload` | second flush push | `2 / 6 pages · 1 gallery` | `(secondPair.subtitle → "4 / 6 pages · 1 gallery")` |
| K `.update` | announcement | `0 / 5 pages · 1 gallery` | `(dipPair.completedUnitCount → 3) == 0`; `(dipPair.subtitle → "3 / 5 pages · 1 gallery")` |
| K `.update` | first flush push | `1 / 5 pages · 1 gallery` | `(firstPair.subtitle → "3 / 5 pages · 1 gallery")` |
| L mismatch | announcement | `0 / 8 pages · 1 gallery` | `(dipPair.completedUnitCount → 4) == 0`; `(dipPair.subtitle → "4 / 8 pages · 1 gallery")` |
| L mismatch | first flush push | `1 / 8 pages · 1 gallery` | `(firstPair.subtitle → "4 / 8 pages · 1 gallery")` |

The frozen band is exactly C pushes wide in each case, and its width equals the counted portion the
floor was holding: 4, 3 and 4 respectively. No new case passed pre-fix.

**The counted staging is real** — the three `SessionGallery` literals, quoted:

- J: `SessionGallery(gid: "210360", title: "Errored", pageCount: 6, completedPageCount: 4)`
- K: `SessionGallery(gid: "210361", title: "Trusted", pageCount: 5, completedPageCount: 3)`
- L: `SessionGallery(gid: "210362", title: "Regrown", pageCount: 6, completedPageCount: 4)`

Each has `0 < completedPageCount < pageCount`, so each record is counted RAW by D-G4-01's first half.
None is the 6-of-6 shape whose vacuity let this defect ship green for four rounds.

## Writer sweep — every `downloadIndex[gid]` writer, confirmed row by row

Completeness greps at execution HEAD. `grep -rn 'downloadIndex\[' AppPackage/Sources/DownloadClient/`
returns 19 lines: 3 doc-comment mentions (`+ExecutionSupport.swift:209`, `:244`,
`+ContinuedSession.swift:543`), 10 reads (`+ExecutionSupport.swift:266`, `:271`,
`+RetryHelpers.swift:109`, `+Persistence.swift:32`, `+Folders.swift:70`, `+PublicAPI.swift:42`,
`:70`, `:275`, `+BackgroundDownloads.swift:135`, `:161`) and **5 writes**
(`+Persistence.swift:150`, `:153`, `:251`, `+Folders.swift:144`, `:223`, `+PublicAPI.swift:240` —
six lines, of which `+Persistence.swift:251` is the single `updateDownloadIndex` primitive itself).
`grep -rn 'updateDownloadIndex(' AppPackage/Sources/DownloadClient/` returns 8 lines: 1 declaration
(`+Persistence.swift:250`) and **7 call sites**. Unmapped write sites: **0**.

| # | Site (file:line at execution) | Movement class | Observed disposition |
|---|---|---|---|
| 1 | `updateDownloadIndex` in `ensureWorkingManifest`, `+ExecutionSupport.swift:466` | downward on wipe/mismatch | **COVERED by construction** — lexically inside `prepareWorkingSeed`'s bracket call (bracket opens at `:295`, preparation body encloses `ensureWorkingManifest`) |
| 2 | `updateDownloadIndex` in `reconcileWorkingManifestAgainstPageFiles`, `+ExecutionSupport.swift:446` | downward | **COVERED by construction** — same bracket; the function's own withdrawal is REMOVED (region grep for the floor scalar over its body: `0`) |
| 3 | `updateDownloadIndex` in `writeInitialManifest`'s reusable branch, `+PublicAPI.swift:133` | identity | **COVERED** — inside `writeInitialManifest`'s bracket; `reusableExistingManifest` returns the same manifest, delta 0, withdraws nothing |
| 4 | `updateDownloadIndex` in `writeInitialManifest`'s fresh branch, `+PublicAPI.swift:138` | downward when replacing a counted record | **COVERED** — same bracket (mover 4) |
| 5 | `updateDownloadIndex` in `+ExecutionPerform.swift:179` | upward/identity | **HOLDS** — confirmed in source, see the cannot-lower note below |
| 6 | `updateDownloadIndex` in `flushManifestPageProgress`, `+Persistence.swift:247` | upward | **HOLDS** — same confirmation |
| 7 | `downloadIndex[gid] = record` in `reloadDownloadRecord`, `+Persistence.swift:153` | disk-truth republication | **HOLDS** — not a deliberate coordinator movement; a lowering here is the genuine-regression class the floor exists to mask (the residual defence the corrected push doc names) |
| 8 | `downloadIndex[gid] = nil` in `reloadDownloadRecord`, `+Persistence.swift:150` | deletion | **EXCLUDED** — departure; valued by `reconcileRetiredSessionPages` from the honest record; must not withdraw |
| 9 | `downloadIndex[gid] = nil` in `deleteFolder`, `+Folders.swift:144` | deletion | **EXCLUDED** — same rule |
| 10 | `downloadIndex[record.manifest.gid] = DownloadFolderRecord(...)` in `renameUserFolder`, `+Folders.swift:223` | identity — same manifest, re-slotted paths | **HOLDS** — the record is rebuilt from `record.manifest` verbatim; only path components change |
| 11 | `downloadIndex[gid] = nil` in `delete`, `+PublicAPI.swift:240` | deletion | **EXCLUDED** — same rule |
| 12 | `updateDownloadIndex` in the capture-restore path, `+PublicAPI.swift:327` | upward | **HOLDS** — same confirmation |

**Rows 5, 6 and 12 — the cannot-lower confirmation, with one correction to the plan's table.** The
plan's row 5 names `refreshManifestPageFileHashes`; source shows the site at
`+ExecutionPerform.swift:170-179` actually calls `storage.addingCurrentFileHashes(to:folderURL:)`.
The disposition is unchanged and the function is strictly stronger: `addingCurrentFileHashes`
(`DownloadStore+Operations.swift:82-108`) skips any page whose hash is already non-empty
(`guard pages[page]?.isEmpty != false else { continue }`), throws when a claimed page's file is
absent, and otherwise assigns `hashReadableAsset`'s return — so it can only turn an EMPTY hash into a
non-empty one, or throw before the index write happens. `refreshManifestPageFileHashes`
(`:141-170`, row 6 and, via `refreshManifestPageFileHash` at `:111-138`, row 12) only ever assigns
`hashReadableAsset`'s return to a page key that already exists, never `""`. And `hashReadableAsset`
(`:252-263`) either throws `AppError.fileOperationFailed` or returns `fileHash(at:)`
(`DownloadStore.swift:545-558`), a SHA256 hex digest — 64 characters, never empty. No path can blank
a hash or drop a page claim. Recorded as a finding rather than silently adapted, per the plan's rule.

One nuance worth writing down: rows 6 and 12 build their result from `readManifest(folderURL:)`, the
on-DISK manifest, not from the index record. The hash refresh itself cannot lower; a lowering could
only arrive from the disk manifest already being lower, which is row 7's disk-truth class and not a
deliberate coordinator movement. Every coordinator writer keeps the two in step by writing the
manifest and re-indexing from the same value in one synchronous stretch.

## Compounding, atomicity and WR-05

**Compounding.** The bracket is stateless per movement: it computes a local `beforeCount`/
`afterCount` pair and applies a plain subtraction to the floor. Two corrections in one session
therefore compose in either order — subtraction is commutative and no bracket reads another's
intermediate state — and a nested or re-entered preparation would simply measure its own enclosed
delta.

**Atomicity.** The bracket body contains no `await`, `prepareWorkingSeed` and `writeInitialManifest`
are both non-async, and the only suspension in the whole announcing path is
`prepareWorkingSeedAnnouncingProgress`'s push, which is issued strictly AFTER the bracket returns. No
interleaved push can therefore observe a lowered basis under an un-lowered floor or the reverse. Test
J's `#expect(spy.progressUpdates.count == 1)` at the announcement is the behavioural half of that
argument: the announcement's push is the only push in existence at that point, and it already reads
the withdrawn value.

**WR-05 subsumption.** Neither side of the bracket reads the working manifest. Both readings are
`downloadIndex[gid]?.manifest`, the exact value `schedulableSnapshot` sums the numerator from via
`schedulableDownloads()` → `indexedDownloads(gids:)`. Working-manifest / index-record divergence — the
re-slot-after-title-change path included — can no longer leave the floor holding a difference,
because the amount withdrawn is measured on what the basis was counting rather than on what a
mechanism happened to touch.

**Supersession.** 15-26-SUMMARY.md's Table 2 row 5 dispositioned `.redownload` / `.update` / fresh
`.initial` as "Blanks? no / Withdraws? no — **HOLDS**". That disposition is wrong for every counted
record and is superseded by this plan's writer sweep above; the existing summary is left unedited, as
summaries always are.

## Verification

| Gate | Result |
|---|---|
| `grep -c 'func withdrawingCountedBasisMovement' +ExecutionSupport.swift` | `1` |
| `grep -rc 'withdrawingCountedBasisMovement(' Sources/DownloadClient/ --include='*.swift'` | `+ExecutionSupport.swift:1`, `+PublicAPI.swift:1` — exactly 2 call occurrences (`:295`, `:126`); the declaration reads `withdrawingCountedBasisMovement<T>(` and correctly does not match |
| `await` in the extracted bracket body | `0` |
| floor scalar inside `reconcileWorkingManifestAgainstPageFiles`'s body / in the whole file | `0` / `1` |
| `D-G7-01` in `+ExecutionSupport.swift` / `+ContinuedSession.swift` / `+Manager.swift` | `3` / `2` / `1` |
| `observedIncompleteSessionGIDs` in `+ContinuedSession.swift` before → after | `7` → `7` (no admission, consumption or clear site touched) |
| `observedIncompleteSessionGIDs` in `+ExecutionSupport.swift` | `1` — the bracket's READ, replacing the reconciliation's |
| `git diff` hunks inside `reconcileRetiredSessionPages` or `schedulableSnapshot` | none — the file's only hunks are `@@ -227 +227 @@` (seed comment) and `@@ -537,12 +537,15 @@` (push doc) |
| three new case names in the basis suite | `3` |
| manual index-patch helper names (`patchManifest` / `completeManifest`) in the basis suite, comments filtered | `0` |
| `testingPrepareWorkingSeedAnnouncingProgress` / `flushManifestPageProgress` occurrences in the basis suite | `5` / `14` — every new case body contains both |
| `wc -l` for every edited file | 642, 372, 605, 603, 596, 730 — all below the 1000 `file_length` error gate |
| SwiftLint `--strict` over `Sources/DownloadClient` + `Tests/DownloadsFeatureTests` | exit `0`, zero violations |
| Task 1 targeted run (basis + ledger, one invocation) | RED `exit=65` (3 failing) → GREEN `exit=0`, 19 tests in 2 suites |
| Task 2 full FeatureTests run (one invocation) | `exit=0`, zero `✘` in the log |

**Behaviour-preserving relocation, the strongest single check.** Tests G
(`testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes`) and H
(`testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed`) exercise the `.repair` blanking route
and pass byte-identical — the basis suite's diff is a single pure-addition hunk,
`@@ -314,0 +315,251 @@`, so no existing case body or literal changed. Their withdrawal now fires
from the bracket instead of the reconcile body, at the same amount, in the same atomic stretch.

**Full-run blast radius.** Every suite green, including the ones whose preparations now route through
the bracket with no live session (`continuedSessionID == nil` makes every withdrawal a no-op):
`DownloadCoordinatorRepairSeedTests`, `DownloadInterruptedResumeTests`,
`DownloadEnqueueManifestTests` (the enqueue route the second call site wraps), all five
continued-session suites (`Basis`, `Ledger`, `Expiration`, `Identity`, `Interleave`), and
`DownloadSchedulingTests` — where a failure would have been a real regression, never flake.

## Deviations from Plan

### Findings recorded rather than silently adapted

**1. [Finding — acceptance-criterion premise false at execution] The `one deliberate downward mover`
grep was already `0` before this plan ran.**
- **Found during:** Task 1, Step 5 verification
- **Issue:** The plan's acceptance criterion asserts `grep -c 'one deliberate downward mover'` is "at
  least `1` at planning time" for both `+ContinuedSession.swift` and `+ExecutionSupport.swift`. Both
  measured `0` at execution HEAD, because the premise text wraps across a line break in source:
  `+ContinuedSession.swift:537` ends "…has exactly one" and `:538` opens "deliberate downward mover".
  The negative gate was therefore trivially satisfied and proved nothing.
- **Disposition:** The gate is reported as measured (`0` before, `0` after) and a meaningful
  substitute is recorded instead: `grep -c 'deliberate downward mover'` in `+ContinuedSession.swift`
  went `1` → `0` for the singular-premise sentence, and the replacement paragraph was verified by
  reading rather than by grep. `+ExecutionSupport.swift` was `0` before and after because that file's
  false premise was phrased differently ("the first mechanism in the phase that deliberately LOWERS…"
  and "whoever blanks, withdraws"); both of those paragraphs are deleted, verified by reading the
  rewritten doc.
- **Files:** documentation only; no code impact.

**2. [Finding — sweep row names the wrong function] Row 5's site calls `addingCurrentFileHashes`, not
`refreshManifestPageFileHashes`.**
- **Found during:** Task 2, Step 2
- **Issue:** The plan's row 5 asks the executor to confirm `refreshManifestPageFileHashes` cannot
  lower a completed count at `+ExecutionPerform.swift:179`; that site actually calls
  `storage.addingCurrentFileHashes(to:folderURL:)` (`+ExecutionPerform.swift:170-179`).
- **Disposition:** Both functions were confirmed non-lowering in source with the evidence recorded in
  the sweep section above. The row's disposition (`HOLDS`, upward/identity) is unchanged; only the
  function name is corrected.
- **Files:** documentation only; no code impact.

### Deliberate implementation choices inside the plan's shape

- **The bracket is module-internal, not `private`.** `writeInitialManifest` lives in
  `DownloadClient+PublicAPI.swift`, and Swift's `private` in an extension is file-scoped, so a
  file-private bracket could not have a second call site. The plan's "private to the module" is
  honoured as `internal`, and the reason is written into the bracket's doc. This does not re-widen
  15-28's tightening: nothing new is `public`, and no session-lifecycle mutator changed access.
- **Test K does not assert `expectTheCompletedSeriesNeverRewinds`.** The case deliberately issues one
  macro-cadence push before the wipe (so the withdrawal is measured against a push-latched floor
  rather than the start seed alone), which places the honest one-time dip between two pushes. That
  dip is D-G6-01's recorded and accepted consequence, not a rewind defect; Tests J and L assert the
  series property for the ordering where the dip precedes the first push. The reasoning is in K's doc
  comment.
- **Task 2 produced zero source hunks.** The sweep is verification, and its two structural notes —
  compounding and atomicity — were already written into the bracket's doc during Task 1, so there was
  nothing left to edit. `git status` was clean after the Task 1 commit and stayed clean.

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced.

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema change at a trust boundary
was introduced; the change is confined to in-memory session accounting and its two existing
index-write sites.

## What This Does NOT Close

**The SC2 device axis remains open and is NOT claimed.** `15-UAT.md` test 2 still requires a physical
iOS 26 device re-run: the system progress card is rendered outside the app by system UI, and the
scheduler's stall-detection response does not exist in the simulator. Nothing in this plan closes
that item, and a green device run would not have closed G-15-7 either. They are independent axes and
neither discharges the other.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` — FOUND
- Commit `46bf72de` — FOUND
