---
phase: 15-continued-background-downloads
reviewed: 2026-08-05T00:00:00Z
depth: standard
files_reviewed: 52
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
findings:
  critical: 2
  warning: 5
  info: 0
  total: 7
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 52
**Status:** issues_found

## Summary

Reviewed the continued-processing session store and its scheduling seam, the download
coordinator's session accounting (D-G4-01 basis, D-G2-01 ledger, D-G7-01 floor withdrawal),
the pause/convergence paths, `DownloadStore`'s probe classification, and the phase's test
suite.

Mechanical gates were re-derived rather than trusted:

- **Lint budget.** No file in `Sources/DownloadClient` or `Sources/BackgroundProcessingClient`
  exceeds the 1000-line error threshold (largest: `DownloadStore.swift` at 808), and
  `awk 'length($0)>120'` over the changed Swift sources returned nothing.
  `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` exists and carries
  `parent_config: ../../../.swiftlint.yml`, per the new-module rule in `CLAUDE.md`.
- **Localization catalog.** `DownloadClient/Resources/Localizable.xcstrings` has 8 keys, each
  with all six locales. Parsed the JSON and printed every substitution's plural category set
  per locale: `continued_session.subtitle` exposes all three numeric arguments as named
  `%#@…@` substitutions (`completed`/`total`/`galleries`, `argNum` 1/2/3, `lld`), `en` and `de`
  category sets are identical per variable (`[other]`, `[one, other]`, `[one, other]`), and
  `ja`/`ko`/`zh-Hans`/`zh-Hant` are `other`-only.
- **Round 13's new censuses hold.** Independently re-derived by grep: `blockScheduling(` calls
  are Folders 2 / PublicAPI 1 / Scheduling 1 / Testing 1 = 5 (Manager's occurrence is the
  declaration, excluded by the scanner); mutations of `lastPushedCompletedPageCount` are
  ContinuedSession 4 / ExecutionSupport 1 = 5. The hash-masked log inventory pinned by
  `DownloadLogPrivacyInvariantTests` also matches source exactly (10 total, 3/1/1/2/3).
  `DownloadSourceInventoryTests`'s scanner correctly excludes declarations and comment lines.
- **Session store.** `ContinuedProcessingSession`'s identity-before-submit ordering, its
  adoption/stray gate, its at-most-once `endSession` and its per-request take-back all hold
  under adversarial tracing; the `.unavailable` arms correctly return a non-nil handle whose
  stream is already terminal, which the coordinator's consuming task then drains.

The two BLOCKERs below are narrow-branch correctness defects the suite does not reach, and
both sit next to a written premise that source contradicts — the same generator this phase has
lost four rounds to. WR-01 is a third instance of that generator, currently without behavioral
consequence.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: `pauseAllSchedulable` reads each gallery's queue-intent generation too late, so an expiration pause silently reverts a user action that landed earlier in the same loop

