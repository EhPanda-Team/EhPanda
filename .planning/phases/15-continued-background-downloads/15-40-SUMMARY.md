---
phase: 15-continued-background-downloads
plan: 40
subsystem: downloads
tags: [swift, downloads, documentation, source-census, swift-testing, drift-guard]

requires:
  - phase: 15-continued-background-downloads
    provides: "15-39's carried non-answers across the repair-seed copy — WR-03 and WR-04 sit on the seam it reworked, so both corrections were derived against post-15-39 source"
provides:
  - "Five doc claims re-derived from fresh source enumerations: WR-01 as a rule over commitPause's exit categories, WR-02 as the block-free mobilizer invariant, WR-03 as a per-consumer licensing condition, WR-04 as the residual's true (narrow) reach, IN-01 count-free"
  - "DownloadSourceInventoryTests: the blockScheduling call-site census and the lastPushedCompletedPageCount writer census, per-file equality plus a separately-counted joined total, with a known-member guard"
  - "The floor inventory's re-run-the-grep sentence replaced by a pointer to the census that breaks when the writer set moves"
affects: [15-41, continued-background-downloads verification, SC2, SC3]

tech-stack:
  added: []
  patterns:
    - "Category rules over site counts: a doc states what each OUTCOME class does, so a new exit is covered the moment it picks an outcome"
    - "Every surviving inventory is paired with a source-scanning equality; comment lines are excluded from the scan so correcting a sentence cannot move the number it stands for"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift

key-decisions:
  - "15-40: WR-03 took remedy (a). The gap's own premise was wrong — a fresh enumeration shows four of the seven +Operations sites read a LISTING-derived path, not a manifest-constructed one — and the two genuinely constructed-path routes both throw, so (b) would have changed classification semantics for no consumer."
  - "15-40: WR-04 took remedy (a). The verifier's own detail records the current behaviour as correct; widening the comparison to the blankable population would refuse genuine positive absences because some OTHER page went unanswered, contradicting the per-page rule line 2 states."
  - "15-40: WR-01 and WR-02 are phrased as rules (exit category, block-free mobilizer) rather than as corrected lists, because a corrected list is the shape that drifted."
  - "15-40: The census scanner skips comment lines, so a doc that cites an inventory is not itself part of the inventory it cites."

patterns-established:
  - "Decide-one against a FRESH enumeration, not against the gap record: two of this round's five gap premises did not survive re-derivation"
  - "Falsifiability for a census that asserts current source is demonstrated by mutation of the scan input, recorded bookkeeping-style, rather than by an unavailable honest RED"

requirements-completed: [SC2, SC3]

coverage:
  - id: D1
    description: "The blockScheduling call-site census fails when a site is added or removed, so WR-02's block-free-mobilizer invariant cannot silently rot"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testSchedulingBlockCallSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D2
    description: "The lastPushedCompletedPageCount writer census pins the five-writer inventory the floor doc keeps, in every mutating form"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testFloorWriterAssignmentsMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D3
    description: "No production behavior changed: the whole plan's diff outside the new test file touches no executable line"
    requirement: SC3
    verification:
      - kind: static
        ref: "git diff over both task commits, filtered to non-comment changed lines — empty"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 40: Kill the drift generator behind G-15-20 Summary

