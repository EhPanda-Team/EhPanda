---
phase: 15-continued-background-downloads
reviewed: 2026-08-05T00:00:00Z
depth: standard
files_reviewed: 47
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 1
  warning: 6
  info: 5
  total: 12
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 47
**Status:** issues_found

## Summary

The tree at HEAD is in good mechanical shape. I re-verified the project gates rather than trusting the
prior report: no reviewed file exceeds the 1000-line `file_length` error threshold (largest is
`DownloadContinuedSessionBasisTests.swift` at 996), no reviewed file has a line over the 120-character
limit, no banned API spelling (`try?`, `@unchecked Sendable`, `nonisolated(unsafe)`, `NSLock`,
`@preconcurrency`) appears anywhere in scope, `BGTaskScheduler` is named in exactly one file
(`ContinuedTaskScheduling.swift`), and the hash-masked log inventory that
`DownloadLogPrivacyInvariantTests` asserts by equality matches source exactly (3/1/1/2/3, total 10).
The `continued_session.subtitle` catalog entry satisfies the project's labeled-substitution and
plural-category rules (`en`/`de` category sets match, CJK locales are `other`-only, all six locales
present). `ContinuedProcessingSession`'s post-WR-08 identity ordering, its adoption/stray gate, and its
`endSession` take-back all hold up under adversarial tracing, and `ContinuedProcessingSessionTests`
covers every arm of them.

The material finding is a genuine hole in this round's headline fix. D-G13-01 is stated as absolute — a
per-file probe's non-answer is never authority to destroy a recorded hash — and
`reconcileWorkingManifestAgainstPageFiles` honours it *within one folder*. But the repair-seed
materialization path launders an unprobeable page in the **source** folder into a positive absence in
the **destination** folder, after which the reconciliation blanks it, rewrites the manifest,
re-publishes the record and withdraws from the monotonic floor. That is exactly the G-15-13 failure
mode reached through the one branch the fix was not traced across, and it is the recurring
branch-scoped-reasoning defect this phase keeps producing.