**Classification:** BLOCKER

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:356-366`

**Issue:**

```swift
func pauseAllSchedulable(expiring sessionID: UUID) async {
    let gids = await schedulableDownloads().map(\.gid)      // snapshot taken once
    for gid in gids {
        guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
        let expiration = ExpirationPauseOwnership(
            sessionID: sessionID,
            queueIntentGeneration: queueIntentGeneration(for: gid)   // read LAZILY, per iteration
        )
        _ = await pause(gid: gid, expiration: expiration)
    }
}
```

`ownsExpirationPause` (`DownloadClient+Scheduling.swift:271-278`) compares
`queueIntentGeneration(for: gid)` against `expiration.queueIntentGeneration`. Because the
expected generation is read at the top of *that gallery's own iteration*, the comparison can
only detect a mobilizing tap that lands **during that gallery's pause**. A tap that lands
after `gids` was computed but before the loop reaches gallery `B` advances `B`'s generation
*before* the loop reads it; the loop then records the already-advanced value, the comparison
succeeds, and the stale expiration pauses the gallery the user just mobilized.

Reachability, derived from source:

1. `pauseAllSchedulable` is entered only from `handleContinuedSessionEvent`'s `.expired` arm
   (`+ContinuedSession.swift:306-308`), which calls `markContinuedSessionEnded` **first**. So
   `continuedSessionID == nil` for the whole loop and the loop-level session guard passes on
   every iteration.
2. `pause(gid:expiration:)` suspends repeatedly per gallery — `fetchDownload`,
   `writeInitialPauseRecord`'s three awaits, the unbounded `await taskToCancel?.value`,
   `notifyObservers`, `scheduleNextIfNeeded`. The coordinator is a reentrant actor, so a
   user-initiated call runs freely inside that window.
3. Every queue-mobilizing entry point advances the generation and calls
   `ensureContinuedSession()` only **after** several awaits, so `continuedSessionID` is still
   `nil` in between. `enqueue(payload:)` is the clearest: `advanceQueueIntentGeneration` at
   `+PublicAPI.swift:99`, then `await queueStore.enqueue` (100), `await notifyObservers` (101),
   `await scheduleNextIfNeeded` (102), and only then `await ensureContinuedSession()` (107).
   The gallery is `.queued` in that window, so `commitPause`'s
   `[.queued, .active].contains(displayStatus)` guard admits it and the pause completes.

Net effect: the user taps Download on a gallery while the system-expired queue is being paused
and the gallery is silently removed from the queue again. `ensureContinuedSession` then finds
no pending work, so no session starts either — the tap produces nothing at all.

The suite does not reach this.
`DownloadContinuedSessionInterleaveTests.testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue`
stages a single gallery and lands the retry inside *that gallery's own* cancellation wait —
precisely the case the lazy read does cover.
`DownloadContinuedSessionExpirationTests` runs multi-gallery expirations
(`testExpirationResultIsIndependentOfEnqueueOrder`, 3 galleries) but never mobilizes anything
mid-loop.

**Fix:** capture every gallery's generation in the same synchronous stretch that captures the
gid list, so any tap after the expiration is detected regardless of loop position.

```swift
func pauseAllSchedulable(expiring sessionID: UUID) async {
    // One read, so a mobilizing tap landing anywhere after the expiration advances a
    // generation this loop has already RECORDED — not one it is about to read.
    let ownerships = await schedulableDownloads().map { download in
        (
            gid: download.gid,
            expiration: ExpirationPauseOwnership(
                sessionID: sessionID,
                queueIntentGeneration: queueIntentGeneration(for: download.gid)
            )
        )
    }
    for ownership in ownerships {
        guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
        _ = await pause(gid: ownership.gid, expiration: ownership.expiration)
    }
}
```

(The labelled tuple satisfies the project's `labeled_tuple_elements` rule; a small named struct
is equally fine.) `schedulableDownloads()` does not suspend today — it is a same-actor read of
`queueStore.gids` plus `indexedDownloads(gids:)` — which is the identical justification
`ensureContinuedSession` already records for its own guard, so the pair stays consistent.

**What would falsify this:** a production route in which every mobilizing entry point stamps
`continuedSessionID` *before* it advances the queue-intent generation. Grepping
`advanceQueueIntentGeneration(for:)` over `Sources/DownloadClient` gives exactly four callers —
`resume` (`+Scheduling.swift:360`), `performRetry` (`+RetryHelpers.swift:37`),
`performRetryPages` (`+RetryHelpers.swift:89`) and `enqueue` (`+PublicAPI.swift:99`) — and in
all four the `ensureContinuedSession()` call is the last statement of the enclosing public
operation, after the advance and after at least two awaits.

---

#### CR-02: a `.repair` whose working-manifest reconciliation is REFUSED reports zero session progress for its whole run, reproducing the terminal `0 / N` card D-G5-01 exists to prevent

**Classification:** BLOCKER

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:389` (announcement gate)
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:496-503` (the false written premise)
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:530` (the all-or-nothing refusal)
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:126-129` (D-G4-01 basis)

**Issue:** the D-G5-01 doc closes with

> "A genuinely all-pages-vanished repair is no longer reconciled: it falls back to the
> pre-D-G5-01 arc, where the seed's empty `existingPages` makes the run re-fetch every page and
> **the record's honesty catches up at flush time**"

The second half is false, and the state the first half describes is exactly what the whole
session-accounting design treats as a liveness hazard. Traced:

1. A completed gallery loses **every** page file (Files-app deletion, iCloud eviction, an
   external volume). Its manifest still claims all N hashes, so `manifest.isComplete` is `true`
   and `isIncomplete` (`completedPageCount < pageCount`) is `false`.
2. `storage.validate(...)` reports `.missingFiles`, which is what routes such a record to
   `.repair` — via `resumeMode`'s `storage.validate` branch (`+SchedulingHelpers.swift:62-67`)
   and via `queuedMode`'s `.error where lastError?.code == .fileOperationFailed` branch
   (`+SchedulingHelpers.swift:16-20`). `validateImageData(gid:)`
   (`+PersistenceNormalize.swift:102-107`) is the production writer that puts a
   complete-reading, all-files-missing record into exactly that `.error(fileOperationFailed)`
   state.
3. `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
   (`+ExecutionSupport.swift:586-587`), and `ensureWorkingManifest` finds a valid manifest and
   returns it verbatim.
