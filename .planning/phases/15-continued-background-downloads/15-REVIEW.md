---
phase: 15-continued-background-downloads
reviewed: 2026-08-10T10:22:01Z
depth: standard
files_reviewed: 76
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
  - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
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
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/PageFileScan.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift
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
  critical: 1
  warning: 6
  info: 3
  total: 10
status: issues_found
---

# Phase 15: Code Review Report (third review, after gap-closure plans 15-65 … 15-69)

**Reviewed:** 2026-08-10T10:22:01Z
**Depth:** standard
**Files Reviewed:** 76
**Status:** issues_found

## Summary

Effort was concentrated on `git diff a4e51de7..HEAD` (17 commits, five gap-closure plans), with a
normal standard-depth pass over the untouched remainder.

### Verdict on the previous round's ten findings

| Prior ID | Verdict | Notes |
| --- | --- | --- |
| CR-01 (unbracketed generation advance) | **Closed at its root** | `advanceQueueIntentGeneration` now wraps its own increment (`+Manager.swift:852-856`). I re-derived the arithmetic: at the advance `hasSessionCreditReading` is still true (the index record survives a re-queue), so `creditedAfter` really is computed as regime 3's zero rather than falling back to `creditedBefore` — the withdrawal fires. All four callers are top-level statements in `async` functions, none inside a bracket, and on the enqueue route `writeInitialManifest`'s bracket (`+PublicAPI.swift:151-165`) closes at line 103 before the advance at line 115. The new one-page-at-a-time test discriminates: pre-fix the re-queue frame reads `4 / 24` and the first keeper page cannot exceed it. **But the "nesting is impossible at the type level" claim is false — see WR-04.** |
| CR-02 (`deleteFolder` unconfined name) | **Closed at its root for the escape; the closure introduced a new user-facing defect** | `userFolderURL(name:)` is gone, every user-folder mutation is a `mutatingConfinedUserFolder` body, and the six-argument escape catalog asserts disk-then-records-then-verdict. Two residuals: the confinement predicate now refuses folders the app itself lists (**CR-01** below), and `removeFolder(relativePath:)` still offers the deleted construction verbatim (**WR-01**). `writeInitialManifest`'s `createDirectory(at:)` does pass `withIntermediateDirectories: true` (`+Networking.swift:235-241`), so dropping enqueue's eager parent creation is safe. |
| CR-03 (reads still delete) | **Closed at its root** | Re-derived the family myself: ten declarations carry `discardingRejected` and all ten now default to `false` (`DownloadStore.swift:185, 205, 261, 276, 294, 466, 501, 537, 757` and `DownloadStore+Operations.swift:680`). Exactly **three** production sites still pass `true` — not four — and the store's own doc (`DownloadStore.swift:788-793`) agrees. Two are entitled on the stated test (covers carry no recorded hash). The third is not (**WR-02**). `sanitizeLocalFilesIfNeeded` is deleted rather than defanged, and the new `DownloadReadPathNonMutationTests` asserts from both sides (file bytes + a relaunched coordinator's persisted reading), which is a genuine discriminator. |
| WR-01 (per-page hold could blank MORE) | **Closed at its root** | The loop's guard is now `blankedPageCount + refutedSurvivingPageCount < completedPageCount` (`+WorkingManifestReconciliation.swift:235`). I verified the algebra against the code: the caller's `positivelyAbsentPages ∪ refutedPages` (`+ExecutionSupport.swift:452-460`) is *set-identical* to the loop's two counters computed over the same scan, and an authorized removal moves a page from one term to the other, so the sum is invariant and the two guards cannot disagree. The paired 2-page/3-page cases genuinely cross the discontinuity. |
| WR-02 (refuted files never deleted on automatic routes) | **Closed at its root, with a recovery gap at the new seam** | `authorizedReconciliationScan` gives `prepareWorkingSeed` the classify → guard → remove → rescan → blank ordering. But the durable write happens *after* the destruction and, unlike the validate route, this copy has **no** post-removal recovery and no error log — see **WR-03**. |
| WR-03 (orphaned `ContentMismatchScan` doc) | **Fixed** | The doc block was moved back onto `struct ContentMismatchScan` (`DownloadStore+Operations.swift:19-35`); `DownloadValidationPolicy` keeps only its own. Confirmed by reading the file, not by trusting the summary. |
| WR-04 (silent retry refusal) | **Closed at its root, one sibling unswept** | `retryPagesDone(.failure)` sets a toast, the inadmissible selection carries its own `.fileOperationFailed`, and `AppError(error)` round-trips the payload (`AppError.swift:7-9`), so the message survives the client seam. `toggleDownloadPauseDone(.failure)` 25 lines away is still silent — **WR-05**. |
| WR-05 (fetch-time-emptied selection settles as a failure) | **Closed at its root** | `normalizeFetchedPayload` is `throws(AppError)` and is called at `+Execution.swift:153`, nine lines before `performDownload` at 162 — so nothing has been blanked, announced or fetched when it fires. `settleDownloadFailure` clears the queue intent and removes the gid, so the stale selection cannot re-throw forever. The no-widening property holds: `nil` stays `nil`, a surviving subset stays a present `Set`, and the only input that used to empty it now produces no payload. |
| IN-01 (`waitForTaskValue` 10s default) | **Not fixed** — re-raised as IN-01. |
| IN-02 (two localized-key spellings) | **Not fixed, and widened** — re-raised as IN-02. |

