---
phase: 15-continued-background-downloads
reviewed: 2026-08-10T02:57:36Z
depth: standard
files_reviewed: 69
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppModels/Download/DownloadInspection.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
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
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorStorageTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreHashTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 3
  warning: 5
  info: 2
  total: 10
status: issues_found
---

# Phase 15: Code Review Report (re-review after gap-closure plans 15-61 … 15-64)

**Reviewed:** 2026-08-10T02:57:36Z
**Depth:** standard
**Files Reviewed:** 69
**Status:** issues_found

## Summary

Scrutiny was concentrated on `git diff 782013eb..HEAD` (the four gap-closure fixes) with a normal
standard-depth pass over the unchanged remainder.

**Verdict on the four prior BLOCKERs:**

| ID | Verdict | Notes |
| --- | --- | --- |
| CR-01 (validation deletes before the guard) | **Partly closed — sibling paths still delete on a read** | The `validateImageData` route is genuinely fixed at its root: `storage.validate`, the presence scan and `blankingPass` all pass `discardingRejected: false`, rejected pages carry a file identity, and removal happens strictly after the combined wholesale guard. The reachable `.rejected` deletion that reconciles nothing now lives on `loadManifest` / `sanitizeLocalFilesIfNeeded` / `resumeMode` instead — see **CR-03** below. Two behavioral seams the fix opened are **WR-01** and **WR-02**. |
| CR-02 (stale observation credits a redo) | **Closed at its root, but the fix introduces a new defect** | Generation-stamped observation is the right mechanism and every one of the four queue-mobilizing entry points does advance before its snapshot. But the generation advance is now an unbracketed downward mover of the credited basis, which the monotonic floor then masks — see **CR-01** below. |
| CR-03 (rename source path traversal) | **Closed at its root for `renameFolder`; the sibling `deleteFolder` was not swept** | `DownloadStore.renameUserFolder` + `confinedDirectUserFolderURL` is a solid boundary (lexical parent, resolved parent, single component, normalization-identity, re-checked inside the `operate` closure, symlink source rejected by `attributesOfItem`), and the argument-driven escape suite is thorough. `deleteFolder(name:)` still builds its URL from an unconfined, unnormalized caller name — see **CR-02** below. |
| CR-04 (invalid page selection widens to a whole-gallery repair) | **Closed at its root** | The `retryPages` domain filter precedes every mutation (verified line by line against `performRetryPages`' writes), and `normalizeFetchedPayload` now preserves an explicit-but-empty selection so `pendingPageIndices` cannot reinterpret it. Two consequences of the narrowing are unhandled at the callers — **WR-04**, **WR-05**. |

Lint posture on the delta is clean: no file exceeds 1000 lines, no line exceeds 120 characters, no
`swiftlint:disable`, no `try?`, no force unwraps, `private let logger` present in every logging file
touched. The 15-64 `waitForTaskValue` deadline change was verified to alter no assertion (all six
removals are argument-only). The 15-62 "fourth guard clause is strictly a strengthening" claim and
the "every pre-existing caller is byte for byte unchanged" claim were both **refuted** — WR-01 and
WR-02.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01 [BLOCKER]: The CR-02 fix moves a downward basis movement outside every D-G7-01 bracket, so the stale monotonic floor absorbs the redo's real progress

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:245`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:37`,
`AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:117`,
`AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:360`,
`AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:106-108`,
`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:769-771`,
`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:941-945`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:273-286`

**Issue:** `advanceQueueIntentGeneration(for:)` is now a *deliberate downward mover of the session
accounting basis*, and none of its four call sites is wrapped in `withdrawingCountedBasisMovement`.

Trace the CR-02 scenario the new test stages (gallery A, 4 pages, keeper B holding the session open):

1. A is observed incomplete at generation 0, finishes its four pages, departs. The reconcile retires
   it: `retiredSessionPages["A"] = 4`. A push latches `lastPushedCompletedPageCount = 4`.
2. The user re-queues A. `performRetry` advances the generation to 1 (`RetryHelpers.swift:37`),
   unbracketed.
3. On the next push, `sessionCreditedPages` now returns **0** for A (line 245: observation stamped 0,
   current generation 1), and `reconcileRetiredSessionPages` drops A's ledger entry because A is back
   in `finishedPages` (line 770). The summed numerator therefore falls by 4 in one step.
4. `lastPushedCompletedPageCount` is still 4. The redo's later run announces a basis, so
   `prepareWorkingSeed`'s bracket measures `creditedBefore == creditedAfter == 0` and withdraws
   nothing (`ExecutionSupport.swift:277-284`).

The floor is now permanently four pages above the honest sum for the rest of the session. Every one
of the next four pages of *genuine* work — A's or the keeper's — produces no movement on the card.
That is exactly the failure mode the file's own doc calls out as G-15-6/G-15-7 ("the credit for every
later page of real work is absorbed until the summed numerator climbs back over the pre-movement
total"), and it is the signal `ContinuedTaskScheduling`'s expiration policy reads to decide which
task is most stalled. It also falsifies the invariant restated at `ContinuedSession.swift:236`: "No
regime boundary can therefore drop the credited count on its own; deliberate movers are bracketed."

Before the fix this movement was bracketed by accident: the credited value stayed at 4 across the
re-queue (the bug) and fell to 0 inside `prepareWorkingSeed`'s bracket, which withdrew exactly 4. The
fix moved the drop earlier without moving the withdrawal with it.

The new test cannot see this. Its own doc records the reason — "The monotonic floor holds the
numerator at the four pages A really did finish, so the re-queue's own push … discriminates nothing"
— and it then lands **six** keeper pages in a single flush specifically to clear the floor in one
jump. Landing them one at a time would show the first four producing a frozen card.

`enqueue(payload:)` has the same shape with an extra twist: `writeInitialManifest`'s bracket
(`PublicAPI.swift:143`) closes at line 157, and the generation advances at line 107 — *after* it — so
that bracket measures both endpoints under the old generation and can never see this drop either.

**Fix:** Wrap the advance itself, so the withdrawal is measured across exactly the movement:

```swift
public func advanceQueueIntentGeneration(for gid: String) {
    withdrawingCountedBasisMovement(gid: gid) {
        queueIntentGenerations[gid, default: 0] += 1
    }
}
```

`withdrawingCountedBasisMovement` is already `rethrows`/non-async and reads
`sessionCreditedPages(gid:)` on both sides, which is precisely the quantity that steps from `recorded`
to `0` here; it is a no-op (delta zero) for every gallery whose record reads incomplete or that has a
live basis, so the three other call sites cost nothing. Add a regression case that lands the keeper's
pages **one at a time** across the re-queue and asserts the pushed numerator moves on the first one.

### CR-02 [BLOCKER]: `deleteFolder` still builds its filesystem target from an unconfined caller-supplied name — the un-swept sibling of CR-03

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:96-97`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:379-388`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:161-163`,
`AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:101-103`

**Issue:** 15-63 gave `renameFolder` a real boundary and left the adjacent destructive operation on
the old construction. `deleteFolder(name:)` passes the raw `name` straight to
`storage.userFolderURL(name:)` — which only appends the component — and then to
`storage.removeFolder(at:)`.

`removeFolder`'s guard is lexical prefix containment only (`targetURL.path.hasPrefix(rootPath + "/")`),
so it stops `..` and absolute paths but **admits any nested path under the root**. A caller passing
`"MyFolder/[123_abc] Some Title"` therefore recursively deletes a gallery folder, and passing
`"MyFolder/[123_abc] Some Title/..."` reaches anything beneath it. The name is never normalized, so
none of `renameUserFolder`'s refusals (single component, normalization identity, symlink source,
directory-type check) apply.