4. `reconcileWorkingManifestAgainstPageFiles` blanks all N claimed pages, then hits
   `guard blankedPageCount < manifest.completedPageCount else { return manifest }` (line 530).
   With every file gone, `blankedPageCount == completedPageCount == N`, so the residual guard
   **refuses** and the manifest comes back complete.
5. `prepareWorkingSeedAnnouncingProgress` gates its announcement on
   `!workingSeed.manifest.isComplete` (line 389), which is now `false`, so the run makes **no**
   basis announcement.
6. `schedulableSnapshot`'s D-G4-01 basis is
   `download.isIncomplete || observedIncompleteSessionGIDs.contains(download.gid)`
   (lines 127-128). The record reads complete, and the trust set is only ever grown from
   `snapshot.incompleteGalleryIDs` — the only two additive writers are lines 264 and 529, both
   `formUnion(snapshot.incompleteGalleryIDs)`, verified by grepping every occurrence of
   `observedIncompleteSessionGIDs` in `Sources/DownloadClient`. So the gallery contributes
   **0** to the numerator and N to the denominator, for the whole run.
7. The record never becomes honest at flush time. `flushManifestPageProgress` →
   `refreshManifestPageFileHashes` (`DownloadStore+Operations.swift:179-208`) only ever assigns
   `pages[page] = try hashReadableAsset(...)`, a non-empty string, so `completedPageCount`
   (`pages.values.filter({ !$0.isEmpty }).count`) can only rise or stay. It can never fall to
   make `isIncomplete` true.
8. At completion the gallery departs untrusted, so `reconcileRetiredSessionPages` retires
   `observedSchedulablePages[gid] ?? 0` = 0 (line 512). The drain push then reports
   `0 / 1 page · 0 galleries` over a full N-page re-download.

That is G-15-5's exact shape — the maximally stalled reading the scheduler force-expires first,
which D-11 turns into a pause of every schedulable download — surviving inside the branch
G-15-9's positive-signal defence introduced.

`DownloadContinuedSessionLedgerTests.testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`
covers K = 1 missing page of 6, where the reconciliation *proceeds* (`1 < 6`). Nothing covers
K = N, where it refuses. `DownloadRepairSeedSignalPropagationTests` covers the
unprobeable-vs-absent distinction across the seed copy, not this refusal.

**Fix:** the basis has to follow "this run has real page work over a complete-reading record",
not "the manifest reads incomplete". The seed already knows: `workingSeed.existingPages` is
short of the manifest's page count exactly when the folder cannot supply the claimed pages.
Admit the gid to the trust set there, inside the existing announcement, and delete the
"catches up at flush time" sentence from the D-G5-01 doc.

