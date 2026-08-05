---
phase: 15-continued-background-downloads
plan: 41
subsystem: downloads
tags: [swift, downloads, hygiene, dead-code, guard-shape, swift-testing, file-length]

requires:
  - phase: 15-continued-background-downloads
    provides: "15-39's rework of the DownloadClient+ExecutionSupport.swift function family IN-04 sits in, and 15-40's doc corrections on the same seam"
provides:
  - "WR-06 closed at the root: the dead `.error` disjunct deleted AND the function renamed to `clearCancellationLikeDownloadErrors`, its one caller swept"
  - "IN-02 closed: buildInspectionPages' three return arms share one indentation column"
  - "IN-03 closed: captureCachedPage carries the G-15-14 guard shape (`pageCount > 0` plus the honest bound), pinned by a new falsifiable case rather than by a recorded derivation"
  - "IN-04 closed: the selection binds straight from `payload.pageSelection`, already `Set<Int>?`"
  - "DownloadContinuedSessionBasisTests.swift split as a proven pure relocation: 996 lines becomes 692 + 342"
affects: [continued-background-downloads verification, SC1, SC2]

tech-stack:
  added: []
  patterns:
    - "A guarded bound over a widened one: `max(count, 1)` silently admits the degenerate input the guard class exists to refuse"
    - "Suite split as an extension of the same suite type, so relocation costs no test identity, no trait and no suite membership"
    - "A doc that quotes the token an acceptance grep counts becomes part of the inventory it describes — reworded, not suppressed"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift

key-decisions:
  - "15-41: WR-06 took BOTH halves of the finding. Deleting the disjunct alone leaves a name promising an `.error` normalization the body never performs, so the function is renamed `clearCancellationLikeDownloadErrors` — precision over the section's `normalize*` prefix symmetry, which the plan's own artifact list offers as the example name."
  - "15-41: IN-03 took the test pin, not the recorded derivation. An existing staging idiom reaches `captureCachedPage` with a zero-page record through two production public functions (`makeInitialManifest` + `updateDownloadIndex`); no seam was added."
  - "15-41: the IN-03 comment was reworded so it does not contain the literal `max(download.pageCount, 1)`. The acceptance grep counts that token, and a doc quoting it makes the doc part of the inventory it describes — 15-40's own lesson, applied one round later."
  - "15-41: the cut line was chosen by helper usage, and the two helpers partition cleanly — `landPageFiles` is used only by cases that stay, `restorePermissions` only by cases that move. Nothing needed promoting to the shared helpers file, which is therefore byte-unchanged."

patterns-established:
  - "Relocation proof by static census against the runner's own total: 867 → 868 @Test attributes pre/post, and the run reports 868 — the split's contribution is provably zero without trusting either number alone"

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "captureCachedPage refuses a zero-page record instead of writing a page file no manifest claims"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testCaptureCachedPageRefusesAZeroPageRecord"
        status: pass
    human_judgment: false
  - id: D2
    description: "The relocated reconciliation family keeps its suite membership and every assertion: all three cases run and pass under the original suite name"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift — testAWholesaleScanFailure…, testAMassPartialProbeFailure…, testAGenuinePartialLoss…"
        status: pass
    human_judgment: false
  - id: D3
    description: "The split moved zero cases: static @Test census delta is exactly Task 1's one added case, and the runner's total agrees with the census"
    requirement: SC2
    verification:
      - kind: static
        ref: "867 @Test at d61f4d45, 868 now, run total 868"
        status: pass
    human_judgment: false

duration: 41min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 41: Close the G-15-21 hygiene group Summary

**The four source hygiene items are closed at their roots rather than papered over — a dead disjunct and the dishonest name above it are both gone, the one page-count site the G-15-14 sweep widened now carries the sweep's own guard shape with a falsifiable pin, and the basis suite is split back to real headroom by a relocation proven byte-identical and count-neutral.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-05T13:10:00Z
- **Completed:** 2026-08-05T13:51:00Z
- **Tasks:** 2
- **Files modified:** 8 (1 created, 7 modified)

## Accomplishments

