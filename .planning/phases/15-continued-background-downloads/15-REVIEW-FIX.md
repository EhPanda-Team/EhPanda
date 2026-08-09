---
phase: 15-continued-background-downloads
fixed_at: 2026-08-09T09:06:33Z
review_path: .planning/phases/15-continued-background-downloads/15-REVIEW.md
iteration: 2
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-08-09T09:06:33Z
**Source review:** `.planning/phases/15-continued-background-downloads/15-REVIEW.md`
**Iteration:** 2

The iteration-1 report (a single-finding pass against the previous review) is preserved in history
at `c94c085c`; this file replaces it with the report for the current review's ten findings.

**Summary:**
- Findings in scope: 10 (2 critical, 8 warning; scope = `critical_warning`)
- Fixed: 10
- Skipped: 0

Two findings were fused by the review's own amendments: **CR-01 absorbs WR-04** (the coverage
identity CR-01 needs is exactly what gives `ContentMismatchScan.verified` a reader), and **WR-07 was
committed in two parts** (the production change, then the consumer re-derivation its changed basis
forced). Every other finding is one atomic commit.

## Rulings applied

This pass ran under the amendments recorded at `15-REVIEW.md` line 444 (committed `4e70160b`). Two
of them changed what "as instructed" means, and both were raised as decision checkpoints *before*
any code was written rather than deviated from silently:

- **CR-02, pin (a) retargeted to exit 1 (Q1, Option A).** The pin as originally written named a
  production write seam that does not exist in the shape the review assumed; the ruling retargeted
  it to the first post-removal exit and sanctioned a count-keyed test double on two conditions —
  document the listing choreography inside the double, and assert the armed failure was consumed
  **exactly once**. Both are honoured; the consumption assertion is the *first* assertion in the
  test, so a double that never fired cannot let the test pass vacuously.
- **WR-08 resolved as a dispositioned residual (Q5, Option C).** All three proposed remedies
  collided with binding invariants (re-fetching present files rewrites the missing-only filter the
  D-SSOT-04 laundering defence rests on; keeping the entry across an enqueue re-creates the G-15-5
  dead end; narrowing the basis cannot separate the two families without consulting the disk, which
  D-SSOT-07 forbids). Current behaviour is therefore pinned as a known residual and recorded in
  both this report and the `D-SSOT-08` doc, with the sanctioned follow-up named.

**D-SSOT-04 was not weakened by any route.** The rejected order reversal is not present; CR-02's fix
keeps removal first and makes the *write* recoverable instead. No `swiftlint:disable` was added, and
no rule was relaxed.

## Fixed Issues

### CR-01 (+ WR-04): Unclassified pages are not counted as a hold, so `validationErrors` clears over unanswered evidence

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift`
**Commit:** `8c453708`

**Applied fix:** `claimedPages` was lifted to the caller so the pass can state a *partition identity*
rather than an ad-hoc union. `prospectiveBlankPages(claimedPages:presenceScan:mismatchedPages:)` and
a new `unclassifiedPages(claimedPages:contentScan:prospectiveBlankPages:)` together make the claimed
set exhaustive: every claimed page is verified, mismatched, held, prospectively blanked, or
unclassified. The residual joins the hold set —
`heldPages = contentScan.held ∪ unremovedPages ∪ unclassifiedPages(…)` — so a page the scan could
not answer for keeps the operation-level entry alive instead of being silently dropped, which is
what made Validate unreachable.

**WR-04 absorbed:** `ContentMismatchScan.verified` is no longer dead because the partition identity
subtracts it; its doc comment now names `unclassifiedPages` as the reader, so the next reviewer can
see why the field exists without re-deriving it.

**Falsifiability banked:** three independent mutations were confirmed to fail the new tests
(including flipping `canValidateImageData` to `false`), so the coverage is not vacuous.

### CR-02: Mismatched page files are destroyed before anything durable is written

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift`
**Commit:** `f2f7ab60`

