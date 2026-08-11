---
phase: 15-continued-background-downloads
reviewed: 2026-08-11T00:00:00Z
depth: standard
files_reviewed: 85
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppModels/Download/DownloadInspection.swift
  - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
  - AppPackage/Sources/AppTools/Defaults.swift
  - AppPackage/Sources/AppTools/LogsDirectoryMigration.swift
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
  - AppPackage/Sources/DownloadClient/DownloadClient+SeedReconciliation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/PageFileScan.swift
  - AppPackage/Sources/DownloadsFeature/DownloadInspectorReducer.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/Resources/ResourceStringSymbols.swift
  - AppPackage/Sources/Resources/Resources/Localizable.xcstrings
  - AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderOperationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorPauseFailureTests.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSeedRecoveryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreHashTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 0
  warning: 5
  info: 5
  total: 10
status: issues_found
---

# Phase 15: Code Review Report (fourth review, after gap-closure plans 15-70 … 15-77)

**Reviewed:** 2026-08-11T00:00:00Z
**Depth:** standard
**Files Reviewed:** 85
**Status:** issues_found

## Summary

Effort was concentrated on `git diff 3c84d648..HEAD` — the delta since the previous review report was
committed (plans 15-70 … 15-77 plus three follow-up commits), which touches 34 files — with a
standard-depth pass over the rest of the 85-file scope and a root-level re-derivation of all ten
prior findings.

Every prior finding is closed at its root, and I verified each one by reading the code rather than
the fix report. The new work is of the same quality as the rest of the phase. What it introduces is
one genuinely new module — `LogsDirectoryMigration` — that has not been through a review round yet,
and that is where four of the five warnings sit. The fifth is a deliberate, documented departure
from a binding project convention in the swipe-delete work.

### Verdict on the previous round's ten findings