### Localization (independently verified)

Parsed `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` as JSON: 10 keys, all
sorted, and **every** key carries all six locales (`de`, `en`, `ja`, `ko`, `zh-Hans`, `zh-Hant`) —
including the two new ones. Neither new key takes an argument, so no numeric specifier and no
substitution question arises. The one key with substitutions (`continued_session.subtitle`) is
compliant: three named `%#@…@` variables, no bare `%lld` in any outer value, `en` and `de` category
sets equal (`{other}`, `{one, other}`, `{one, other}`), and `ja`/`ko`/`zh-Hans`/`zh-Hant` are
`other`-only. No `shouldTranslate: false` entries exist. The key-*spelling* consistency angle is
still broken — IN-02.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01 [BLOCKER]: The new delete confinement refuses user folders the app itself lists, so a folder visible in Downloads can no longer be deleted from inside the app

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:104-110`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:622-640`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:601-638`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:363-376`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:394-431`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:477-483`,
`App/Info.plist:145-146`, `App/Info.plist:170-171`

**Issue:** `confinedDirectUserFolderURL(named:)` requires `normalizedUserFolderName(rawName) ==
rawName` (line 627). The folder *listing* applies no such filter: `scanDownloads` (line 608-617)
promotes **every** visible directory under the root to a user folder, rejecting only gallery-shaped
names and directories that hold a manifest. The two predicates disagree, and the app is shipped
with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` both true over a root inside
`Documents/`, so the user really can create the disagreeing names.

`normalizedFolderName` (line 394-431) *rewrites* rather than rejects: it maps `/`, `\`, `:` and
control characters to a space, collapses runs of whitespace to one, trims leading/trailing
whitespace and trailing dots. So a folder the user creates in the Files app named

- `Manga\Vol1` → normalizes to `Manga Vol1`
- `Art  Books` (two spaces) → `Art Books`
- `Misc etc.` → `Misc etc`
- ` Photos` → `Photos`

is listed by `fetchFolders()`, is a usable download destination, and now fails
`confinedDirectUserFolderURL`, so `deleteFolder` returns `.fileOperationFailed(invalid folder name)`
before it ever looks at the disk. **This is a regression introduced by this delta**: before 15-68,
`deleteFolder` built `root/<name>` and `removeFolder(at:)` accepted it, so these folders deleted
correctly. `renameUserFolder` has had the same predicate since the previous round, so both mutating
actions on such a folder are now dead ends and the user must leave the app to remove it. The error
message compounds it — the app calls the name invalid while displaying it.

The escape suite does not catch this because its `whitespacePaddedAlias` argument stages a padded
name whose trimmed form is a **different, real** folder (`"  Keeper  "` vs `Keeper`), which must be
refused. It never stages a folder whose *own on-disk name* is the padded one, so the case that
matters is outside the catalog.

**Fix:** Key the boundary on the listing that produced the name rather than on normalization
identity. Keep every structural check (non-empty, not `.`/`..`, single path component, standardized
parent == root, resolved parent == root, and the leaf's `.typeDirectory` re-check inside the lock),
and replace the `normalizedUserFolderName(rawName) == rawName` clause for *source* names with an
exact-membership test against the scanned listing:

```swift
// DownloadStore+Operations.swift
func confinedDirectUserFolderURL(named rawName: String) -> URL? {
    guard !rawName.isEmpty,
          rawName != ".", rawName != "..",
          rawName.split(separator: "/", omittingEmptySubsequences: false).count == 1,
          !rawName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    else { return nil }
    ...
}
```

The single-component + resolved-parent pair is what refused `"MyFolder/[123_abc] Title"`, `..`,
`../Outside` and the absolute path; none of those refusals depends on the normalization clause.
Destinations (`createUserFolder`, `ensureUserFolder`, the rename's new name) must keep normalizing,
which they already do at their callers. Add an argument to `DeleteEscapeSource`'s sibling — a
folder whose real on-disk name is `Art  Books` — asserting it deletes, and the same for
`renameFolder`.

## Warnings

### WR-01: `removeFolder(relativePath:)` is still public, still unused, and reproduces verbatim the unconfined construction CR-02 deleted

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:417-425`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:443-455`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:92-98`

