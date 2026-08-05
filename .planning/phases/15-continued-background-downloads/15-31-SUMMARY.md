---
phase: 15-continued-background-downloads
plan: 31
subsystem: downloads
tags: [download-client, scheduling, reference-counting, actor-reentrancy, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "The ACTIVE-OWNERSHIP CONVERGENCE contract and its five prior sweep rounds (delete, deleteFolder, commitPause's catches, the queued-work-item cancel), 15-28's DEBUG testing-forwarder seam, and D-03's removal of the fallback tier that makes an unconverged exit unrecoverable"
provides:
  - "moveDownload releases its scheduling block and converges (notifyObservers then scheduleNextIfNeeded) on every one of its six exits"
  - "commitPause's not-found exit converges — the one unconverged .settled path the sweep found in a site the plan expected to be clean"
  - "schedulingBlockedGalleryCounts: the scheduling block as a per-operation reference count, so overlapping same-gid operations can no longer strip each other's hold (WR-03)"
  - "blockScheduling(gid:) / releaseScheduling(gid:) with a logged contract violation on an unmatched release"
  - "Single-release-per-exit discipline at all four block sites; every function-scoped defer that sat behind an explicit release is gone"
  - "Four DEBUG seam members (testingSchedulingBlockedGalleryIDs, testingIsSchedulingBlocked, testingBlockScheduling, testingReleaseScheduling)"
  - "Three regressions: two move-exit convergence cases observed failing first, one refcount contract case"
affects: [continued-background-downloads, download-scheduling, download-folder-operations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A cross-suspension exclusion flag on a reentrant actor is a reference count, never set membership: set membership makes the first finisher release a hold the second still needs"
    - "Release-then-converge, one release per exit path: a defer is only safe as a site's SOLE release, because a count cannot absorb the double-release a Set tolerated"
    - "Never converge while the affected gallery is still blocked — the convergence runs but the scheduler silently skips the gallery it was run for"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift

key-decisions:
  - "15-31: The scheduling block is stored as [String: Int] and schedulability tests ABSENCE of a key, never a stored zero — releaseScheduling removes the entry at zero so the three readers' `== nil` / `!= nil` spellings cannot disagree with the count."
  - "15-31: commitPause is the only site keeping no defer either — the sweep found its not-found exit converged nowhere, so the plan's expected disposition ('convergence owned one frame up on every path') was false in source and the exit was fixed rather than documented as intended."
  - "15-31: An unmatched releaseScheduling logs at .error and leaves the dictionary untouched rather than decrementing anyway; decrementing would consume a different live operation's hold and strand that operation's download."
  - "15-31: The mid-suspension teardown window is narrowed to each operation's own suspensions but not eliminated, and is deliberately left unstaged — closing it deterministically would require adding production suspension hooks that G-15-8's recorded suggested_fix does not ask for."

patterns-established:
  - "Sweep-with-disposition: every member of a mechanism's call set is proven against the invariant from source before the reported member is patched, and a per-site disposition table is the deliverable"
  - "A seam-only regression states its falsifiability structurally (what change to production makes it fail) when it cannot be run against the pre-fix shape"

requirements-completed: []

coverage:
  - id: D1
    description: "A successful folder move leaves the moved gallery unblocked and immediately rescheduled, instead of queued and idle with no fallback tier to restart it"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift#testAMoveLeavesTheGalleryUnblockedAndTheQueueConverged"
        status: pass
    human_judgment: false
  - id: D2
    description: "A failed folder move (destination occupied) releases the block and converges, so the gallery it never moved is handed back to the scheduler"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift#testAFailedMoveReleasesTheBlockAndConverges"
        status: pass
    human_judgment: false
  - id: D3
    description: "Two overlapping holds on one gallery's scheduling block release independently — the first release no longer unblocks a gallery the second holder still needs hidden (WR-03)"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift#testOverlappingBlocksOnTheSameGalleryReleaseIndependently"
        status: pass
    human_judgment: false
  - id: D4
    description: "The invariant holds across the whole block-insert set with a per-site disposition, and pause / delete / folder-operation semantics are unchanged apart from the added exit convergence"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air' (full plan, 0 failures)"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift#testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes"
        status: pass
    human_judgment: false

# Metrics
duration: 50min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 31: Scheduling-Block Exit Convergence Summary

**`moveDownload` now releases its scheduling block and converges on all six exits, and the block itself became a per-operation reference count so two overlapping same-gid operations can no longer strip each other's hold — closing G-15-8 with WR-03 bundled, both convergence defects observed failing first.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-08-05T01:05Z
- **Completed:** 2026-08-05T01:55Z
- **Tasks:** 1 (TDD: RED commit + GREEN commit)
- **Files modified:** 9

## Accomplishments

- **The invariant, swept rather than patched.** "No exit may leave a gid blocked or the queue unconverged" is stated once on the storage declaration and enforced at all four block sites with a per-site disposition proven from source. `moveDownload` — the one ACTIVE-OWNERSHIP CONVERGENCE family member the phase's five convergence rounds never touched — releases and converges on every one of its six exits.
- **The sweep found a second unconverged exit.** `commitPause`'s not-found path returned `.settled(.failure(.notFound))` with no convergence anywhere, and its caller does not converge on `.settled` values. The plan's expected disposition for that site ("convergence owned one frame up on every path") was false in source; the exit was fixed rather than written down as intended.
- **WR-03's class removed, not its instance.** `schedulingBlockedGalleryIDs: Set<String>` (public) became `schedulingBlockedGalleryCounts: [String: Int]` (internal) with `blockScheduling(gid:)` / `releaseScheduling(gid:)`. All 17 planning-time references converted; `grep -rc 'schedulingBlockedGalleryIDs' AppPackage/Sources/DownloadClient/` now totals **0**.
- **No double-release survives the conversion.** Every function-scoped `defer` that sat behind an explicit release is gone; `commitPause` lost its `defer` too once its exits needed individual placement.
- **The DEBUG seam.** Four members added to `DownloadClient+Testing.swift`, all consumed by suites — the expiration-parity trio reads `testingSchedulingBlockedGalleryIDs()` with its assertion values untouched.

## Task Commits

1. **Task 1 (RED): the move-exit convergence regressions** — `b1973e17` (test)
2. **Task 1 (GREEN): the refcount conversion and the four-site sweep** — `dab4a285` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — the counted storage with the G-15-8 invariant and WR-03 derivation on its declaration, plus `blockScheduling` / `releaseScheduling`; gained a file-local `logger` for the unmatched-release report
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` — `moveDownload` release + converge on all six exits under a new ACTIVE-OWNERSHIP CONVERGENCE doc comment; `deleteFolder` converted to single-release-per-exit
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — `delete` converted to single-release-per-exit
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — `isSchedulableDownload` tests the count's absence; `commitPause` converted to single-release-per-exit and its not-found exit now converges
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift`, `…+ResponseValidationHelpers.swift` — the two remaining readers converted to key-presence tests
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — the four seam members
- `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift` — three new cases plus a private `MoveConvergenceGallery` fixture
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift` — read spelling only (diff verified below)

## Per-Site Sweep Table

Every site that inserts into the scheduling block, every exit of each, where its single release sits, and the evidence that the queue converges after it. Read from current source, not from the prior comments.

| Site | Exit | Release placement | Convergence evidence |
|---|---|---|---|
| `moveDownload` (`+Folders.swift:170`) | invalid folder name | *(precedes the block — no release needed)* | n/a: nothing was blocked, nothing mutated |
| | record not found (after `fetchDownload` suspension) | `:179`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| | gallery busy (`activeGalleryID == gid`) | `:185`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| | same-destination success | `:200`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| | destination exists | `:206`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| | move-failure catch (after `reloadDownloadRecord` suspension) | `:224`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| | success (after `reloadDownloadRecord` suspension) | `:230`, before convergence | inline `notifyObservers()` + `scheduleNextIfNeeded()` |
| `deleteFolder` (`+Folders.swift:100`, per contained gid) | folder not found | *(precedes the block)* | n/a |
| | typed-error removal failure | `:119`, before convergence | pre-existing `notifyObservers()` + `scheduleNextIfNeeded()`, unchanged |
| | untyped-error removal failure | `:128`, before convergence | pre-existing pair, unchanged |
| | success | `:142`, inside the teardown loop, before convergence | pre-existing pair, unchanged; the release moved **ahead** of it (the old `defer` ran after) |
| `delete` (`+PublicAPI.swift:194`) | record vanished (not found) | `:210`, before convergence | pre-existing pair, unchanged |
| | typed-error removal failure | `:223`, before convergence | pre-existing pair, unchanged |
| | untyped-error removal failure | `:230`, before convergence | pre-existing pair, unchanged |
| | success | `:241`, before convergence | pre-existing pair, unchanged; release moved ahead of it |
| `commitPause` (`+Scheduling.swift:194`) | record not found | `:203`, before convergence | **ADDED** `notifyObservers()` + `scheduleNextIfNeeded()` — see Deviations |
| | `.superseded` (first ownership check) | `:211` | caller-owned: `pause(gid:expiration:)` `+Scheduling.swift:182-184` converges and re-ensures on every `.superseded` |
| | status not `.queued` / `.active` | `:217`, before convergence | pre-existing pair, now reached with the gid unblocked |
| | `.superseded` (second ownership check) | `:233` | same caller-owned path as above |
| | success | `:240`, before convergence | pre-existing pair, now reached with the gid unblocked |
| | typed-error catch | `:248`, before convergence | pre-existing pair, unchanged |
| | untyped-error catch | `:259`, before convergence | pre-existing pair, unchanged |

**Caller-path evidence for `commitPause` (checked in source, not inferred).** `pause(gid:expiration:)` is its only caller. It converges on `.superseded` (`notifyObservers` → `scheduleNextIfNeeded` → `ensureContinuedSession`, `+Scheduling.swift:182-184`) and returns `.settled` values verbatim without converging. Every `.settled` path therefore had to converge inside `commitPause` itself — five of six did, and the sixth (not found) is the deviation recorded below.

## Double-Release Removal Evidence

| Site | Pre-fix shape | Post-fix |
|---|---|---|
| `moveDownload` | one function-scoped `defer` (its only release, but converging nowhere) | `defer` dropped; `grep -c defer` over the extracted body = **0**; six explicit releases, one per exit |
| `deleteFolder` | function-scoped `defer` **plus** explicit `remove` loops in both catch bodies → **double-remove on every error exit** (harmless on a `Set`, would decrement a live count) | `defer` dropped; exactly one `releaseScheduling` loop per exit path |
| `delete` | function-scoped `defer` **plus** explicit `remove` in both catch bodies → same double-remove | `defer` dropped; exactly one release per exit path |
| `commitPause` | do-scoped `defer` as the sole release (no double-release), but two exits converged while the gid was still blocked and one converged nowhere | `defer` dropped so each exit places its own release ahead of its convergence |

`blockScheduling(gid:)` appears at exactly four operation sites — `+Scheduling.swift:194` (`commitPause`), `+Folders.swift:100` (`deleteFolder`), `+Folders.swift:177` (`moveDownload`), `+PublicAPI.swift:194` (`delete`) — plus the DEBUG forwarder at `+Testing.swift:116`.

## The `moveDownload` Exit Skeleton (quoted)

```swift
blockScheduling(gid: gid)
guard let download = await fetchDownload(gid: gid) else {
    releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
    return .failure(.notFound)
}
guard activeGalleryID != gid else {
    releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
    return .failure(.fileOperationFailed(String(localized: .downloadStoreDownloadBusy)))
}
guard destinationURL.standardizedFileURL != download.folderURL.standardizedFileURL else {
    releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
    return .success(())
}
guard !fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) else {
    releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
    return .failure(.fileOperationFailed(String(localized: .downloadStoreFolderAlreadyExists)))
}
do { … } catch {
    logger.error("\(error, privacy: .private)")
    await reloadDownloadRecord(gid: download.gid, token: download.token)
    releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
    return .failure(.fileOperationFailed(error.localizedDescription))
}
await reloadDownloadRecord(gid: download.gid, token: download.token)
releaseScheduling(gid: gid); await notifyObservers(); await scheduleNextIfNeeded()
return .success(())
```

*(Statements are shown one-per-line in the source; they are joined here only to keep the quote compact. The body contains no `defer`, and every return path is preceded by a `scheduleNextIfNeeded` call.)*

## Falsifiability: the RED run

Taken before any production change landed — only the read-only `testingIsSchedulingBlocked` seam existed at that point, so the defect under test was untouched. Command: the plan's targeted invocation, single run, exit non-zero (`** TEST FAILED **`).

```
✘ Test testAMoveLeavesTheGalleryUnblockedAndTheQueueConverged() recorded an issue at
  DownloadOwnershipConvergenceTests.swift:134:9: Expectation failed:
  (scheduledGalleryRecorder.snapshot() → []) == ([gallery.gid] → ["210380"])

✘ Test testAFailedMoveReleasesTheBlockAndConverges() recorded an issue at
  DownloadOwnershipConvergenceTests.swift:172:9: Expectation failed:
  (scheduledGalleryRecorder.snapshot() → []) == ([gallery.gid] → ["210390"])

✘ Test run with 21 tests in 3 suites failed after 0.757 seconds with 2 issues.
```

Two facts worth recording honestly:

1. **The recorder read empty, not late.** No scheduling pass ran at all after either move exit — exactly the "queued and idle" consequence the gap named and the review missed. The assertion is deterministic rather than polled: `scheduleNextIfNeeded` is awaited inside the operation and the runner records its selection synchronously within it, so an empty recorder cannot be a timing artifact.
2. **The `testingIsSchedulingBlocked(...) == false` halves PASSED pre-fix**, because the old function-scoped `defer` did release the block by the time the function returned. They are not decoration: once the `defer` was dropped in favour of six explicit releases, they became the only thing pinning that a new exit path cannot silently skip its release.

**Refcount case falsifiability (structural, stated in its doc comment).** `testOverlappingBlocksOnTheSameGalleryReleaseIndependently` cannot be run against the pre-fix shape — a `Set` has no counting seam to drive. Reverting the storage to set membership makes its first `testingIsSchedulingBlocked` read `false` and the case fail.

## Expiration-Parity Diff Inspection

`git diff AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift` contains exactly two hunks, four changed lines, all of the form `manager.schedulingBlockedGalleryIDs` → `manager.testingSchedulingBlockedGalleryIDs()`. No assertion value, comparison, or doc comment changed. Both cases pass in the targeted and full runs.

## Recorded Scoping Choice: the mid-suspension teardown window

This fix **narrows** the window in which a gid is hidden from `schedulableDownloads()` to each operation's own suspensions, and guarantees that every exit hands the gallery back and reruns scheduling. It does **not** eliminate the window itself: a completion-path convergence can still land on the actor while an operation legitimately holds a block across `fetchDownload` or `reloadDownloadRecord`, read no pending work, and end the session — after which this fix's convergence is what recovers the queue, since `scheduleNextIfNeeded`'s tail is the reconcile.

Staging that interleave deterministically would require adding suspension hooks to production code paths purely so a test could park inside them. G-15-8's recorded `suggested_fix` does not ask for that, and inventing a sleep-based approximation would produce a flaky case asserting a timing coincidence rather than a contract. The two deterministic contracts are what the regressions pin instead: **every exit unblocks and converges**, and **overlapping blocks release independently**. This is a deliberate scope boundary, recorded here rather than papered over.

## Decisions Made

- The count's absence — never a stored zero — is the schedulable condition, so `releaseScheduling` deletes the entry at zero and the three readers' `== nil` / `!= nil` spellings cannot drift from the count.
- An unmatched `releaseScheduling` logs at `.error` (gid hash-masked, per the module's log-privacy invariant) and leaves the dictionary untouched. Decrementing anyway would consume a *different* live operation's hold and strand the download that operation is protecting; trapping would turn a bookkeeping slip into a crash on a user's device.
- `commitPause` keeps `do`/`catch` but no `defer`, so its exits place their own releases ahead of their convergences. The previous do-scoped `defer` was not a double-release hazard, but it did make two exits converge while the gid was still blocked — the "Forbidden" clause of the ACTIVE-OWNERSHIP CONVERGENCE doc.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] `commitPause`'s not-found exit converges nowhere**

- **Found during:** Task 1, Step 3 (the mandated per-site sweep)
- **Issue:** The plan's directed disposition for `commitPause` was to keep its `defer` and *"confirm from source that every commitPause caller path converges after release"*. Source contradicts that premise: `commitPause`'s `guard let currentDownload = await fetchDownload(gid: gid) else { return .settled(.failure(.notFound)) }` converged nowhere, and its only caller returns `.settled` values verbatim without converging. That is the same shape as G-15-8's own defect — a block held across a suspension, released, and the queue left unconverged — inside the very site the plan expected to be clean.
- **Fix:** Converted `commitPause` to single-release-per-exit like its three siblings (dropping the `defer`), and added `notifyObservers()` + `scheduleNextIfNeeded()` after the release on the not-found exit. Two further exits (status-not-queued-or-active, and success) previously ran their existing convergence *while still holding the block*; placing the release ahead of it makes those convergences able to see the gallery they were run for.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift`
- **Verification:** Full `FeatureTests` plan, 0 failures — including the expiration-parity trio (which compares expired vs. per-gallery-paused state through the coordinator's own `pause` entry point), `DownloadPauseAndReconcileTests`, and `DownloadSchedulingTests`.
- **Committed in:** `dab4a285`
- **Why it is not scope creep:** the plan's own `must_haves` require the invariant to be *"enforced across the WHOLE schedulingBlocked insert set … with a per-site disposition"*, and the phase's standing owner mandate forbids branch-scoped fixes. Documenting a proven-unconverged exit as intended would have refilled this gap next round.

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical functionality found by the mandated sweep)
**Impact on plan:** Strengthens the plan's stated invariant at the one site the plan assumed compliant. No behavior outside release discipline and exit convergence was touched; the prohibition list is intact (see below).

## Prohibition Check

| Prohibition | Status |
|---|---|
| Must NOT change which operations block which gids, the blocking predicate's meaning, `shouldSchedule`, or pause/expiration semantics | **Held.** The same four operations block the same gids; `shouldSchedule` is byte-identical; the predicate changed spelling only (`!set.contains(gid)` → `counts[gid] == nil`). Pause/expiration outcomes are pinned unchanged by the expiration-parity trio. |
| Must NOT patch `moveDownload` alone | **Held.** All four sites swept with the per-site disposition table above; the sweep is what found the `commitPause` deviation. |
| Must NOT weaken or delete an existing case or literal | **Held.** No case removed; the expiration suite's diff is four read-spelling lines. |
| Must NOT invent a racy test | **Held.** No sleep-based case added; the non-stageable window is recorded as a scoping choice above. |
| Must NOT reach for a concurrency or lint escape hatch or a SwiftLint suppression | **Held.** Zero `swiftlint:disable`, zero `@unchecked`/`@preconcurrency`; SwiftLint `--strict` over `AppPackage/Sources/DownloadClient/` and `AppPackage/Tests/DownloadsFeatureTests/` exits 0. |

## Acceptance Criteria Evidence

| Criterion | Result |
|---|---|
| `grep -c 'schedulingBlockedGalleryCounts' …+Manager.swift` ≥ 1 | **5** |
| `grep -rc 'schedulingBlockedGalleryIDs' …/DownloadClient/` total = 0 | **0** (17 at planning time) |
| `blockScheduling(gid:` at the four operation sites | **4** operation sites + 1 DEBUG forwarder |
| `moveDownload` body has no `defer`, `scheduleNextIfNeeded` on every return path | **0** `defer`; 6 exits, 6 calls |
| `grep -c 'ACTIVE-OWNERSHIP CONVERGENCE' …+Folders.swift` ≥ 2 | **2** |
| `grep -c '…seam members…' …+Testing.swift` ≥ 4 | **4** |
| The three case names present | **3** |
| Targeted run exit 0, single invocation | `** TEST SUCCEEDED **` — 22 tests, 3 suites |
| Full `FeatureTests` run exit 0, single invocation | `** TEST SUCCEEDED ** [96.629 sec]` — 0 `✘` across the whole plan |
| Every edited file `wc -l` < 1000 | Folders 277, Manager 656, Scheduling 339, PublicAPI 373, PageDownload 338, ResponseValidationHelpers 385, Testing 138, OwnershipConvergenceTests 313, ExpirationTests 417 |

## Issues Encountered

- **The RED cases needed a seam that did not exist yet.** Adding the whole four-member seam up front would have meant writing production code named after the refcount before the refcount existed. Resolved by landing only `testingIsSchedulingBlocked` (a read-only exposure of the *existing* `Set`, incapable of masking or creating the convergence defect) in the RED commit, then repointing it at the count in the GREEN commit. The RED readings are therefore taken against untouched production behavior.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-access, or schema surface. The plan's three registered threats (`T-15-31-01` unconverged move exits, `T-15-31-02` overlapping releases, `T-15-31-03` double-release during conversion) are all mitigated and evidenced above.

## Next Phase Readiness

- G-15-8 is closed with WR-03 bundled; the review warning that routed through these sites is discharged.
- Plan 15-32 is the last of round 11; after it the phase needs re-verification.
- **Independent and still outstanding:** `15-UAT.md` test 2 needs a physical-device re-run on iOS 26 covering the `.redownload` route and a `.repair` gallery in a multi-gallery queue. Nothing in this plan discharges it.

## Self-Check: PASSED

- All modified source and test files exist on disk.
- Both task commits exist in history: `b1973e17` (RED), `dab4a285` (GREEN).
- No absolute home paths in this document (`grep -c '/Users/'` = 0).
- Cited source line numbers re-derived from current HEAD after the edits landed.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
