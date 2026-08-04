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
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 40
**Status:** issues_found

## Narrative Findings (AI reviewer)

### Summary

Round 4, focused on the plan 15-25 mechanism (D-G5-01 reconciliation,
`prepareWorkingSeedAnnouncingProgress`, the merged session seed) plus a standard pass over the
rest of the phase's surface.

Three of the four things the brief asked me to probe came back clean, and I want to say so
plainly rather than pad the list:

- **The seed merge is correct.** The superseded-start rule really is carried by the
  `guard continuedSessionID == sessionID` at `DownloadClient+ContinuedSession.swift:221`, not by
  the assignment semantics that were removed; both collections are cleared by the same session's
  own synchronous reset at lines 197-200, and there is no `await` between the guard and the
  seed. `lastPushedCompletedPageCount` staying an assignment is safe for a reason the comment
  does not state but that holds: a push landing inside the client-start hop returns at
  `guard let clientSessionID = continuedClientSessionID` (line 556) *before* it reads or writes
  that scalar, and `continuedClientSessionID` is provably nil during the hop because its only
  writer is line 225 and `markContinuedSessionEnded` nils it before `hasLiveContinuedSession`
  can go false again.
- **The new suspension is accounted for.** `performDownload` has already suspended at
  `fetchLatestPayload` before it reaches the announcement, `pendingPageIndices` re-validates file
  presence on disk rather than trusting the pre-hop `existingPages`, and
  `downloadPages(existingManifest:)` consumes only `manifest.pages.keys`. Two concurrent pushes
  for one session mutate all state before their respective hops, so they cannot land out of order.
- **Trust-set arithmetic is sound.** `observedIncompleteSessionGIDs` is only ever fed from
  `snapshot.incompleteGalleryIDs`, which is the record-incomplete subset of the same read the
  basis was computed from; both clear sites are identity-gated; and a gid re-admitted after a
  same-session completion is counted exactly once, because `reconcileRetiredSessionPages` clears
  its retired entry on rejoin.

What did not come back clean is the arithmetic *around* the reconciliation. It is the first
mechanism in this codebase that can **lower** an already-counted gallery's `completedPageCount`
mid-session, and the session's monotonic floor is a single scalar over the whole-queue sum. In a
multi-gallery session that combination charges one repair's honest downward correction against
every other gallery's forward progress, freezing the card for as many pages as were blanked —
the same liveness failure family as G-15-5, reached from the fix rather than from the bug.

### Critical Issues

#### CR-01: The reconciliation lowers an already-pushed count, and the session's monotonic floor freezes the whole card

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:321-340`,
`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:563-567`

**Issue:**
`lastPushedCompletedPageCount` is a *session-wide scalar* floor applied to the *summed*
numerator:

```swift
let completedPageCount = max(
    lastPushedCompletedPageCount,
    sessionProgress.displayCompletedPageCount
)
```

Its correctness argument is written down on `pushContinuedSessionProgress`
(`DownloadClient+ContinuedSession.swift:524-529`): *"With the accounting basis no longer
shrinking, the one movement it still catches is a genuine regression in a gallery's own finished
count — pages disappearing from disk between two flushes."* D-G5-01 invalidates that premise.
`reconcileWorkingManifestAgainstPageFiles` now makes exactly that movement — pages disappearing
from a gallery's finished count — a **legitimate, coordinator-caused basis correction** rather
than a regression, and the floor cannot tell the two apart.

Reachable chain, entirely through the production contract:

1. Gallery G1 is `.inactive` with a record reading 99/100 because the user deleted its page
   files through the Files app — an integration the app ships deliberately
   (`UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace`). The record derives from the
   manifest's hashes, not the files, so `completedPageCount` stays 99.
2. Gallery G2 is queued alongside it. The user resumes/enqueues; `ensureContinuedSession`
   snapshots. G1's record reads incomplete, so D-G4-01's raw-counting half admits its 99 pages
   into the numerator, and line 226 seeds `lastPushedCompletedPageCount = 99 + g2Start`.
3. G1's run reaches `prepareWorkingSeed`. `resumeMode` resolved `.repair`,
   `shouldReuseWorkingFolder` keeps the folder, and the reconciliation blanks all 99 hashes. The
   record honestly drops to 0/100.
4. The announcement pushes. The honest sum is now `0 + g2Start`; the floor clamps it back to
   `99 + g2Start`.
5. For the next **99 pages of real work anywhere in the queue**, every push is clamped to that
   same value. G2's genuine progress is invisible for the whole stretch.

The single-gallery case is a no-op (pre-fix the card also sat at 99/100 for the run), which is
why this did not surface in the ledger suite. The multi-gallery case is a strict regression:
before 15-25 no incomplete gallery's counted basis could shrink, so the floor never bit on a
correction the coordinator itself caused.

The consequence is the one D-11 punishes. A card whose completed count does not advance while
work proceeds is the stalled reading the scheduler force-expires first, and this phase's own
expiration policy turns that into a pause of every schedulable download.

No test covers a reconciliation that lowers a count the session had already pushed. Test E
(`DownloadContinuedSessionLedgerTests.swift:585`) stages the *opposite* case — a
complete-reading, therefore untrusted, record whose floor contribution is zero — so the floor
never engages there.

**Fix:** Have the reconciliation report the correction and excuse it from the floor. Return the
blanked count alongside the manifest, and withdraw only the portion the basis was actually
counting (record incomplete, or gid already in `observedIncompleteSessionGIDs`) before the
announcement pushes:

```swift
// DownloadClient+ExecutionSupport.swift
private func reconcileWorkingManifestAgainstPageFiles(
    manifest: DownloadManifest,
    existingPages: [Int: String],
    folderURL: URL
) throws -> ReconciledManifest {   // .manifest + .blankedPageCount
    ...
}