The recovery path then diverges from the manifest, which is the SSOT rule's core prohibition: the
coordinator's cleanup keys on `parentFolderName == name` (line 102), which matches nothing for a
nested name, so `downloadIndex`, the queue store and the background-task store keep entries for a
gallery whose folder this call just erased. The deleted gallery goes on reading `.completed` from an
in-memory record until the next full rescan.

Two of the three arguments the prior review used to make the rename case a BLOCKER apply verbatim
here — it is a public client API, and its filesystem boundary must enforce confinement itself — with
the third (escaping the sandbox root) replaced by unbounded data loss *inside* the root. The escape
suite added by 15-63 covers only `renameFolder`; there is no `deleteFolder` confinement test.

**Fix:** Move deletion behind the same boundary the rename now uses:

```swift
public func deleteUserFolder(named rawName: String) throws {
    guard let folderURL = confinedDirectUserFolderURL(named: rawName) else {
        throw invalidUserFolderNameError()
    }
    try fileManager.operate { manager in
        guard confinedDirectUserFolderURL(named: rawName) == folderURL,
              itemType(at: folderURL, using: manager) == .typeDirectory
        else { throw invalidUserFolderNameError() }
        try manager.removeItem(at: folderURL)
    }
}
```

Call it from `DownloadClient+Folders.swift:116` instead of `storage.removeFolder(at:)`, and extend
`RenameEscapeSource` (or add a sibling `arguments:` suite) so `..`, `../Outside`, an absolute path,
`"Alias Target/Nested"`, a whitespace-padded alias and a symlinked direct child are all asserted
refused with the target's bytes intact. Consider also tightening `removeFolder(at:)` itself to
resolve symlinks before the prefix comparison, since it is the shared primitive.

