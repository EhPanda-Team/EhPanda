---
phase: 15-continued-background-downloads
reviewed: 2026-07-29T00:41:45Z
depth: standard
files_reviewed: 28
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
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 3
  warning: 3
  info: 0
  total: 6
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-07-29T00:41:45Z
**Depth:** standard
**Files Reviewed:** 28
**Status:** issues_found

## Summary

The phase still has three shipping defects. The coordinator clears an in-flight session before the
client start returns, allowing a second user action to collide with the live store's single-session
guard and leave the newest work without background coverage. A failed filesystem deletion of the
active gallery similarly leaves the queue without an owner or convergence pass. Download identities
and titles are also deliberately emitted as public unified-log fields despite being sensitive
library data. The current tests conceal the first race because their client spy accepts overlapping
starts that the live store refuses.

The plist and string catalog parse successfully, and the continued-session plural substitutions
match the repository's locale rules. Option B did remove the unused dependency key and accessor,
but source and test documentation still claims both exist.

Review guidance used: `gsd-code-review`, `swift-concurrency-pro` (actor reentrancy, cancellation,
unstructured tasks, and `AsyncStream` lifecycle), and `swift-testing-pro` (async-test fidelity and
teardown).

## Critical Issues

### CR-01 [BLOCKER]: A drain during client start can make the newest tap lose background coverage

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:87-107`

**Issue:** `ensureContinuedSession` marks coordinator session S1 live and then suspends in
`backgroundProcessingClient.start`. While that main-actor hop is returning, a queue drain can enter
`reconcileContinuedSession` and clear S1 even though `continuedClientSessionID` is still `nil`
(`:213-227`). A second queue-mobilizing tap can then create coordinator session S2 and call
`start`. The live `ContinuedProcessingSession` still holds S1 at that instant and refuses S2 through
its single-session guard (`ContinuedProcessingSession.swift:85-87`). S2 rolls its bookkeeping back
at `:93-99`; when S1 finally resumes, its ownership check fails and it finishes S1. The final state
has pending/running work but no continued-processing session, and only another user tap can restore
coverage.

The regression at
`DownloadContinuedSessionIdentityTests.swift:86-137` does not exercise production behavior:
`BackgroundProcessingClientSpy` accepts S2 while S1 is held and overwrites its current continuation,
whereas the live store returns `nil`.

**Fix:** Do not clear coordinator ownership while its client start is in flight. Record that
reconciliation is deferred, keep `hasLiveContinuedSession` and `continuedSessionID` set so a newer
tap folds into the pending session, and reconcile immediately after the client ID is installed:

```swift
// reconcileContinuedSession
guard await hasPendingWork() else {
    guard continuedSessionID == sessionID else { return }
    guard let clientSessionID = continuedClientSessionID else {
        continuedSessionNeedsReconciliation = true
        return
    }
    markContinuedSessionEnded(sessionID: sessionID)
    await backgroundProcessingClient.finish(clientSessionID, true)
    return
}

// ensureContinuedSession, after start returns and ownership is rechecked
continuedClientSessionID = clientSession.id
if continuedSessionNeedsReconciliation {
    continuedSessionNeedsReconciliation = false
    await reconcileContinuedSession()
}
```

Add a deterministic regression using a spy that refuses an overlapping start exactly like
`ContinuedProcessingSession`: drain while S1 start is held, enqueue/tap again, release S1, and assert
the pending/live S1 is reconciled against the new work rather than leaving the queue uncovered.

### CR-02 [BLOCKER]: A failed active-gallery deletion permanently stalls scheduling

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:182-215`

**Issue:** Deleting the active gallery cancels its task and clears both `activeTask` and
`activeGalleryID` before removing the folder. If `removeGalleryFolders` fails (permissions,
filesystem error, or a transient coordination failure), both catch branches reload the record and
return without notifying or calling `scheduleNextIfNeeded`. The cancelled task's deferred cleanup
cannot recover: its generation no longer owns `activeGalleryID`, so
`finishActiveTaskIfOwned` returns without scheduling. The failed gallery remains queued, any
following galleries remain stranded, and the continued-processing session is neither refreshed nor
completed.

The two deletion convergence tests cover only a record that vanished successfully; neither forces
folder removal to throw after active-task ownership has been cleared.