**Applied fix:** the primary remedy in the review (reverse the order — write first, remove after) was
**REJECTED** by the amendments and is *not* implemented, because that ordering launders a refuted
file into the record: `retryPages` clears the entry, `pendingPageIndices` then fetches only pages
whose file is **missing**, so a surviving corrupt file is skipped and `addingCurrentFileHashes`
re-records the corruption as truth. Removal therefore stays first, and the *write* is made
recoverable instead:

- `let removedPages = contentScan.mismatched.subtracting(unremovedPages)` names precisely the pages
  whose files this pass destroyed.
- `blankingPass(gid:manifest:folderURL:)` performs one bracketed attempt — it is the sole
  `withdrawingCountedBasisMovement(` call site in this file and takes its own **fresh** scan, so the
  D-G7-01 bracket is never nested.
- `recoveredBlanking(gid:manifest:removedPages:folderURL:)` retries the pass exactly once when the
  record still claims a page this pass deleted (`DownloadManifest.claimsAnyPage(in:)`), and on a
  second failure logs an error naming the page list publicly and the gid hash-masked.

The counter-intuitive ordering is documented **in the source**, at the function, with the laundering
chain spelled out and the recover-once contract stated — the design reads as a bug without it.

**Pin (a) — retargeted to exit 1 per the ruling.**
`testATransientPostRemovalRescanFailureRecoversSoTheDurableBlankStillLands` drives a
`PostRemovalListingFailureFileManager`: removing an item **arms** a one-shot failure, and the next
directory listing fails once. The double's listing choreography is documented at the type, and the
test's **first** assertion is `control.consumedFailureCount == 1`, so it cannot pass without the
failure having actually fired. The control object is `Mutex`-backed and separate from the
`sending FileManager`, because the manager's ownership is transferred and cannot be observed after.

**Pin (b) — `.immutable` staging, with the empirical confirmation the ruling asked to record.**
`testAnUnwritableManifestKeepsTheEntryAndTheNextValidateConvergesTheRecord` stages an unwritable
manifest with the BSD `.immutable` flag. **Empirically confirmed on this machine:** an atomic write
over an immutable file throws `NSCocoaErrorDomain` code **513** (backed by `EPERM`), while the
enclosing folder stays writable and page-file removal still succeeds — which is exactly the regime
the pin needs (removal lands, write does not). The flag is cleared in a `defer` declared *after* the
tree-removal `defer` so it runs first, and the test's first post-staging assertion names the staging
premise. Noted honestly: this is a **characterization/regression** pin, not a falsifier, since the
recovery-fails outcome equals the pre-fix outcome.

**Log-privacy census 10 → 11 (Q3, accepted as a structural pin).** `recoveredBlanking`'s error log is
the first hash-masked identity log in `DownloadClient+PersistenceNormalize.swift`, so
`expectedHashMaskedCounts` gains that file with count `1` and the total moves from 10 to 11. The
census is an **owned inventory**, not a mirror of observed output: the entry is justified in prose
next to it, so a future unexplained log cannot be absorbed by bumping a number.

**Falsifiability banked:** seven mutations were confirmed to fail, including the post-relaunch case
where the record reads `.completed` over files this pass deleted.

### WR-01: The widened retry selection blanks every page it sends

**Files modified:** `AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRetryTests.swift`
**Commit:** `741d0c68`

**Applied fix:** the `.retryPages` optimistic overlay now skips pages that are already `.downloaded`,
so the page list stops contradicting the badge beside it. A page is rewritten to `.pending` only
when it is both in the retry selection **and** not already downloaded; every other page is returned
unchanged. `testDownloadInspectorLeavesDownloadedPagesAloneWhenTheRetrySelectionCoversThem` pins it.

### WR-02: The button says "Retry Failed Pages" while sending pages that never failed