- Closed **G-15-21 (warning, grouped)** at all four source sites plus the file-length headroom item.
- **IN-03 got a real test instead of a derivation.** The plan permitted recording a static derivation if no staging could reach the site without a production seam. One could: two existing public production functions place a zero-page record in the index, and a staged cache entry makes the pre-fix write observable. The case is genuinely falsifiable rather than vacuously green.
- **Split the basis suite as a proven pure relocation.** Every moved line is byte-identical to its original, verified by `diff` against `HEAD`, and the case count is unchanged — established two independent ways that agree.
- **Caught one drift-generator in my own work** before committing: the IN-03 comment quoted the exact token the acceptance criterion greps for, which would have left the criterion reading `1` and made the doc part of the inventory it described. This is 15-40's recorded lesson recurring one round later, in a fix rather than in a doc.

## Task Commits

1. **Task 1: Close the four source hygiene items at their roots** — `f1cc1723` (fix)
2. **Task 2: Split the basis suite as a pure relocation and restore its headroom** — `23059bd4` (test)

---

## The four items, each with its proof

### WR-06 — both halves taken, and the caller sweep

The finding has two halves and the plan is explicit that both are real: the `displayStatus == .error` disjunct admitted iterations whose body did nothing, AND the name promised an `.error` normalization no line performed. Deleting the disjunct alone would have left the second half standing.

**Before** (`+PersistenceNormalize.swift:32-48`, undocumented):

```swift
public func normalizeNeedsAttentionDownloads(_ downloads: [DownloadedGallery]) async {
    for download in downloads {
        let shouldClearCancellationError = download.lastError.map { … } ?? false
        guard download.displayStatus == .error
                || shouldClearCancellationError else {
            continue
        }
        if shouldClearCancellationError {
            downloadErrors[download.gid] = nil
        }
    }
}
```

**After** — the loop's only guard is `shouldClearCancellationError`, and the `if` that duplicated it is gone with the disjunct:

```swift
public func clearCancellationLikeDownloadErrors(_ downloads: [DownloadedGallery]) async {
    for download in downloads {
        let shouldClearCancellationError =
            download.lastError.map {
                isCancellationLikeAppError($0.appError)
            } ?? false
        guard shouldClearCancellationError else { continue }
        downloadErrors[download.gid] = nil
    }
}
```

**The name.** `clearCancellationLikeDownloadErrors`, the plan's own example. It deliberately does not carry the section's `normalize*` prefix: the sibling `normalizeInterruptedDownloads` genuinely normalizes state (it clears `activeGalleryID`), while this function only clears an error, and prefix symmetry is what let a name drift away from its body in the first place. The doc derives its "why" from `isCancellationLikeAppError`'s semantics, read fresh at `+ResponseValidationHelpers.swift:374-384` — it matches only a `fileOperationFailed` whose reason reads as a cancellation, i.e. interruption residue rather than something the user must attend to. The deleted disjunct is recorded in that doc so the shape cannot be "restored".

**The caller sweep.** A repository grep found exactly two occurrences of the old name: the definition and one call site, `syncDownloadsState` (`+Scheduling.swift:139`). No test referenced it. Both updated.

```
grep -rc 'normalizeNeedsAttentionDownloads' AppPackage  →  sums to 0
grep -rn 'clearCancellationLikeDownloadErrors' AppPackage
  +PersistenceNormalize.swift:43   (definition)
  +Scheduling.swift:139            (the one former call site)
```

### IN-02 — the three arms line up

`buildInspectionPages`' `if let failedPage` arm returned four spaces deeper than its two siblings. Re-indented; nothing else in the function moved. The three `return .init(` arms now share one column (`:18` region, `:34-42`, `:44-50` pre-edit numbering):

```swift
                if fileManager.operate({ … }) {
                    return .init(          // arm 1 — nested one level deeper by its own `if`
            if let failedPage = failedPages[page] {
                return .init(              // arm 2 — now level with arm 3
            return .init(                  // arm 3 — the fallthrough
```

Arms 2 and 3 are the two siblings the finding names; arm 1 sits inside an extra `if fileManager.operate` and is correctly one level in.

### IN-03 — guarded, not widened, and pinned

**Before:** `index <= max(download.pageCount, 1)`. For a record claiming zero pages that reads `index <= 1`, so index 1 was **admitted**.

**After:**

```swift
guard let download = await fetchDownload(gid: gid),
      download.pageCount > 0,
      index >= 1,
      index <= download.pageCount
else { return }
```