### CR-03 [BLOCKER]: The read paths still delete rejected page files and reconcile nothing — CR-01 relocated, not eliminated

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift:27-40`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:265-286`,
`AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift:68-73`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:491-503`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:826-851`

**Issue:** `validate`'s new `discardingRejected` parameter defaults to `true`, and the doc at
`DownloadStore+Operations.swift:494-498` justifies leaving two callers on that default because their
"answer feeds nothing destructive". That is the wrong test, and the fix's own prose two paragraphs
above says so: "a probe that deletes what it refuses is a mutation performed by an ACT OF LOOKING".
The hazard is not what the answer feeds — it is that forming the answer deletes files.

Both remaining callers are reachable from an ordinary read:

- **Opening a downloaded gallery.** `loadManifest(gid:)` calls `sanitizeLocalFilesIfNeeded` →
  `scanCompletedFolder`, whose two calls discard their results (`_ =`) and exist purely for the
  probe's side effect; both take the discarding default. A zero-byte or non-regular page file is
  deleted there. `loadManifest` then runs `storage.validate(verifiesContentHashes: false)` — also
  discarding — which now reports `.missingFiles` for the page the sweep just removed, and returns a
  failure. **Nothing reconciles the manifest.** Its hash for that page is still non-empty, so under
  D-SSOT-07 the downloads list keeps rendering the gallery `.completed`, the badge keeps counting the
  page, and the divergence survives relaunch. This is CR-01's end state (files gone, record still
  claiming them, no durable correction) reached by opening the reader instead of by tapping Validate.
- **`resumeMode(for:)`** (`SchedulingHelpers.swift:68`) performs the same discarding validate to
  decide repair-versus-redownload. It converges only if the user subsequently starts the download;
  until then the record lies about pages this call deleted.

CLAUDE.md's manifest rule is explicit that a scan observing the record's claim to be wrong must
"reconcile the manifest **durably at that moment**", and that in-memory state must never be required
to make the record truthful. Here the app itself creates the falsehood and records nothing at all —
not even a session-scoped signal.

**Fix:** Two options, in order of preference.

1. Make the housekeeping deletion reconcile. Give the sweep a real name and a real contract: have
   `scanCompletedFolder` take a full `pageFileScan(discardingRejected: true)` and, when it deletes
   anything, run the deleted pages through `reconcileWorkingManifestAgainstPageFiles` under
   `withdrawingCountedBasisMovement` exactly as `blankingPass` does — the removed pages are positive
   absences by construction, so the loop's three refusal lines already handle them.
2. If the sweep must stay non-reconciling, flip both callers to `discardingRejected: false` (as
   15-61 did for `validateImageData`), and change the parameter's default to `false` so the
   dangerous behavior is opt-in and every new caller must name it. The entitled actors — the repair
   seed, the finalize merge and the capture target — already pass paths explicitly.