**Issue:** The stated mechanism of the CR-02 fix is structural: "Deleting the function is what makes
that unwritable rather than merely discouraged" (`DownloadStore.swift:96`). It is not unwritable.
`removeFolder(relativePath:)` is `public`, takes an arbitrary caller-supplied relative path, joins
it to the root with `folderURL(relativePath:)` and hands it to the prefix-contained primitive — so
`storage.removeFolder(relativePath: name)` is a one-line rewrite of the exact defect, admitting
`"MyFolder/[123_abc] Some Title"` again while the coordinator's exact `parentFolderName == name`
cleanup key matches nothing.

Its own doc concedes it "has no production caller today", which makes it dead public API kept for
vocabulary. Nothing owns it: no test exercises it, and `DownloadSourceInventoryTests` has no census
over it, so the next round that needs "remove a folder by name" will find it by autocomplete.

**Fix:** Delete it. `removeGalleryFolders` (the only real user of the primitive) passes URLs the
scan produced and calls `removeFolder(at:)` directly. If a record-path spelling is genuinely wanted
later, it can be reintroduced with the record's own `relativePath` as its only source. If it must
stay now, make it `internal` and add it to the delete-escape argument catalog.

### WR-02: `materializeRepairSeed`'s source page scan still deletes, and the act does not reconcile the record it destroys files for — the one surviving `discardingRejected: true` that fails the round's own entitlement test

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:151-172`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:820-839`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:718-746`,
`AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift:59-71`,
`AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift:87-103`

**Issue:** The entitlement rule this round adopted is "may this act delete only if the same act
durably blanks the record for the page it destroyed?". This site does not satisfy it, and the code
says so in its own comment: *"What the SOURCE folder's own record owes for the file removed here is a
separate question, and this round did not answer it"* (line 166-167).

The source folder is not an anonymous staging area. `repairSeed(for:payload:)` returns
`download.folderURL` — the gallery's **currently indexed folder**, carrying the manifest that was
just copied whole into the destination. `materializeRepairSeed` then deletes refused page files
inside it while writing nothing to its manifest. The destination's reconciliation blanks the
*copy*; the source keeps claiming the pages whose files this call removed.

That divergence is normally invisible because the source folder is superseded garbage that
`removeSupersededFolders` deletes at `completeDownload`. It becomes visible on two conditions that
are both reachable:

1. The run does not complete (failure, cancellation, app termination), so the stale folder survives
   with a lying manifest.
2. `deduplicatedDownloadIndex` picks it. Dedup is by `displayDate` (`+Persistence.swift:68`), and a
   `removeItem` on a child bumps the *parent directory's* mtime. The destination's mtime is set by
   the manifest copy; the source's is bumped afterwards by these deletions. If no page is copied —
   precisely the all-refused shape — the source ends up the newer folder and wins the index.

The reachability window is narrow (repair mode, plus a destination path that differs from the
source, i.e. an upstream title change), but the shape is exactly the record/disk divergence the
manifest-SSOT rule calls out, created by the app, marked by nothing.

**Fix:** Either drop the entitlement here — take the non-mutating default and let the destination's
own reconciliation record the absence, which is what actually blanks anything on this route — or
give the source folder the same classify → guard → remove → **blank** treatment the destination now
gets, reconciling `sourceFolderURL`'s manifest under the same guards before returning. The first is
strictly simpler and costs only the orphan zero-byte file, which IN-03 already flags as an
unswept population. Add a case staging an interrupted repair-with-rename and asserting the source
folder's manifest and its page files agree afterwards.

### WR-03: `prepareWorkingSeed`'s copy of the classify-guard-remove-rescan-blank ordering omits the post-removal recovery and the error log the validate route treats as mandatory

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:441-487`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:206-215`,
`AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:304-337`,
`AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift:210-241`

**Issue:** The doc claims this "mirrors `reconcileValidatedRecordAgainstPageFiles`' ordering …
rather than inventing a second one" (line 419-421). It mirrors the ordering and drops the
compensation. That function states the requirement explicitly: *"Three exits fire AFTER the removal
— a rescan that could not enumerate, the loop's own refusal lines applied to the post-removal scan,
and a thrown manifest write — and each would otherwise leave the record claiming pages this pass
deleted. So every one of them re-attempts the same pass ONCE"*, and logs the removed indices at
`error` when the retry also fails.

`authorizedReconciliationScan` has all three exits and handles none of them:

- The rescan (line 477) can report `scanSucceeded == false`, in which case
  `reconcileWorkingManifestAgainstPageFiles` returns the manifest verbatim at line 210 over pages
  this function just deleted.
- The post-removal loop can still refuse if the rescan's terms grew (a page whose file vanished
  concurrently), leaving the same state.
- `storage.writeManifest` can throw, which propagates out of `prepareWorkingSeed` and aborts the
  run with the deletion already performed and the record unchanged.

The run route makes the first two self-healing by accident — `existingPages` is empty or short, so
`pendingPageIndices` re-fetches the removed pages — but the third leaves a durable divergence, and
none of the three is logged, so a device archive cannot show which files were destroyed against a
record that still claims them. The `scanSucceeded` source also moved (line 399, now
`reconciliationScan.scanSucceeded` instead of `destinationScan.scanSucceeded`), so a failed rescan
now flips `inheritedPages` to its pessimistic branch and can over-report the announced basis for an
incomplete record — the direction the announcement's own doc calls "the defect".

**Fix:** Reuse the compensation rather than the ordering alone. Have `authorizedReconciliationScan`
return the removed page set alongside the scan, and in `prepareWorkingSeed` apply the same
"recover once, then log at `error` with the masked gid and the removed indices" step
`recoveredBlanking` already implements — ideally by lifting that helper so both routes share one
implementation, which is the argument the blanking loop itself makes for being shared. Add a case
that fails the manifest write after an authorized removal and asserts the log/recovery, mirroring
the validate-route case.

### WR-04: The "nesting is impossible at the type level" claim behind the self-bracketing advance is false, and nothing detects a nested advance

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:270-295`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:837-856`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:191-209`