**Files modified:** `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift`,
`AppPackage/Sources/DownloadsFeature/Resources/Localizable.xcstrings`
**Commit:** `455694ef`

**Applied fix:** key `retry_failed_pages` → `retry_pages`, label `.retryFailedPages` → `.retryPages`.
All six locales the catalog supports were updated together — "Retry Pages" / "Seiten erneut
versuchen" / "ページを再試行" / "페이지 다시 시도" / "重试页面" / "重試頁面". The label's doc notes it is
also the accessibility reading, so it is not silently changed to a shorter string later.

### WR-03: `enqueue` is the one enqueue site that does not clear `validationErrors`

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
**Commit:** `e70392cf`

**Applied fix:** `clearDownloadFailureState(gid:)` now runs immediately before
`advanceQueueIntentGeneration(for:)` in `enqueue`, with a doc naming the **G-15-5** dead end it
closes: session-scoped state that outranks queue membership in status derivation must be cleared at
or before enqueue, or the gallery can never reach a schedulable status.
`testEnqueueingARecordUnderAnOperationLevelEntryStillReachesTheQueue` pins the behaviour, and a new
`testQueueEnqueueCallSitesMatchTheRecordedCensus` (PublicAPI 1, RetryHelpers 2, Scheduling 1,
Testing 1 = 5) makes a *future* enqueue site that forgets the clear visible instead of silent.

**Falsifiability banked:** two mutations confirmed to fail.

### WR-04: `ContentMismatchScan.verified` is dead

Fused into **CR-01** (commit `8c453708`) by the review's own amendment — see that entry. The field is
now read by `unclassifiedPages`, and its doc names that reader.

### WR-05: The `withdrawingCountedBasisMovement` call-site inventory is stale in three places

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift`,
`AppPackage/Sources/DetailFeature/DetailReducer.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
**Commit:** `f9948572`

**Applied fix:** "three call sites" → "four", naming the validate-time one; "Neither call site
deletes" → "No call site deletes", with the validate-time caller's disposition stated explicitly
(its removals happen **before** the bracket opens, which is why the sentence stays true); and a stale
`D-G5C-01` reference corrected to `D-SSOT-08`. The count is then **owned** rather than narrated:
`testCountedBasisBracketCallSitesMatchTheRecordedCensus` records ExecutionSupport 2,
PersistenceNormalize 1, PublicAPI 1 = 4, so the next change to the bracket population fails a test
instead of quietly re-staling the prose. CR-02 was deliberately shaped as a *single* bracketed-attempt
helper so this count stays at four.

### WR-06: The shared test helpers shipped alongside two private shadow copies

**Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`
**Commit:** `5eed5dc8`

**Applied fix:** both private shadow copies deleted; the call sites now use the extracted shared
helpers, and the shared helpers' doc was strengthened so the next extraction does not re-fork them.
Only `expectNoBlankHashedPageKeptItsFile` remains local, because it asserts a file-level invariant
specific to that suite.

### WR-07: The inspector's display path still performs a destructive filesystem probe

**Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift`,
`AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTStateCases.swift`
**Commits:** `803e6d52`, then `8b4bfdbf` (consumer re-derivation)

**Applied fix:** a `discardingRejected: Bool = true` parameter was threaded through the probe stack —
`probeAssetFile(at:discardingRejected:)` (now explicit), `sanitizeAssetFileIfNeeded`, `pageFileScan`,
`existingPageRelativePaths`, `imageURLs`, `localCoverURL`, `existingCoverRelativePath`,
`existingCoverFileURL`, and both `existingAssetFileURL` overloads — with the deletion isolated in
`discardRejectedAssetIfPermitted(at:discardingRejected:)`. The **display and index-scan** paths
(`loadInspection`, and `makeRecord` on the `reloadDownloadIndex` path) now pass
`discardingRejected: false`. The default is unchanged, so every acting path keeps its housekeeping.
This is what "live file-presence scans are reconciliation **inputs**, never a competing display
basis" requires now that status no longer derives from presence: a read must not mutate the disk.