This is exactly the shape the seven G-15-14 range sites carry — `buildInspectionPages` (`+PublicAPIHelpers.swift:17`) and `pendingPageIndices` (`+ExecutionSupport.swift:737`) both open with `guard … pageCount > 0`. The class-tying comment sits above it and records the upstream closures (`enqueue`'s zero-page refusal at `+PublicAPI.swift:73`, `validateDecodedManifest`'s empty-page rejection at `DownloadStore.swift:548`) as the reason this is defence in depth rather than a live defect.

```
grep -c 'max(download.pageCount, 1)' …/DownloadClient+PublicAPI.swift  →  0
```

**The pin decision: a test case, not a recorded derivation.** The plan made this conditional on whether an existing staging idiom could reach `captureCachedPage` with a zero-page record without a production seam. It can, through two functions production itself uses:

- `makeInitialManifest(payload:)` returns `pages: [:]` for a zero-page payload — the existing suite already asserts this at `testDownloadPagesWithAZeroPagePayloadCompletesWithoutTrapping`.
- `updateDownloadIndex(folderURL:manifest:)` (`+Persistence.swift:250`, `public`) is the index writer every production capture and flush publishes through. `writeInitialManifest` and `performCacheCapture` both call it.

`fetchDownload` then answers with a record whose `pageCount` is `pages.count`, i.e. zero. No test-only seam was added, and `DownloadClient+Testing.swift` was not touched.

The case is falsifiable rather than vacuous: a restorable cache entry is staged deliberately, because `restorePageFromCache` returns `nil` without one and the case would pass for a reason unrelated to the bound. With it staged, the pre-fix path reaches `write(data:to:)` (`+Cache.swift:75`) and lands `<gid>_token_1.jpg` in the folder — the unclaimed write the gap describes. The case asserts the folder is empty afterwards. It is `testCaptureCachedPageRefusesAZeroPageRecord`, and it passed in the full run.

### IN-04 — the redundant rebuild is gone

`payload.pageSelection` is declared `Set<Int>?` at `AppModels/Download/DownloadedGallery+Extensions.swift:30`, confirmed by reading the declaration rather than the gap text. The binding keeps its name and the `Set`-membership use below is unchanged:

```swift
let selectedIndices = payload.pageSelection
```

```
grep -c 'pageSelection.map(Set.init)' …/DownloadClient+ExecutionSupport.swift  →  0
```

### The Task 1 diff, stated from `git diff`

Five source files, and only the four named functions plus the one WR-06 call site:

| File | What changed |
|---|---|
| `+PersistenceNormalize.swift` | WR-06: rename, disjunct deleted, doc added |
| `+Scheduling.swift` | WR-06: the single call site, one line |
| `+PublicAPIHelpers.swift` | IN-02: indentation only, 7 lines |
| `+PublicAPI.swift` | IN-03: the guard and its comment |
| `+ExecutionSupport.swift` | IN-04: one line |