| Prior ID | Verdict | Evidence I re-derived |
| --- | --- | --- |
| CR-01 (delete confinement refused listed folders) | **Closed at its root** | `confinedDirectUserFolderURL` (`DownloadStore+Operations.swift:655-674`) dropped the `normalizedUserFolderName(rawName) == rawName` clause and replaced it with an admission test whose terms are the listing's: empty / `.` / `..` / multi-component / control characters / gallery-shaped, plus the two parent comparisons. All four shapes the finding named (`Art  Books`, ` Photos`, `Manga\Vol1`, `Misc etc.`) now resolve. `DownloadFolderAdmissionTests` stages each one under its *own* on-disk name — the shape the refusal catalog structurally could not reach — and asserts disk, page bytes and all three record stores converge on delete, and that rename still MINTS its destination. The asymmetry (source admitted as written, destination normalized) is asserted inside the fixture, so a case that stopped discriminating fails. |
| WR-01 (`removeFolder(relativePath:)` dead public) | **Closed at its root** | The function is deleted, not demoted (`DownloadStore+Operations.swift:423-457` now goes straight from the doc to the URL-taking primitive). `grep` over `AppPackage/Sources` finds no `removeFolder(relativePath` anywhere. The replacement doc states what the deletion buys *precisely* — `folderURL(relativePath:)` is still public, so what remains is a two-function composition both docs refuse — which is the honest version of the "unwritable" claim the finding challenged. |
| WR-02 (`materializeRepairSeed` source scan deleted without reconciling) | **Closed at its root, by the simpler of the two options** | `DownloadStore+Operations.swift:174-177` now scans the source folder with the non-mutating default. The old comment's "this round did not answer it" is replaced by a verdict that names the record (`repairSeed` hands the gallery's currently-indexed folder), the entitlement test it fails, and the `displayDate`/mtime route by which the lying source could win `deduplicatedDownloadIndex`. The `discardingRejected: true` census is now 2 (both covers) and is owned by `testDiscardingRejectedSitesMatchTheEntitlementCensus`. |
| WR-03 (`prepareWorkingSeed` had the ordering without the compensation) | **Closed at its root** | `recoveredBlanking` was lifted to module-internal and returns `DownloadManifest?` instead of `Bool`, and both routes call the one implementation. `prepareWorkingSeed` now enumerates its three post-removal exits and handles all three (`+ExecutionSupport.swift:340-373, 431-500`): exit 3 returns a `Result` rather than throwing, so the bracket's second reading still runs — I checked that reasoning and it holds, a throw would unwind past the withdrawal and strand the monotonic floor. `WorkingSeed.removedPages` carries this-pass's own destructions, and `inheritedPages` subtracts them in **both** branches, which closes the over-report the finding named. `DownloadSeedRecoveryTests` pins the rescan-failure and thrown-write exits separately. |
| WR-04 (the "impossible at the type level" claim was false) | **Closed at its root, and made detectable** | Both docs now state the sibling rule as a convention (`+ExecutionSupport.swift:278-292`, `+Manager.swift:868-874`). `basisMovementDepth` is incremented/`defer`-decremented around every bracket and `reportIssue`s (never traps) above depth 1. `DownloadClient+Testing.swift:139-155` ships a `#if DEBUG` probe that writes the forbidden shape with a *real* production mover inside it, and `testANestedCountedBasisMovementIsDetectedWhileASiblingIsNot` wraps it in `withKnownIssue` — which fails if no issue is recorded — then asserts the following unnested advance records nothing and still advances the generation. That is a falsifiable detector, not a claim. |
| WR-05 (`toggleDownloadPauseDone(.failure)` silent) | **Closed at its root** | `DownloadInspectorReducer.swift:241-255` sets `state.toast = error.actionFailureToast` and reloads. The helper was renamed off `retryFailureToast` and its doc now states the mapping over `AppError` as a whole. `DownloadInspectorPauseFailureTests` pins both reachable kinds (`.notFound`, `.unknown`) plus the payload arm as a rename guard, with the exits enumerated from source in the suite header. The list screen's sibling stays silent and is recorded as an open item on `DownloadsReducer` (see IN-03). |
| WR-06 (unused private scanner + self-contradicting doc) | **Closed at its root** | `downloadsTestFiles(in:)` is gone; lines 27 and 65-72 of `DownloadSourceInventoryTests.swift` now name `clientModuleFiles(in:)`, `clientDoubleTreeFiles(in:)` and `clientDoubleFiles(in:)` and say "the two trees". |
| IN-01 (`waitForTaskValue` 10s default) | **Dispositioned, declined, and I agree** | `DownloadDeleteConvergenceTests.swift:111-126` writes out the argument in full — a wall-clock bound cannot separate a missing notification from an unscheduled collector, and 15-21 recorded this exact call site taking 13.2s under contention. The sibling detector points at that one owner instead of restating it. Not re-raised. |
| IN-02 (two localized-key spellings) | **Closed at its root** | All 22 `String(localized:)` sites in `DownloadClient` use `.RLocalizable.`; the module-local catalog is deleted, its `resources:` entry removed from `Package.swift`, and I diffed the 10 moved keys against the shared catalog — none missing, no value drift. |
| IN-03 (unswept refused page files) | **Not closed, and 15-71 widened it** — re-raised as IN-03. |

### Localization (independently verified, not trusted)

Parsed both catalogs as JSON.

- **Shared catalog** (`Sources/Resources/Resources/Localizable.xcstrings`): 43 keys, sorted, and every
  key carries all six locales (`de`, `en`, `ja`, `ko`, `zh-Hans`, `zh-Hant`) — 43/43 for each. No
  `shouldTranslate: false` entry exists, so that rule has nothing to violate. `continued_session.subtitle`
  is compliant: three named `%#@…@` substitutions with `argNum` 1/2/3, no bare numeric specifier in any
  outer value, `en` and `de` category sets equal per variable (`{other}`, `{one,other}`, `{one,other}`),
  and `ja`/`ko`/`zh-Hans`/`zh-Hant` `other`-only. The bare `%lld` values that remain (`download_store.page_missing`,
  `download_store.page_image_corrupted`, `pages`, `stars`, `days`/`hours`/`minutes`/`seconds`) are all in
  the **shared** catalog, where the rule is satisfied by hand-written labelled symbols — and each one has
  its labelled symbol in `ResourceStringSymbols.swift`.
