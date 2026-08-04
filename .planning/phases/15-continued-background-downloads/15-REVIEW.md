---
phase: 15-continued-background-downloads
reviewed: 2026-08-05T00:00:00Z
depth: standard
files_reviewed: 40
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
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
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
findings:
  critical: 1
  warning: 7
  info: 5
  total: 13
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 40
**Status:** issues_found

## Summary

The review was weighted, as instructed, toward the continued-session accounting seam: the monotonic
floor (`lastPushedCompletedPageCount`), D-G6-01's withdrawal, the session-start seed, the retirement
ledger, the trust set, and `schedulableDownloads()` as the single schedulable-work authority.

**What holds.** D-G6-01's arithmetic was re-derived rather than accepted. The withdrawal really is
atomic with the blanking (`writeManifest` and `updateDownloadIndex` are same-actor synchronous, and
`prepareWorkingSeed` stays non-`async`), and the exact-portion test mirrors `isSessionWork`'s first
disjunct exactly — `manifest.completedPageCount < manifest.pageCount` is the same predicate as
`DownloadedGallery.isIncomplete`. The session-start seed is not merely "safe in the under-seed
direction" as its comment claims: it is exact, because `schedulableSnapshot()` is a same-actor call
that cannot suspend, so the only window a withdrawal can land in is the `start` hop, which is
strictly after the snapshot read. The rejoin/retire interaction I expected to break also holds — a
reconciled gallery is necessarily `activeGalleryID` at that moment, so the WR-01 union puts it back
in the snapshot, and the announcing push's `reconcileRetiredSessionPages` runs *ahead* of the
nil-client guard, so a frozen retired value is released before a stale floor can latch onto it.

**What does not hold.** D-G6-01 was installed on a premise that is written down in two places and is
false: that `reconcileWorkingManifestAgainstPageFiles` is the accounting basis's *only* deliberate
downward mover. It is not. `ensureWorkingManifest` — one call earlier, in the same function — writes
a fresh all-empty manifest and re-indexes it, and `setupWorkingFolder` deletes the working folder
before it. That pair lowers a counted gallery's basis to zero and withdraws nothing, because the
withdrawal is attached to the *blanking loop* rather than to the *basis movement*, and the blanking
loop cannot fire on an all-empty manifest. The result is the same freeze G-15-6 described, reached
on a route one UI tap takes — and that tap is itself the one that starts the session. That is CR-01.

Seven warnings and five informational findings follow. IN-01, IN-02 and IN-03 are carried forward
from the previous review, which deliberately left them open; all three still hold at this HEAD.

No SwiftLint suppression, `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, `try?`,
`try!`, over-length line or debt marker exists in any reviewed source or test file. The localization
catalog conforms to the project's labeled-substitution rule (three named numeric substitutions,
`en`/`de` plural-category sets equal, `ja`/`ko`/`zh-Hans`/`zh-Hant` `other`-only). The plist
wildcard and the single `import BackgroundTasks` site are intact.

## Critical Issues

### CR-01: A wiped working folder lowers a counted gallery's basis with no withdrawal, re-opening the G-15-6 freeze on the `.redownload` route

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:376-402`
(also `:407-422`, `:453-483`; floor at `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:582-586`)

**Issue:**

D-G6-01's invariant is stated twice — on the reconciliation (`+ExecutionSupport.swift:338-351`) and
on the push (`+ContinuedSession.swift:537-548`) — as: *the accounting basis has exactly one
deliberate downward mover, and the floor masks only movements the coordinator did not deliberately
make.* Both statements are wrong. `prepareWorkingSeed` contains a **second** deliberate downward
mover, upstream of the reconciliation:

```swift
try setupWorkingFolder(folderURL:shouldReuse:seedContext:)    // :225 — deletes the folder when !shouldReuse
let manifest = try ensureWorkingManifest(payload:folderURL:)  // :231
```

and `ensureWorkingManifest` (`:407-422`) writes a fresh, all-empty manifest and re-indexes it:

```swift
let manifest = makeInitialManifest(payload: payload)
try storage.writeManifest(manifest, folderURL: folderURL)
updateDownloadIndex(folderURL: folderURL, manifest: manifest)   // :420 — the record drops to 0 / N
```

The withdrawal cannot see that. It is attached to the blanking loop, and the loop's guard
(`pages[page]?.isEmpty == false`, `:384`) never fires on an all-empty manifest, so control reaches
`guard blankedPageCount > 0 else { return manifest }` at `:388` and returns **before** the
counted-basis test and the withdrawal at `:394-400`.

