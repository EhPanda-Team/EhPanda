---
phase: 15-continued-background-downloads
reviewed: 2026-08-09T16:18:27Z
depth: standard
files_reviewed: 66
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreHashTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 4
  warning: 0
  info: 0
  total: 4
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-09T16:18:27Z
**Depth:** standard
**Files Reviewed:** 66
**Status:** issues_found

## Summary

The continued-download implementation contains four release-blocking correctness or security defects. Most seriously, validation can delete rejected page files before the manifest reconciliation's wholesale guard, leaving a complete-claiming manifest after the files are gone. The folder rename API also accepts an unconstrained source path. Two additional state-boundary errors can falsely credit an old run to a new redo and can widen an invalid page retry into a whole-gallery repair.

The review applied the repository's manifest-as-SSOT and Swift concurrency rules. A direct SwiftPM test invocation could not start the tests because the package's implicit macOS 10.13 deployment target is lower than several dependencies' macOS requirements; findings below are therefore based on direct source and test tracing.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01 [BLOCKER]: Validation deletes rejected files before the wholesale reconciliation guard

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:123-126`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:226-243`, `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:404-407`, `AppPackage/Sources/DownloadClient/DownloadStore.swift:234-275`, `AppPackage/Sources/DownloadClient/DownloadStore.swift:823-846`

**Issue:** `validateImageData` first calls `storage.validate`, and `validatePages` obtains existing pages through the default destructive scan. `pageFileScan` defaults `discardingRejected` to `true`, so probing a zero-byte or non-regular page deletes it immediately. The subsequent reconciliation performs another default-destructive scan before evaluating the combined wholesale guard at line 243. For a complete one-page gallery with a zero-byte page, validation deletes the only file, the wholesale guard then refuses to blank the only hash, and the persisted manifest still claims completion. The in-memory `validationErrors` entry disappears on relaunch, so the app can again display the gallery as complete even though validation itself removed its file. This violates the manifest SSOT contract and contradicts the function's documented requirement that refusal precede every destructive act.

**Fix:** Make every evidence-gathering scan before line 243 non-mutating (`discardingRejected: false`) and extend the scan result to report rejected page identities separately from unprobeable pages. Include rejected claimed pages in `prospectiveBlankPages`, then remove their files only after the wholesale guard accepts the combined set and blank their hashes through the same guarded persistence/recovery path. Add a one-page zero-byte fixture that asserts a wholesale refusal leaves both the manifest and the file untouched.

### CR-02 [BLOCKER]: A prior run's incomplete observation is reused as proof for a later redo

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:212-220`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:730-780`, `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:28-43`, `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:830-843`

**Issue:** `observedIncompleteSessionGIDs` is keyed only by gallery ID and lives for the entire continued-processing session. Once a session observes a gallery incomplete, line 220 credits any later complete record for that GID at its full recorded page count. A reachable sequence is: gallery A is observed incomplete, A completes and retires while gallery B keeps the session alive, and the user queues an update/redownload of A before B drains. `performRetry` advances the queue-intent generation but `clearDownloadSessionState` does not retire A's old observation. On A's rejoin, its complete pre-redo manifest is therefore credited as current-session work, violating the queued-window-zero rule and presenting a false 100% contribution before the new run announces any work. The existing run-proof retirement does not solve this separate session-observation lifetime leak.

**Fix:** Scope incomplete observations to the queue-intent/run generation, for example `[GID: QueueIntentGeneration]`, and accept an observation only when it matches the work generation being measured. At minimum, every fresh queue intent (`retry`, `retryPages`, and already-known-gallery enqueue/resume paths) must remove the prior GID observation before the first post-enqueue snapshot. Add a two-gallery test that completes A, keeps the session alive with B, requeues A, and asserts A contributes zero until its new run establishes a basis.

### CR-03 [BLOCKER]: Folder rename permits source path traversal outside the download root

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:41-53`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:77-80`, `AppPackage/Sources/DownloadClient/DownloadStore.swift:132-134`

**Issue:** `renameFolder` normalizes only `newName`. It passes attacker-controlled `oldName` directly to `userFolderURL`, which merely appends the component to the root and performs no confinement check. Values such as `../Documents` standardize outside the download root, after which `moveItem` can move an arbitrary sandbox-accessible directory into the downloads directory. The delete path has an explicit root-containment check, but rename does not. Even if the current UI normally supplies a listed folder, this is a public client API and its filesystem boundary must enforce confinement itself.

**Fix:** Move rename into `DownloadStore` and require both resolved URLs to be direct children of `rootURL` after standardization/symlink-safe resolution. Reject an `oldName` unless it is already a valid normalized user-folder name (normalizing it silently would rename a different folder), reject separators and traversal components, and re-check containment immediately before `moveItem`. Add tests for `..`, `../name`, absolute paths, nested components, and symlink escapes.

### CR-04 [BLOCKER]: An invalid page selection silently expands into a whole-gallery repair

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:45-56`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift:155-169`, `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:899-926`

**Issue:** `retryPages` deduplicates caller-provided indices but never checks them against the gallery's `1...pageCount` domain. Payload normalization later removes invalid values and converts an empty filtered selection to `nil`. `pendingPageIndices` interprets `nil` as no selection and schedules every missing page. Consequently, `retryPages(gid:pageIndices: [0, 999])` reports success and widens the request into a whole-gallery repair. Stale inspection data after a page-count change or any malformed public caller can therefore trigger materially broader work than requested.

**Fix:** Validate the selection against the fetched download's page count at the `retryPages` boundary. If no requested index is valid, return a validation failure (or an explicitly documented no-op) and do not enqueue. Preserve a distinct explicit-empty selection through normalization so downstream code can never reinterpret it as an unrestricted selection. Add coverage for all-invalid and mixed valid/invalid arrays and assert that normalization never widens the selected set.

---

_Reviewed: 2026-08-09T16:18:27Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
