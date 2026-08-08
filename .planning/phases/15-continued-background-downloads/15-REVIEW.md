---
phase: 15-continued-background-downloads
reviewed: 2026-08-08T07:38:11Z
depth: standard
files_reviewed: 56
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreHashTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-08T07:38:11Z
**Depth:** standard
**Files Reviewed:** 56
**Status:** issues_found

## Summary

Adversarial standard-depth review of the continued-background-downloads phase: the
`ContinuedProcessingSession` / `ContinuedTaskScheduling` lifecycle in
`BackgroundProcessingClient`, the `BackgroundProcessingClient` dependency seam, the
`DownloadCoordinator` continued-session machinery (snapshot, credited-pages regimes,
retirement ledger, monotonic floor, D-G7-01 withdrawal brackets, drain branch, expiration
pause ownership), the repair-seed / manifest-reconciliation path in `DownloadStore`, the
`Info.plist` / `Package.swift` wiring, the localized card catalog, and the full test suite
including the census/inventory guards.

Every file was read in full and the high-risk logic was traced adversarially against its
documented invariants, with the phase's known failure mode (branch-scoped fixes missing
sibling exit paths) applied as a checklist:

- **Session lifecycle** — `start()`'s identity-before-submit ordering, the three
  `.unavailable` producers, `endSession`'s clear-state-before-terminal-actions ordering and
  the abandoned-identifier arm, the process-scoped register-once/resubmit-per-session rule
  (G-15-31), and the identity gates on `updateProgress`/`finish` are all consistent; the 13
  lifecycle tests in `ContinuedProcessingSessionTests` pin each ordering.
- **Credited-pages arithmetic** — the three regimes of `sessionCreditedPages`
  (live-basis measurement, honest record, D-G4-01 queued-window zero) were traced at the
  regime boundaries, including `pageCount == 0`, the announce handoff, and the run-exit
  freeze (`freezeSessionCreditForRetiringRun` while the basis still stands). The retirement
  ledger is added to numerator and denominator symmetrically in
  `pushContinuedSessionProgress`, the monotonic floor's only downward movers are inside
  documented `withdrawingCountedBasisMovement` brackets, and the run-exit retirement in
  `processDownload`'s `defer` precedes `finishActiveTaskIfOwned` on every exit path.
- **Active-ownership convergence** — every exit that clears ownership in `commitPause`,
  `delete`, `moveDownload`, and the error handlers releases its scheduling block, notifies,
  and re-schedules; `resume(gid:)` deliberately leaves `ensureContinuedSession` to its two
  callers (the `.inactive` toggle branch and the `.superseded` pause arm), and both were
  verified to call it.
- **Drain branch** — D-G2B-01's terminal push before `markContinuedSessionEnded` and
  D-G3-01's re-check of the drain predicate after the push's main-actor hop are present and
  ordered correctly.
- **Repair/reconciliation** — `reconcileWorkingManifestAgainstPageFiles` blanks hashes only
  on positive absence behind its three-line defence (scan-succeeded, unprobed-pages,
  all-or-nothing residual), and `materializeRepairSeed` carries source-side non-answers
  across the copy (G-15-19). Path containment via `validatedChildURL` guards traversal.
- **Catalog compliance** — `continued_session.subtitle` uses three labeled `%#@variable@`
  numeric substitutions with coherent plural-category sets per locale (en/de equal;
  ja/ko/zh-Hans/zh-Hant `other`-only), all keys carry all six locales, and the sole `%@`
  argument stays positional. No violations.
- **Pattern sweeps** — no debug artifacts, no `try!`/`as!`/`try?`, no
  `swiftlint:disable`, no empty catch blocks, no TODO/FIXME in the reviewed sources. The
  deliberate designs I probed (the kept `missingFiles` repair route, the UIBackgroundModes
  retention, the noop client's suspension points per G-15-36, the unserialized seam pushes)
  all carry WHY comments at the site.

One defect survives the sweep, in a test helper's declared contract. A sibling sweep of
every other labeled-tuple-returning helper in the suite found no second instance.

## Warnings

### WR-01: Tuple return labels contradict the returned values in `setupZeroBytePageFiles`

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift:382`
**Issue:** The helper declares its return type as `(sourceFolderURL: URL, destinationFolderURL: URL)` (line 382) but returns `(emptyPageURL, goodPageURL)` (line 409) — two page-**file** URLs inside a single gallery folder, not two folder URLs. The one current caller happens to destructure positionally with the correct local names (`let (emptyPageURL, goodPageURL) = try setupZeroBytePageFiles(...)`, line 147), so today's tests behave correctly, but the declared labels assert a contract the function does not fulfil. The project's `labeled_tuple_elements` lint rule exists precisely so tuple labels can be trusted; here they are actively wrong. A future test in this parameterized suite that accesses `.sourceFolderURL`/`.destinationFolderURL` by label would receive a zero-byte page file while believing it holds a gallery folder, silently constructing the wrong fixture — a test that passes (or fails) for the wrong reason. That makes this a latent test-reliability hazard, not a style preference.
**Fix:**
```swift
func setupZeroBytePageFiles(
    rootURL: URL, gid: String, storage: DownloadStore
) throws -> (emptyPageURL: URL, goodPageURL: URL) {
```
Rename the declared tuple labels to match the returned values (`emptyPageURL:`/`goodPageURL:`). The caller at line 147 already uses these names and needs no change.

---

_Reviewed: 2026-08-08T07:38:11Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