The route is a first-class UI action, and it is the action that starts the session:

1. `AppPackage/Sources/DetailFeature/DetailView.swift:264` sends
   `.retryDownloadButtonTapped(store.downloadNeedsRepair ? .repair : .redownload)`.
   `downloadNeedsRepair` (`DetailReducer.swift:93-97`) requires
   `badge.progress.completedPageCount == 0`, so an errored gallery with **any** downloaded pages
   takes the `.redownload` arm.
2. `retry(gid:mode:)` (`+RetryHelpers.swift:9-26`) enqueues, schedules, and then calls
   `ensureContinuedSession()` at `:18`.
3. The session snapshot counts the gallery **raw**: `isSessionWork = download.isIncomplete || …`
   (`+ContinuedSession.swift:127-129`). With a record reading 6 of 10, the card opens at 6/10 and
   `lastPushedCompletedPageCount` is seeded to 6 (`:236-239`).
4. The run resolves `.redownload` (`queuedMode` → `effectiveRetryMode`, `hasUpdate` false),
   `shouldReuseWorkingFolder` returns `false` for `.redownload` (`+ExecutionSupport.swift:443-444`),
   the folder is deleted, `ensureWorkingManifest` writes an all-empty manifest and re-indexes → the
   record is now **0 of 10**.
5. `blankedPageCount == 0` → **no withdrawal**. The floor still holds 6.
6. `prepareWorkingSeedAnnouncingProgress` pushes (`:290-292`; the manifest is incomplete): honest sum
   0, `max(6, 0) = 6` → `"6 / 10 pages · 1 gallery"`. Every one of the next **six** page flushes
   pushes the same 6. The numerator does not move while six real pages download.

That is verbatim the reading D-11's stall-expiration policy punishes: the scheduler force-expires the
tasks reporting least progress, and `handleContinuedSessionEvent`'s `.expired` arm
(`+ContinuedSession.swift:299-302`) pauses **every** schedulable download. Both interleavings are
covered — if the wipe lands inside the client-start hop, the additive seed evaluates to
`max(6 + 0, 0) = 6` and the freeze is identical.

Two further instances of the same root cause, same fix:

- `validatedManifest` (`+PersistenceNormalize.swift:6-20`) returns `nil` when the payload's page
  count differs from the stored manifest's, and when the manifest is unreadable. Both drive
  `ensureWorkingManifest` down the same fresh-manifest branch on `.initial` and `.repair` runs, so a
  gallery that gained pages upstream, or whose manifest was truncated by a crash, drops its whole
  counted basis with no withdrawal.
- An `.update` of a gallery already in `observedIncompleteSessionGIDs` (trusted, therefore counted
  raw at its full `completedPageCount` per `:127-129`) is wiped by `shouldReuseWorkingFolder`'s
  `.update` arm and withdraws nothing. This is Table 3 row 3 of `15-26-SUMMARY.md`, reached through
  the un-blanked mover.

`15-26-SUMMARY.md`'s own sweep, Table 2 row 5, records `.redownload / .update / fresh .initial` as
"Blanks? no / Withdraws? no — **HOLDS**". That disposition is correct only for a basis that was
already zero; it is wrong for every counted (incomplete or trusted) record — exactly the population
D-G4-01's raw-counting half exists to serve.

**Fix:** Pair the withdrawal with the *basis movement*, not with the blanking. Keeping "whoever
lowers, withdraws" structural means computing the delta once, around the whole preparation, from the
record the snapshot actually reads:

```swift
private func prepareWorkingSeed(
    payload: DownloadRequestPayload,
    existingDownload: DownloadedGallery,
    folderURL: URL
) throws -> WorkingSeed {
    // D-G6-01: read the basis the numerator is summed from — the INDEX record — before any mover
    // runs, and withdraw whatever this synchronous stretch takes off it. Three movers exist, not
    // one: setupWorkingFolder's deletion, ensureWorkingManifest's fresh-manifest write, and
    // reconcileWorkingManifestAgainstPageFiles' blanking.
    let before = indexedDownloadRecord(gid: payload.gallery.gid)   // same-actor, no suspension
    let wasCountedBasis = (before?.isIncomplete ?? false)
        || observedIncompleteSessionGIDs.contains(payload.gallery.gid)
    let basisBefore = wasCountedBasis ? (before?.completedPageCount ?? 0) : 0

    // …existing body, with the withdrawal removed from reconcileWorkingManifestAgainstPageFiles…

    if continuedSessionID != nil, wasCountedBasis {
        let basisAfter = indexedDownloadRecord(gid: payload.gallery.gid)?.completedPageCount ?? 0
        lastPushedCompletedPageCount -= max(basisBefore - basisAfter, 0)
    }
    return seed
}
```