- **`DownloadsFeature` catalog**: 20 keys, sorted, 20/20 per locale, and the three count-taking keys
  (`downloaded`, `pending`, `failed`) each use a named `count` substitution with no bare numeric anywhere —
  the module-local rule, satisfied.
- `continuedSessionSubtitle`'s inline `defaultValue` (the fix in `3abd49f8`) does stop the stray
  `%lld%lld%lld` extraction; I confirmed no such key exists in either catalog.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: A staged case-only rename can strand the user's activity logs in `Logs-migrating-<UUID>` permanently — no regime recovers it, and the code's own contract says the next launch will

**File:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:242-279`

**Related:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:63-66`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:109-117`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:170-178`,
`AppPackage/Tests/AppToolsTests/LogsDirectoryMigrationTests.swift`

**Issue:** `renameThroughStaging` moves the legacy directory to `Logs-migrating-<UUID>` and then tries
to move it onto `Logs`. Two of that function's three outcomes leave the staged directory standing,
and **nothing ever looks at it again**:

1. The second move fails, `mergeContents(of: staging, into: destination)` runs, and it returns
   `.merged(movedCount:skippedCount:)` with `skippedCount > 0`. `renameThroughStaging`'s
   `guard case let .failed(reason) = merged else { return merged }` (line 260) returns that value
   **without restoring**, so the staging directory survives holding the skipped files.
2. `restore` itself fails (line 276-278), which is dispositioned in the reason string only.

In both cases the next launch classifies from `regime(storedNames:currentSpellingResolves:)`, which
keys exclusively on the literal name `"logs"` (line 114). `Logs-migrating-<UUID>` is not that name, so
the regime is `.nothingToMigrate` and the migration returns at line 154 forever. The logs are neither
read (`FileUtil.logsDirectoryURL` resolves `Defaults.FilePath.logs`) nor merged nor removed — and the
directory is directly under `Documents`, which the app publishes through `UIFileSharingEnabled`, so
the user sees a permanent `Logs-migrating-B3F1…` folder in the Files app.

This contradicts the module's own stated contract twice. `Outcome.failed`'s doc says "the next launch
retries from the state left behind" (line 64-66); it does not, for any state `renameThroughStaging`
leaves. And `renameThroughStaging`'s doc argues only about a **crash** between the two moves — the two
non-crash exits above are not considered at all.

Reachability is narrow but real on device, not only in the simulator: `run`'s `.rename` arm falls back
to staging whenever the atomic move throws (line 177), which is exactly what a log write racing the
classification produces. `LogsDirectoryMigrationTests` covers `regime`, `mergeDecision`, `mergeContents`
and the two rename regimes, but **no case drives `renameThroughStaging`'s failure exits at all**, so
neither residual is pinned from either side.

**Fix:** Make the staged name recoverable rather than terminal, and pin it. The classification already
has the documents listing in hand, so add a fourth regime keyed on the staging prefix:

```swift
// LogsDirectoryMigration
private static let stagingPrefix = "\(Defaults.FilePath.logs)-migrating-"

public static func regime(storedNames: [String], currentSpellingResolves: Bool) -> Regime {
    guard Defaults.FilePath.logs != legacyDirectoryName else { return .nothingToMigrate }
    if let staged = storedNames.first(where: { $0.hasPrefix(stagingPrefix) }) {
        return .recoverStaging(named: staged)   // merge into `Logs`, or rename onto it when free
    }
    guard storedNames.contains(legacyDirectoryName) else { return .nothingToMigrate }
    ...
}
```