public func prepareWorkingSeedAnnouncingProgress(
    payload: DownloadRequestPayload,
    existingDownload: DownloadedGallery,
    folderURL: URL
) async throws -> WorkingSeed {
    let prepared = try prepareWorkingSeed(...)   // carries blankedPageCount
    if let continuedSessionID, !prepared.seed.manifest.isComplete {
        // A basis correction this coordinator made is not a gallery losing ground, so the
        // floor withdraws exactly the pages the record just stopped claiming. Only pages the
        // basis was counting are withdrawn: an untrusted complete record contributed none.
        if wasCountedInSessionBasis(gid: payload.gallery.gid, before: prepared) {
            lastPushedCompletedPageCount = max(
                lastPushedCompletedPageCount - prepared.blankedPageCount,
                0
            )
        }
        await pushContinuedSessionProgress(sessionID: continuedSessionID)
    }
    return prepared.seed
}
```

Whatever shape is chosen, the invariant to restore is the one the push's own doc comment
asserts: the floor may only mask movements the coordinator did not deliberately make. Add a
regression case that stages two galleries, blanks K pages of one, and asserts the other
gallery's next K pushes still advance the card.

### Warnings

#### WR-01: `schedulableDownloads()` can exclude the gallery that is actually running

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:21-27`,
`AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:118-135`

**Issue:** `schedulableDownloads()` is documented as *"The one authority for selecting work the
scheduler can run"*, but it scopes its index read by queue-store membership:

```swift
let queuedGIDs = queueStore.gids
let downloads = queuedGIDs.isEmpty
    ? await indexedDownloads()
    : await indexedDownloads(gids: queuedGIDs)
return downloads.filter(isSchedulableDownload)
```

`isSchedulableDownload` accepts `displayStatus == .active` (i.e. `activeGalleryID == gid`)
independently of queue membership, so the two predicates disagree whenever the running gallery is
absent from the persisted queue *and* the queue is non-empty. Two ways in:

- `nextUnqueuedSchedulableDownload` (`DownloadClient+Scheduling.swift:96`) exists precisely to
  schedule a gallery that is *"schedulable before it is reflected in the persisted queue"*. Once
  it is running, any subsequent `enqueue`/`retry` of a second gallery makes `queuedGIDs`
  non-empty and drops the running gallery out of every later read.
- `handleProcessDownloadIncompleteError` (`DownloadClient+Execution.swift:205-218`) and
  `settleDownloadFailure` (`DownloadClient+Persistence.swift:177-181`) both
  `await queueStore.remove(gid)` while `activeGalleryID` is still set and the deferred
  `finishActiveTaskIfOwned` has not run.

Consequences, all on paths this phase owns:

1. The running gallery's pages leave the card's numerator and denominator, and on the *next* push
   it is detected as departed and retired at a frozen value — its real ongoing progress stops
   being reported while it downloads. The stall signal again.
2. `pauseAllSchedulable(expiring:)` (`DownloadClient+ContinuedSession.swift:337-347`) selects
   through the same call, so an expiration would skip pausing the one gallery actually consuming
   resources, contradicting the policy written on `handleContinuedSessionEvent`.
3. `hasPendingWork()` disagrees with it (it short-circuits on `activeTask != nil`), so the two
   halves of the drain decision are computed from different definitions.

It self-heals once the gallery rejoins the queue or its task settles, which is why this is a
warning rather than a blocker.

**Fix:** Union the active gallery into the read rather than relying on queue membership:

```swift
func schedulableDownloads() async -> [DownloadedGallery] {
    let queuedGIDs = queueStore.gids
    // The running gallery is schedulable by `isSchedulableDownload`'s own `.active` clause
    // whether or not the persisted queue has caught up, so scoping the read by queue
    // membership alone would drop it from the one authority that selects it.
    let scopedGIDs = queuedGIDs + [activeGalleryID].compactMap(\.self)
    let downloads = scopedGIDs.isEmpty
        ? await indexedDownloads()
        : await indexedDownloads(gids: scopedGIDs)
    return downloads.filter(isSchedulableDownload)
}
```