This also closes WR-05 (the working manifest and the index record no longer have to agree) and keeps
the unclamped-subtraction / additive-seed contract intact. Whatever shape is chosen, the two
paragraphs asserting a single downward mover (`+ExecutionSupport.swift:342-351`,
`+ContinuedSession.swift:537-548`) must be corrected, and the regression must stage a **counted**
gallery — an errored record with `completedPageCount > 0` retried with `.redownload` — and assert
that the first push after the wipe advances rather than repeating the pre-wipe numerator. Staging an
already-complete or untrusted record is vacuous here, exactly as blanking in a serial two-gallery
queue was vacuous for G-15-6.

## Warnings

### WR-01: The reconciliation persists an irreversible manifest edit from a probe that cannot distinguish "absent" from "unreadable right now"

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:376-402`
(signal sources: `AppPackage/Sources/DownloadClient/DownloadStore.swift:159-181`, `:375-391`,
`:562-584`, `:608-616`)

**Issue:** `reconcileWorkingManifestAgainstPageFiles` treats "not in `existingPages`" as
authoritative evidence that a page's file is gone, and acts on it destructively — it blanks the
recorded content hash, **writes the manifest to disk** and re-indexes. But `existingPages` is a
best-effort probe that swallows failure in three places:

- `existingAssetFileURLs` (`DownloadStore.swift:375-391`) returns `[]` on any `contentsOfDirectory`
  failure, with an explicit comment that the error is deliberately not logged.
- `existingPageRelativePaths` drops any page whose file fails `sanitizeAssetFileIfNeeded` (`:176`).
- `sanitizeAssetFileIfNeeded` (`:562-584`) falls back to `canReadNonEmptyFile` when
  `attributesOfItem` throws, and `canReadNonEmptyFile` (`:608-616`) returns `false` on **any**
  `FileHandle(forReadingFrom:)` or `read` failure — descriptor exhaustion, a transient `EBUSY`, a
  data-protection denial.

Before D-G5-01 the same empty answer was harmless: it only caused a re-fetch. It now mutates durable
state. A page whose file is present and intact but momentarily unreadable loses its recorded hash
(so `validateImageData` cannot content-verify it again until a full run re-hashes it), the record
drops by that count, `resumeMode` and `loadManifest`'s `.missingFiles` gate change answers, and —
with a session live — the floor is withdrawn for a correction that was never real. Nothing logs it.
This runs on every start mode, including the ordinary `.initial` resume that is Phase 15's main flow.

**Fix:** Make the destructive half require a positive signal. Have `existingAssetFileURLs` surface
enumeration failure (throw, or return an optional) instead of `[]`, and have
`reconcileWorkingManifestAgainstPageFiles` refuse to blank when the scan failed, or when it would
blank *every* claimed page of a folder whose manifest read succeeded. At minimum log at `.notice`
with the blanked count and the hash-masked gid, so a device archive can show whether a blanking was
real.

### WR-02: `moveDownload` holds a scheduling block across three suspensions and converges on none of its six exits

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:152-206`

**Issue:** `moveDownload` inserts `gid` into `schedulingBlockedGalleryIDs` at `:163` with a
function-scoped `defer`, then suspends at `fetchDownload` (`:167`), `moveItem` (`:195`) and
`reloadDownloadRecord` (`:200`, `:203`), and returns on six exits without ever calling
`scheduleNextIfNeeded()`. Its siblings `delete` (`+PublicAPI.swift:196-231`), `deleteFolder`
(`+Folders.swift:117-149`) and `commitPause` (`+Scheduling.swift:205-248`) all converge — the first
two were fixed in this phase.

While the block is held, `isSchedulableDownload` (`+Scheduling.swift:118-123`) excludes the gid. If
the moved gallery is the only schedulable work and any concurrent convergence lands in that window —
the `Task` spawned by `finishActiveTaskIfOwned` (`+Execution.swift:254-270`) is one —
`reconcileContinuedSession` reads `hasPendingWork() == false`, pushes a terminal pair, calls
`markContinuedSessionEnded` and `finish(_, true)`. The card goes down while the gallery is
milliseconds from being schedulable again, and D-03/SC3 provide no fallback tier: nothing restarts a
session without a fresh qualifying tap. This is the last un-swept member of the convergence family
this phase has now closed five times.