**Fix:** On both removal-error branches, release the gallery's scheduling block and run the same
notification/scheduling convergence used by the not-found and success paths before returning the
error:

```swift
} catch let error as AppError {
    await reloadDownloadRecord(gid: download.gid, token: download.token)
    schedulingBlockedGalleryIDs.remove(gid)
    await notifyObservers()
    await scheduleNextIfNeeded()
    return .failure(error)
} catch {
    logger.error("\(error)")
    await reloadDownloadRecord(gid: download.gid, token: download.token)
    schedulingBlockedGalleryIDs.remove(gid)
    await notifyObservers()
    await scheduleNextIfNeeded()
    return .failure(.fileOperationFailed(error.localizedDescription))
}
```

Keep the existing `defer` removal as an idempotent safety net, and add a failure-injected test that
starts with an active item plus a queued successor.

### CR-03 [BLOCKER]: Unified logs disclose the user's downloaded gallery identities

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift:59-64`

**Issue:** Download completion logs the gallery title and GID with `privacy: .public`.
`DownloadClient+PublicAPI.swift:99-103` does the same when enqueueing, while failure, pause, resume,
delete, and expiration-interleave logs publicly emit the GID at
`DownloadClient+Execution.swift:171-198`, `DownloadClient+PublicAPI.swift:225`, and
`DownloadClient+Scheduling.swift:168-169,225,304`. A GID resolves to a specific public gallery, and
the title is direct content-identifying data. Marking these fields public puts a user's library into
unredacted unified logs and collected diagnostics, contradicting the phase's explicit effort to
keep gallery identity out of system-owned surfaces.

**Fix:** Remove titles from operational logs and make identifiers private (hash masking preserves
correlation without disclosure). Do the same for error descriptions that can contain gallery-named
paths:

```swift
logger.notice(
    "Download completed, gid: \(gid, privacy: .private(mask: .hash)), pages: \(download.pageCount)."
)
logger.error(
    "Download failed, gid: \(context.gid, privacy: .private(mask: .hash)), error: \(error)."
)
```

Audit every `.public` interpolation in the listed DownloadClient files rather than fixing only the
two title-bearing messages.

## Warnings

### WR-01 [WARNING]: The session spy violates the live client's single-session contract

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:243-279`

**Issue:** Every accepted `start` mints a new ID and replaces `currentSessionID` and
`continuation`, even when a previous session is still held. The live store explicitly refuses that
call. This mismatch makes the most important in-flight-start regression pass under a lifecycle that
production cannot exhibit and hides CR-01.

**Fix:** Make refusal on an already-held session the spy's default behavior, while retaining an
explicit one-shot refusal control for tests that need it:

```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
```

Update the drain/start interleave test to assert the corrected deferred-reconciliation behavior
rather than allowing one session to overwrite another.

### WR-02 [WARNING]: Option B left authoritative comments describing the deleted dependency API

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:301-310`

**Issue:** The coordinator property documentation says the client keeps a dependency-key
registration and `DependencyValues` accessor and obtains its unimplemented `testValue` from them.
Option B deleted all three claims. The test documentation at
`DownloadContinuedSessionTests.swift:10-12` repeats the nonexistent `testValue` explanation.
These comments now describe an override/composition path that cannot be used and directly undo the
architectural clarity Option B was chosen to provide.

**Fix:** State that `DownloadClient.live` injects `.live` directly, tests inject a client directly,
and `BackgroundProcessingClient()` gets macro-generated unimplemented endpoints without a
dependency key. Remove references to the deleted key, accessor, and `testValue`.

### WR-03 [WARNING]: The held-start test can leak its parked task on an early failure

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift:97-114`

**Issue:** `testBailOutFinishNeverLandsOnTheMostRecentStartsSession` parks `firstTap` behind a start
gate, but does not install the defensive `defer { gate.release() }` used by the progress-gate test
above it. Any throwing `#require` or assertion failure before line 113 leaves the task waiting on
the gate's stream. That can turn the intended failure into a leaked task or a hung test process.

**Fix:** Install the release defer immediately after arming the gate, and keep the explicit release
at the intended interleave point (release is idempotent):

```swift
let gate = spy.armStartGate()
defer { gate.release() }
let firstTap = Task {
    await fixture.manager.ensureContinuedSession()
}
```

---

_Reviewed: 2026-07-29T00:41:45Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
