---
phase: 15-continued-background-downloads
reviewed: 2026-08-09T06:02:32Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - AGENTS.md
  - AppPackage/Sources/AppModels/Download/DownloadInspection.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
  - AppPackage/Sources/DetailFeature/DetailReducer.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorStorageTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
findings:
  critical: 2
  warning: 8
  info: 0
  total: 10
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-09T06:02:32Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

The round's central mechanism — the validate-time reconciliation in
`reconcileValidatedRecordAgainstPageFiles` — gets the headline ordering right: the wholesale guard
is computed over the combined `positivelyAbsent ∪ mismatched` set and evaluated *before* the first
`removeItem`, and the blanking still flows through the one shared loop. `DownloadRetryPagesTests`
and `DownloadValidationReconciliationTests` pin that ordering from the outside, and
`DownloadManifestSSOTInvariantTests` genuinely falsifies the "no display consults the disk" claim
rather than restating it.

Two defects survive that, both in the same function, and both are about what happens **after** the
guard passes.

1. The function's own documented contract — "any hold, any refusal and any thrown write answers
   false" — is not implemented for the presence scan's `unprobedPages`. A page the pass could not
   classify at all is silently excluded from the coverage answer, so `validationErrors` is cleared
   over an unanswered page and the Validate gate then closes behind it.
2. Every destructive step (`removeMismatchedPageFiles`) happens *before* anything durable is
   written. Three post-removal exits — a failed rescan, the loop's own refusal lines, and a thrown
   manifest write — all leave the persisted manifest claiming hashes for page files this pass has
   already deleted, with only session-scoped state marking it. That is the exact inversion of the
   AGENTS.md clause "the refuted file is removed under the same guards so the record and the disk
   agree", and it survives relaunch as a `.completed` gallery whose files are gone.

Beyond those, the D-SSOT-08 widening was applied at the selection site without revisiting what
consumes the selection: the inspector's optimistic overlay now blanks every page it sends, and the
button that sends it is still labelled "Retry Failed Pages". Three documentation inventories that
this module treats as load-bearing went stale in the same change (the `withdrawingCountedBasisMovement`
call-site count is now wrong in three places), and the newly-extracted shared test helper shipped
alongside two private shadow copies of itself — the precise "three private copies could drift"
outcome its own doc comment says it exists to prevent.

No `swiftlint:disable`, no hardcoded secrets, no injection surface, no line over 120 characters,
no file over 1000 lines. Reducer naming and dialog placement are unaffected by this change set.

## Critical Issues

### CR-01: A page the presence scan could not classify is not counted as a hold, so `validationErrors` is cleared over unanswered evidence and Validate becomes unreachable

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:215`, `:228`
(guarded population computed at `:251-261`)

**Issue:**
`heldPages` is built from `contentScan.held ∪ unremovedPages` only. `contentMismatchScan` iterates
`pageFileScan.pages` — the files the listing *yielded* — so a claimed page that landed in
`presenceScan.unprobedPages` never enters any of its three sets. `prospectiveBlankPages` knows about
that population (it explicitly `.subtracting(presenceScan.unprobedPages)` at `:259`), and the
blanking loop protects it (`DownloadClient+ExecutionSupport.swift:685`), but the **return value**
does not see it.

Reachable sequence, all inside one gallery with three claimed pages:

- page 1's file deleted externally → positively absent;
- page 2's file yielded by the listing but `.unprobeable` (`probeAssetFile` answers `.unprobeable`
  when `fileExists` is false — the listing/probe race — and when both the metadata read and the
  content read throw), so `presenceScan.unprobedPages == {2}`;
- page 3 verified.

`storage.validate` short-circuits on page 1. The reconciliation blanks `{1}`, `heldPages` is
**empty**, `reconciledManifest.pages != manifest.pages` is true, so the function returns `true` and
`validateImageData` clears the entry (`:129-130`). The record now reads `.inactive`, 2 of 3, with
**no operation-level signal at all** — while page 2 is still claimed and was never classified.

The follow-on is worse than the missing signal: `DownloadedGallery.canValidateImageData`
(`AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift:57-60`) is
`[.completed, .updateAvailable].contains(displayStatus) || lastError?.code == .fileOperationFailed`.
Both disjuncts are now false, so the single sensor the whole design routes through is **disabled**
for that gallery. The user cannot ask again about the page the pass could not answer for.

This contradicts the function's own header ("Any hold, any refusal and any thrown write answers
false", `:188-190`), the `validationErrors` declaration ("a page whose bytes could not be probed or
read at all", `DownloadClient+Manager.swift:441-446`), and the AGENTS.md clause the round rewrote.

**Fix:**
```swift
// DownloadClient+PersistenceNormalize.swift — inside reconcileValidatedRecordAgainstPageFiles
let claimedPages = Set(manifest.pages.filter({ !$0.value.isEmpty }).keys)
let unclassifiedPages = claimedPages.intersection(presenceScan.unprobedPages)
let heldPages = contentScan.held
    .union(unremovedPages)
    .union(unclassifiedPages)
