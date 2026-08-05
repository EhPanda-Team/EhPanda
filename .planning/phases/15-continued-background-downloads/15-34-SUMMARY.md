---
phase: 15-continued-background-downloads
plan: 34
subsystem: downloads
tags: [swift, swift-testing, download-client, closed-range, liveness, gap-closure]

requires:
  - phase: 15-continued-background-downloads
    provides: "The continued-processing session and the deleted discretionary background tier, which is what turns a process trap into lost work with nothing left to resume it"
provides:
  - "Every `1...pageCount` range in DownloadClient is guarded against a zero-page upstream parse"
  - "A deliberate zero-page disposition at both entrances (D-G14-01): enqueue refuses, a mid-run refetch settles as a visible failed download"
  - "DownloadZeroPagePayloadTests — four cases pinning the range sites and the enqueue refusal"
affects: [download-execution, download-enqueue, download-inspector, phase-15-verification]

tech-stack:
  added: []
  patterns:
    - "Zero-page range-site guard: a page-count range is either guarded or replaced by comparison, module-wide with no exceptions"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift

key-decisions:
  - "D-G14-01 (first half): a zero-page payload is refused at enqueue with .notFound, ahead of every folder and queue mutation — a queue entry no run can finish is a standing liveness hazard now that the discretionary background tier is gone."
  - "D-G14-01 (second half): a zero-page freshly fetched detail throws .notFound at fetchLatestPayload's existing guard boundary, so the run's established catch settles the download as FAILED rather than no-opping into a 0-of-0 record that would read complete."
  - "The RED-first step was deliberately replaced by a static derivation: a pre-fix run TRAPS rather than fails, and a killed/wedged xcodebuild test invocation wedges testmanagerd on this machine (recorded project memory)."
  - "The guard invariant is stated and implemented as the WHOLE class — all four remaining unguarded page-count range sites in the module were swept, not just the two the gap named."

patterns-established:
  - "Class-scoped gap closure: when a fix's comment states a module-wide invariant, every site of that class is swept in the same plan so the comment is derivable in source rather than aspirational."

requirements-completed: []

coverage:
  - id: D1
    description: "pendingPageIndices returns an empty array for a zero-page payload, on both the plain and the page-selection branch, instead of trapping on an invalid ClosedRange"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testPendingPageIndicesOfAZeroPagePayloadIsEmpty"
        status: pass
    human_judgment: false
  - id: D2
    description: "downloadPages completes with an empty batch result for a zero-page payload, driving initializePageDownloadState's guarded index-list construction through the public entry point"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testDownloadPagesWithAZeroPagePayloadCompletesWithoutTrapping"
        status: pass
    human_judgment: false
  - id: D3
    description: "The two swept sibling range sites — normalizeFetchedPayload's page-selection validation and buildInspectionPages' page enumeration — answer empty for a zero-page input"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testTheModulesOtherPageCountRangeSitesAnswerEmptyForAZeroPagePayload"
        status: pass
    human_judgment: false
  - id: D4
    description: "enqueue refuses a zero-page payload with .failure(.notFound) and commits nothing — no index record, no queue entry (D-G14-01)"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testEnqueueRejectsAZeroPagePayload"
        status: pass
    human_judgment: false
  - id: D5
    description: "A zero-page mid-run refetch throws .notFound at fetchLatestPayload and settles the download as failed through the run's existing catch chain (D-G14-01)"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (full run, TEST SUCCEEDED — the catch chain itself is traced in source below, not re-staged)"
        status: pass
    human_judgment: true
    rationale: "The throw's disposition is proven by source tracing (fetchNormalizeAndDownload → processDownload catch → handleProcessDownloadError → handleProcessDownloadAppError → persistFailure → settleDownloadFailure), not by a case that stages a zero-page HTTP detail response. A verifier should confirm the traced chain rather than accept it from the summary."

duration: 12min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 34: Zero-Page Payload Guards Summary

**A gallery whose freshly fetched detail parses with no pages now fails the download visibly instead of trapping the process on `1...0`, and the zero-page disposition is decided at both entrances rather than silently no-opped.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-05T07:28:58Z
- **Completed:** 2026-08-05T07:41:00Z
- **Tasks:** 2
- **Files modified:** 5 (4 modified, 1 created)

## Accomplishments

- **Both range sites the gap named are guarded**, and neither can build an invalid `ClosedRange` from an upstream page count any more.
- **The disposition is decided, not defaulted (D-G14-01).** `enqueue` refuses a zero-page payload before any folder or queue mutation; a zero-page refetch mid-run throws at `fetchLatestPayload`'s existing guard boundary so the run's established catch settles the download as failed.
- **The invariant was swept to its whole class.** Two further unguarded page-count ranges in the same module were closed in the same pass, so the comment "no range in this module is built from an unguarded page count" is derivable in source rather than aspirational.
- **Four zero-page cases** drive the public entry points and pass; the full FeatureTests run is green with no positive-count behavior change.

## Task Commits

