---
phase: 15-continued-background-downloads
reviewed: 2026-08-07T00:00:00Z
depth: standard
files_reviewed: 55
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
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 1
  warning: 4
  info: 0
  total: 5
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-07
**Depth:** standard
**Files Reviewed:** 55
**Status:** issues_found

## Summary

Re-review after round 17 (plans 15-50 … 15-53, commits `ddab4a8d..e9466fa6`). Every finding in the
round-16 report was re-derived against source at HEAD, and all five are **closed**:

- **CR-01 (round-16), the boolean proof unlocking the record's full count.** Closed by
  `provenPageWorkRunPageDebts: [String: Set<Int>]` (`+Manager.swift:631`), the single credited-pages
  definition (`+ContinuedSession.swift:227-236`) that both the opening snapshot (`:165-171`) and the
  departure retirement (`:712-716`) read, the departure freeze (`:258-267`) and the run-exit
  withdrawal of session trust (`+Execution.swift:329-334`). The decrement really does live at
  `flushManifestPageProgress` (`+Persistence.swift:273`) rather than at `flushDownloadProgress`. Two
  of the three consequences the report named are gone; the third — the paused-repair drain —
  terminates at `2 / 2 pages · 0 galleries` under
  `testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid`.
- **WR-01, per-session handler accumulation.** Closed. `registeredIdentifier`
  (`ContinuedProcessingSession.swift:88`) is assigned only on the successful-registration path
  (`:178`), so the throwing-submit arm reuses it and the refused arm re-mints; the split is pinned by
  `testTwoSequentialSessionsRegisterOneIdentifierAndSubmitTwice`,
  `testARefusedRegistrationYieldsUnavailableAndReleasesTheStore` (2 identifiers) and
  `testAThrowingSubmissionYields…` (1 identifier, 2 submissions).
- **WR-02, the atomic `.unavailable` double.** Closed. All three closures open with
  `await Task.yield()` (`DownloadContinuedSessionExpirationTests.swift:428`, `:436`, `:439`), and the
  rule is now censused rather than conventional. See WR-02 below for the one value the census does
  not reach.
- **WR-03, the implicit nil-generation policy.** Closed. `guard let generation else { return true }`
  (`+Execution.swift:363`), with `testAGenerationLessRunRetiresNothingWhileALiveRunOwnsTheSlot` making
  the disposition an executed fact.
- **WR-04, the self-policing prose scanner.** Closed. `DownloadSourceInventoryTests.scannedFiles()`
  excludes itself by path (`:638`, `:646-648`). Note that round-16's WR-04 and the G-15-33 gap record
  both asserted `DownloadLogPrivacyInvariantTests.scannedFiles()` carries "a recorded rationale" for
  its own exclusion. **That premise is false**: `DownloadLogPrivacyInvariantTests.swift:256` has no
  doc comment at all, and `grep -n "second line of defence\|Excluding this file"` over that file
  returns nothing. 15-53's own doc records the correction (`DownloadSourceInventoryTests.swift:617-620`,
  "that function carries no doc comment, so it implements this decision without recording it"), and
  the false claim is not carried forward here.

Mechanical gates re-derived rather than trusted:

- **Censuses.** All seven pinned tables match source. `blockScheduling(` = Folders 2 / PublicAPI 1 /
  Scheduling 1 / Testing 1 = 5; floor writers = ContinuedSession 4 / ExecutionSupport 1 = 5;
  `schedulableDownloads()` = ContinuedSession 2 / PendingWork 1 = 3; `pendingPageIndices(` =
  ExecutionSupport 1; `provenPageWorkRunPageDebts` = ContinuedSession 2 / Execution 1 /
  ExecutionSupport 1 / Manager 1 / Persistence 1 = 6. The two new double censuses also match
  (`updateProgress:` at `DownloadFeatureTestSupportTypes.swift:335` and
  `DownloadContinuedSessionExpirationTests.swift:435`; six `Task.yield()` across the same two files,
  the seventh occurrence being a comment line in `DownloadContinuedSessionRunProofTests.swift:64`
  that `executableLines(in:)` correctly drops).