Beyond that, the round's doc-comment rewrites carry several claims source does not satisfy. The review
brief asked for these specifically, and there are four: `commitPause`'s convergence ownership claim,
`writeSettledPauseRecord`'s three-writer enumeration, `probeAssetFile`'s "the callers hand this a file a
directory listing just produced" premise, and the all-or-nothing guard's "equality here means every one
of them would go". None of them is cosmetic: each states an invariant a future reader would rely on
when deciding whether a new call site is safe, and each is the shape of premise that produced G-15-6,
G-15-7 and G-15-13.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: The repair-seed materialization converts an unprobeable source page into a positively-absent destination page, so D-G13-01's "a non-answer never destroys a recorded hash" does not hold across the seed copy

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:296-341`, `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:475-511`, `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:63-74`, `AppPackage/Sources/DownloadClient/DownloadStore.swift:191-244`

**Issue:**

`reconcileWorkingManifestAgainstPageFiles` defends line 2 (`unprobedPages`) only against the scan of the
folder it is reconciling. The `.repair` route can reach it with a **different** folder than the one whose
probe failed, and the conversion in between is lossy in the wrong direction:

1. `prepareWorkingSeed` → `setupWorkingFolder` (line 562). For `.repair`, `shouldReuseWorkingFolder`
   returns `true`, so nothing is deleted; but when the payload's computed folder path does not exist —
   the ordinary upstream-title-change re-slot, which `DownloadCoordinatorRepairSeedTests
   .testRepairSeedReusesCompletedFilesWhenPageCountMatches` already exercises — the `!fileExists`
   branch calls `storage.materializeRepairSeed(from: seed.folderURL, manifest:, to: folderURL)`.
2. `materializeRepairSeed` (`DownloadStore+Operations.swift:63-74`) selects pages through
   `existingPageRelativePaths(folderURL: sourceFolderURL, …)`, which is the **collapsed** probe
   (`DownloadStore.swift:196-198`): it returns `pageFileScan(...).pages` and discards
   `unprobedPages` entirely. It then re-probes with `sanitizeAssetFileIfNeeded(at: sourcePageURL)`
   (line 72), whose `Bool` forward is `false` for `.unprobeable` as well as `.rejected`. An unprobeable
   source page is therefore **not copied**. The manifest, however, is copied whole (lines 47-50), still
   claiming that page's hash.
3. Back in `prepareWorkingSeed`, `ensureWorkingManifest` finds a valid manifest at the destination
   (gid and `pageCount` both match the payload) and returns it verbatim.
4. `storage.pageFileScan(folderURL: destinationFolder, manifest:)` now lists a folder that genuinely
   does not contain that page's file. That is a **positive absence** — `scanSucceeded == true`,
   `unprobedPages` empty — so line 1 and line 2 of the defence both pass it through.
5. `reconcileWorkingManifestAgainstPageFiles` blanks the hash (line 489), writes the manifest
   (line 498), re-indexes (line 499), and the enclosing `withdrawingCountedBasisMovement` bracket
   subtracts the counted portion from `lastPushedCompletedPageCount` — "for a movement that never
   physically happened, and irreversibly", in the exact words the G-15-13 case doc uses.

The all-or-nothing residual (line 494) does not catch it: it only fires when *every* claimed page would
go, and the trigger class G-15-13 was narrowed to is explicitly "many-but-not-all files".

The doc on `reconcileWorkingManifestAgainstPageFiles` names this route and classifies it as safe —
"the repair-seed materialization, which copies only the pages whose source files existed **and passed
sanitization** while copying the manifest whole" (lines 403-404) — but "passed sanitization" is precisely
where `.unprobeable` and `.rejected` are conflated back together, one layer below where the round-12 fix
separated them. `PageFileScan`'s own doc (`DownloadStore.swift:59-63`) asserts that "every
non-destructive caller is entitled to collapse both pairs — a probe that finds nothing re-fetches, which
is harmless either way"; `materializeRepairSeed` is classified as such a caller and is not one, because
its output feeds a destructive decision one step later.

**Fix:** carry the source scan's `unprobedPages` through the copy so the destination reconciliation
cannot read them as absences. The minimal shape is to refuse the seed when the source could not answer
for every claimed page, so no non-answer is ever re-derived as an absence:

```swift
// DownloadStore+Operations.swift
public func materializeRepairSeed(
    from sourceFolderURL: URL,
    manifest: DownloadManifest,
    to destinationFolderURL: URL
) throws {
    let sourceScan = pageFileScan(folderURL: sourceFolderURL, manifest: manifest)
    // A page the SOURCE probe could not classify is not copied, so the destination listing would
    // report it as a positive absence and the working-seed reconciliation would blank its hash
    // (D-G13-01: a non-answer is never authority to destroy recorded state). Refuse the seed
    // rather than materialize a folder that launders the non-answer.
    guard sourceScan.scanSucceeded, sourceScan.unprobedPages.isEmpty else {
        throw AppError.fileOperationFailed(
            String(localized: .RLocalizable.downloadStoreManifestCorrupted)
        )
    }
    …
}
```

with `repairSeed(for:payload:)` (or `setupWorkingFolder`) treating the refusal as "no seed", so the run
falls back to `createDirectory(at: folderURL)` and re-fetches — the accepted cost the defence already
documents. A test belongs beside
`DownloadContinuedSessionBasisTests.testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing`,
staged the same way (`PartialProbeFailureFileManager` plus real `0o000` modes) but with a
`makeStartPayload(for:mode: .repair)` whose title differs from the fixture folder, so `setupWorkingFolder`
takes the materialization branch.

### Warnings

#### WR-01: `commitPause`'s convergence contract is documented as "callers own it on every path"; source converges inline on three of five exits

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:380-385`, `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:215-269`