**Issue:** The plan's structural claim — that `withdrawingCountedBasisMovement` taking a non-async,
non-escaping closure while all four callers are `async` makes nesting impossible — does not hold.
`advanceQueueIntentGeneration(for:)` is a **synchronous, actor-isolated** method
(`+Manager.swift:852`). The bracket's closure is non-escaping and non-`Sendable`, so it inherits the
enclosing function's actor isolation, and any synchronous actor method is callable inside it. A
future queue-mobilizing path written as

```swift
try withdrawingCountedBasisMovement(gid: gid) {
    advanceQueueIntentGeneration(for: gid)   // compiles today
    ...
}
```

nests two brackets, which the bracket's own doc forbids outright ("They compose as SIBLINGS only")
because the inner delta is then withdrawn twice — silently over-withdrawing the monotonic floor.

The claim's factual half is true today: I checked all four call sites (`+RetryHelpers.swift:37` and
`:132`, `+Scheduling.swift:360`, `+PublicAPI.swift:115`) and each is a top-level statement outside
any bracket. But the safety is discipline, not construction, and the censuses do not cover it —
`expectedBracketCallSites` counts *calls*, and a nested call adds one to a file's count, which the
next round would simply update the table for. The doc at `DownloadSourceInventoryTests.swift:197-200`
asks the reader to check nesting by hand, which is the same unowned-invariant shape that suite exists
to abolish.

**Fix:** State the property honestly in both docs (`+ExecutionSupport.swift:270-275` and
`+Manager.swift:843-845`): sibling composition is a convention enforced by review, not by the type
system. Then make it detectable — either add a `withdrawalDepth` counter incremented/decremented
around `movement()` with a `reportIssue` (not a crash) when it exceeds one, which costs nothing in
release and fails a debug test run, or add a source census counting bracket tokens that appear
inside another bracket's brace span.

### WR-05: `toggleDownloadPauseDone(.failure)` is still the silent visible no-op WR-04 fixed 25 lines above it

**File:** `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift:221-225`

**Related:** `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift:189-198`

**Issue:** The retry branch now reports its refusal through the toast surface the reducer already
owns. The pause/resume branch immediately below still does `if case .failure = result { return
.send(.loadInspection) }` — reload and say nothing. The failure is reachable: `togglePause` answers
`.failure(.unknown)` for a gallery whose status moved out of the toggleable set between the render
and the tap, and `.failure(.notFound)` for a gallery that has been deleted underneath the inspector,
which is exactly the "the row reverts and nothing tells the user why" shape WR-04 named. The
`retryFailureToast` mapping added one screen away is directly reusable.