Route it through the existing `mergeContents` so nothing new can overwrite, and have the merge-with-skips
exit at line 260 fall through to `restore` as well (a partially merged staging directory is exactly the
"leave it for the next launch" state the doc promises). Add three cases: the merge-with-skips exit, the
`restore`-fails exit, and a second `run` over the directory each leaves behind asserting it converges.

### WR-02: `mergeContents` is `public`, recursively deletes its source on a stale-listing premise, and its own doc promises "Nothing is ever overwritten or deleted"

**File:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:188-232`

**Related:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:184-187`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:221-230`

**Issue:** The emptiness the removal rests on is decided from `sourceNames`, listed at line 196 — before
the move loop runs. The guard at line 223 (`decision.skips.isEmpty`) therefore asserts that the
directory was empty *as of that listing*, and line 225 then issues an unconditional
`try fileManager.removeItem(at: source)`, which on a directory is **recursive**. Anything that appeared
in `source` between the listing and the removal is destroyed without being counted, reported or logged.
The comment above it — "Only an emptied directory is removed, so a skipped file is never deleted along
with the directory that holds it" — states a property the code does not check.

Today no in-app path can reach that window: in the `.merge` regime `source` is `Documents/logs`, and
nothing writes there any more now that `Defaults.FilePath.logs` is `"Logs"`; in the staging path
`source` is a UUID-named directory nothing else knows about. But **`mergeContents` is `public`** and its
signature takes two arbitrary `URL`s with no stated caller constraint, while its doc line 187 says
"Nothing is ever overwritten or deleted." That sentence is the thing a future caller will trust, and it
is false about the one operation in the function that is irreversible.

**Fix:** Decide the removal from the disk at the moment of removal, and correct the doc.

```swift
guard decision.skips.isEmpty else { return .merged(movedCount: movedCount, skippedCount: decision.skips.count) }
// Re-listed rather than inferred: `sourceNames` describes the directory before the moves, and only
// an emptiness observed now licenses a recursive removal.
let remaining = (try? fileManager.contentsOfDirectory(atPath: source.path)) ?? ["<unlistable>"]
guard remaining.isEmpty else {
    return .merged(movedCount: movedCount, skippedCount: remaining.count)
}
do { try fileManager.removeItem(at: source) } catch { ... }
```

Then rewrite line 187 to say what is true: nothing is overwritten, no *file* is deleted, and the source
*directory* is removed only when a fresh listing shows it empty.

### WR-03: The migration's only failure diagnostic is redacted in the unified log, and the per-file errors behind it are discarded outright

**File:** `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift:56`

**Related:** `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift:48-54`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:204-219`

**Issue:** `logger.error("Failed to migrate the legacy logs directory: \(reason)")` interpolates a
dynamic `String` with no privacy specifier. `Logger` defaults non-literal interpolations to `.private`,
so on a device this line renders as `Failed to migrate the legacy logs directory: <private>` — the
message survives and the only part that carries information does not. The two `.notice` branches three
lines above mark their counts `privacy: .public` explicitly, so the omission reads as an oversight
rather than a decision, and this is the one branch where a field report matters.

It compounds with the producer. `mergeContents`' per-file `catch` (line 211-213) swallows the underlying
`error` entirely and the aggregate `reason` reports only `"N of M log files could not be moved"` — no
name, no errno. So even un-redacted the diagnostic could not identify which file or why. Between the
two, a migration failure in the field is undiagnosable, while `LogsDirectoryMigration`'s own header
claims "every failure becomes an `Outcome` the caller logs" (line 29-31).

This is not caught by `DownloadLogPrivacyInvariantTests`, and correctly so — that census scans
`DownloadClient` and `BackgroundProcessingClient` only, and its scoping rationale is sound. The gap here
is the opposite of the one it guards: too private, not too public.

**Fix:** Classify the reason deliberately. `Outcome.failed`'s payload is app-authored prose plus an
`error.localizedDescription`; none of it is gallery-derived, and the paths it can name are the app's own
container. Either mark it public —