**Issue:** the `schedulingBlockedGalleryCounts` doc states: "Every operation that blocks pairs each of
its exits with exactly one `releaseScheduling(gid:)` followed by convergence (`notifyObservers()` then
`scheduleNextIfNeeded()`); `commitPause` is the one site whose convergence **its callers own on every
path** instead." Source disagrees on three of `commitPause`'s five exits — the vanished-record exit
(Scheduling.swift:233-236), the wrong-status exit (247-250) and the settled-success exit (264-268) all
call `notifyObservers()` and `scheduleNextIfNeeded()` themselves, and `pause(gid:expiration:)`'s
`.settled` arm adds nothing. Only the two `.superseded` exits (241-242, 260-261) delegate upward.
A reader adding a sixth exit and trusting the stated rule would omit convergence and reproduce G-15-8 at
the one site the rule was written to describe.

**Fix:** state the actual split, e.g. "`commitPause` converges inline on every `.settled` exit and hands
convergence to `pause(gid:expiration:)` on its two `.superseded` exits, which is the only place the rule
is one frame up."

#### WR-02: `writeSettledPauseRecord`'s enumeration of interleaving writers is incomplete — `enqueue(payload:)` is a fourth

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:304-326`, `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:70-120`

**Issue:** the doc says "The writers this re-clears are the queue-mobilizing entry points, which take no
scheduling block and so are free to land inside the wait: `performRetry` and `performRetryPages` each set
`queuedModes[gid]` and enqueue the gid, and `resume(gid:)` does the same." `enqueue(payload:)` also takes
no scheduling block, also calls `advanceQueueIntentGeneration` and `await queueStore.enqueue(...)`
(PublicAPI.swift:99-100), and is reachable from a user tap while a pause is parked on
`await taskToCancel?.value`. Its enqueue is re-cleared by this function exactly as the other three are,
so behaviour is fine — but the *enumeration* is the artefact a future edit would reason from, and a
three-item list that source answers with four is the recorded shape of G-15-7 (a written premise naming
one mover while source held four).

**Fix:** add `enqueue(payload:)` to the list, or replace the enumeration with the invariant it stands in
for: "every queue-mobilizing entry point takes no scheduling block, so any of them can land inside the
wait; this re-clear is what makes an explicit pause win regardless of which one did."

#### WR-03: `probeAssetFile`'s existence-guard rationale is false for its public `sanitizeAssetFileIfNeeded` callers, which pass constructed paths

**File:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:691-696`, `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:11,58,72,242,249,258,301`

**Issue:** the guard's comment justifies returning `.unprobeable` on a failed `fileExists` with: "The
callers hand this a file a directory listing just produced, so a stat-backed existence check that then
denies it is a question left unanswered — a positive absence is a claimed page whose file the successful
listing never yielded, and that page never reaches this function at all." That holds for `pageFileScan`
and for `existingAssetFileURL(in:prefix:)`, and for nothing else. `sanitizeAssetFileIfNeeded` is
`public`, and seven call sites in `DownloadStore+Operations.swift` hand it URLs built from a manifest
relative path (`linkOrCopyReadableAsset`'s `sourceURL`, `hashReadableAsset`'s `fileURL`,
`isReadableAssetFile`, `validatePage`, `validPageCount`, both `materializeRepairSeed` sites). For those, a
missing file is a *positive* absence and is now classified as the one outcome the enum exists to mark as
"never authority to destroy state". Behaviour is unchanged today because the `Bool` forward collapses
both, but the enum's own stated purpose — "a new exit cannot default into 'positively absent': it has to
be named" (lines 663-665) — is inverted here: a genuine absence silently defaults into `unprobeable`, and
the first consumer to take the classification through a non-listing path inherits it.

**Fix:** either restate the comment to say the classification is meaningful only for listing-derived
URLs and that `sanitizeAssetFileIfNeeded`'s other callers must keep using the `Bool` forward, or split
the probe so a caller that knows its path is constructed gets `.rejected` for a missing file:

```swift
private func probeAssetFile(at url: URL, wasListed: Bool) -> AssetFileProbeOutcome {
    guard fileManager.operate({ $0.fileExists(atPath: url.path) }) else {
        // A listing-derived path that then fails a stat is an unanswered question; a caller-built
        // path that does not exist is a positive absence.
        return wasListed ? .unprobeable : .rejected
    }
    …
}
```