```
`claimedPages` is already derived inside `prospectiveBlankPages`; lift it to the caller and pass it
to both, so the guard's population and the coverage answer are read off one expression. Then add the
missing regime to `SSOTStateCase.all` and to `DownloadValidationReconciliationTests` — a claimed page
whose presence probe cannot answer, beside a page that blanks — asserting `displayStatus == .error`
and `lastError?.code == .fileOperationFailed` after the pass.

### CR-02: Mismatched page files are destroyed before anything durable is written, and three post-removal exits leave the manifest claiming pages this pass deleted

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:210-237`

**Issue:**
The wholesale guard at `:208` is correctly evaluated before the removal — that part is right, and
`testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved` pins it. But once the guard passes, the
order is *remove files → rescan → blank → write*, and **every** failure after `:210` leaves the
files gone and the hashes intact:

1. `:219` — `storage.pageFileScan` can return `scanSucceeded == false`
   (`DownloadStore.swift:228-230`, any `contentsOfDirectory` failure). The loop then returns the
   manifest verbatim (`DownloadClient+ExecutionSupport.swift:678`).
2. `:220-227` — `reconcileWorkingManifestAgainstPageFiles` applies its own refusal lines to the
   *post-removal* scan. Under a concurrent external change its wholesale line
   (`ExecutionSupport.swift:699`) can now fire over a set the pre-removal guard already cleared.
3. `:229-237` — `storage.writeManifest` throws (disk pressure, sandbox, a folder removed under the
   app). The `catch` returns `false` and its comment asserts "nothing was destroyed" — which is
   exactly what is no longer true once `removeMismatchedPageFiles` has run 20 lines above it.