#### WR-02: Nothing pins `performDownload` to the announcing preparation

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift:29`

**Issue:** The whole of D-G5-01's liveness half rests on one call site choosing
`prepareWorkingSeedAnnouncingProgress` over `prepareWorkingSeed`. Both are `public` with
identical signatures apart from `async`. Every test that exercises the announcement
(`DownloadContinuedSessionLedgerTests.swift:642` and `:733`) calls the announcing variant
*directly*, with a hand-built payload and a task runner stubbed to `.skippedOperation`, so the
production run never reaches this line. Reverting it to `prepareWorkingSeed` — the exact
regression the phase just spent a round closing — leaves the entire suite green.

That is the phase's stated dominant failure mode (a fix's own wiring silently coming undone)
sitting on an unguarded line.

**Fix:** Either cover the wiring with a case that drives `processDownload`/`performDownload` and
asserts a push is issued before any page work, or make the silent variant unreachable from the
run path — e.g. rename `prepareWorkingSeed` to a non-`public`
`prepareWorkingSeedWithoutAnnouncing` and expose it to the two suites that need it through the
existing `#if DEBUG` seam pattern in `DownloadClient+Testing.swift`.

#### WR-03: `storage.validate` now reports a repaired-but-interrupted gallery as valid

**File:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift:295-297`,
`AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:312-316`

**Issue:** `validatePage` treats an empty expected hash as "nothing claimed, nothing to check":

```swift
guard !expectedHash.isEmpty else {
    return nil
}
```

D-G5-01 blanks exactly those hashes, so pages that previously produced
`.missingFiles(.downloadStorePageMissing(page:))` now produce `.valid`. Two consumers see it:

- `validateImageData(gid:)` (`DownloadClient+PersistenceNormalize.swift:84-104`). After a repair
  that failed with `fileOperationFailed`, `canValidateImageData` is true, and the inspector's
  user-initiated integrity check now answers "valid" for a gallery whose files are demonstrably
  gone, clearing `validationErrors[gid]`.
- `loadManifest(gid:)` (`DownloadClient+PublicAPI.swift:242-250`), whose `.missingFiles` gate no
  longer rejects the gallery, so the offline reader opens it with holes instead of falling back
  to remote.

Neither is data loss, and both are arguably self-consistent (the manifest genuinely no longer
claims those pages, and an interrupted `.initial` download has always behaved this way). The
defect is that the deliberate-consequence paragraph on `reconcileWorkingManifestAgainstPageFiles`
enumerates only `displayStatus` and `resumeMode`, so a later reader cannot tell whether the
`validate` change was considered or missed — precisely the "intentional design reads as a bug"
problem the surrounding doc comments exist to prevent.

**Fix:** Extend that paragraph to name `storage.validate` and both call sites, stating why
answering `.valid` for a no-longer-claimed page is correct; or, if it is not, have `validatePage`
distinguish "not claimed" from "claimed and present" on the `verifiesContentHashes: true` path.

### Info

#### IN-01: `resumeMode`'s validate branch is now near-dead for the state it was written for

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift:44-56`

**Issue:** `resumeMode` reaches `storage.validate(...)` only when the record does *not* read
incomplete. D-G5-01 makes the record read incomplete on exactly the route that branch was written
for (a complete-looking record with vanished files), so the earlier `.inactive && isIncomplete`
branch now absorbs it and the `.missingFiles` arm survives only for records the reconciliation
has not yet touched. The reconciliation's doc asserts "`resumeMode`'s incomplete-inactive branch
resolves `.repair` for it exactly as its missingFiles branch did before", which is true, but
leaves the older branch looking unreachable with nothing saying otherwise.

**Fix:** Add a line to `resumeMode` recording that the validate branch is now the
pre-reconciliation fallback, so a later reader neither deletes it as dead nor re-derives its
purpose.

#### IN-02: The log-privacy invariant's token list cannot see a URL leak

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:30-50`

**Issue:** The banned interpolations are `gid`, `title`, `error` and `localizedDescription`.
`DownloadClient+ResponseValidation.swift:270` logs `url: \(requestURL?.absoluteString ?? "")`,
and a gallery/page URL embeds the gid and token. It is safe today only because `OSLogPrivacy`
defaults strings to private; an explicit `, privacy: .public` added there later would pass this
invariant unchanged.

**Fix:** Add `"url" + publicClassification` and `"absoluteString" + publicClassification` to
`forbiddenInterpolations`.

#### IN-03: `maskedCount >= 8` is a magic threshold

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:80-81`

**Issue:** `#expect(maskedCount >= 8)` pins an unexplained lower bound on the number of
hash-masked interpolations. It cannot fail for a reason a reader can predict, and it silently
tolerates every mask above the eighth being removed as long as eight remain.

**Fix:** Drop the count in favour of the per-message assertions already below it, or name the
eight sites the bound refers to in a comment so a future removal is legible.

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