**Fix:**

```swift
case .toggleDownloadPauseDone(let result):
    if case .failure(let error) = result {
        state.toast = error.retryFailureToast   // rename to `actionFailureToast`
        return .send(.loadInspection)
    }
    return .none
```

Rename the private `AppError` helper to something not retry-specific and add a reducer case for the
pause branch alongside the three new retry cases.

### WR-06: `DownloadSourceInventoryTests` carries an unused private scanner and two load-bearing doc sentences that describe a scoping the censuses do not use

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:834-836`

**Related:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:27`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:65-72`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:611-677`

**Issue:** `downloadsTestFiles(in:)` has no caller. Both double-fidelity censuses scope through
`clientDoubleFiles` / `clientDoubleTreeFiles`, which count over the downloads test target **plus**
the processing client's module. The suite's own header nevertheless says every census names its tree
"through `clientModuleFiles(in:)`, `downloadsTestFiles(in:)` or `clientDoubleFiles(in:)`" (line 27)
and that the walk is scoped "to this directory through `downloadsTestFiles(in:)`" (line 67) — while
line 29-31 of the same doc states the correct two-tree scoping. The file contradicts itself, and
`clientDoubleTreeFiles` — the function that actually decides the population — is named in neither
sentence.

This is precisely the defect class the suite was built to abolish ("a comment silently becomes a
false premise, and a later fix reasoning from it lands wrong"), living inside the suite. Swift emits
no warning for an unused private method, so nothing failed.

**Fix:** Delete `downloadsTestFiles(in:)` and rewrite lines 27 and 65-72 from source: name
`clientModuleFiles(in:)`, `clientDoubleTreeFiles(in:)` and `clientDoubleFiles(in:)`, and say "the
two trees" rather than "this directory". If the function is wanted for a future test-target-only
census, add that census in the same change so the declaration has an owner.

## Info

### IN-01: `waitForTaskValue`'s 10s default still lengthens three deliberate hang-detectors tenfold

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:104-106`

**Related:** `AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift:113`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift:90`

**Issue:** Unchanged since the previous review and not covered by any of the five plans. The two
convergence suites document their bound as the thing that "turns the pre-fix missing notification
into a named failure instead of a hung suite"; under the 10s default each of those regressions costs
ten seconds of wall clock instead of one.

**Fix:** Keep the 10s default for the scheduling-sensitive observer cases and pass an explicit short
bound at the two sites whose purpose is to detect a *missing* notification.

### IN-02: The localized-key spelling split is unresolved and 15-69 widened it

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:93`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift:207`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:504`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:656`

**Issue:** The module now carries ten `String(localized: .RLocalizable.…)` call sites and eight bare
`String(localized: .…)` ones for the same kind of key. Both new keys added this round
(`.downloadStoreInvalidPageSelection`, `.downloadStorePageSelectionOutdated`) took the bare
spelling, and `DownloadStore+Operations.swift` now uses both forms eight lines apart
(`.downloadStoreFolderAlreadyExists` at 504 and 556, `.RLocalizable.downloadStoreInvalidFolderName`
at 656).

**Fix:** Pick one spelling for the module — the `RLocalizable.` prefix is the majority — and apply
it in a single mechanical pass.

### IN-03: With the folder sweep deleted, nothing removes refuted files for pages the manifest does not claim

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:448-455`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:803-870`,
`AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift:1-38`

**Issue:** A consequence of CR-03 worth recording rather than a defect. Every read now leaves a
refused (zero-byte / non-regular) page file in place, and the only remover,
`removeRefutedPageFiles`, is driven from `refutedPages`, which is derived from
`claimedPages` — pages with a **non-empty** hash. A page whose hash is empty (an interrupted
download, a page just blanked by a reconciliation) whose file is a zero-byte remnant is therefore
removed by nothing: the fetch picks a fresh unique name and the remnant stays. The probe's
first-writer rule (`DownloadStore.swift:233-238`) means a usable file still settles the page, so
correctness is unaffected — but repeated failed retries accumulate orphan files with no sweeper,
where the deleted `sanitizeLocalFilesIfNeeded` used to clear them on every reader open.

**Fix:** No action required for correctness. If the accumulation matters, extend
`authorizedReconciliationScan`'s removal set to include refuted files for unclaimed pages — those
have no hash to diverge from, so they are entitled under the round's own test — rather than
reintroducing a read-time sweep.

---

_Reviewed: 2026-08-10T10:22:01Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