**Fix:** Release the block and converge on every exit, exactly as `delete` does:

```swift
// ACTIVE-OWNERSHIP CONVERGENCE: release before converging, or the scheduler skips this gallery.
schedulingBlockedGalleryIDs.remove(gid)
await notifyObservers()
await scheduleNextIfNeeded()
```

### WR-03: `schedulingBlockedGalleryIDs` is an uncounted `Set` released by `defer` across suspensions

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:372`
(insert / `defer remove` sites: `+PublicAPI.swift:183-186`, `+Folders.swift:100-106`, `:163-166`,
`+Scheduling.swift:194-197`)

**Issue:** Four sites insert a gid and remove it in a `defer`, and every one of them suspends while
holding it, on a reentrant actor. Because the set is uncounted, two overlapping operations on the
same gid release the block when the **first** one finishes — while the second still needs it. A
`pause` overlapping a `delete`, or a `delete` overlapping a `moveDownload`, therefore lets
`scheduleNextIfNeededCore` start a download whose folder the other operation is about to move or
remove. `moveDownload`'s own `activeGalleryID != gid` guard does not help: it runs before the block
can be lost.

**Fix:** Make it a reference count — `var schedulingBlockedGalleryIDs = [String: Int]()` with
`blockScheduling(gid:)` / `releaseScheduling(gid:)` helpers — and have `isSchedulableDownload` test
`schedulingBlockedGalleryIDs[gid] == nil`. Keep the `defer` shape so no exit can leak a block.

### WR-04: Nine session-lifecycle mutators are `public` with no production caller outside the module

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:121, 153, 192, 290, 324, 350, 410, 565`
and `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:280`

**Issue:** `schedulableSnapshot`, `continuedSessionSubtitle`, `ensureContinuedSession`,
`handleContinuedSessionEvent`, `markContinuedSessionEnded`, `pauseAllSchedulable`,
`reconcileContinuedSession`, `pushContinuedSessionProgress` and
`prepareWorkingSeedAnnouncingProgress` are all `public`. A grep over `App/`, `ShareExtension/` and
every `AppPackage/Sources/*` module other than `DownloadClient` returns **zero** callers for all
nine — they are public solely for the cross-module `DownloadsFeatureTests` target. Any of the
modules that link `DownloadClient` can therefore call `markContinuedSessionEnded(sessionID:)` or
`pauseAllSchedulable(expiring:)` and detach or cancel the live session. The module already carries
the correct pattern in `DownloadClient+Testing.swift` (`#if DEBUG` + a `testing…` prefix).

**Fix:** Drop these to package/internal access and expose whatever the suites genuinely need through
the existing `#if DEBUG` seam in `DownloadClient+Testing.swift`. Note this is a prerequisite for
CR-01's regression test, which drives the preparation directly.

### WR-05: The withdrawal's amount and its counted-basis test are read from a manifest the numerator is not summed from

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:394-400`

**Issue:** `wasCountedBasis` and `blankedPageCount` are both derived from the **working** manifest,
while the numerator is summed from the **index record** (`schedulableSnapshot` →
`schedulableDownloads` → `indexedDownloads`). Those are the same manifest only when the working
folder is the record's folder. They diverge on the re-slot-after-title-change path the codebase
explicitly supports (`+Execution.swift:78-81`): `folderRelativePath` resolves to the *new* title's
folder, `setupWorkingFolder` materializes a repair seed into it, and `updateDownloadIndex` then
replaces the record wholesale. When the record's `completedPageCount` and the working manifest's
disagree, the numerator's drop is not `blankedPageCount`, and the floor is left holding the
difference — the same freeze band as CR-01, narrower.

**Fix:** Subsumed by CR-01's suggested fix: compute the delta from the index record before and after
the preparation rather than from the working manifest's blanking count.

### WR-06: `resolveSource` force-unwraps `galleryURL` while the same file falls back for it

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:177`

**Issue:** `ThumbnailURLsRequest(galleryURL: payload.gallery.galleryURL.forceUnwrapped, …)` passes an
IUO into a non-optional `URL` parameter. `Optional.forceUnwrapped`
(`AppPackage/Sources/AppTools/Extensions/Optional+ForceUnwrapped.swift:7-13`) logs and returns
`nil`, so a payload without a `galleryURL` traps at the call boundary and kills the download run —
during a backgrounded continued-processing session, that is a crash the user sees as the card
vanishing mid-download. `Gallery.galleryURL` is `Optional`, and `resolvedImageSource` **in the same
file** (`:504`) handles the same value with `payload.gallery.galleryURL ?? payload.host.url`. Two
treatments of one optional, a few hundred lines apart, and the safer one is the sibling's.