End state in all three: the persisted manifest claims non-empty hashes for pages whose files this
function deleted, and the only marker is the session-scoped `validationErrors` entry. After
relaunch the gallery reads `.completed` (`DownloadClient+Persistence.swift:103-109`) with missing
files — a durable record/disk divergence the app itself created, which is precisely the class
AGENTS.md forbids ("the refuted file is removed under the same guards so the record and the disk
agree"). It is also strictly worse than the wholesale-refusal residual the plan accepts as
deliberate: there, nothing was destroyed.

Note the `catch` swallows the error without logging on the explicit premise that the loop logs its
own writes — but the branch that matters here is the one where the loop wrote *nothing*, so the
removals leave no trail at all.

**Fix:** make the destruction contingent on the correction being durable. Concretely, blank the
mismatched pages' hashes and write the manifest first, then remove the files for the pages the
write actually recorded, and demote any page whose file could not be removed to `held` exactly as
today:

```swift
// 1. guard over the combined prospective set (unchanged)
// 2. blank + write, still through the one loop, inside the D-G7-01 bracket
let reconciledManifest = try withdrawingCountedBasisMovement(gid: download.gid) {
    try reconcileWorkingManifestAgainstPageFiles(
        manifest: manifest,
        pageFileScan: presenceScan.blankingAbsent(contentScan.mismatched), // absent ∪ mismatched
        folderURL: folderURL
    )
}
// 3. only now remove the files whose hash the record no longer claims
let unremovedPages = storage.removeMismatchedPageFiles(...)
```
If reversing the order is judged to reopen the D-SSOT-04 laundering shape, the minimum acceptable
alternative is to keep the current order but make the post-removal path recover rather than return:
re-attempt the blanking write for the pages actually removed, and if that still fails, log the
removed set at `error` so a device archive can show which files were destroyed against a record that
still claims them. Silently returning `false` is not an option once files are gone.

## Warnings

### WR-01: The widened retry selection makes the inspector blank every page it sends, so the page list contradicts the badge beside it

**File:** `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift:150-165`
(driven from `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:76`)

**Issue:** `.retryPages` optimistically rewrites **every** selected index to
`status: .pending, fileURL: nil`, with no `status != .downloaded` guard. That was correct while the
call site sent `inspection.failedPageIndices`; under D-SSOT-08 the wholesale-refusal family sends
the whole page set, every member of which reads `.downloaded`. Tapping the button therefore flips
the page list to "N pending, 0 downloaded" and drops every thumbnail while the badge in the same
screen still reads N of N — a two-basis disagreement in exactly the family this round exists to
remove. `retryPagesDone(.success)` returns `.none`, so the correction only arrives on the next
`observeDownloadsDone` → `loadInspection` round trip. The durable overlay at `:264-277` already has
the right guard (`page.status != .downloaded`); the immediate write does not.

**Fix:**
```swift
pages: inspection.pages.map { page in
    guard retryingPageIndices.contains(page.index), page.status != .downloaded else { return page }
    return .init(index: page.index, status: .pending, relativePath: page.relativePath, fileURL: nil, failure: nil)
}
```

### WR-02: The button still says "Retry Failed Pages" while sending pages that never failed

**File:** `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:79`
(basis at `AppPackage/Sources/AppModels/Download/DownloadInspection.swift:80-85`)

**Issue:** The local was renamed `isRetryFailedPagesDisabled` → `isRetryPagesDisabled` and the
selection widened, but the label is still `.retryFailedPages` ("Retry Failed Pages" in
`AppPackage/Sources/DownloadsFeature/Resources/Localizable.xcstrings`). The widening predicate is
`displayStatus == .error && lastError?.code == .fileOperationFailed`, which also admits an ordinary
incomplete record whose run failed with a file-shaped error — for that record the button now
enqueues a repair over the *whole* gallery, including pages that were never attempted. That is the
"second, page-selection-shaped resume" the D-SSOT-08 doc says the widening stops short of; the
predicate does not stop short of it, and the label describes neither behavior.

**Fix:** rename the key to a neutral one (e.g. `retry_pages` → "Retry Pages"), filling every locale
the catalog supports, and update `DownloadsView+Subviews.swift` and the label's accessibility
reading. If the narrower contract was actually intended, restrict the widening to the family the
doc argues for (a record whose claimed count equals its page count) rather than to `.error` at
large.

### WR-03: `enqueue` is the one enqueue site that does not clear `validationErrors`, leaving a queued-but-never-schedulable gallery

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:95-102`
(invariant stated at `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:448-451`)

**Issue:** `validationErrors`' declaration states the rule flatly: "anything that enqueues must
clear it at or before the enqueue", because the map outranks queue membership in `displayStatus`.
Four of the five `queueStore.enqueue` call sites honour it (`resume` at
`DownloadClient+Scheduling.swift:361`, `performRetry` and `performRetryPages` at
`DownloadClient+RetryHelpers.swift:36`/`:88`, plus the testing seam). `enqueue(payload:)` does not
call `clearDownloadFailureState` at all, and it explicitly supports an already-known gallery
(`:79-80`).

Consequence when it is reached with a live entry: `displayStatus` returns `.error`
(`DownloadClient+Persistence.swift:94-95`), so `shouldSchedule` fails both its arms
(`DownloadClient+Scheduling.swift:126-135`) and the gallery sits in the queue store forever without
running — the G-15-5 dead-end shape, silently. The reachable route is Detail's badge-load window:
the download menu is gated on `downloadBadge == nil`
(`AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift:97`), not on
`hasLoadedDownloadBadge`, so it is presented before the badge lands for an existing record.

**Fix:** add `clearDownloadFailureState(gid: payload.gallery.gid)` immediately before
`advanceQueueIntentGeneration(for:)` at `:99`, and add the site to whichever census owns the rule so
the fifth entrance cannot regress. Family 3 of `DownloadManifestSSOTInvariantTests` should gain a
drive through `enqueue` for a record carrying an operation-level entry.

### WR-04: `ContentMismatchScan.verified` is dead

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:20-21`, `:264-265`

**Issue:** `verified` is written by `contentMismatchScan` and read by nobody — not by
`reconcileValidatedRecordAgainstPageFiles` (which uses only `.mismatched` and `.held`), not by any
other production site, and not by any test. Its doc justifies keeping it on the grounds that "a
caller deciding whether the pass covered every claimed page needs to see the whole partition, not a
remainder it has to re-derive" — but the one caller does not read it, and CR-01 is precisely a
coverage answer computed *without* consulting the partition. Either the field is unnecessary or the
coverage computation should be expressed through it.

**Fix:** if CR-01 is fixed by deriving coverage from the partition, express it as
`verified.count + mismatched.count == claimedPages.count` and the field earns its place. Otherwise
delete `verified` and let the scan return the two sets it actually licenses decisions from.

### WR-05: The `withdrawingCountedBasisMovement` call-site inventory is stale in three places, and the census that is supposed to own it cannot see the change

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:568-572`;
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:245`;
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift:152-155`

**Issue:** This round added a fourth call site of the D-G7-01 bracket
(`DownloadClient+PersistenceNormalize.swift:221`). Three load-bearing comments still describe three
or two:

- `Manager.swift:568-572` — "That bracket has **three** call sites — `prepareWorkingSeed`'s whole
  preparation and the basis announcement in `prepareWorkingSeedAnnouncingProgress`, both in
  `DownloadClient+ExecutionSupport.swift`, and `writeInitialManifest`'s body in
  `DownloadClient+PublicAPI.swift`".
- `ExecutionSupport.swift:245` — "**Neither** call site deletes — the exclusion is stated here
  because it is the invariant every other writer is dispositioned against." The new caller *does*
  delete page files (before the bracket, so the invariant survives), which is exactly the
  disposition that needed restating rather than silently inheriting.
- `DownloadSourceInventoryTests.swift:154-155` — "whose single implementation serves **both** of its
  call sites".

`expectedFloorWriters` counts *assignments to `lastPushedCompletedPageCount`*, and the bracket's
single implementation keeps that count at 5 no matter how many call sites it grows — so the census
this module points at as the owner of the claim is structurally unable to catch it. That is the
"exhaustive-sounding inventory that source quietly answers with one more entry" the same file warns
about, recurring in the same round.

**Fix:** correct all three sentences to four call sites and name the validate-time one, restate the
no-deletion disposition for it explicitly, and add a call-site census for
`withdrawingCountedBasisMovement(` to `DownloadSourceInventoryTests` alongside the existing
scheduling-block and pending-list tables so the number is owned rather than re-asserted.

### WR-06: The shared test helpers extracted this round shipped alongside two private shadow copies of themselves

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift:514-600`;
`AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift:213-258`;
`AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:439-519`

**Issue:** `galleryFolderURL`, `pageFileURL`, `recordRealPageHashes` and `corruptPageFile` were
added to the shared `DownloadFeatureTestCase` extension in this change set, with a doc comment
whose entire justification is: "Three private copies could drift in two of them while every suite
stayed green, because each would simply be looking at a folder that is not there." The same change
set then left private copies in two of the three suites. Because a concrete-type extension shadows a
protocol-extension default, both suites bind to their own copies and the shared members are used by
`DownloadManifestSSOTInvariantTests` alone — so the extraction bought nothing and the predicted
drift is now live rather than hypothetical.

**Fix:** delete the `private extension DownloadValidationReconciliationTests` members
(`galleryFolderURL`, `pageFileURL`, `corruptPageFile`, `recordRealPageHashes`) and the
`private extension DownloadInspectionBasisTests` members (`galleryFolderURL`, `pageFileURL`,
`recordRealPageHashes`); keep only the genuinely suite-local `expectNoBlankHashedPageKeptItsFile`,
`downloadedCount` and `requirePage`. `DownloadFeatureTestHelpers.swift` is at 970 of a 1000-line
error limit, so no lines move into it.

### WR-07: The inspector's display path still performs a destructive filesystem probe, which is newly consequential now that status no longer derives from presence

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:365-370`
(`DownloadStore.swift:247`, `:739`, `:746`, `:756-762`)

**Issue:** `buildInspectionPages` genuinely writes nothing now, and its new doc correctly says so.
But its caller resolves rendering resources through `storage.existingPageRelativePaths` →
`pageFileScan` → `probeAssetFile`, and `probeAssetFile` **deletes** any file it classifies
`.rejected` via `discardRejectedAsset`. So merely opening the inspector (or any
`reloadDownloadIndex`) can remove a zero-byte or non-regular page file.

Before D-SSOT-07 that deletion was self-consistent: the page's status came from presence, so it
immediately read `.pending`. Now the status comes from the manifest hash, so the page goes on
reading `.downloaded` over a file the display path just destroyed — a record/disk divergence created
by a read, licensed by no reconciliation, and invisible until the user runs Validate. The
`DownloadManifestSSOTInvariantTests` family-2 probe cannot catch it because its mutations write
non-empty bytes.

**Fix:** give `pageFileScan` a non-discarding mode for the rendering-resource caller (or move
`discardRejectedAsset` behind an explicit `reconciling:` flag that only the reconciliation paths
pass), so a display read classifies without mutating. Add an SSOT case whose external mutation
truncates a claimed page to zero bytes and assert that `loadInspection` leaves the file alone.

### WR-08: The D-SSOT-03 held family has no invariant case, and its widened retry queues a run that fetches nothing and clears the error anyway

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift:322-502`;
behavior at `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:80-95` and
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:895-923`

**Issue:** `DetailReducer.swift:104-113` names two families that can reach the error surface
claiming every page: the wholesale-unverifiable one and the operation-level one. `SSOTStateCase.all`
covers only the first (`refusedWholesaleAfterValidating`). The second — a complete-claiming record
under a `validationErrors` entry because a page's bytes could not be read, staged in
`DownloadValidationReconciliationTests.testAnUnreadablePageHoldsWhileAMismatchedSiblingStillReconciles`
— is never driven through family 3.

Driving it by hand shows why that matters. `retryablePageIndices` returns the whole page set,
`retryPages` clears `validationErrors` at enqueue and queues a `.repair`, and the run's
`pendingPageIndices` then filters the selection down to pages whose file is **missing**
(`ExecutionSupport.swift:913-922`) — an unreadable-but-present file is not missing, so the run
fetches nothing, finalize re-merges nothing, and the gallery settles back to `.completed`. The user
tapped the affordance, the error disappeared, and the unreadable page was never touched. Family 3
would pass this case (it reaches `.queued`), which is exactly the "predicates alone are not enough"
gap the suite's own header warns about, one level further out.

**Fix:** add the held family to `SSOTStateCase.all` (stage via `0o000` on one page file, as the
reconciliation suite already does, with a `restorePermissions` teardown) and extend family 3's
success criterion past `.queued` for it — either the run must actually re-fetch the named pages, or
the operation-level entry must survive a retry that could not address it. If the run legitimately
cannot fix present-but-unreadable bytes, the honest affordance for that family is the destructive
route, and `retryablePageIndices` should not claim it.

---

## Disposition of Items Flagged as Known

Reviewed and agreed with the recorded disposition; no action requested:

- `DetailDownloadRepairPredicateTests.swift:13`, `:52-53` — "corrupt-in-place" named as a
  complete-claiming family member. Stale after the content arm, comment-only, and `DetailReducer`'s
  own doc already carries the correction. Agreed.
- `DetailReducer.swift:112` — cites `D-G5C-01`. The sentence's factual claims hold under D-SSOT-08;
  the decision ID is the only stale token. Agreed, though it is worth fixing in the same pass as
  WR-05 since both are stale-reference defects.
- The wholesale-refusal record reading `.completed` after relaunch until re-validated. Agreed: no
  file was destroyed on that path, the residual is pinned from both sides
  (`DownloadValidationReconciliationTests:288-301`, `:424-437`), and the alternative is letting a
  transient signal destroy recorded hashes. Note that CR-02 is *not* this residual — there the
  files really are gone.

---

_Reviewed: 2026-08-09T06:02:32Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