Plus `DownloadZeroPagePayloadTests.swift`, the IN-03 pin (see the deviation below on why this file is not in the plan's `files_modified`).

---

## The split, proven a relocation

### The cut, chosen by helper usage

The plan named the reconciliation/probe-defence family as the expected cluster and required confirming it against actual helper usage. It confirmed exactly, and the two file-private helpers partition with no overlap at all:

| Helper | Used by cases that STAY | Used by cases that MOVE | Disposition |
|---|---|---|---|
| `landPageFiles(_:of:in:)` | 14 references | 0 | Stays in the basis file |
| `restorePermissions(at:to:)` | 0 | 3 references | Travels into the new file |

Neither is referenced anywhere else in the test target (grepped over `AppPackage/Tests/DownloadsFeatureTests`). **Nothing needed promoting**, so `DownloadFeatureTestHelpers.swift` is byte-unchanged and appears in neither commit — consistent with 15-39, which deliberately avoided promoting this same `restorePermissions` and wrote its own batched `restoreOriginalModes` instead. No helper exists twice.

### The moved cases

All three moved into `DownloadContinuedSessionReconciliationTests.swift` as `extension DownloadContinuedSessionBasisTests`, which declares no suite of its own:

| Moved case | Topic | Body |
|---|---|---|
| `testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` | G-15-9, directory-level non-answer | unchanged |
| `testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing` | G-15-13, per-file non-answer | unchanged |
| `testAGenuinePartialLossBlanksExactlyTheMissingPages` | the genuine-absence companion | unchanged |

"Unchanged" is asserted mechanically, not by eye. The 292 moved lines were extracted from `HEAD` by line range and diffed against their new location:

```
diff <(git show HEAD:…BasisTests.swift | sed -n '657,948p') <(sed -n '29,320p' …ReconciliationTests.swift)
  →  IDENTICAL: the 292 moved lines are byte-for-byte the original
diff <(git show HEAD:…BasisTests.swift | sed -n '980,995p') <(…the new file's helper block)
  →  IDENTICAL: restorePermissions moved byte-for-byte
```

The retained region is equally untouched. `git diff -U0` on the basis file shows exactly four hunks: six added header lines, one changed header line, the 293-line deletion, and the 17-line helper deletion. Nothing else. Both retained blocks diffed clean against `HEAD` at their shifted offsets.

Every moved case keeps its production-issued choreography verbatim — each still pins `spy.progressUpdates.count == 1` so the pair it reads is the announcement's own push, and the `0o311` / `0o000` mode staging and `PartialProbeFailureFileManager` double are untouched. No push was converted from production-issued to hand-issued, because no line changed.

### The count proof, two ways that agree

15-40's summary records `** TEST SUCCEEDED **` but no numeric total, so the baseline was re-derived rather than quoted:

| Measure | Pre-plan (`d61f4d45`) | Now | Delta |
|---|---|---|---|
| Static `@Test` census over `AppPackage/Tests` | 867 | 868 | **+1** |
| Runner's summed `Test run with N tests` | — | 868 | — |

The static census and the runner's own total agree exactly at 868, and the delta from before this plan is **+1** — precisely Task 1's zero-page pin. **The split contributed zero.** Neither number is trusted alone: the census could miss a parameterized expansion, the runner's total could hide a silently skipped case, and their agreement rules out both.

### Headroom restored

| File | Before | After |
|---|---|---|
| `DownloadContinuedSessionBasisTests.swift` | 996 | **692** |
| `DownloadContinuedSessionReconciliationTests.swift` | — | **342** |

Both are well under the plan's ~850 target and far from the 1000-line `file_length` error gate. Each file's header now states which half of the charter it holds and points at the other; both keep the choreography-discipline paragraph, since cases in both rely on it.

## Verification

- **Full `FeatureTests`, one invocation, whole plan:** `** TEST SUCCEEDED ** [96.631 sec]`, exit `0`. **868 tests, zero failures** across every target. No `xcodebuild` invocation overlapped another and none was killed.
- `✔ Suite DownloadContinuedSessionBasisTests passed` — one suite, holding cases from both files, which is the identity preservation the extension buys.
- `✔ Test testCaptureCachedPageRefusesAZeroPageRecord() passed` alongside all three moved cases.
- SwiftLint `--strict` over every touched file: `Found 0 violations, 0 serious`. No `swiftlint:disable`, no `@unchecked`, no `@preconcurrency`, no `try?`, no concurrency escape hatch.

## Prohibitions, checked

| Prohibition | Status | Evidence |
|---|---|---|
| Must NOT rewrite, restage, weaken or drop any moved case | **Held** | `diff` against `HEAD` reports the 292 moved lines byte-identical; count delta is +1 and attributable to Task 1 alone |
| Must NOT change `captureCachedPage`'s behavior for any currently reachable input | **Held** | The new guard refuses only `pageCount == 0`, which `enqueue` and `validateDecodedManifest` both close upstream; for every `pageCount > 0` record the bound `index <= download.pageCount` is what the old expression already evaluated to. The derivation is recorded in the source comment |
| Must NOT leave a caller on the old WR-06 name, or keep the dead disjunct under the new name | **Held** | Old-name grep sums to 0 across `AppPackage`; the loop's only guard is `shouldClearCancellationError` |
| Must NOT reach for a concurrency or lint escape hatch or a SwiftLint suppression | **Held** | Lint clean strict over all eight files |

## Decisions Made

- **WR-06 took both halves and a non-family name.** Recorded above with the reasoning: prefix symmetry is what allowed the drift.
- **IN-03 took the test pin over the recorded derivation**, because the staging turned out to exist. The two enabling functions and the falsifiability argument are recorded.
- **The IN-03 comment does not quote the old expression.** See the deviation below.
- **No helper promotion.** The partition is clean, so `DownloadFeatureTestHelpers.swift` stays byte-unchanged.

## Deviations from Plan

### 1. [Rule 2 — Missing critical property] The IN-03 comment quoted the token its own acceptance grep counts

- **Found during:** Task 1, running the acceptance greps before committing
- **Issue:** My first draft of the class-tying comment wrote the old bound verbatim as `max(download.pageCount, 1)` to explain what changed. The acceptance criterion is `grep -c 'max(download.pageCount, 1)' … outputs 0`, and it read `1`. The code was correct; the doc had made itself a member of the inventory it described.
- **Fix:** Reworded to "the upper bound used to raise that count to a floor of one instead of guarding it", which says the same thing and carries no matching token. Re-ran the grep: `0`.
- **Why this is worth recording:** it is exactly 15-40's own finding ("the census scanner skips comment lines, so a doc that cites an inventory is not itself part of the inventory it cites") recurring one round later in a *fix* rather than in a doc. A grep-based gate and a doc that quotes the grep's needle cannot both be honest.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift`
- **Committed in:** `f1cc1723` (corrected before the task's commit)

### 2. [Rule 2 — Artifact not in `files_modified`] The IN-03 pin lands in `DownloadZeroPagePayloadTests.swift`

- **Found during:** Task 1
- **Issue:** The plan's frontmatter `files_modified` lists only the four sources and the three Task 2 test files, but Task 1's action directs the pin into `DownloadZeroPagePayloadTests.swift` ("add the case there") if the staging exists. The action text and the file list disagree.
- **Fix:** Followed the action text, since the file list is written for the case where the derivation is recorded instead. The file gained one case and three imports (`AppTools`, `ComposableArchitecture`, `UIKit`), all `sorted_imports`-clean, mirroring `DownloadCoordinatorCaptureTests.swift`'s idiom for staging a restorable cache entry with a per-test `DataCache` rather than the shared one.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift`
- **Committed in:** `f1cc1723`

### 3. [Process slip, no impact] A `git stash`/`git stash pop` round trip while measuring the baseline census

- **Found during:** Task 2, deriving the pre-plan `@Test` count
- **Issue:** I wrapped a `git grep` against an old ref in a `stash`/`pop` pair out of misplaced caution. The stash list is shared across worktrees and the pair is explicitly forbidden by the executor's own rules; it happened to be a no-op here (nothing was stashed, `git stash list` is empty, the working tree verified intact immediately afterwards) only because the ref-scoped `git grep` never needed a clean tree.
- **Fix:** Verified `git stash list` empty and both files' line counts and modification state unchanged, then measured with plain `git grep <ref>` and `grep` over the working tree, which is what the measurement needed all along.
- **Files modified:** none
- **Committed in:** n/a

---

**Total deviations:** 3 (1 self-caught drift generator, 1 plan-internal inconsistency resolved toward the action text, 1 process slip with no effect).
**Impact on plan:** No scope change. The plan's four items and the split all landed as specified, and IN-03 landed on the stronger of its two permitted outcomes.

## Issues Encountered

None beyond the deviations. Two out-of-scope discoveries 15-40 logged — `validPageCount(folderURL:manifest:)` and `isReadableAssetFile(at:)` having no caller in `AppPackage/Sources` — were **deliberately not touched**, as this plan's scope note requires; neither file's dead-function region appears in either commit.

## Threat Flags

None. No network endpoint, auth path, file-access pattern or schema shape is introduced or moved. The register's three threats are dispositioned: `T-15-41-01` mitigated by the guard shape plus the new pin, `T-15-41-02` by the extension-based move with byte-identical bodies and an unchanged count, `T-15-41-03` by deleting the dead disjunct and renaming the function so there is no lost branch to "restore".

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **G-15-21 closed.** All four source items fixed at their roots with greps and quotes recorded, and the headroom item resolved with both files far from the gate.
- **Both suite files have room again**, which is what the next round's regressions needed: 692 and 342 lines against a 1000-line limit.
- **Still outstanding and NOT claimed here:** the physical-device re-run of `15-UAT.md` test 2 on iOS 26. Nothing in this plan changes runtime behavior on any reachable input, so that axis sits exactly where 15-39 and 15-40 left it.
- **Noted for a future round, still untaken:** the unused `validPageCount` / `isReadableAssetFile` pair, and WR-05's `waitForTaskValue` default, which round 12 judged fixable only at the helper's default for all seven call sites.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- Commit `f1cc1723` — FOUND
- Commit `23059bd4` — FOUND

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
</content>
</invoke>