#### WR-04: the all-or-nothing residual guard is structurally unreachable whenever any claimed page is unprobed, and its comment says otherwise

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:492-494`

**Issue:**

```swift
guard blankedPageCount > 0 else { return manifest }
// Only claimed pages are blanked above, so equality here means every one of them would go.
guard blankedPageCount < manifest.completedPageCount else { return manifest }
```

The comment was true before `unprobedPages` existed. It is not true now: the blanking loop (lines 484-491)
excludes every page in `pageFileScan.unprobedPages`, so the maximum reachable `blankedPageCount` is
`completedPageCount − |unprobed ∩ claimed|`. With even one unprobed claimed page the equality can never
be reached, and line 3 of the documented three-line defence — described at lines 458-462 as "the residual
second line" that fires "when a nominally successful listing … would nonetheless blank every claimed
page" — is silently disabled for exactly the mixed population. The resulting behaviour happens to be the
more correct one (the absent pages really are absent), so this is a stated-invariant defect rather than a
wrong outcome; but the doc is what a future reader will use to decide whether line 3 still protects them.

**Fix:** compare against the blankable population rather than the claimed one, and correct the comment:

```swift
let blankablePageCount = manifest.completedPageCount - manifest.pages.keys.filter({
    pageFileScan.unprobedPages.contains($0) && manifest.pages[$0]?.isEmpty == false
}).count
// Only claimed, probed pages are blanked above, so equality here means every one of them would go.
guard blankedPageCount < blankablePageCount else { return manifest }
```

#### WR-05: two convergence suites gate on a 1-second deadline the repository has already recorded as insufficient under CI

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift:90-94`, `AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift:113-117`, `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:717-730`

**Issue:** both cases await an observer-collector `Task` through
`waitForTaskValue(…, timeout: .seconds(1))`. The value they wait for is produced by an unstructured
`Task` consuming an `AsyncStream`, so the deadline bounds *scheduler latency*, not the work. The same
helper file carries the repository's own recorded lesson on `waitUntil`: "One second did not survive CI,
where the whole target's suites run in parallel and a task can sit unscheduled far longer than the work
itself takes" — and uses 10 seconds. Every other deadline in the phase (`expireSession`, the interleave
suite, the expiration suite) uses 10 seconds. These two are the outliers, and a timeout here surfaces as
a hard failure (`waitForTaskValue` throws), not a retry.

**Fix:** raise both to `.seconds(10)`, matching `waitUntil` and every other call site in the phase. The
deadline still costs nothing on a healthy run because `waitForTaskValue` returns as soon as the collector
yields.

#### WR-06: `normalizeNeedsAttentionDownloads` carries a guard disjunct that can never affect the outcome

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:32-48`

**Issue:**

```swift
guard download.displayStatus == .error
        || shouldClearCancellationError else {
    continue
}
if shouldClearCancellationError {
    downloadErrors[download.gid] = nil
}
```

When `displayStatus == .error` and `shouldClearCancellationError == false`, the guard admits the
iteration and the body does nothing. The function is therefore exactly equivalent to
`if shouldClearCancellationError { downloadErrors[gid] = nil }`. A dead disjunct in a
"needs attention" normalizer reads as an intentional error-status branch that was lost, which is the
worst kind of dead code: it invites a future edit to "restore" behaviour that was never there. It also
makes the function's name promise more than it delivers — nothing about `.error` records is normalized.

**Fix:** delete the disjunct and let the loop say what it does, or rename the function to match:

```swift
for download in downloads {
    guard let lastError = download.lastError,
          isCancellationLikeAppError(lastError.appError)
    else { continue }
    downloadErrors[download.gid] = nil
}
```

### Info

#### IN-01: `continuedSessionTask`'s doc says "like the eight above"; only four of the nine session-state declarations precede it

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:431-436`