1. **Task 1: Guard both range sites and cover them with zero-page cases** — `2e790c68` (fix)
2. **Task 2: Decide the zero-page disposition at both entrances (D-G14-01)** — `9c6298e6` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — `pendingPageIndices` returns `[]` ahead of the range and ahead of the selection branch.
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` — `initializePageDownloadState` builds its index list conditionally, in `makeInitialManifest`'s shape.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — `enqueue` refuses a zero-page payload with `.failure(.notFound)` (D-G14-01).
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` — `fetchLatestPayload` throws `AppError.notFound` for a zero-page detail (D-G14-01); `normalizeFetchedPayload` validates a page selection by comparison instead of by building a range.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift` — `buildInspectionPages` guards the record's page count.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift` — new four-case suite (183 lines), with the RED-first deviation recorded in its suite doc.

## The Guards, Quoted

`pendingPageIndices` (`DownloadClient+ExecutionSupport.swift`), the empty-payload return ahead of the range:

```swift
    ) -> [Int] {
        // G-15-14. The invariant is the whole class, not this site: no range in this module is
        // built from an unguarded page count. `makeInitialManifest` and `reusableExistingManifest`
        // already branch on the same value, so zero is a modeled input here too — and `1...0` is an
        // invalid ClosedRange that traps the process rather than failing the download. The guard
        // sits ahead of the selection branch because a selected page cannot rescue a range that
        // never formed.
        guard payload.galleryDetail.pageCount > 0 else { return [] }
        let selectedIndices = payload.pageSelection.map(Set.init)
        return (1...payload.galleryDetail.pageCount).filter { page in
```

`initializePageDownloadState` (`DownloadClient+PageDownload.swift`) — no unconditional range construction remains; the rest of the body runs unchanged over an empty index list, so no input reaches a different tail than before:

```swift
        let pageCount = context.payload.galleryDetail.pageCount
        let pageIndices = pageCount > 0 ? Array(1...pageCount) : []
        collectExistingPages(
            pageIndices: pageIndices,
            ...
        )
        progress.completedCount = progress.results.count
        guard progress.completedCount > 0 else { return }
```

`enqueue` (`DownloadClient+PublicAPI.swift`), sitting at line 73 — ahead of `try storage.ensureRootDirectory()` at line 75 and therefore ahead of every folder and queue mutation:

```swift
    ) async -> Result<Void, AppError> {
        guard payload.galleryDetail.pageCount > 0 else { return .failure(.notFound) }
        do {
            try storage.ensureRootDirectory()
```

`fetchLatestPayload` (`DownloadClient+ExecutionFetch.swift`), joining the missing-gallery-URL guard at one boundary:

```swift
        let detail = detailResponse.galleryDetail
        // D-G14-01, the mid-run half: ...
        guard detail.pageCount > 0 else { throw AppError.notFound }
```

## The Catch Chain, Traced in Source

The zero-page throw needs no new plumbing; it rides the mechanism the missing-gallery-URL guard eight lines above already uses. Each hop was read in source at this HEAD, not asserted from memory:

1. `fetchLatestPayload` throws `AppError.notFound` (`DownloadClient+ExecutionFetch.swift:23`).
2. `fetchNormalizeAndDownload` propagates it — the call is `try await` with no local catch (`DownloadClient+Execution.swift:138`).
3. `processDownload`'s `catch` receives it (`DownloadClient+Execution.swift:44`); the `catch is CancellationError` arm above does not match.
4. `handleProcessDownloadError` routes it (`DownloadClient+Execution.swift:50`).
5. `handleProcessDownloadAppError` takes the `error as? AppError` branch (`DownloadClient+Execution.swift:104-108`), passes `isCancellationLikeAppError` (which is `false` for `.notFound` — it matches only `.fileOperationFailed` carrying a cancellation reason, `DownloadClient+ResponseValidationHelpers.swift:374-384`), logs with the hash-masked gid, and calls `persistFailure` (`:179`).
6. `persistFailure` calls `settleDownloadFailure(gid:error:)` (`DownloadClient+Persistence.swift:171`).
7. `settleDownloadFailure` records `downloadErrors[gid] = DownloadFailure(error: error)`, clears the queue intent and removes the gid from the queue store (`DownloadClient+Persistence.swift:177-181`).

The result is a visible failed download the user can retry — never a 0-of-0 record that reads complete.

## Decisions Made

- **D-G14-01, both halves**, as recorded in the frontmatter and named at both sites in source.
- **The RED-first step was replaced by a static derivation**, recorded in the suite doc where the cases live rather than skipped quietly. Pre-fix, all four cases would TRAP (an invalid-`ClosedRange` precondition kills the runner process), and a wedged `testmanagerd` costs a host reboot on this machine. The falsifiability evidence is the pre-fix expressions quoted against the module's own zero-page branches in `makeInitialManifest` and `reusableExistingManifest`, which establish zero as a modeled input, plus post-fix GREEN.
- **The empty case in `initializePageDownloadState` is a conditional construction, not an early return.** An early return would have skipped `progress.completedCount = progress.results.count`, making behavior-identity depend on the caller always passing a fresh `PageDownloadProgress`. The conditional list needs no such argument.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Two further unguarded page-count ranges in the same module**

