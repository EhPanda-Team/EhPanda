---
phase: 15-continued-background-downloads
plan: 32
subsystem: downloads
tags: [download-client, log-privacy, invariant-scanner, documentation-correctness, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-26's active-gallery union in schedulableDownloads(), 15-28's DEBUG testing-forwarder seam and the DownloadContinuedSessionTests relocation, 15-30's working-manifest reconciliation refusals plus its blanking notice, and 15-31's schedulingBlockedGalleryCounts refcount with testingBlockScheduling"
provides:
  - "A log-privacy invariant with no unclassified blind spot: every interpolation in a DownloadClient logger call must carry an explicit privacy classification"
  - "expectedHashMaskedCounts: a named per-file inventory of the module's hash-masked interpolations, asserted by equality plus a joined-text total"
  - "resolveSource's gallery URL handled by guard-let-throw (AppError.notFound) instead of a force-unwrap helper"
  - "The unexpected-HTML request URL classified .private explicitly"
  - "A true dedupe rationale on schedulableDownloads() (redundant defence) and a why-still-reachable note on resumeMode's storage.validate branch"
  - "LockedBox: the Mutex-backed test box renamed target-wide, so its name no longer advertises the unchecked-Sendable escape hatch"
  - "First direct coverage of the active-gallery union at the pending-work seam, with a control assertion and a run-verified structural falsifiability claim"
affects: [continued-background-downloads, download-logging, download-scheduling]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An invariant scanner that only matches a written classification is blind to the absence of one: require the classification at every interpolation, not just the forbidden spellings of it"
    - "A threshold assertion pins nothing unless it names what it stands for — a per-file inventory turns every log change into a visible table edit"
    - "Balanced-parenthesis span extraction is what lets a source scan see multi-line log messages and nested calls inside an interpolation"
    - "A union's coverage needs a control assertion that removes the union's input, or the staging can pass for the wrong reason"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
    - "17 further DownloadsFeatureTests files re-spelled by the LockedBox rename"

key-decisions:
  - "15-32: The IN-05 union staging in the plan was FALSE in source and was replaced: a complete record listed in the persisted queue reads displayStatus .queued (displayStatus tests queue membership BEFORE completeness) and shouldSchedule accepts any queued work item, so the planned complete-record control would have read true. The queued remainder is made unschedulable by a live operation's scheduling block (15-31's testingBlockScheduling) instead — a real record, a real production mechanism, and the real predicate."
  - "15-32: The plan's manifest-helper extension (a completedPageCount parameter on writeQueuedManifest) was NOT added, because it existed only to serve that false premise; adding an unused parameter would be dead code."
  - "15-32: The union case's structural falsifiability was not merely asserted in prose — the union was temporarily reverted in source and the case observed failing at exactly its first expectation while the pre-existing case stayed green, then the union was restored."
  - "15-32: resolveSource takes the guard rather than the sibling's `?? payload.host.url` fallback: retargeting a thumbnail request at the host root is a behavior change, and the guard is behavior-identical to the force-unwrap it replaces."
  - "15-32: The no_unchecked_sendable custom rule fires inside doc comments (its excluded_match_kinds omits doccomment), so the LockedBox doc says 'unchecked-Sendable escape hatch' rather than spelling the attribute; no suppression was added."

patterns-established:
  - "RED-first for a scanner: the new check is observed failing on the known blind-spot site BEFORE the site is fixed, so the check is proven to see what the old one could not"
  - "A doc claim about a branch's reachability names the concrete routes that still reach it, each re-derived from source at the HEAD the note is written at"

requirements-completed: []

coverage:
  - id: D1
    description: "WR-06 — resolveSource's gallery URL is handled by a guard that throws the producer's own error, with no force-unwrap helper left in the function"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air' (full plan, ** TEST SUCCEEDED **)"
        status: pass
    human_judgment: false
  - id: D2
    description: "IN-02 — every interpolation in a DownloadClient logger call carries an explicit privacy classification, enforced by a check observed failing on the known unclassified site first"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testEveryDownloadLogInterpolationCarriesAnExplicitPrivacyClassification"
        status: pass
    human_judgment: false
  - id: D3
    description: "IN-03 — the hash-mask count is asserted against a named per-file inventory (plus a joined-text total) rather than a bare lower bound"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testDownloadIdentityLogsStayHashMasked"
        status: pass
    human_judgment: false
  - id: D4
    description: "IN-04 / IN-01 — the dedupe rationale states the true mechanism, and resumeMode's storage.validate branch carries the routes that still reach it"
    verification:
      - kind: static
        ref: "grep -c 'redundant defence' DownloadClient+PendingWork.swift = 1; grep -c 'would double that gallery' = 0; grep -c 'G-15-9' DownloadClient+SchedulingHelpers.swift = 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "IN-05 rename — UncheckedBox is gone from the target and the declaration is LockedBox, with zero behavior change"
    verification:
      - kind: static
        ref: "grep -rc 'UncheckedBox' AppPackage/Tests --include='*.swift' = 0 files; grep -c 'final class LockedBox' DownloadFeatureTestSupportTypes.swift = 1"
        status: pass
    human_judgment: false
  - id: D6
    description: "IN-05 coverage — a schedulable active gallery absent from a non-empty persisted queue is seen by hasPendingWork, with a control assertion isolating the union, verified falsifiable by reverting the union in source"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift#testHasPendingWorkSeesAnActiveGalleryThePersistedQueueLagsBehind"
        status: pass
    human_judgment: false

# Metrics
duration: 50min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 32: G-15-12 Hygiene Closure Summary

**Six confirmed hygiene items closed with evidence: the log-privacy scanner now sees unclassified interpolations (proven RED-first on the one site that had none), the mask count derives from a named per-file inventory including 15-30's blanking notice, two wrong or missing written premises now state what is true in source, the dead force-unwrap became the producer's own guard, and the Mutex-backed test box is `LockedBox` with the active-gallery union covered at its mandated seam.**

## Performance

- **Duration:** ~50 min
- **Commits:** 2 task commits + this docs commit
- **Full FeatureTests run:** `** TEST SUCCEEDED ** [108.541 sec]`, exit 0, single invocation

## The six-item closure table

| Item | Fix | Landed | Evidence |
|------|-----|--------|----------|
| **WR-06** dead force-unwrap in `resolveSource` | `guard let galleryURL = payload.gallery.galleryURL else { throw AppError.notFound }` hoisted above the page-number loop; the request takes the bound value | `DownloadClient+ExecutionSupport.swift`, Task 1 (`2c71852a`) | The extracted `resolveSource` body greps `0` for the helper's name; repository-wide count elsewhere unchanged at 20 |
| **IN-04** false dedupe rationale | Sentence rewritten to redundant defence with the real mechanism named | `DownloadClient+PendingWork.swift`, Task 1 (`2c71852a`) | `grep -c 'redundant defence'` = 1; `grep -c 'would double that gallery'` = 0 |
| **IN-01** unexplained near-dead branch | Why-still-reachable note naming G-15-9's refusal route and the untouched-record route | `DownloadClient+SchedulingHelpers.swift`, Task 1 (`2c71852a`) | `grep -c 'G-15-9'` = 1, inside the comment block directly above the `storage.validate` branch |
| **IN-02** scanner blind spot | Request URL classified `.private`; new scanner check requires an explicit classification at every logger interpolation | `DownloadClient+ResponseValidation.swift` + `DownloadLogPrivacyInvariantTests.swift`, Task 1 (`2c71852a`) | RED output below names the site before the fix; GREEN after |
| **IN-03** underived threshold | `expectedHashMaskedCounts` per-file inventory asserted by equality, plus `expectedHashMaskedTotal` over the joined module text | `DownloadLogPrivacyInvariantTests.swift`, Task 1 (`2c71852a`) | `grep -c 'expectedHashMaskedCounts'` = 2; `grep -c 'maskedCount >= 8'` = 0 |
| **IN-05** misleading name, missing union coverage, file-length headroom | Rename `UncheckedBox` → `LockedBox` across the target; new union case with a control; headroom disposition recorded | `DownloadFeatureTestSupportTypes.swift` + 18 files + `DownloadPendingWorkTests.swift`, Task 2 (`30e3473f`); headroom restored by 15-28 | `grep -rc 'UncheckedBox' AppPackage/Tests` = 0 files; union case passes and was observed failing with the union reverted |

## The scanner RED output (verbatim, before Step 3 classified the site)

```
✘ Test testEveryDownloadLogInterpolationCarriesAnExplicitPrivacyClassification() recorded an issue
  at DownloadLogPrivacyInvariantTests.swift:122:9: Expectation failed:
  (unclassified → ["AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift:
  (requestURL?.absoluteString ?? \"\")"]).isEmpty → false
✘ Test testEveryDownloadLogInterpolationCarriesAnExplicitPrivacyClassification() failed after 0.015 seconds with 1 issue.
✔ Test testNoDownloadLogPublishesGalleryIdentity() passed after 0.027 seconds.
✔ Test testDownloadIdentityLogsStayHashMasked() passed after 0.029 seconds.
```

The two pre-existing checks stayed green through the RED run, and the new inventory check passed
there too — its table was derived from the module as it stood before any classification landed, so
the classification sweep did not move it.

The GREEN run after Steps 2 and 3:

```
✔ Test testEveryDownloadLogInterpolationCarriesAnExplicitPrivacyClassification() passed after 0.012 seconds.
✔ Test testNoDownloadLogPublishesGalleryIdentity() passed after 0.027 seconds.
✔ Test testDownloadIdentityLogsStayHashMasked() passed after 0.028 seconds.
✔ Test run with 3 tests in 1 suite passed after 0.029 seconds.
```

Three `@Test` functions carry the four invariant checks: the forbidden-public check, the new
unclassified check, and the masked-inventory plus operational-message checks that share one test.

## Classification sweep dispositions

The RED run flagged exactly one site across the whole module, so the sweep table has one row. The
count was independently re-derived after the fix with the same balanced-span algorithm, over the
module as committed: **0 unclassified interpolations remain.**

| Site | Interpolated value | Disposition | Why |
|------|--------------------|-------------|-----|
| `DownloadClient+ResponseValidation.swift` unexpected-HTML `logger.error` | `requestURL?.absoluteString ?? ""` | `.private` | A gallery request URL embeds the gallery path — identity-adjacent. `.private` also matches the unified log's default for a dynamic string, so the behavior is unchanged; only the invariant's visibility of it changed |

The sibling `snippet:` interpolation in the same call was already `.private` and was left as it was.

## The hash-masked inventory (IN-03)

| Module file | Masked interpolations |
|-------------|----------------------|
| `DownloadClient+Execution.swift` | 3 |
| `DownloadClient+ExecutionSupport.swift` | 1 — 15-30's working-manifest blanking notice |
| `DownloadClient+Manager.swift` | 1 |
| `DownloadClient+PublicAPI.swift` | 2 |
| `DownloadClient+Scheduling.swift` | 3 |
| **Total** | **10** |

The replaced assertion was a bare `>= 8` lower bound: it had already drifted two sites below the
truth, and 15-30's notice — a log whose entire purpose is to leave a blanking trail in a device
archive — could have been added or removed without moving it.

## The rename inventory (IN-05)

Re-derived at execution time with a whole-target grep. Every file the plan listed as a user was a
user, no file appeared outside the plan's list, and one plan-listed file
(`DownloadPendingWorkTests.swift`) carried no occurrence — it is in the list for the new case only.

| File | Occurrences re-spelled |
|------|-----------------------|
| `FolderManagerReducerTests.swift` | 8 |
| `DownloadInspectorLoadTests.swift` | 7 |
| `DownloadsReducerRefreshTests.swift` | 6 |
| `DetailReducerMetadataTests.swift` | 5 |
| `DownloadObserverReadingTests.swift` | 4 |
| `DownloadsReducerActionTests.swift` | 4 |
| `DetailReducerDownloadTests.swift` | 3 |
| `DetailReducerMetadataUpdateTests.swift` | 3 |
| `DetailReducerPauseAndGuardTests.swift` | 3 |
| `DownloadProcessCacheTests.swift` | 3 |
| `DownloadObserverRefreshTests.swift` | 2 |
| `DownloadProcessTests.swift` | 2 |
| `ReadingReducerDownloadTests.swift` | 2 |
| `DetailReducerObserveTests.swift` | 1 |
| `DownloadAutomationTests.swift` | 1 |
| `DownloadImageParsingTests.swift` | 1 |
| `DownloadInspectorSkipTests.swift` | 1 |
| `ReadingReducerLocalTests.swift` | 1 |
| `DownloadFeatureTestSupportTypes.swift` | 1 (the declaration) |
| **Total** | **58 across 19 files** |

Zero behavior change: the type body, its generic signature, and every call site's semantics are
identical; only the identifier and the declaration's new doc line differ. Historical planning
artifacts that record the old name were deliberately left alone — they are a record of what was
true when they were written.

## The union coverage, and its falsifiability actually run

`testHasPendingWorkSeesAnActiveGalleryThePersistedQueueLagsBehind` stages the state the union
exists for: gid `210401` is the active gallery with **no task installed** (so `hasPendingWork`'s
`activeTask` short-circuit cannot answer) and is **absent from the persisted queue**, while gid
`210402` is queued and held by a live operation's scheduling block. Assertion 1 expects
`hasPendingWork() == true`; the control clears `activeGalleryID` and expects `false`.

The structural claim in its doc comment was verified rather than asserted: the union was
temporarily reverted in `schedulableDownloads()` and the targeted suite re-run.

```
✘ Test testHasPendingWorkSeesAnActiveGalleryThePersistedQueueLagsBehind() recorded an issue
  at DownloadPendingWorkTests.swift:60:9: Expectation failed: await manager.hasPendingWork()
✔ Test testHasPendingWorkReflectsQueueState() passed after 0.052 seconds.
```

Exactly the first expectation failed, the pre-existing case stayed green, and the union was then
restored (`git checkout --` on that one file; the probe was never committed).

## The 999-line headroom disposition

`DownloadContinuedSessionTests.swift` is **596 lines** against the `file_length` ERROR gate of 1000
— 404 lines of headroom, restored structurally by 15-28's relocation of the expiration-and-teardown
family into `DownloadContinuedSessionExpirationTests.swift` (15-28-SUMMARY records the same 596).
This plan added nothing to it: `git diff --stat` across both task commits shows the file untouched.

`wc -l` for every file this plan touched that could approach the gate:

| File | Lines |
|------|-------|
| `DownloadLogPrivacyInvariantTests.swift` | 302 |
| `DownloadFeatureTestSupportTypes.swift` | 591 |
| `DownloadPendingWorkTests.swift` | 86 |
| `DownloadContinuedSessionTests.swift` | 596 (untouched) |

## Verification

- **Task 1 targeted run** — RED (1 failure, the known site) then GREEN (3 tests, 0 failures), one
  invocation each.
- **Task 2 full run** — `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan
  FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air'` →
  `** TEST SUCCEEDED ** [108.541 sec]`, exit 0. The new case passed in 3.275 s.
- **Falsifiability probe** — one further targeted invocation with the union reverted, then restored.
  No two `xcodebuild` invocations ever overlapped.
- **SwiftLint** (DerivedData artifactbundle binary, `--strict`) — 0 violations across
  `AppPackage/Sources/DownloadClient/` and `AppPackage/Tests/DownloadsFeatureTests/`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's union staging rested on a premise that is false in source**

- **Found during:** Task 2, Step 2
- **Issue:** The plan staged the queued remainder as gid `210402` with a **complete** manifest,
  described as "not schedulable". In source it is schedulable: `displayStatus(for:)` tests
  `queueStore.contains(gid)` *before* `record.manifest.isComplete`, so any gid in the persisted
  queue reads `.queued`; `shouldSchedule` returns `true` for `isQueuedWorkItem` regardless of its
  pages. The control assertion would have read `true` and the case would have failed — or, had it
  been written the other way round, passed for the wrong reason. This is the same class of defect
  the plan exists to close.
- **Fix:** The queued record is made unschedulable by a live operation's **scheduling block**
  (`testingBlockScheduling`, 15-31's refcount seam), which is exactly what `isSchedulableDownload`
  tests before it consults `shouldSchedule`. A real record, a real production mechanism, and the
  real predicate — and the control now genuinely isolates the union, as the reverted-union probe
  above proves.
- **Consequence:** the plan's mandated extension of `writeQueuedManifest` (a `completedPageCount`
  parameter) was **not** added — it existed only to stage the complete record the false premise
  called for, and an unused parameter is dead code. The helper is unchanged; the new case calls it
  twice with its existing signature.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift`
- **Commit:** `30e3473f`

**2. [Rule 3 - Blocking] `no_unchecked_sendable` fires inside doc comments**

- **Found during:** Task 2, Step 1 lint gate
- **Issue:** The `LockedBox` doc line explained the rename by naming the banned attribute. The
  custom rule's `excluded_match_kinds` lists `comment` and `string` but **not** `doccomment`, so the
  explanatory doc tripped the rule at error severity.
- **Fix:** Reworded to "the unchecked-Sendable escape hatch this project bans at error severity",
  which carries the same meaning without spelling the attribute. No suppression, no rule change.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift`
- **Commit:** `30e3473f`

## Prohibitions

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No production behavior change beyond the WR-06 guard and the IN-02 classification | held | The other two production edits are comment-only; `git show` for `2c71852a` touches no other executable line, and the full suite is green |
| No case or line added to `DownloadContinuedSessionTests.swift` | held | `git diff --stat` across both commits lists the file zero times |
| Existing privacy invariants not weakened | held | The forbidden-interpolation check and all four operational-message checks are unchanged; the masked check moved from `>= 8` to an equality against a 10-site table |
| No concurrency or lint escape hatch, no SwiftLint suppression, zero occurrences of the old box name | held | `--strict` lint clean; the one lint hit was fixed by rewording, not suppressing; `grep -rc 'UncheckedBox' AppPackage/Tests` returns no non-zero file |

## Known Stubs

None.

## Threat Flags

None. The plan's three registered threats are all mitigated in place: T-15-32-01 by the explicit
classification plus the RED-first scanner check, T-15-32-02 by the named inventory, T-15-32-03 by
the two corrected premises and the guard, each pinned by an acceptance grep above. No file this plan
touched introduced new network, auth, file-access, or schema surface.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift` — FOUND
- Commit `2c71852a` — FOUND
- Commit `30e3473f` — FOUND