**Issue:** the property doc reads "which is what keeps this property — like the eight above —
module-internal". Counting the internal session-state declarations in the type: `hasLiveContinuedSession`
(408), `continuedSessionID` (416), `continuedClientSessionID` (422),
`continuedSessionNeedsReconciliation` (430) sit above it; `lastPushedCompletedPageCount` (469),
`retiredSessionPages` (483), `observedSchedulablePages` (492) and `observedIncompleteSessionGIDs` (510)
sit below. Nine total, four above. A positional claim that is wrong is small on its own, but this file's
other inventory (the five writers of `lastPushedCompletedPageCount`, lines 440-456) is load-bearing and
correct, which makes an adjacent incorrect one actively misleading.

**Fix:** "like the other eight".

#### IN-02: mis-indented branch in `buildInspectionPages`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift:34-42`

**Issue:** the `if let failedPage = failedPages[page]` branch's `return .init(…)` and its arguments are
indented four spaces deeper than the surrounding `if let relativePath` and trailing `return` branches,
so the three arms of what is a single three-way selection do not line up. No lint rule catches it
(`indentation_width` is not opt-in here and `opening_brace` is disabled), which is why it survived.

**Fix:** re-indent the block to match the sibling arms at lines 19-32 and 44-50.

#### IN-03: `captureCachedPage`'s page bound uses `max(pageCount, 1)`, the one page-count site the G-15-14 sweep widened rather than guarded

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:280-289`

**Issue:** every other page-count site in the module now refuses zero explicitly (`pendingPageIndices`,
`initializePageDownloadState`, `buildInspectionPages`, `makeInitialManifest`, `reusableExistingManifest`,
`normalizeFetchedPayload`, `enqueue`, `fetchLatestPayload`). This one instead *admits* index 1 for a
zero-page record via `index <= max(download.pageCount, 1)`. Reachability is now closed upstream — a
zero-page payload cannot be enqueued and `validateDecodedManifest` rejects an empty page dictionary — so
this is latent, but it is the odd site out: it would write a page file into the gallery folder that no
manifest claims (`refreshManifestPageFileHashes` skips it at its `pages[page] != nil` guard), leaving an
orphan asset invisible to `pageFileScan`.

**Fix:** `guard download.pageCount > 0, index >= 1, index <= download.pageCount else { return }`, with a
one-line comment tying it to the same G-15-14 class as the seven range sites.

#### IN-04: redundant `Set` re-wrap of an already-`Set` page selection

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:695`

**Issue:** `payload.pageSelection` is declared `Set<Int>?`
(`AppModels/Download/DownloadedGallery+Extensions.swift:30`), so `payload.pageSelection.map(Set.init)`
builds a second identical `Set` on every call. Harmless, but it reads as a conversion and invites the
reader to look for the `[Int]` it is converting from.

**Fix:** `let selectedIndices = payload.pageSelection`.

#### IN-05: doc-comment mass on private helpers now exceeds implementation by 2-3x, and the drift found above is its direct cost

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:384-475`, `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:68-121`, `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:532-578`, `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:170-212`

**Issue:** `reconcileWorkingManifestAgainstPageFiles` carries 91 lines of doc for a 36-line private body;
`pushContinuedSessionProgress` 46 for 46; the `.superseded` arm of `pause(gid:expiration:)` holds a
34-line inline comment around five statements. The project's "document deliberate designs" convention is
being honoured, but at this density the prose is no longer verifiable by reading the adjacent code — five
of this review's findings (CR-01, WR-01, WR-02, WR-03, WR-04) are prose that source stopped satisfying,
and every one of them lives in a comment of this size. The bodies themselves are clean.

**Fix:** move the historical narrative (which gap produced which rule, what the superseded attempts were)
out of the source doc and into the phase's decision record, and keep at the call site only the invariant
plus the one sentence saying what breaks if it is violated. Where an inventory is genuinely load-bearing
— the five writers of `lastPushedCompletedPageCount`, the audited-safe callers of
`existingAssetFileURL` — prefer a test that fails when the inventory drifts (the pattern
`DownloadLogPrivacyInvariantTests.expectedHashMaskedCounts` already establishes) over a comment that asks
the reader to re-run a grep.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