- **Found during:** Task 1, while grepping `1\.\.\.` across `AppPackage/Sources/DownloadClient/` to confirm the plan's two sites were the complete class.
- **Issue:** The plan mandates that each guard's comment state the invariant as the WHOLE class ("no range in this module is built from an unguarded page count"). Two more sites contradicted that:
  - `normalizeFetchedPayload` — `.filter({ (1...payload.galleryDetail.pageCount).contains($0) })` (`DownloadClient+ExecutionFetch.swift:151` pre-fix). Reached whenever a selective download carries a non-nil raw page selection; the range is constructed inside the filter and traps before `contains` is ever consulted.
  - `buildInspectionPages` — `(1...download.pageCount).map { … }` (`DownloadClient+PublicAPIHelpers.swift:12` pre-fix). A record's page count is `manifest.pages.count`; `validateDecodedManifest` rejects an empty page dictionary so no manifest read from disk can be zero, but `writeInitialManifest` indexes the in-memory `makeInitialManifest` result directly, and the function is `public`.
  Leaving these would have made the new comments provably false in source — exactly the failure shape G-15-15 records for this phase (doc comments asserting what source does not support).
- **Fix:** `normalizeFetchedPayload` now validates by comparison (`$0 >= 1 && $0 <= pageCount`), so no range exists there to be invalid; the predicate is identical for every positive count. `buildInspectionPages` gained `guard download.pageCount > 0 else { return [] }`. Both carry a comment naming G-15-14 and their place in the class.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift`, `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift`
- **Verification:** `testTheModulesOtherPageCountRangeSitesAnswerEmptyForAZeroPagePayload` drives both; full FeatureTests run green.
- **Committed in:** `2e790c68` (part of the Task 1 commit)

**Sweep result.** `grep -rn '1\.\.\.' AppPackage/Sources/DownloadClient/` now returns seven sites, and every one is guarded: `makeInitialManifest` and `reusableExistingManifest` (pre-existing ternaries), `validateDecodedManifest` (its `guard manifest.pages.isEmpty == false` sits two lines above the range), and the four closed here. The class has no exceptions left, so the comments are derivable.

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical functionality)
**Impact on plan:** No scope creep beyond the invariant the plan itself mandates be stated as a whole class. Zero behavior change for any positive page count, and both added guards are in files the plan already lists or in the same module's sibling helper.

## Prohibition Status

| Prohibition | Status | Evidence |
|---|---|---|
| No silent no-op for a zero-page run | satisfied | The mid-run disposition is `settleDownloadFailure`, traced hop-by-hop above. |
| No behavior change for any positive page count | satisfied | Every guard is a `> 0` branch or an equivalent comparison; full FeatureTests run `TEST SUCCEEDED`, including the enqueue, retry and scheduling suites. |
| No deliberately trapping test run | satisfied | No pre-fix run was staged; the derivation is static and recorded in the suite doc. One `xcodebuild test` invocation at a time throughout. |
| No concurrency/lint escape hatch, no SwiftLint suppression, no new suspension | satisfied | No `swiftlint:disable`, `@unchecked`, `@preconcurrency` or `try?` added; the build's SwiftLint plugin reported zero violations. Every added guard is a synchronous check inside an existing function — no previously synchronous tail gained an `await`. |

## Issues Encountered

Two simulators share the name "iPhone Air" on this host, which makes the plan's `name=iPhone Air` destination ambiguous. Runs used the explicit device id instead; the scheme, test plan and `-only-testing` selector are otherwise exactly as planned.

## Test Runs

- Targeted (Task 1): 3 cases, `TEST SUCCEEDED` (33.7 s).
- Targeted (Task 2): 4 cases, `TEST SUCCEEDED` (37.7 s).
- Full FeatureTests: `TEST SUCCEEDED` (61.5 s), single invocation, zero failures.

`wc -l` for every edited file, all far below the 1000-line gate: ExecutionSupport 712, PageDownload 344, PublicAPI 382, ExecutionFetch 187, PublicAPIHelpers 65, DownloadZeroPagePayloadTests 183.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

G-15-14 is closed: both named range sites are guarded and covered, the two sibling sites of the same class are swept, both entrance dispositions are decided and named D-G14-01 at their sites, and the settling path is traced in source.

Remaining for this phase: G-15-15..G-15-18 (warning groups, plans 15-35..15-38), then re-verification. The 15-UAT.md test 2 physical-device re-run on iOS 26 remains an independent, unclaimed item — with G-15-13 (15-33) and G-15-14 (this plan) now landed, its precondition is met.

## Self-Check: PASSED

- Created file present: `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift`
- Modified files present, including the swept sibling `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift`
- Commits present in history: `2e790c68`, `9c6298e6`
- No absolute home paths recorded in this document

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