```swift
func prepareWorkingSeedAnnouncingProgress(
    payload: DownloadRequestPayload,
    existingDownload: DownloadedGallery,
    folderURL: URL
) async throws -> WorkingSeed {
    let workingSeed = try prepareWorkingSeed(
        payload: payload,
        existingDownload: existingDownload,
        folderURL: folderURL
    )
    // The record's own incompleteness is the common case. A REFUSED reconciliation leaves a
    // complete-reading record over a folder holding none of its claimed pages, and every page
    // this run downloads would otherwise count as zero session work for its whole life.
    let hasUnreusablePages = workingSeed.existingPages.count < workingSeed.manifest.pageCount
    guard let continuedSessionID, !workingSeed.manifest.isComplete || hasUnreusablePages else {
        return workingSeed
    }
    observedIncompleteSessionGIDs.insert(payload.gallery.gid)
    await pushContinuedSessionProgress(sessionID: continuedSessionID)
    return workingSeed
}
```

The explicit `insert` is required *in addition to* the push: the push's `formUnion` is sourced
from `snapshot.incompleteGalleryIDs`, which by construction cannot contain a complete-reading
record, so an announcement alone changes nothing on this branch. Add a ledger case at K = N
(write the fixture's manifest complete and stage **no** page files) asserting the drain reports
`N / N`, not `0 / 1`.

**What would falsify this:** (a) a production path that lowers `completedPageCount` for a
repaired record — the only manifest/index writers in the module are
`reconcileWorkingManifestAgainstPageFiles` (refuses on this branch), `ensureWorkingManifest`
and `writeInitialManifest` (fresh manifests, not taken for `.repair` with a valid stored
manifest), `refreshManifestPageFileHash(es)` (monotone, above) and `addingCurrentFileHashes`
(fills empty hashes only); or (b) proof that no production route can request `.repair` for a
complete-reading record whose files are all gone — but `resumeMode`'s `storage.validate` branch
exists precisely to route that state to `.repair`, and its own doc names case (a) "the
reconciliation REFUSED its destructive half" as one of the two states that still arrive there.

### Warnings

#### WR-01: `schedulableDownloads()`'s "one authority" premise is contradicted by the scheduler, in two doc sites

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:17-41`
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:387-388`
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:38-53`

**Issue:** `schedulableDownloads()` is documented as

> "The one authority for selecting work the scheduler can run. **Scheduling**, the pending-work
> gate and the continued-session card all select through this function, so queue lifetime and
> reported counts cannot acquire separate definitions."

and `+Manager.swift:387` restates it as "the single authority the card, the pending-work gate
and **the scheduler** all read". Source disagrees. Grepping `schedulableDownloads()` over
`Sources/DownloadClient` yields exactly three call sites plus the declaration:
`schedulableSnapshot()` (`+ContinuedSession.swift:122`), `pauseAllSchedulable`
(`+ContinuedSession.swift:357`) and `hasPendingWork()` (`+PendingWork.swift:14`). The scheduler
is not among them: `scheduleNextIfNeededCore` (`+Scheduling.swift:38-53`) performs its own
`indexedDownloads(gids: queuedGIDs)` read and applies `isSchedulableDownload` through
`nextQueuedDownload` / `nextUnqueuedSchedulableDownload`.

What is genuinely shared is the *predicate* (`isSchedulableDownload`), not the *read scope*.
The scheduler's scoped read deliberately does **not** carry the active-gallery union that WR-01
added to `schedulableDownloads()` (`+PendingWork.swift:45-47`), so the two disagree in exactly
the state that union was written for. Today the divergence is inert because
`scheduleNextIfNeededCore` returns at `guard activeTask == nil` whenever an active gallery
exists, but the invariant as written is false — and this phase's recorded defect generator is
a later fix reasoning from a census source no longer answers to.

**Fix:** state what is actually shared, and name where the scheduler's own read lives.

```
/// The read authority for the pending-work gate and the continued-session card.
///
/// The scheduler shares the PREDICATE (`isSchedulableDownload`) but not this read:
/// `scheduleNextIfNeededCore` scopes its own `indexedDownloads(gids:)` to the persisted
/// queue and does not carry the active-gallery union below. That divergence is inert only
/// because the scheduler returns at `guard activeTask == nil` whenever an active gallery
/// exists; anything that changes that guard has to revisit this.
```

Correct the matching sentence at `+Manager.swift:387-388`, and consider adding a
`schedulableDownloads()` call-site census to `DownloadSourceInventoryTests` so the claim is
owned rather than merely corrected.

---

#### WR-02: `BGTaskScheduler.register` is called lazily at first session start, not before launch completes

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift:66-80`
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:141-152`
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift:60-68`

**Issue:** `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)` is
invoked only from `ContinuedProcessingSession.start`, which runs on the first qualifying user
tap — arbitrarily long after `application(_:didFinishLaunchingWithOptions:)` returns. Grepping
`BGTaskScheduler` across `App/` and `AppPackage/Sources` returns hits in exactly one file
(`ContinuedTaskScheduling.swift`), so there is no launch-time registration anywhere, and
`AppDelegate` registers nothing.

Apple's documented contract for `register(forTaskWithIdentifier:using:launchHandler:)` is that
launch handlers are registered before the application finishes launching. The module's docs
cover identifier uniqueness, handler permanence and Info.plist permission at length but say
nothing about *when* registration is legal — while the phase did record a comparable open
question next to it (`App/Info.plist:160-165`: "No Apple source states whether a
continued-processing submission consults `UIBackgroundModes` … Removing it would need a
device-verified experiment of its own").

This is raised as an unresolved contract question, not an asserted runtime failure: whether a
post-launch `register` is honoured for `BGContinuedProcessingTask` is not derivable from this
repository. It matters because the store's design — a fresh UUID identifier minted per session
— makes pre-launch registration structurally impossible, so the exemption is load-bearing for
the entire design.

**Fix:** record a device-verified note beside `ContinuedTaskScheduling.live.register`, in the
same shape as the Info.plist note, stating that post-launch registration is accepted for
wildcard-permitted continued-processing identifiers and how that was verified. **What would
falsify the concern:** an Apple statement that continued-processing identifiers are exempt from
the pre-launch registration rule — in which case that statement is exactly what the comment
should cite.

---

#### WR-03: `restoredIndices` computes a `prefix` that is always the whole array

**Classification:** WARNING

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift:42-46`

**Issue:**

```swift
let restoredIndices = Set(
    progress.results
        .prefix(progress.completedCount)
        .map(\.index)
)
```

`progress.completedCount` is assigned `progress.results.count` at line 97 inside
`initializePageDownloadState`, immediately before this runs, with no other writer in between
(the only other mutation, `progress.completedCount += 1` at line 254, happens later inside
`applyPageTaskOutcome`). The `prefix` therefore always returns the entire array. It reads as a
deliberate bound and is not one, which invites a future reader to preserve a relationship that
does not exist.

**Fix:**

```swift
let restoredIndices = Set(progress.results.map(\.index))
```

---

#### WR-04: stray trailing blank line before the closing brace of two extensions

**Classification:** WARNING

**Files:**
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:625`
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:370`

**Issue:** both files end their `extension DownloadCoordinator` block with an empty line between
the last member's `}` and the extension's `}`. The project config does not catch it
(`vertical_whitespace_closing_braces` is opt-in and is not listed in the root
`.swiftlint.yml`), and no other file in the module does this — it is residue from the
round-by-round edits rather than a formatting choice.

**Fix:** delete the blank line in both files.

---

#### WR-05: unintended trailing comma in a parameter list

**Classification:** WARNING

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift:54-57`

**Issue:**

```swift
public func clearSelectedFailedPages(
    gid: String,
    selectedPageIndices: [Int],
) {
```

Swift accepts the trailing comma, so this compiles and lints clean, but it is the only
occurrence in `Sources/DownloadClient` and reads as an unfinished edit rather than a style
decision.

**Fix:** remove the trailing comma after `selectedPageIndices: [Int]`.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