**Fix:** Use the sibling's fallback, or throw explicitly:

```swift
guard let galleryURL = payload.gallery.galleryURL else { throw AppError.notFound }
```

### WR-07: The client spy consumes a one-shot `refuseNextStart()` on refusals it did not cause

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:264-268`

**Issue:**

```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
```

The reset sits inside a guard that fires for **two** reasons. When the refusal is caused by the
spy's single-session guard (`currentSessionID != nil`), an armed `refuseNextStart()` is silently
spent without having been the reason for anything. A case that arms a refusal and then races a
second start observes the refusal against the wrong call, and the arm it believes it still holds is
gone. Test-double fidelity flaws are how this phase's last three blockers survived their suites.

**Fix:** Reset only on the branch that consumed it:

```swift
guard $0.currentSessionID == nil else { return true }
guard !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
return false
```

## Info

### IN-01: `resumeMode`'s `storage.validate` branch is near-dead after D-G5-01

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift:47-52`
**Issue:** With the reconciliation making an interrupted repair's record honestly incomplete, the
`displayStatus == .inactive, download.isIncomplete` branch above it now catches nearly everything
that used to reach the `.missingFiles` probe. The probe stays reachable only for a complete-reading
record whose files vanished and which has not yet been run. Carried forward from the previous
review; still holds.
**Fix:** Leave it, but record on the branch why it is still needed, so a later reader does not delete
it as dead.

### IN-02: The privacy invariant cannot see an unclassified interpolation

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift:270`;
scanner at `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:30-50`
**Issue:** `url: \(requestURL?.absoluteString ?? "")` carries no explicit privacy classification. The
unified log defaults dynamic strings to private, so current behavior is correct, but the invariant
only greps for `, privacy: .public` — an interpolation with no classification at all is invisible to
it, and a gallery page URL is content-identifying. Carried forward; still holds.
**Fix:** Write the classification explicitly
(`\(requestURL?.absoluteString ?? "", privacy: .private)`) and consider a scanner rule that flags
interpolations carrying no classification.

### IN-03: `maskedCount >= 8` is an unexplained magic threshold

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:81`
**Issue:** The number pins nothing derivable — it is neither the current count nor a stated minimum
for a named set of log sites, so it drifts silently as logs are added or removed. Carried forward;
still holds.
**Fix:** Assert against a named list of the log messages that must be masked, or state in a comment
which eight sites the number corresponds to.

### IN-04: The dedupe in `schedulableDownloads()` is justified by a rationale that does not hold

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:35-37` and `:41-43`
**Issue:** The doc says the union "deduplicates because a gid reaching `indexedDownloads(gids:)`
twice would double that gallery's pages in the summed denominator". It would not:
`indexedDownloads(gids:)` (`+Persistence.swift:51-57`) builds `Set(gids)` and filters
`downloadIndex.values`, which holds exactly one record per gid, so a duplicate is impossible by
construction. The `!scopedGIDs.contains(activeGalleryID)` check is harmless, but its stated reason is
wrong — and a wrong reason is what later justifies a bad edit.
**Fix:** Correct the sentence to say the check is redundant defense, or drop the check.

### IN-05: `UncheckedBox` is a misnomer, and the pending-work suite has no case for the union it is named after

**Files:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:8-19`;
`AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift:7-24`
**Issue:** `UncheckedBox` is `Mutex`-backed and genuinely checked; the name invites the exact
`@unchecked Sendable` pattern the project bans at error severity. Separately,
`DownloadPendingWorkTests` declares itself the home of "the coordinator's schedulable-work predicate
against real queue state" but has one case and no coverage of the `activeGalleryID` union plan 15-26
added to that authority — the union's only pin lives in `DownloadContinuedSessionBasisTests`. Note
also that `DownloadContinuedSessionTests.swift` is 999 lines against a hard 1000-line `file_length`
error gate: one added line breaks the build.
**Fix:** Rename to `LockedBox`; add a `hasPendingWork` / `schedulableDownloads` case for the
active-but-unqueued state to `DownloadPendingWorkTests`; move a case out of
`DownloadContinuedSessionTests.swift` to restore headroom.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