- **Lint budget.** `awk 'length($0)>120'` returns nothing over all fourteen files round 17 touched;
  the largest is `ContinuedProcessingSessionTests.swift` at 914 lines, under the 1000-line
  `file_length` error limit; no `swiftlint:disable`, `try!`, `@unchecked Sendable` or
  `nonisolated(unsafe)` appears anywhere in `Sources/DownloadClient`,
  `Sources/BackgroundProcessingClient` or `Tests/DownloadsFeatureTests`.

The BLOCKER below is a **regression introduced by 15-50**, and it is the mirror image of the defect
15-50 closed. The debt subtraction is applied only on the complete-reading branch, so the credited
basis is a step function of the record's own count rather than the `max(x - owed, 0)` the function's
own doc claims. For the family whose debt holds pages the record still claims — which is precisely
the refusal family the debt exists for — the credited basis DROPS at the instant the record becomes
complete, and the monotonic floor then absorbs every later page of real work. That is consequence 2
of G-15-30 ("held the numerator at that constant for the whole re-download") reached through
G-15-30's own fix, on the half of the refusal family whose record reads incomplete.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: the credited basis subtracts the run's page debt only on the complete-reading branch, so a refusal repair of an INCOMPLETE record loses credit the moment its record completes and the pushed numerator freezes for the rest of the run