**Five doc claims the code contradicted are now derived from fresh source enumerations and phrased as rules rather than counts, and the two inventories that survive in a doc are pinned by `DownloadSourceInventoryTests`, which fails the build when either drifts — so the fifth round of this shape has nothing to grow from.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-05T12:40:00Z
- **Completed:** 2026-08-05T13:01:56Z
- **Tasks:** 2
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- Closed **G-15-20 (warning, promoted)** at all five sites, each correction derived from an enumeration performed at execution time and quoted below beside the sentence it produced.
- **Two of the five gap premises did not survive re-derivation.** WR-03's stated mechanism ("seven call sites pass manifest-constructed paths") is false against post-15-39 source, and WR-04's `suggested_fix` contradicts the verification's own detail. Both are recorded with the trace, and both decisions changed as a result. This is the failure mode the plan was written to interrupt, observed one level up: the gap record describing the drift was itself drifting.
- Paired every surviving inventory with a **drift-failing census** on the `DownloadLogPrivacyInvariantTests` pattern, and replaced the floor doc's "re-run that grep" with a pointer to it.
- **No executable line moved.** The plan licensed exactly one behavior change (WR-04's comparison) conditionally; the trace refused it.

## Task Commits

1. **Task 1: Correct the five claims decide-one each, from fresh source enumerations** — `6aba1457` (docs)
2. **Task 2: Pin every surviving inventory with a drift-failing census test** — `8b57004c` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — **created**, 258 lines (well under the 1000-line gate). Two censuses, per-file equality plus separately-counted joined totals.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — WR-01's category rule, IN-01's count-free aside, the floor doc's census pointer.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — WR-02's invariant-phrased writer statement.
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — WR-03's per-consumer licensing condition on `probeAssetFile`'s existence guard.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — WR-04's residual sentence and the narrowing on the defence's line 3.

---

## The five corrections, each with the enumeration that decided it

### WR-01 — `commitPause`'s convergence ownership

**The enumeration, performed at execution time** over `DownloadClient+Scheduling.swift:215-269` (post-15-39 line numbers), classifying each exit by what it does after `releaseScheduling(gid:)`:

| Exit | Line | Outcome | Converges |
|---|---|---|---|
| Vanished record | `:236` | `.settled(.failure(.notFound))` | INLINE — `notifyObservers()` then `scheduleNextIfNeeded()` |
| Ownership lost before the write | `:242` | `.superseded` | delegates one frame up |
| Wrong display status | `:250` | `.settled(.success(()))` | INLINE |
| Ownership lost after the unbounded wait | `:261` | `.superseded` | delegates one frame up |
| Settled success | `:268` | `.settled(.success(()))` | INLINE |

Five exits: three `.settled`, all converging inline; two `.superseded`, both delegating. The claim "`commitPause` is the one site whose convergence its callers own on every path instead" was false for three of five, and contradicted `commitPause`'s own inline comment at `:227-232`.

**Before** (`+Manager.swift`): "…`commitPause` is the one site whose convergence its callers own on every path instead."

**After:**

> `commitPause` splits that convergence by exit CATEGORY rather than owning all of it or delegating all of it: every `.settled` exit releases and then converges inline, and every `.superseded` exit releases and hands the convergence one frame up to `pause(gid:expiration:)`, which converges on every `.superseded` value it receives. Phrased as a rule over the two outcomes, not as a count of sites: its exits are a set someone will add to, and a new one is covered the moment it picks an outcome, with nothing here to drift out of date.

`grep -c 'site whose convergence'` → **0**.

### WR-02 — `writeSettledPauseRecord`'s writer list

**The enumeration:** grepped `blockScheduling` over `AppPackage/Sources` — five call sites plus one declaration and two doc mentions. Every call site is `commitPause` (`+Scheduling.swift:224`), `delete` (`+PublicAPI.swift:203`), `deleteFolder` (`+Folders.swift:100`), `moveDownload` (`+Folders.swift:177`) and the testing forwarder (`+Testing.swift:129`). None of the five mobilizes the queue — they park, delete or move. Separately, `enqueue(payload:)` (`+PublicAPI.swift:98-100`) calls `advanceQueueIntentGeneration` then `await queueStore.enqueue(...)` with no block, exactly as `resume(gid:)` (`+Scheduling.swift:354-358`) does — so the doc's three-name list was a four-name list.

**Before:** "…which take no scheduling block and so are free to land inside the wait: `performRetry` and `performRetryPages` each set `queuedModes[gid]` and enqueue the gid, and `resume(gid:)` does the same."

**After** (the sentence naming the census, per the acceptance criterion):

> The writers this re-clears are the queue-mobilizing entry points, stated as an invariant rather than as an inventory: NO queue-mobilizing entry point takes a scheduling block, so any of them is free to land inside the unbounded wait above and put back the queue intent this pause has just removed. The invariant holds from the other side — every operation that takes a block parks, deletes or moves a gallery, and none of them mobilizes the queue — which is why `DownloadSourceInventoryTests` pins the `blockScheduling(gid:)` call-site census instead: a mobilizer quietly gaining a block, or a new blocking operation appearing, fails that test. The enumeration this replaces named three such writers and source answered with a fourth, `enqueue(payload:)`, which advances the gid's queue intent and enqueues it exactly as `resume(gid:)` does.

`grep -c 'queue-mobilizing'` → **4** (≥ 1 required). No writer list survives; `enqueue(payload:)` is named as the counter-example that broke the list, not as a new inventory.

### WR-03 — decided **(a)**, and the gap's own premise was wrong

**The post-15-39 caller census.** Nine callers reach `probeAssetFile`, two directly and seven through the collapsing `Bool` forward. Provenance was re-derived per caller rather than taken from the gap text:

| # | Site | Enclosing | Path provenance | What the answer does |
|---|---|---|---|---|
| 1 | `DownloadStore.swift:247` | `pageFileScan` | listing (`existingAssetFileURLs`) | takes the full classification |
| 2 | `DownloadStore.swift:505` | `existingAssetFileURL(in:prefix:)` | listing (the `fileURLs` array) | first-match filter |
| 3 | `+Operations.swift:11` | `linkOrCopyReadableAsset` | caller's: **constructed** for the manifest copy (`:80-83`), listing-derived for the cover (`:92`) and pages (`:110`) | **throws** |
| 4 | `+Operations.swift:91` | repair-seed cover | listing (`existingCoverRelativePath` → `existingCoverFileURL` → `existingAssetFileURL`) | skips the cover copy |
| 5 | `+Operations.swift:105` | repair-seed pre-copy guard | listing (`sourceScan.pages`, post-15-39) | inserts into the carried set |
| 6 | `+Operations.swift:280` | `validPageCount` | listing (`existingPageRelativePaths`) | a count — **no caller in `AppPackage/Sources`** |
| 7 | `+Operations.swift:287` | `isReadableAssetFile` | caller's | **no caller in `AppPackage/Sources`** (one test) |
| 8 | `+Operations.swift:296` | `hashReadableAsset` | listing via `addingCurrentFileHashes` (`:138`); **constructed** via `refreshManifestPageFileHashes` (`:193`) | **throws** |
| 9 | `+Operations.swift:339` | `validatePage` | listing (`existingPageRelativePaths`) | `.missingFiles` → re-fetch |

**The gap's stated mechanism does not survive this.** G-15-20's detail says the seven `+Operations` sites "pass URLs built from a manifest relative path". Four of them (#4, #5, #6, #9) read a path a directory listing just produced — `existingPageRelativePaths` is `pageFileScan(...).pages`, and `pageFileScan` names its files from `existingAssetFileURLs`. Only two ROUTES are genuinely constructed: the manifest copy through #3, and a just-written page file's own relative path through #8 (fed by `flushManifestPageProgress`'s `PageResult.relativePath` and `captureCachedPage`'s `pageResult.relativePath`). Both **throw** on a false answer.

**Decision: (a), restate the comment.** (b) — splitting the probe so constructed-path callers get a positive absence — would change classification semantics for two routes whose only consumer of a false answer is a `throw`, i.e. for no destructive consumer at all, which is scope this warning does not license. The plan's own criterion agrees: (b) is justified "only if the post-15-39 census shows a constructed-path caller whose answer still reaches a destructive decision", and none does.

**Before:** "Not a positive absence. The callers hand this a file a directory listing just produced, so a stat-backed existence check that then denies it is a question left unanswered…"

**After** (the licensing condition made explicit and moved onto the consumer):

> Not a positive absence — for the LISTING-DERIVED callers, which is what this outcome is stated for. `pageFileScan` and `existingAssetFileURL(in:prefix:)` hand this a file an enumeration has just yielded… Two routes construct their path instead of reading it off a listing: the manifest copy in `materializeRepairSeed`, through `linkOrCopyReadableAsset`, and a just-written page file's own relative path, through `hashReadableAsset` from `refreshManifestPageFileHashes`. For those a missing file IS a positive absence, and this function still answers `unprobeable`. The licensing condition is therefore on the consumer rather than on the path: a caller holding a constructed path may keep reading the collapsed `Bool` only while its answer can never reach a decision that destroys recorded state. Both of these throw instead — a recoverable failed operation — and after G-15-19 no caller of the collapsed forward feeds an absence into a destructive decision at all. One that needed to would have to take a classification of its own, through `pageFileScan(folderURL:manifest:)`, rather than read a non-answer this comment has licensed for someone else's callers.

`grep -c 'a directory listing just produced'` → **0**. Consistent with the 15-39 seam: 15-39 established that the collapse's permission belongs to the whole consumer ROUTE, and this comment now states the same rule from the probe's side.

### WR-04 — decided **(a)**, with the trace

**The trace** over `reconcileWorkingManifestAgainstPageFiles` (`+ExecutionSupport.swift:500-536` post-15-39). Writing C for the claimed pages (`manifest.completedPageCount` = `pages.values.filter({ !$0.isEmpty }).count`), P for the claimed pages the scan yielded a file for, U for the claimed pages in `unprobedPages`:

- the loop blanks exactly `B = C \ (P ∪ U)`;
- the guard is `blankedPageCount < manifest.completedPageCount`, i.e. it refuses when `|B| = |C|`, i.e. when `P` and `U` are both empty of claimed pages.

So the residual is unreachable whenever a single claimed page is unprobed — which is what WR-04 confirms.

**Decision: (a), correct the sentence; no executable line moves.** Three pieces of evidence, in the order the plan asks for them:

1. **The verifier's own detail supports (a).** G-15-20 says of WR-04: *"The resulting behaviour is the correct one, so this is a stated-invariant defect, not a wrong outcome."* The `suggested_fix`'s "compare against the blankable population" contradicts that same entry's detail; a `suggested_fix` is a hypothesis, and this one loses to its own record.
2. **(b) would contradict the defence's line 2, not extend it.** In the mixed shape (one claimed page unprobed, K genuinely absent), line 2 has already protected the unprobed page individually. The remaining K are positive absences — "a claimed page whose file a SUCCESSFUL listing simply did not yield" — which the same doc block's closing sentence declares "fully blankable… a scan that finds K of them blanks exactly those K". (b) would refuse all K because ONE other page went unanswered, which is a per-gallery veto replacing a per-page rule.
3. **(b) inverts line 3's own rationale.** Line 3 refuses because the shape is "more likely a shape neither signal above caught". A caught non-answer is evidence the per-file signal WAS answering, so its presence weakens the case for the wholesale refusal rather than triggering it.

The threat register's `T-15-40-03` (taking (b) wrongly and refusing legitimate reconciliations) is mitigated by not taking it.

**Before:** "Only claimed pages are blanked above, so equality here means every one of them would go."

**After:**

> The loop skips every claimed page the scan ACCOUNTED for — one the listing yielded, or one line 2 holds as unprobed — so this equality is reachable only where it accounted for none of them: the residual fires on the shape where a nominally successful listing explains no claimed page at all. On a MIXED shape it deliberately does not fire, and that is not a gap: line 2 has already refused the unprobed portion one page at a time, and the rest is the positive absence this reconciliation exists to record. Widening the comparison to the blankable population would refuse those genuine absences because some OTHER page went unanswered, which is the opposite of the per-page rule line 2 states.

The defence's line-3 bullet gained the matching narrowing (`:483-493`), so the numbered summary and the guard now say the same thing. `grep -c 'every one of them would go'` → **0**. No pinning regression was added to `DownloadCoordinatorRepairSeedTests.swift`, because that file is (b)'s obligation and (b) was not taken; the file is byte-unchanged at 411 lines.

### IN-01 — `continuedSessionTask`'s positional count

**The enumeration:** the nine session-state declarations in `+Manager.swift` are `hasLiveContinuedSession` (`:408`), `continuedSessionID` (`:416`), `continuedClientSessionID` (`:422`), `continuedSessionNeedsReconciliation` (`:430`), `continuedSessionTask` (`:436`), `lastPushedCompletedPageCount` (`:469`), `retiredSessionPages` (`:483`), `observedSchedulablePages` (`:492`), `observedIncompleteSessionGIDs` (`:510`) — pre-edit numbering. Four precede `continuedSessionTask` and four follow; "the eight above" was wrong in both readings (and under the broader "module-internal declarations" reading it is five and four). Every one of them is module-internal.

**Before:** "…which is what keeps this property — like the eight above — module-internal."

**After:**

> …which is what keeps this property module-internal like every other session-state declaration in this section: reaching one of them from a suite would widen its access for the test's sake, so each is reached through a testing forwarder instead. Stated as that rule rather than as a position in the list — an unchecked count is the shape this file has already had to correct.

`grep -c 'like the eight above'` → **0**, and the replacement carries no number.

---

## The two censuses, derived fresh and reconciled

Both tables were derived by enumerating source at execution time, then checked against the docs Task 1 left. Neither disagreed, so no doc needed a second correction.

**`blockScheduling(` call sites** — declaration and comment mentions excluded:

| File | Sites | Which |
|---|---|---|
| `DownloadClient+Folders.swift` | 2 | `deleteFolder(name:)`, `moveDownload(gid:toFolderName:)` |
| `DownloadClient+PublicAPI.swift` | 1 | `delete(gid:)` |
| `DownloadClient+Scheduling.swift` | 1 | `commitPause(gid:expiration:)` |
| `DownloadClient+Testing.swift` | 1 | `testingBlockScheduling(gid:)`, the forwarder |
| **Total** | **5** | matches round 12's enumeration exactly |

**`lastPushedCompletedPageCount` mutations** — declaration and comment mentions excluded, every mutating form counted:

| File | Writers | Which |
|---|---|---|
| `DownloadClient+ContinuedSession.swift` | 4 | session-start reset (`:202`), seed merge (`:242`), teardown zero (`:337`), per-push re-latch (`:610`) |
| `DownloadClient+ExecutionSupport.swift` | 1 | D-G7-01's withdrawal (`:279`) |
| **Total** | **5** | matches the floor doc's five-writer inventory exactly |

The floor doc's closing sentence now reads:

> This list does not ask to be re-grepped: `DownloadSourceInventoryTests` asserts the same census per file and fails the build when a writer is added or removed, which is the difference between an inventory that is owned and one that was true once.

`grep -c 'Re-run that grep'` → **0**; `grep -c 'DownloadSourceInventoryTests'` → **1**.

## Falsifiability bookkeeping

Both censuses assert current source, so an honest RED is not available — the suite passes the moment it compiles. Falsifiability is therefore recorded as the edits that flip each equality, and demonstrated by running the suite's scan logic over mutated copies of the module (a pure-text exercise; no source was committed in a mutated state):

| Mutation | Census effect | Caught by |
|---|---|---|
| A `blockScheduling(gid: gid)` added inside `resume(gid:)` — a mobilizer gaining a block, exactly what WR-02's invariant forbids | block census 5 → 6, `+Scheduling.swift` 1 → 2 | per-file equality AND the joined total |
| A sixth floor writer added in `+ContinuedSession.swift` | floor census 5 → 6, that file 4 → 5 | per-file equality AND the joined total |
| A doc comment merely MENTIONING `blockScheduling(` and a floor assignment | **no change** | the scanner skips comment lines, so correcting a sentence cannot move the number it stands for |
| A vacuous walk (wrong root, empty enumeration) | — | `#require` on the known member `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift`, plus `#require(files.isEmpty == false)` |
| Two same-named files collapsing a table key | — | the joined total is counted over the concatenated text, which cannot collapse |

Detection tokens are assembled from fragments (`"block" + "Scheduling("`, `"lastPushed" + "CompletedPageCount"`, `"func" + " "`, `"var" + " "`), so a repository grep gate counting either inventory cannot match the suite that enforces it.

## Verification

- **Targeted:** `-only-testing:DownloadsFeatureTests/DownloadSourceInventoryTests` → `Test run with 2 tests in 1 suite passed`, `** TEST SUCCEEDED ** [34.155 sec]`.
- **Full:** one `FeatureTests` invocation, whole plan → `** TEST SUCCEEDED ** [89.979 sec]`.
- Invocations were strictly sequential; none overlapped.
- SwiftLint `--strict` over all five touched files: `Found 0 violations, 0 serious in 4 files` (Task 1) and `0 violations… in 2 files` (Task 2). No `swiftlint:disable`, no `@unchecked`, no `@preconcurrency`, no `try?`.

## Prohibitions, checked

| Prohibition | Status | Evidence |
|---|---|---|
| Must NOT change production behavior except WR-04's comparison, and only if the trace supports it | **Held** | The trace refused (b). `git diff` over both commits, filtered to lines that are not comments, is EMPTY outside the new test file — the whole production diff is comment-only |
| Must NOT correct any sentence from the gap record's wording alone | **Held** | Every correction is quoted above beside the enumeration that produced it; two of the five (WR-03, WR-04) reversed the gap's own prescription as a result |
| Must NOT add anything to `DownloadContinuedSessionBasisTests.swift`; WR-04's regression would go in `DownloadCoordinatorRepairSeedTests.swift` | **Held** | Neither file appears in either commit's `--stat`; the basis suite is still 996 lines, the repair-seed suite still 411 |
| Must NOT reach for a concurrency or lint escape hatch or a SwiftLint suppression, and must NOT weaken or delete an existing case | **Held** | Lint clean strict; no test case was edited, weakened or removed; the new file only adds |

## Decisions Made

- **WR-03 → (a)**, because the constructed-path population is two routes rather than seven and both throw. Recorded with the full nine-caller census.
- **WR-04 → (a)**, because the verification's own detail calls the current behaviour correct and (b) would veto per-page positive absences on a per-gallery basis.
- **WR-01 and WR-02 phrased as rules**, not as corrected lists, since a corrected list is the shape that produced this gap.
- **The census scanner ignores comment lines**, so a doc that cites an inventory is not part of the inventory it cites — without this the WR-02 rewrite would itself have moved the number it points at.
- **The floor-doc pointer landed in Task 2's commit**, not Task 1's, so the reference is never dangling. Both tasks' file lists include `+Manager.swift` and Task 2 Step 3 owns this edit explicitly.

## Deviations from Plan

### 1. [Rule 1 — Wrong premise in the gap record] WR-03's stated mechanism is false against post-15-39 source

- **Found during:** Task 1 (the WR-03 re-enumeration)
- **Issue:** G-15-20's detail (and the plan's objective, which transcribes it) states that "seven `sanitizeAssetFileIfNeeded` call sites in `DownloadStore+Operations.swift` pass manifest-constructed paths". Fresh enumeration: four of the seven read a path that a directory listing just produced, via `existingPageRelativePaths` (which IS `pageFileScan(...).pages`) or via `sourceScan.pages`; one more resolves through `existingCoverRelativePath`, also listing-backed. Only two ROUTES are genuinely constructed, and both throw.
- **Fix:** No source change beyond the corrected comment. The census is recorded above, and the correction states what actually holds. This is the plan's own discipline working as intended — it forbids correcting a sentence from the gap's wording, and the gap's wording was wrong.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift` (comment only)
- **Committed in:** `6aba1457`

### 2. [Rule 1 — Wrong premise in a suggested_fix] WR-04's prescribed remedy contradicts its own verification detail

- **Found during:** Task 1 (the WR-04 trace)
- **Issue:** G-15-20's `suggested_fix` says "compare against the blankable population rather than the claimed one"; the same entry's `detail` says "The resulting behaviour is the correct one". The plan anticipated this and made the remedy decide-one on the trace.
- **Fix:** Took (a). The three-part trace is recorded above; the decisive point is that (b) would refuse K genuine positive absences because one OTHER page went unanswered, which inverts the per-page rule the defence's line 2 states and which 15-39 extended across the copy.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` (comment only)
- **Committed in:** `6aba1457`

### 3. [Rule 3 — Blocking] Private-type access on the extension members

- **Found during:** Task 2 (first targeted run)
- **Issue:** `DownloadSourceInventoryTests.swift` failed to compile: members of a `private extension` default to `fileprivate`, so `scannedFiles() -> [ScannedFile]` and `requireKnownMembers(in: [ScannedFile])` exposed the `private` `ScannedFile` type.
- **Fix:** Marked both `private static func`, matching `DownloadLogPrivacyInvariantTests`, which spells the same two members the same way.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- **Committed in:** `8b57004c` (fixed before the task's commit)

---

**Total deviations:** 3 (2 wrong-premise findings in the gap record itself, 1 compile fix).
**Impact on plan:** No scope change. Both premise findings resolved toward the plan's stated default remedy, and both are recorded so 15-41's verifier re-derives rather than trusts.

## Issues Encountered

None beyond the deviations. Note one out-of-scope discovery, deliberately NOT acted on: `validPageCount(folderURL:manifest:)` (`+Operations.swift:271`) and `isReadableAssetFile(at:)` (`:286`) have no caller anywhere in `AppPackage/Sources` — `isReadableAssetFile` has exactly one test consumer and `validPageCount` has none. That is a hygiene item of G-15-21's shape, found while enumerating for WR-03; removing public API is outside a doc-correction plan's licence.

## Threat Flags

None. No network endpoint, auth path, file-access pattern or schema shape is introduced or moved; the production diff is entirely comment text. The register's three threats are dispositioned: `T-15-40-01` mitigated by the rule-phrased corrections plus the `blockScheduling` census, `T-15-40-02` by decisions consistent with the 15-39 seam, `T-15-40-03` by declining (b) on the trace.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **G-15-20 closed.** All five claims read true against enumerations quoted above; both surviving inventories break the build when they drift.
- **Ready for 15-41** (G-15-21, the hygiene group). Two of its neighbours surfaced here and are noted, not taken: the unused `validPageCount` / `isReadableAssetFile` pair.
- **Still outstanding and NOT claimed here:** the physical-device re-run of `15-UAT.md` test 2 on iOS 26. Nothing in this plan changes runtime behavior, so that axis is exactly where 15-39 left it.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- Commit `6aba1457` — FOUND
- Commit `8b57004c` — FOUND

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