Add a case that opens `loadManifest` over a one-page gallery whose only page file is zero bytes and
asserts *both* that the file survives and that the manifest still matches the disk afterwards.

## Warnings

### WR-01: The new per-page rejection guard can make the reconciliation blank *more*, not less — the opposite of 15-62's self-reported claim

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:701-719`

**Issue:** The fourth clause (`pageFileScan.rejectedPageRelativePaths[page] == nil`) narrows the
per-page decision, but it feeds `blankedPageCount`, which the wholesale guard on line 719 compares
against `manifest.completedPageCount`. Shrinking the count can drop a gallery *below* the
all-or-nothing threshold and thereby license blanking that the guard previously refused.

Concrete mixed shape, two claimed pages, discarding caller (`prepareWorkingSeed`,
`ExecutionSupport.swift:324`): page 1's file is zero bytes and its housekeeping deletion fails
(read-only volume, `EBUSY`); page 2's file is genuinely absent.

- Before: page 1 was indistinguishable from an absence, so `blankedPageCount == 2`, `2 < 2` fails,
  the wholesale guard refuses and **nothing** is blanked.
- Now: page 1 is skipped, `blankedPageCount == 1`, `1 < 2` passes and **page 2 is blanked**.

Blanking page 2 is arguably the more correct outcome, but it is a behavior change the plan explicitly
told the reviewer not to expect, it is unreviewed, and no test stages a mixed rejected-plus-absent
shape — `DownloadValidationRejectionArmTests` covers only the two wholesale shapes and one authorized
single-page rejection.

**Fix:** Either state the widened behavior in the doc at lines 648-656 and add a mixed-shape case
pinning it, or measure the guard over the pages the loop *would* have considered (absences plus
surviving rejections) so that adding a per-page hold cannot relax the wholesale threshold.

### WR-02: `probeAssetFileContent`'s rejection never deletes, so the "every pre-existing caller is byte for byte unchanged" claim is false, and a refuted page can hold its claimed hash forever on the automatic paths

**File:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:949-957`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:96-100`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:645-647`

**Issue:** Both `PageFileScan`'s doc ("A discarding caller whose housekeeping deletion succeeded
reports nothing here … which keeps every pre-existing caller byte for byte") and
`reconcileWorkingManifestAgainstPageFiles`' line 2b rest on rejections being deleted for discarding
callers. The content-read exit at line 953 returns `.rejected(fileRemains: true)` **unconditionally**
— it never deletes, by deliberate design documented at lines 942-948 — so for a *discarding* caller a
page whose metadata read threw and whose first byte read hit EOF now lands in
`rejectedPageRelativePaths` and is no longer blanked, where before it was treated as an absence and
blanked.

The consequence is asymmetric: `removeRefutedPageFiles` is called from exactly one place
(`reconcileValidatedRecordAgainstPageFiles`), so only a user-initiated Validate can ever clear such a
page. On the automatic routes — `prepareWorkingSeed` and `blankingPass` — the page keeps a non-empty
hash beside a file that is refuted and present, i.e. the record claims a complete page over unusable
bytes, indefinitely. That is the mirror of the D-SSOT-04 laundering shape the guard was added to
prevent, and it is not what the doc claims happens.

**Fix:** Correct the two doc claims to name the content-read exit as the exception, and decide the
substantive question explicitly: either have the discarding callers remove a surviving refuted file
before their reconciliation (giving them the same classify-authorize-remove ordering
`validateImageData` now has), or record the surviving refutation somewhere durable so the record does
not silently claim a page whose bytes were positively refuted.

### WR-03: `ContentMismatchScan`'s documentation was orphaned onto the newly inserted `DownloadValidationPolicy`

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:9-35`

**Issue:** `DownloadValidationPolicy` was inserted between `ContentMismatchScan`'s doc comment
(lines 9-18) and its declaration (line 35), with no blank line at the seam. Lines 9-29 are one
contiguous `///` block, so the compiler and Quick Help attach the whole thing — including "What a
fresh content pass was able to determine about each CLAIMED page…" and the three-set partition
rationale — to `DownloadValidationPolicy`, and `ContentMismatchScan` is left undocumented. The
resulting block reads as two unrelated summaries stacked on one type.