```swift
case let .failed(reason):
    logger.error("Failed to migrate the legacy logs directory: \(reason, privacy: .public)")
```

— or, if the `localizedDescription` embedding is the concern, split the outcome into a public summary
and a private detail. Separately, have `mergeContents` accumulate `(name, error)` pairs and put the first
few into the reason so the summary names something actionable.

### WR-04: `moveDownload` dropped destination normalization but kept the call that CREATES the folder, so the public client API can now mint a name the app's own minting rules refuse

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:204-268`

**Related:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:576-581`,
`AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:655-674`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:648-656`,
`AppPackage/Sources/DownloadClient/DownloadClient.swift:36`

**Issue:** 15-70 replaced `normalizedUserFolderName(folderName)` + `confinedDirectUserFolderURL` with
`confinedDirectUserFolderURL(named: folderName)` alone, and the reasoning it gives is correct for the
**resolution** — a picked destination must not be rewritten into a neighbour of itself. But line 265 still
calls `try storage.ensureUserFolder(named: folderName)`, which **creates** the directory. So the one
site that was converted from minting to admitting is also the one site that mints, and the admission
test is deliberately looser than the minting test:

| name | `normalizedUserFolderName` (minting) | `confinedDirectUserFolderURL` (admission) |
| --- | --- | --- |
| `".hidden"` | rewritten to `"hidden"` (`trimsLeadingDots: true`) | admitted verbatim |
| `"  "` | rejected (empties) | admitted verbatim |
| `"Misc etc."` | rewritten to `"Misc etc"` | admitted verbatim |
| 400-byte name | truncated to `maxFolderComponentByteCount` | admitted verbatim |

`.hidden` is the sharp one: `directoryURLs(in:)` enumerates with `[.skipsHiddenFiles]`
(`DownloadStore.swift:654`), so `scanDownloads` will never list a dot-prefixed directory as a user
folder. A gallery moved into one is **not** in `fetchFolders()`, not in any folder filter, and its
record is dropped by the next index rebuild — the gallery disappears from the app while its files sit on
disk.

No in-app route reaches it: the move menu and the list dialog both offer values `fetchFolders()`
produced, and `scanDownloads` cannot produce a hidden or whitespace-only name. So this is a contract
defect rather than a live one — but `moveDownload` is a `public` endpoint on `DownloadClient`
(`DownloadClient.swift:36`) whose only guard is now a comment asserting what its callers happen to pass,
and the previous line of defence was removed in the same change that made the comment the guard.

**Fix:** Keep the picked-destination admission for the *resolution*, and refuse to create a name the
app would not mint. The two questions are different and both belong here:

```swift
guard let destinationParentURL = storage.confinedDirectUserFolderURL(named: folderName)
else { return .failure(.fileOperationFailed(String(localized: .RLocalizable.downloadStoreInvalidFolderName))) }
...
do {
    // Admitted as written for resolution, but a folder is only CREATED under a name this app would
    // mint: `ensureUserFolder` is a minting site, and a picked destination that does not exist is
    // not a destination the listing produced.
    if !fileManager.operate({ $0.fileExists(atPath: destinationParentURL.path) }) {
        guard storage.normalizedUserFolderName(folderName) == folderName else {
            return .failure(.fileOperationFailed(String(localized: .RLocalizable.downloadStoreInvalidFolderName)))
        }
    }
    try storage.ensureUserFolder(named: folderName)
```

(Equivalently: keep `ensureUserFolder` for the recreate-a-listed-folder case only, by checking existence
before rather than inside it.) Add the four rows of the table above to `DownloadFolderOperationTests`'
refusal catalog, asserted against `moveDownload` rather than only against `createFolder`.

### WR-05: The per-row delete confirmation is attached to the row, against the project convention that names this exact case — and the same file attaches its other dialog to the list

**File:** `AppPackage/Sources/DownloadsFeature/DownloadsView.swift:227-229`

**Related:** `AppPackage/Sources/DownloadsFeature/DownloadsView.swift:54-58`,
`AppPackage/Sources/DownloadsFeature/DownloadsView.swift:173-177`,
`AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift:73-101`,
`AppPackage/Sources/DownloadsFeature/DownloadRowFeature.swift:62-77`

**Issue:** `CLAUDE.md`'s placement rule ends with an explicit exception: *"for a per-row destructive
action whose row can scroll out of view, the stable action-source is the enclosing list container, so
attach it there."* The swipe Delete is precisely a per-row destructive action in a scrolling `List`, and
the dialog is attached to `DownloadRow`. The doc at lines 173-177 acknowledges the conflict —
*"That is in tension with the project's placement rule"* — and overrides it on the grounds that per-row
state buys per-row popover anchoring. That is a real trade-off, but it is an override of a binding
convention recorded only in a source comment, with no decision entry behind it and no test on the side
it gives up.

Two things make it worth fixing rather than accepting:

1. **The file is now internally inconsistent.** The list-level move dialog *is* attached to the container
   (line 56), and its comment points at the row for the delete one. A future contributor reading the
   convention and then this file gets two different answers about the same screen.
2. **The property it trades away is untested.** `DownloadsReducer.State.downloads`' setter matches by id
   so a presented dialog survives an `observeDownloads` tick (lines 89-101, and that is well argued and
   correct), but nothing pins the *other* half — a row leaving `visibleRows` while its dialog is up.
   That is reachable: `visibleRows` is derived from `filteredDownloads`, so a background repoint of the
   gallery's `folderName` under an active folder filter, or the gallery leaving the snapshot entirely,
   removes the row and takes its dialog with it mid-decision. `DownloadRowConfirmationTests` and
   `DownloadsSwipeActionSourceTests` cover the dialog's content and the button roles; neither covers the
   teardown the convention exists to prevent.

**Fix:** Either honour the rule or record the override where a rule can see it. To honour it, keep the
per-row *state* (which the `binding_initializer` argument in `DownloadRowFeature`'s header genuinely
requires) and hoist only the *modifier*: `DownloadsReducer` can project the single presented row's
dialog and attach it to the `List`, which is the shape the exception describes —

```swift
List { ForEach(visibleRows, id: \.state.id) { DownloadRow(store: store, rowStore: $0) } }
    .confirmationDialog($store.scope(\.presentedRowDialog, action: \.presentedRowDialog))
```

To keep the current placement, get an owner decision on record rather than a comment, and add a reducer
test asserting what happens when a row with a presented dialog leaves `rows` (today: the dialog vanishes
silently and the deletion never fires).

## Info

### IN-01: `LogsDirectoryMigration` exposes three members publicly for the test target alone, without the `#if DEBUG` discipline this same phase established for `DownloadClient`

**File:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:109`

**Related:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:126`,
`AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:188`,
`AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift:4-10`

**Issue:** `regime(storedNames:currentSpellingResolves:)`, `mergeDecision(sourceNames:destinationNames:)`
and `mergeContents(of:into:)` are `public` with exactly one caller each — `run`, inside the same type —
plus the test suite, which imports `AppTools` non-`@testable`. `DownloadClient+Testing.swift` states the
opposite discipline in this same phase: *"an unconsumed forwarder is attack surface rather than a seam"*,
and gates the whole seam behind `#if DEBUG`. `mergeContents` is also the member WR-02 shows carries an
irreversible operation, so the widened visibility is not free.

**Fix:** Make them `internal` and reach them with `@testable import AppTools`, or keep them public behind
`#if DEBUG` with the seam doc `DownloadClient` uses. `regime` and `mergeDecision` are pure and cheap to
keep public if that is preferred; `mergeContents` is the one that should not be.

### IN-02: `run` reports `.nothingToMigrate` for a legacy name that is a regular file, which is not what that outcome means

**File:** `AppPackage/Sources/AppTools/LogsDirectoryMigration.swift:156-160`

**Issue:** `Outcome.nothingToMigrate`'s doc says "Nothing was found to migrate, and nothing was created."
The `isDirectory` guard returns it for a case where something *was* found and deliberately skipped — a
user-dropped regular file named `logs`. The `AppDelegateReducer` then `break`s and logs nothing, so the
state is invisible. The skip itself is right (moving that file onto `Logs` would break logging outright,
as the comment says); only the reporting collapses two different facts.

**Fix:** Add a case — `case legacyNameIsNotADirectory` — and log it at `.notice`. `LogsDirectoryMigrationTests`'
`aRegularFileNamedLikeTheLegacyDirectoryIsLeftAlone` would then assert the specific outcome rather than
the generic one.

### IN-03: The unswept refused-page-file population from the previous round widened in 15-71

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:151-177`

**Related:** `AppPackage/Sources/DownloadClient/DownloadClient+SeedReconciliation.swift:91-101`,
`AppPackage/Sources/DownloadClient/DownloadStore.swift:792-812`

**Issue:** Carried forward, and recorded rather than re-argued. WR-02's fix took the source scan's
`discardingRejected: true` away, and its own comment names the cost: *"the refused file surviving in a
superseded folder when the run does not complete — IN-03's already-recorded unswept population, accepted
here rather than closed."* So the population that no sweeper clears now includes source-folder refusals
as well as unclaimed-page remnants. Correctness is unaffected — the probe's first-writer rule still
settles a page from a usable file, and `removeSupersededFolders` clears the folder on the completion
path — but repeated failed repairs accumulate orphan files with nothing to remove them.

**Fix:** No action required for correctness. If the accumulation matters, extend
`authorizedReconciliationScan`'s removal set to refuted files for pages the manifest does not claim —
those have no hash to diverge from, so they pass the round's own entitlement test — rather than
reintroducing a read-time sweep.

### IN-04: Four production files and four test files changed in this phase are absent from the review scope, including the newest production code

**File:** `.planning/phases/15-continued-background-downloads/15-REVIEW.md`

**Issue:** `git diff --name-only 5d9be716..HEAD` minus the 85-file scope leaves, among the source tree:
`AppPackage/Sources/DownloadsFeature/DownloadsView.swift`,
`AppPackage/Sources/DownloadsFeature/DownloadRowFeature.swift`,
`AppPackage/Sources/DownloadsFeature/Resources/Localizable.xcstrings`, `Config/Signing.xcconfig`,
plus `DownloadRowConfirmationTests.swift`, `DownloadsSwipeActionSourceTests.swift`,
`DownloadManifestSSOTStateCases.swift` and `DownloadProgressSeriesGuardTests.swift`. `DownloadsView.swift`
and `DownloadRowFeature.swift` are the *newest* production code in the phase (commits `0ea0699a`,
`9400680b`) and carry the whole swipe-delete confirmation design. I reviewed them anyway — WR-05 and the
localization verification above come from them — but a scope list that omits the last three commits'
production files is a gap in the harness, not in the code.

**Fix:** Derive the scope from `git diff --name-only <base>..HEAD` at review time rather than from a list
carried forward from the previous round.

### IN-05: `ListedFolderName` is a file-scope, module-internal enum in the test target with an unused `String` raw value

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderAdmissionTests.swift:121`

**Issue:** The catalog enum is declared outside the suite type and without `private`, so it is visible to
every file in `DownloadsFeatureTests` and can collide with a future name there. Its `String` raw value is
never read — nothing calls `rawValue` or `init(rawValue:)`, and Swift Testing takes case descriptions from
`CustomTestStringConvertible`/`description`, not from `RawRepresentable`. The rest of the suite's helpers
are correctly `private`.

**Fix:** `private enum ListedFolderName: Sendable, CaseIterable`. If the argument labels in test output
matter, add `CustomTestStringConvertible` returning `onDiskName`, which is more useful than the case name
anyway.

---

_Reviewed: 2026-08-11T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