**Consumer re-derivation (`8b4bfdbf`).** One existing test keyed on the retired deletion:
`testDownloadCoordinatorLoadLocalPageURLsRemovesZeroBytePage`. Rather than patch the assertion to
whatever the new run printed, the expectation was **re-derived from the rule** — the read must still
*exclude* the zero-byte page, it must merely stop deleting it — and the test renamed to
`…ExcludesAZeroBytePageWithoutDeletingIt`. Two companions pin the rest of the boundary:
`testSanitizingLocalFilesStillDiscardsAZeroBytePage` (the acting path still discards) and
`testExistingPageRelativePathsKeepsZeroByteFilesWhenNotDiscarding` (the store's **classification** is
identical under both flag values — only the deletion is withheld, which is the whole premise of the
flag; if the two ever diverged, a read would report a different page set than the acting paths see,
which is a second basis by another name).

**Falsifiability banked:** the mutation where the display read deletes the file was confirmed to
fail the new pins.

### WR-08: The D-SSOT-03 held family has no invariant case, and its widened retry fetches nothing

**Files modified:** `AppPackage/Sources/AppModels/Download/DownloadInspection.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift`,
`AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTStateCases.swift`
**Commit:** `704b8dea`

**Applied fix (Option C — pin the current behaviour as a dispositioned residual).** The generated
invariant table gained the missing case, `unreadablePageHeldOverACompleteClaim`, plus two siblings
that arrived with the other findings (`unprobeablePageHeldBesideAReconciledOne`,
`truncatedClaimedPageSurvivesEveryDisplayRead`), taking `SSOTStateCase.all` from 9 to 12 regimes.
`D-SSOT-08`'s doc now records the residual in full:

> Two families reach this shape and are indistinguishable **at the record** — a wholesale
> reconciliation the irreversibility guard refused (files really gone) and a page whose bytes could
> not be **read** (file present and intact). For the first the `.repair` re-fetches everything; for
> the second it fetches nothing, because `pendingPageIndices` narrows any selection to pages whose
> file is **missing**. That family's effective affordances are re-Validate and the destructive route.

It is a residual rather than a defect-in-waiting because each narrower alternative costs more than it
buys, as recorded under "Rulings applied" above. **Named follow-up (Q6, sanctioned signal):** an
**operation-level FAMILY TAG** on the `validationErrors` entry — not a per-page verdict,
session-scoped like the entry itself, and moot after a relaunch (which equalizes the families
anyway). That is a **design round**, not a fix to smuggle into this pass.

## Skipped Issues

None. All ten findings were fixed.

## Verification

All gates were run on the final tree, one `xcodebuild` invocation at a time (never overlapping).

| Gate | Result |
| --- | --- |
| Full `FeatureTests` plan | `** TEST SUCCEEDED **` — 925 tests across 22 test runs, 0 failures |
| Clean app-scheme build | `** BUILD SUCCEEDED **`, 1794 compile tasks, **0 warnings, 0 errors** |
| SwiftLint `--strict`, all 21 touched Swift files | **0 violations, 0 serious** |
| `DownloadLogPrivacyInvariantTests` | `✔ Suite … passed` with the deliberate 10 → 11 inventory change |

The `file_length` limit (1000, error severity) was respected without suppression: when
`DownloadManifestSSOTInvariantTests.swift` reached 1002 lines, the generated-state table was **split
out** into `DownloadManifestSSOTStateCases.swift` with a doc note explaining the split. No regime was
dropped and no case's reasoning was thinned to fit — trimming coverage to satisfy a length rule would
have traded a real invariant for a formatting one.

The "known issues" reported by some suites are pre-existing `withKnownIssue` blocks, not new
failures.

---

_Fixed: 2026-08-09T09:06:33Z_
_Iteration: 2_