**Fix:** Move lines 9-18 back down to immediately precede `struct ContentMismatchScan` on line 35,
leaving `DownloadValidationPolicy` with only its own doc (lines 19-29).

### WR-04: The new `.notFound` refusal from `retryPages` is swallowed silently by its only production caller, and the error kind conflates two conditions

**File:** `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift:189-194`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:81`,
`AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:75-89`

**Issue:** `retryPagesDone(.failure)` clears `retryingPageIndices` and re-sends `.loadInspection`. It
sets no `state.toast`, even though the reducer owns a toast surface and uses it for validation
results (line 235). So the CR-04 narrowing turns a tap on Retry into a visible no-op: the rows flash
to `.pending` from the optimistic rewrite at lines 150-178 and then silently revert. Nothing tells
the user why, and nothing distinguishes it from a network failure.

Separately, `.failure(.notFound)` is the same value `retryPages` returns when the *gallery* is absent
(line 73) and when its folder is absent (line 88). A caller cannot tell "this download is gone" from
"the pages you named are outside this gallery", and the localized string for `.notFound` will read as
the former.

**Fix:** Surface the failure — `state.toast = ...` on the failure branch, matching the validation
action — and introduce a distinct error for an inadmissible selection (e.g.
`.fileOperationFailed(String(localized: .downloadStoreInvalidPageSelection))`) so the message the user
sees matches what happened. Assert the toast in `DownloadRetryPagesTests`.

### WR-05: A selection that only becomes inadmissible at fetch time now settles the run as a failure instead of a no-op

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift:185-191`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift:110-115`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:926-950`

**Issue:** Keeping an empty-but-present selection is correct against the widening, but the run that
inherits it is not a no-op. `pendingPageIndices` returns `[]`, the announcement gate declines,
`downloadCoverImage` still runs, and `finalizeBatchResult` then calls `missingFinalizedPageIndices`
over the **whole** manifest — so any page the `.repair` seed's reconciliation just blanked throws
`IncompleteDownloadError` and the gallery settles into a persistent `.error` record for work the user
never asked to be done. The path is narrow (it needs the fetched page count to have shrunk below
every requested index between the record read at `RetryHelpers.swift:79` and the detail fetch), but
it is precisely the drift the defensive filter exists for, and nothing tests it.

**Fix:** Detect the collapse explicitly at `normalizeFetchedPayload`'s boundary — a non-nil raw
selection that the fetched count empties is a request that can no longer be honoured — and throw a
named `AppError` there so the failure carries a truthful reason, rather than letting the run reach
finalize and report a generic incomplete-download error about pages it was never asked to fetch.

## Info

### IN-01: Raising `waitForTaskValue`'s default to 10s lengthens three deliberate hang-detectors tenfold

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:96-106`

**Issue:** Verified that all six removed `timeout: .seconds(1)` arguments are argument-only and no
assertion changed. Note the trade though: `DownloadDeleteConvergenceTests.swift:112` and
`DownloadOwnershipConvergenceTests.swift:89` document their bound as the thing that "turns the
pre-fix missing notification into a named failure instead of a hung suite" — under the new default
each of those regressions now costs ten seconds of wall clock instead of one, and the flaky observer
cases were addressed by relaxing the bound rather than by removing the scheduling dependency the
comment identifies.

**Fix:** Acceptable as-is; if the suite's failure latency matters, keep the 10s default for the
scheduling-sensitive observer cases and pass an explicit short bound at the two sites whose purpose is
to detect a *missing* notification.

### IN-02: Inconsistent localized-key spelling introduced one line apart in the new store code

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:436-438`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:485`

**Issue:** `renameUserFolder` writes `String(localized: .downloadStoreFolderAlreadyExists)` while
`invalidUserFolderNameError()` eight lines below writes
`String(localized: .RLocalizable.downloadStoreInvalidFolderName)`. Both resolve, but the file now
carries both spellings for the same kind of key, matching a pre-existing inconsistency in
`DownloadClient+Folders.swift` rather than settling it.

**Fix:** Pick one spelling for the module and apply it in the new code.

---

_Reviewed: 2026-08-10T02:57:36Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