**Classification:** BLOCKER

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:227-236` (the step function)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:199-203` (branch 1's premise, refuted by the refusal family)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:220-226` (the monotonicity premise source contradicts)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:801-805` (the floor that turns the drop into a freeze)
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:642`, `:654`, `:663` (the three refusal exits)
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift:158-166` (out-of-order completion, which makes the drop likely rather than order-dependent)

**Issue:** the credited basis is

```swift
let recorded = min(max(completedPageCount, 0), max(pageCount, 0))
guard recorded >= pageCount else { return recorded }          // INCOMPLETE: raw, nothing subtracted
guard observedIncompleteSessionGIDs.contains(gid) else { return 0 }
return max(recorded - (provenPageWorkRunPageDebts[gid]?.count ?? 0), 0)   // COMPLETE: minus the debt
```

As a function of the record's completed count `x` (page count `N`, debt `d`, trusted) this is

- `f(x) = x` for `x < N`
- `f(N) = max(N - d, 0)`

which is **not** `max(x - owed, 0)` and **not** non-decreasing in `x` whenever `d >= 2`:
`f(N-1) = N-1 > f(N) = N-d`. The function's own doc asserts the opposite in the paragraph that
disposes of D-G7-01 (`:220-226`): "`max(x - owed, 0)` is non-decreasing in `x` and moves by at most
as much as `x` does, so the basis delta can only be smaller than the record delta, never larger." The
premise is written about an expression source does not implement.

Branch 1's stated justification (`:199-203`) is the second half of the same error: "Its own count
already excludes the pages this run has not written — that is what incomplete means — so subtracting
the run's outstanding page debt on top would remove them twice." That is true only when the
reconciliation *blanked* the missing pages. It is exactly false for the refusal family, because a
refusal hands the manifest back verbatim (`+ExecutionSupport.swift:642`, `:654`, `:663`): the record
goes on claiming pages whose files are gone, and the run's pending list is derived from the folder
scan, so the debt and the record's claimed pages OVERLAP. Branch 2 exists for that overlap; branch 1
denies it.

**The production route, taken from an existing fixture.** `DownloadContinuedSessionReconciliationTests`'s
`testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` stages exactly the shape:
a 6-page gallery whose record reads 4 of 6, working folder made execute-only so
`contentsOfDirectory` throws and `scanSucceeded` is false. The reconciliation refuses, the record
stays 4/6, `existingPages` is empty, `pendingPageIndices` is `[1…6]` and the debt is all six pages.
That case asserts the announcement's `4 / 6 pages · 1 gallery` and stops. Continue it:

1. Pages land through `flushDownloadProgress`. `downloadPages` runs `withTaskGroup` with
   `options.workerCount` workers (`+PageDownload.swift:158-166`), so completion order is not the
   ascending index order — any owed page can land at any time.
2. The moment the last page the manifest still recorded as blank lands, the record reaches 6/6 and
   the basis crosses from branch 1 to branch 2. With `d` pages still owed, the gallery's credited
   contribution goes from 5 to `6 - d`. For `d = 4` that is 5 → 2.
3. `pushContinuedSessionProgress` clamps the pushed numerator at `lastPushedCompletedPageCount`
   (`:801-805`), so nothing rewinds — and nothing advances either. The card holds 5 while pages 3, 4
   and 5 of the six download, and only reaches 6 at the very last page.

That is a numerator frozen for most of a re-download, which is the stall reading the doc on
`pushContinuedSessionProgress` and `ContinuedProcessingSession.updateProgress` (`:225-226`) both name
as the liveness hazard: "the scheduler forcibly expires tasks that appear stalled, and prioritises
terminating the ones reporting the least progress", and D-11 turns that expiration into a pause of
every schedulable download. Under pre-15-50 source this same run climbed 5 → 6 monotonically; the
freeze is new.

A departure taken while the basis is in the dip retires the dipped value
(`reconcileRetiredSessionPages`, `:712-716`), and the drain branch's terminal pair is then rescued by
the floor: live `0/0` plus retired `2/2` gives `displayCompletedPageCount == 2`, and
`max(lastPushedCompletedPageCount, 2) == 5` with `max(displayPageCount, 5) == 5`, so a paused repair
that fetched two pages reports `5 / 5 pages · 0 galleries` and `finish(clientSessionID, true)`. The
floor is documented as "residual defence" (`+Manager.swift:473-507`); here it is what converts a
basis drop into an over-reported success.

**Why the 887-test suite does not catch it.** No case lands pages across the incomplete → complete
crossover with a debt of two or more:

- Every refusal-family ledger and run-proof case uses a record that already reads COMPLETE
  (`pageCount: 6, completedPageCount: 6` at `DownloadContinuedSessionLedgerRefusalTests.swift:103`,
  `:230`, `:360`, `:462`, `:559` and `DownloadContinuedSessionRunProofTests.swift:88`, `:213`, `:338`,
  `:455`, `:556`, `:652`), so branch 1 is never entered and no crossover exists.
- The reconciliation refusal cases DO use incomplete records (`completedPageCount: 4` of 6 at
  `DownloadContinuedSessionReconciliationTests.swift:56`, `:148`, `:266`) but assert the manifest and
  the single announcement push; none lands a page afterwards.
- `DownloadContinuedSessionBasisTests`' incomplete-record cases land pages, but their reconciliation
  SUCCEEDS, so the debt is exactly the blanked set and the record cannot complete while any owed page
  remains — `testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes` blanks pages 3 and 4 of
  6 and never returns the gallery to complete at all.
- `testARefusalRepairsIntermediatePushesStrictlyIncrease` is the case written to forbid a frozen
  numerator, and it uses a complete-reading record, so it exercises branch 2 for the whole run and
  never crosses.

**Fix:** make the subtraction apply to both branches over the pages the record actually claims, so
the function is one expression, is monotone in the record's count, and is continuous at the
crossover. The debt and the record are readings of different things (the doc already says so at
`:216-219`), so intersect them instead of gating on the branch:

```swift
/// The pages THIS SESSION may credit one gallery with.
///
/// ONE expression rather than two branches (G-15-3x). Gating the subtraction on the record reading
/// COMPLETE made the basis a step function of that record: a refusal hands the manifest back
/// verbatim, so the debt and the record's claimed pages overlap, and the credited value dropped by
/// `owed - 1` at the instant the last blank page landed. The floor then absorbed every later page
/// of real work — the frozen numerator D-11's expiration policy punishes, reached through the fix
/// for the frozen-at-the-ceiling one.
///
/// The intersection is what keeps branch 1's old premise true where it WAS true: an owed page the
/// manifest does not claim was never in `recorded`, so subtracting it would remove it twice. An
/// owed page the manifest DOES claim is a page the refusal left claimed and this run has not
/// fetched, and it must come off.
func sessionCreditedPages(
    gid: String,
    claimedPages: Set<Int>,
    pageCount: Int
) -> Int {
    let recorded = min(max(claimedPages.count, 0), max(pageCount, 0))
    guard observedIncompleteSessionGIDs.contains(gid) || recorded < pageCount else { return 0 }
    let owedAndClaimed = provenPageWorkRunPageDebts[gid]?.intersection(claimedPages) ?? []
    return max(recorded - owedAndClaimed.count, 0)
}
```

Both existing readers already hold the manifest, so `claimedPages` costs no new read:
`schedulableSnapshot` has `download.manifest`, `freezeSessionCreditForRetiringRun` reads
`downloadIndex[gid]?.manifest` directly, and `reconcileRetiredSessionPages` has the
`DownloadedGallery`. Derive it as `Set(manifest.pages.filter({ !$0.value.isEmpty }).keys)`; note that
this also removes the `recorded` vs `completedPageCount` duplication, since the count of that set IS
`completedPageCount`. Then correct the two written premises at `:199-203` and `:220-226` to state the
rule source implements, and add a case: a refusal over an INCOMPLETE record with a live session, one
blank page landed first and at least two pages still owed, asserting
`expectTheCompletedSeriesNeverRewinds` **and** `Set(numerators).count >= 3` — the series shape
`testARefusalRepairsIntermediatePushesStrictlyIncrease` already uses, which is what fails on a frozen
numerator that a single expected string cannot.

**What would falsify this:** a production route that lowers the debt when the record completes
without the owed pages having been written. Re-derived and there is none. The debt's only decrement
is `flushManifestPageProgress` (`+Persistence.swift:273`), which subtracts exactly the pages
`refreshManifestPageFileHashes` was handed; the only removal is `retireProvenPageWork`
(`+Execution.swift:332`), which runs at the run's exit and not before; and neither
`markContinuedSessionEnded` nor `ensureContinuedSession` touches the collection, which
`testRunScopedPageWorkProofSitesMatchTheRecordedCensus` pins.

### Warnings

#### WR-01: `flushManifestPageProgress`'s "single point every landed page passes" premise is false — `performCacheCapture` records a page hash and re-indexes without lowering the debt

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift:231-239` (the claim)
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:341-345` (the writer that bypasses it)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:212-213` (the census that reinforces the claim)

**Issue:** the decrement's doc argues its own position from an exhaustiveness claim:

> This is the single point every such recording passes: the cadence and forced flushes reach it
> through `flushDownloadProgress`, the restored pages of `initializePageDownloadState` reach it
> directly, and so does a background page landing …

`performCacheCapture` is a fourth recording and does not pass it:

```swift
let manifest = try storage.refreshManifestPageFileHash(
    folderURL: captureTarget.folderURL,
    pageIndex: page,
    relativePath: pageResult.relativePath
)
updateDownloadIndex(folderURL: captureTarget.folderURL, manifest: manifest)
```

It writes a non-empty hash for one page and republishes the index record — the same two effects
`flushManifestPageProgress` has — with no `provenPageWorkRunPageDebts` touch. So while a run of that
gallery is in flight, a reader-side cache capture of one of the run's owed pages raises the record by
one while the debt still counts that page as owed, which is exactly the overlap CR-01 is about, one
page at a time. This route is not hypothetical here: it is the production route
`testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero` documents
(`DownloadContinuedSessionLedgerRefusalTests.swift:332-339`) as the way a still-failed-looking page
comes to have its file on disk.

The drift self-heals — the run still fetches the page, because `pendingPageIndices` was fixed at the
preparation, and that flush decrements — so this is a WARNING rather than a blocker. What makes it
worth fixing is the class: `DownloadSourceInventoryTests`' own header names an unowned inventory as
"the recorded generator of G-15-3, G-15-7, G-15-13 and G-15-19", and
`expectedRunProofSites`' doc leans on this one ("The `+Persistence.swift` entry in particular is
load-bearing as a count of ONE"), so a later fix reasoning from "one decrement point, and every
recording reaches it" reasons from a false premise.

**Fix:** route the capture through the same point, so the claim becomes true by construction rather
than by enumeration:

```swift
// DownloadClient+PublicAPI.swift — performCacheCapture
try flushManifestPageProgress(
    folderURL: captureTarget.folderURL,
    pages: [pageResult]
)
```

`flushManifestPageProgress` already performs the hash refresh and the re-index, so the two lines it
replaces are subsumed; it takes `[PageResult]` and `pageResult` is one. If the single-page
`storage.refreshManifestPageFileHash` overload has no other caller after the change, delete it. Then
`expectedRunProofSites` is unmoved (the decrement stays one site) and the doc's exhaustiveness claim
is enforced by there being no other writer of a page hash at all. If the routing is rejected, the
claim at `:231-239` must be narrowed to name this exception explicitly rather than left standing.

---

#### WR-02: `BackgroundProcessingClient.noop` is an atomic double at the main-actor seam and is the default client for every coordinator built without one, yet the timing census excludes it as a "production surface"

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:92-98`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:269-286` (the exclusion)
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:638` (the coordinator's default)
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:775` (the helper's default)

**Issue:** 15-52's population census states its exclusions:

> Three further values of the type are reachable from this target and none is counted, because none
> is a hand-built double: the macro-synthesized no-argument value … and the module's public `live`
> and `noop` values, which are production surfaces a test census must not demand yields from.

Source contradicts that classification for `noop`. It sits under `// MARK: Test`
(`BackgroundProcessingClient.swift:91`), it is hand-built with all three closures written out, it is
never referenced by `DownloadClient.live` (`DownloadClient.swift:77` passes `.live`), and it is the
DEFAULT of both `DownloadCoordinator.init` and `makeBlockingCoordinator`. It is therefore the double
most download suites actually run against, and it is atomic at all three endpoints:

```swift
public static let noop = Self(
    start: { _, _, _, _ in nil },
    updateProgress: { _, _, _, _ in },
    finish: { _, _ in }
)
```

The exposure is narrower than the `.unavailable` double's but is the same failure mode the spy's
header names. With an atomic `start` returning `nil`, `ensureContinuedSession` reaches its refusal
rollback with no suspension at all, so the ownership re-check that arm opens with
(`+ContinuedSession.swift:350`, "A successor already owning the state must remain untouched") is
certified unreachable in every suite that uses the default; and `pushContinuedSessionProgress`, whose
own doc names its ONE real suspension as the `updateProgress` tail (`:768`), becomes fully
synchronous there. A census whose stated purpose is that "a suite green against it is green about a
world that does not exist" should not carve out the value the majority of the target's coordinators
are constructed with.

**Fix:** open all three of `noop`'s closures with `await Task.yield()` for the reason the spy's and
the `.unavailable` double's carry, and bring it inside the census by counting the client module's own
non-`live` values rather than scoping the population to the test target:

```swift
// BackgroundProcessingClient.swift
// Yields for the reason every double at this seam does: `live` forwards onto a `@MainActor` store,
// so all three endpoints hop off the calling actor. This value is the DEFAULT client of
// `DownloadCoordinator.init`, so an atomic version certifies the start window's re-checks as
// unreachable for every suite that does not pass a client of its own.
public static let noop = Self(
    start: { _, _, _, _ in
        await Task.yield()
        return nil
    },
    updateProgress: { _, _, _, _ in await Task.yield() },
    finish: { _, _ in await Task.yield() }
)
```

and correct `expectedClientDoubleConstructionSites` / `expectedClientDoubleSuspensionSites` and their
docs to state the real rule — every hand-built value of this type except `live`, wherever it lives —
rather than a tree scope that happens to exclude the one in Sources.

---

#### WR-03: `15-SECURITY.md` still records a mitigation 15-51 removed, on a high-severity termination threat

**Classification:** WARNING

**File:** `.planning/phases/15-continued-background-downloads/15-SECURITY.md:32`, `:50`, `:56`

**Issue:** T-15-09 (`Denial of Service (app termination)`, severity `high`, status `closed`) records
its mitigation as:

> A fresh UUID per session guarantees no identifier is ever registered twice … `ContinuedProcessingSession.swift:85-87, 122-125`

15-51 deleted per-session minting. The identifier is minted once per process and re-submitted
(`ContinuedProcessingSession.swift:161-180`), and what now guarantees the uniqueness property is
`registeredIdentifier` being assigned only after a successful `register` (`:178`) plus the reuse
branch (`:162-163`). The recorded mitigation does not describe source, and the threat it closes is
"the system kills the app on a second registration of one identifier" — the one claim in the register
that must not be believed on a stale basis.

Two supporting anchors are stale with it. T-15-03 (`:50`) cites
`ContinuedProcessingSession.swift:125` for the minting; line 125 is now
`let session = BackgroundProcessingSession(id: sessionID, events: stream)` and the mint is at `:165`.
The trust-boundary table (`:32`) describes the crossing datum as "Task identifier (bundle id +
`continued` + UUID)", which is still true of the identifier's SHAPE but no longer conveys that one
identifier now serves every session in the process — the fact the third boundary row (`:34`, "the
system can hand the store a task for a request abandoned long ago") now depends on, since a leftover
launch and a live one carry the same string and `handleLaunch` records that they can no longer be
told apart (`ContinuedProcessingSession.swift:259-280`).

**Fix:** rewrite T-15-09's mitigation to the mechanism source implements, re-anchor T-15-03, and add
the process-scoping to the boundary row:

```markdown
| T-15-09 (15-03/05) | Denial of Service (app termination) | Scheduler registration | high | mitigate | ONE identifier is registered per process and re-submitted for every later session; `registeredIdentifier` is assigned only where `scheduling.register` returned true, so a refused registration re-mints and a throwing submission reuses, and no identifier can be registered twice. The store refuses re-entry before any scheduler touch (`guard task == nil, continuation == nil, !isAwaitingTask`), and the coordinator sets `hasLiveContinuedSession` synchronously before its first suspension point. `ContinuedProcessingSession.swift:88, 119-121, 161-180`; `DownloadClient+ContinuedSession.swift:321-324`. Pinned by `testTwoSequentialSessionsRegisterOneIdentifierAndSubmitTwice`. | closed |
```

and change the boundary row's crossing datum to "Task identifier (bundle id + `continued` + UUID,
minted once per process)".

---

#### WR-04: two constructions of the same `PageResult` array — 15-50's shared helper landed beside the private one it was extracted from

**Classification:** WARNING

**Files:**
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:448-464`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift:682-700`

**Issue:** 15-50 added `pageResults(for:in:indices:)` to the shared helpers on a stated rule — "Shared
rather than file-private, on the rule its former home stated: the surface earns a member when a
second file needs it" — and closes with the reason it is shared: "The relative paths come from the
same production API the writer used, so a naming change moves both together rather than leaving a
flush pointed at a file that is not there."

`landPageFiles(_:of:in:)` still builds the identical value from the identical
`fixture.storage.makePageRelativePath(gid:token:index:fileExtension:)` call, in the file the shared
member was extracted from. It is now literally `writePageFiles` followed by `pageResults`, and it is
the one used by `DownloadContinuedSessionBasisTests`' four flush-and-push cases — so the "moves both
together" guarantee the shared helper was added for does not hold for exactly those cases.

**Fix:** express the private one in terms of the shared one, so a change to the relative-path shape
cannot fork:

```swift
func landPageFiles(
    _ indices: [Int],
    of gallery: SessionGallery,
    in fixture: SessionFixture
) throws -> [DownloadCoordinator.PageResult] {
    try writePageFiles(for: gallery, in: fixture, indices: indices)
    return pageResults(for: gallery, in: fixture, indices: indices)
}
```

---

_Reviewed: 2026-08-07_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
