---
phase: 15-continued-background-downloads
plan: 28
subsystem: downloads
tags: [continued-processing, background-downloads, access-control, test-seam, file-length-headroom]

requires:
  - phase: 15-continued-background-downloads
    provides: "The nine session-lifecycle mutators (15-01..15-26), DownloadClient+Testing.swift's #if DEBUG seam pattern, and 15-27's spy refusal-guard split"
provides:
  - "G-15-11: nine session-lifecycle mutators dropped public → internal; no linking module can detach or cancel the live session or push counts to the card"
  - "Six thin #if DEBUG testing forwarders — one per mutator a suite consumes, none for the three with no consumer"
  - "DownloadContinuedSessionExpirationTests.swift — the relocated expiration-and-teardown family, giving DownloadContinuedSessionTests.swift 404 lines of file_length headroom"
  - "The round's mandatory headroom relocation, unblocking plans 15-29..15-32 (G-15-12/IN-05's headroom half)"
affects: [continued-processing-session, background-downloads, downloads-test-doubles]

tech-stack:
  added: []
  patterns:
    - "A capability's mutation surface is module-internal; the cross-module test target reaches it through one #if DEBUG seam of single-expression forwarders"
    - "A seam carries only members a suite genuinely consumes — an unconsumed forwarder is attack surface, not a seam"
    - "A relocation for file-length headroom moves cases whole (byte-identical bodies, doc comments carried) and leaves a pure-deletion diff behind it"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift

key-decisions:
  - "All nine mutators drop to internal, but only six get forwarders: schedulableSnapshot, continuedSessionSubtitle and handleContinuedSessionEvent have zero test call sites, and a forwarder without a consumer is the surface this gap removes"
  - "Every private helper in DownloadContinuedSessionTests.swift turned out to be used exclusively by the relocated family, so nothing was lifted into DownloadFeatureTestHelpers.swift and that file is untouched"
  - "The relocation left the source file's AppModels import dead (its only consumers were the moved snapshot struct's DownloadDisplayStatus and DownloadFailure); the dead import was removed rather than left behind"
  - "The new file omits CustomDump: expectNoDifference is used only by cases that stayed behind, so importing it would have been an unused import"

metrics:
  duration: 9min
  completed: 2026-08-05
  tasks: 2
  files: 13

status: complete
---

# Phase 15 Plan 28: Module-Internal Session Mutators and the Expiration Split Summary

The continued-processing capability's nine session-lifecycle mutators are now internal to
`DownloadClient`, so no linking module can detach or cancel the live session or push counts to the
system card outside the coordinator's own choreography — and the suites reach exactly six of them
through one `#if DEBUG` seam of single-expression forwarders. Along the way the 999-line
`DownloadContinuedSessionTests.swift` shed its expiration-and-teardown family into a new suite,
giving it 404 lines of headroom under the 1000-line `file_length` ERROR gate.

## What Was Built

### Task 1 — the headroom relocation

Nine cases moved whole from `DownloadContinuedSessionTests.swift` into the new
`DownloadContinuedSessionExpirationTests.swift`, together with every private helper they own.

**Cases moved** (in source order, all bodies and doc comments byte-identical):

| # | Case |
|---|------|
| 1 | `testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState` |
| 2 | `testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes` |
| 3 | `testExpirationResultIsIndependentOfEnqueueOrder` |
| 4 | `testEndedSessionReceivesNoFurtherUpdateOrCompletion` |
| 5 | `testConsumingTaskEndsOnItsOwnAfterExpiration` |
| 6 | `testUnavailableSessionLeavesQueueStateEqualToTheInertClient` |
| 7 | `testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession` |
| 8 | `testStaleTeardownDoesNotClearANewerSession` |
| 9 | `testCancellingTheLastQueuedWorkItemCompletesTheSession` |

**Case conservation.** `grep -c '@Test'` was `27` on the source file before the move; after it,
`18` (source) + `9` (new) = `27`. The targeted run confirmed the same number at runtime:
`Test run with 27 tests in 2 suites passed`.

**Helper dispositions.** The plan anticipated that some helpers would be shared and would need
lifting into `DownloadFeatureTestHelpers.swift` per the 15-26 precedent. Inspection of every call
site showed that **none** are — all six declarations are consumed exclusively by the relocated
family, so all six moved and `DownloadFeatureTestHelpers.swift` was not touched:

| Declaration | Consumers before the move | Disposition |
|-------------|---------------------------|-------------|
| `struct GalleryStateSnapshot` | `queueSnapshot`, `runPageFlushScenario` (both moved) | exclusive → moved |
| `func queueSnapshot(_:)` | cases 1, 3 and `runPageFlushScenario` | exclusive → moved |
| `func expirationGalleries(gids:)` | cases 1, 2, 3, 4, 5 | exclusive → moved |
| `func expireSession(of:spy:ensuresSession:)` | cases 1, 2, 3, 4 | exclusive → moved |
| `func runPageFlushScenario(client:gid:)` | case 6 | exclusive → moved |
| `extension BackgroundProcessingClient { static let unavailable }` | cases 6, 7 | exclusive → moved |

No helper exists twice — verified per name across the whole test target:

```
func queueSnapshot          -> DownloadContinuedSessionExpirationTests.swift:1
func expirationGalleries    -> DownloadContinuedSessionExpirationTests.swift:1
func expireSession          -> DownloadContinuedSessionExpirationTests.swift:1
func runPageFlushScenario   -> DownloadContinuedSessionExpirationTests.swift:1
struct GalleryStateSnapshot -> DownloadContinuedSessionExpirationTests.swift:1
static let unavailable      -> DownloadContinuedSessionExpirationTests.swift:1
```

**Byte-faithfulness, from diff inspection.** The source file's diff for the relocation commit is
`1 file changed, 403 deletions(-)` — **zero insertions**. Two hunks: `@@ -1 +0,0 @@` (the dead
`AppModels` import) and `@@ -597,402 +595,0 @@` (the trailing blank line, the nine cases, and the
private-helper section). The struct's original closing brace at `:999` simply became the new
closing brace. There is no `@Test` body hunk of any kind, because there is no added line of any
kind.

### Task 2 — the access drop, the seam, and the sweep

**Nine access drops.** Exactly nine lines changed, one keyword each, no other token on any of them:

```
-    public func schedulableSnapshot() async -> SchedulableSnapshot {
+    func schedulableSnapshot() async -> SchedulableSnapshot {
-    public func continuedSessionSubtitle(
+    func continuedSessionSubtitle(
-    public func ensureContinuedSession() async {
+    func ensureContinuedSession() async {
-    public func handleContinuedSessionEvent(
+    func handleContinuedSessionEvent(
-    public func markContinuedSessionEnded(sessionID: UUID) {
+    func markContinuedSessionEnded(sessionID: UUID) {
-    public func pauseAllSchedulable(expiring sessionID: UUID) async {
+    func pauseAllSchedulable(expiring sessionID: UUID) async {
-    public func reconcileContinuedSession() async {
+    func reconcileContinuedSession() async {
-    public func pushContinuedSessionProgress(sessionID: UUID) async {
+    func pushContinuedSessionProgress(sessionID: UUID) async {
-    public func prepareWorkingSeedAnnouncingProgress(
+    func prepareWorkingSeedAnnouncingProgress(
```

**Six forwarders**, in `DownloadClient+Testing.swift`'s existing `#if DEBUG` extension, each a
single forwarding expression with no conditional, no state, and no extra call:

```swift
public func testingEnsureContinuedSession() async {
    await ensureContinuedSession()
}

public func testingPushContinuedSessionProgress(sessionID: UUID) async {
    await pushContinuedSessionProgress(sessionID: sessionID)
}

public func testingReconcileContinuedSession() async {
    await reconcileContinuedSession()
}

public func testingMarkContinuedSessionEnded(sessionID: UUID) {
    markContinuedSessionEnded(sessionID: sessionID)
}

public func testingPauseAllSchedulable(expiring sessionID: UUID) async {
    await pauseAllSchedulable(expiring: sessionID)
}

public func testingPrepareWorkingSeedAnnouncingProgress(
    payload: DownloadRequestPayload,
    existingDownload: DownloadedGallery,
    folderURL: URL
) async throws -> WorkingSeed {
    try await prepareWorkingSeedAnnouncingProgress(
        payload: payload,
        existingDownload: existingDownload,
        folderURL: folderURL
    )
}
```

Each parameter list and return type is identical to its internal counterpart, so no suite observes
different choreography through the seam than production observes through the internal call. The
extension gained a lead doc recording why the three remaining mutators have no forwarder.

**No forwarder for the unconsumed three.** `schedulableSnapshot`, `continuedSessionSubtitle` and
`handleContinuedSessionEvent` have zero call sites anywhere under `AppPackage/Tests` (verified per
name before the edit), so they got none.

## Zero-caller evidence (the premise, re-verified at execution time)

`grep -rn "<name>" App ShareExtension AppPackage/Sources --include='*.swift'`, filtered to drop
`AppPackage/Sources/DownloadClient/`:

| Symbol | Hits outside DownloadClient |
|--------|-----------------------------|
| `schedulableSnapshot` | none |
| `continuedSessionSubtitle` | none |
| `handleContinuedSessionEvent` | none |
| `ensureContinuedSession` | none |
| `markContinuedSessionEnded` | none |
| `pauseAllSchedulable` | none |
| `reconcileContinuedSession` | none |
| `pushContinuedSessionProgress` | none |
| `prepareWorkingSeedAnnouncingProgress` | none |

Empty for all nine: the drop is compile-provable attack-surface reduction with no behavior delta,
and no symbol had to be held back as a finding.

## Re-spell inventory (90 call sites, 10 files)

Counted per file immediately before the sweep, matching `\.<name>(` for the six forwarded mutators:

| File | Call sites re-spelled |
|------|----------------------|
| `DownloadContinuedSessionLedgerTests.swift` | 29 |
| `DownloadContinuedSessionTests.swift` | 20 |
| `DownloadContinuedSessionIdentityTests.swift` | 12 |
| `DownloadContinuedSessionExpirationTests.swift` | 10 |
| `DownloadContinuedSessionBasisTests.swift` | 9 |
| `DownloadCoordinatorRepairSeedTests.swift` | 3 |
| `DownloadContinuedSessionInterleaveTests.swift` | 2 |
| `DownloadDeleteConvergenceTests.swift` | 2 |
| `DownloadInterruptedResumeTests.swift` | 2 |
| `DownloadOwnershipConvergenceTests.swift` | 1 |
| **Total** | **90** |

Per symbol: `ensureContinuedSession` 40, `pushContinuedSessionProgress` 38,
`prepareWorkingSeedAnnouncingProgress` 9, `reconcileContinuedSession` 1,
`markContinuedSessionEnded` 1, `pauseAllSchedulable` 1.

**No file outside the plan's inventory carried a call site** — the ten files above are exactly the
task's files list, so there is no inventory finding to report.

**Prose was left alone, provably.** The sweep pattern is dot-anchored, and a pre-sweep grep for
call-shaped hits on comment lines returned zero, so no doc comment could be touched by it. Eight
prose mentions of the production names survive unchanged and still read correctly, because they
describe production behavior rather than a test call:

```
DownloadContinuedSessionLedgerTests.swift:23    `reconcileContinuedSession`
DownloadContinuedSessionLedgerTests.swift:684   `ensureContinuedSession`
DownloadContinuedSessionBasisTests.swift:158    `ensureContinuedSession`
DownloadContinuedSessionBasisTests.swift:263    `pauseAllSchedulable(expiring:)`
DownloadCoordinatorRepairSeedTests.swift:74     `prepareWorkingSeedAnnouncingProgress`
DownloadCoordinatorRepairSeedTests.swift:101    `prepareWorkingSeedAnnouncingProgress`
DownloadCoordinatorRepairSeedTests.swift:201    `prepareWorkingSeedAnnouncingProgress`
DownloadContinuedSessionInterleaveTests.swift:107 `ensureContinuedSession`
```

## Verification

| Check | Result |
|-------|--------|
| Task 1 targeted run (both suites, single invocation) | `** TEST SUCCEEDED **` — 27 tests in 2 suites, 3 known issues (the pre-existing `withKnownIssue` unimplemented-endpoint arms) |
| Task 2 full `FeatureTests` plan (single invocation) | `** TEST SUCCEEDED **` — 841 tests, 836 passed, 0 failed, 0 skipped, 5 pre-existing expected failures — identical to 15-27's baseline |
| SwiftLint `--strict`, root config, all 13 touched files | 0 violations, 0 serious |
| `grep -c 'public func …'` over the eight ContinuedSession mutators | `0` (was `8`) |
| `grep -c 'public func prepareWorkingSeedAnnouncingProgress'` | `0` (was `1`) |
| `grep -c` over the six forwarder declarations | `6` |
| `grep -c 'testingSchedulableSnapshot\|testingContinuedSessionSubtitle\|testingHandleContinuedSessionEvent'` | `0` |
| `grep -rn '\.<direct spelling>('` over `AppPackage/Tests/DownloadsFeatureTests/` | no output — none survives, even in dead code |
| `grep -c 'func testExpiration'` source / new | `0` / `3` |
| Test-file diff lines that are not a call re-spelling | `0` |
| Over-120-column lines in any touched file | `0` (no re-spelled line needed re-wrapping) |

### `wc -l` for every touched file (gate is 1000)

| File | Lines |
|------|-------|
| `DownloadClient+ContinuedSession.swift` | 602 |
| `DownloadClient+ExecutionSupport.swift` | 596 |
| `DownloadClient+Testing.swift` | 112 |
| `DownloadContinuedSessionTests.swift` | **596** (was 999 — 404 lines of headroom) |
| `DownloadContinuedSessionExpirationTests.swift` | 417 |
| `DownloadContinuedSessionLedgerTests.swift` | 812 |
| `DownloadCoordinatorRepairSeedTests.swift` | 411 |
| `DownloadContinuedSessionBasisTests.swift` | 345 |
| `DownloadContinuedSessionIdentityTests.swift` | 253 |
| `DownloadInterruptedResumeTests.swift` | 236 |
| `DownloadContinuedSessionInterleaveTests.swift` | 179 |
| `DownloadOwnershipConvergenceTests.swift` | 163 |
| `DownloadDeleteConvergenceTests.swift` | 128 |
| `DownloadFeatureTestHelpers.swift` (untouched) | 716 |

`DownloadContinuedSessionTests.swift` came in at 596 — below the plan's ≤700 target — and the
re-spell added no line to it, because every re-spelled line stayed inside 120 columns.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The relocation left `DownloadContinuedSessionTests.swift`'s `AppModels`
import dead**
- **Found during:** Task 1
- **Issue:** `AppModels` was reachable from that file only through `DownloadDisplayStatus` and
  `DownloadFailure` in the `GalleryStateSnapshot` struct, which moved. Leaving the import behind
  would have been a dead line introduced by this plan's own edit.
- **Fix:** Removed the import. Verified by compiling the whole test target — the remaining 18 cases
  name no `AppModels` type.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift`
- **Commit:** `db02a03d`

### Plan-expectation deltas (no code change)

**A. No helper needed lifting to `DownloadFeatureTestHelpers.swift`.** The plan provided for
shared helpers to be lifted there per the 15-26 precedent and listed that file among the files this
plan modifies. Call-site inspection found every helper exclusive to the moved family, so all six
moved into the new file and `DownloadFeatureTestHelpers.swift` is byte-unchanged. The
no-duplication criterion is satisfied more strongly than the lift would have satisfied it: one
declaration each, in one file.

**B. The new file omits `CustomDump`.** The plan asked for "the same import list as the source
file". `expectNoDifference` appears only in `testStartIsRecordedBeforeAnyProgressUpdate`, which
stayed behind, so copying `CustomDump` across would have added an unused import to a brand-new
file. The new file imports the five modules it uses (`AppModels`, `BackgroundProcessingClient`,
`DownloadClient`, `Foundation`, `Testing`), sorted per `sorted_imports`.

No other deviations. No authentication gates. No architectural changes. No case weakened, no pinned
literal changed, no escape hatch used (`@unchecked Sendable`, `nonisolated(unsafe)`,
`@preconcurrency` and SwiftLint suppressions are all absent from the diff).

## Prohibition ledger

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No case weakened/deleted, no pinned literal changed, no case body altered beyond the seam re-spell | held | Task 1 diff is 403 deletions / 0 insertions; Task 2's test-file diff has 0 lines that are not a call re-spelling; case count 27 → 27 |
| No forwarder for `schedulableSnapshot`, `continuedSessionSubtitle`, `handleContinuedSessionEvent` | held | `grep -c 'testingSchedulableSnapshot\|testingContinuedSessionSubtitle\|testingHandleContinuedSessionEvent'` → `0` |
| No logic, state or conditional inside a forwarder | held | All six bodies quoted above; each is one forwarding expression |
| `prepareWorkingSeed`, the trust set, the floor arithmetic and every other executable production line untouched | held | Production diff is 9 keyword-only lines plus the additive `#if DEBUG` seam; `git diff --stat` on `DownloadClient+ContinuedSession.swift` is 8 changed lines, on `+ExecutionSupport.swift` 1 |
| No concurrency or lint escape hatch | held | SwiftLint `--strict` 0 violations across 13 files; the banned tokens appear nowhere in the diff |

## Threat Flags

None. The two registered threats are both discharged:

- **T-15-28-01 (Elevation of Privilege)** — mitigated and compile-enforced: the nine mutators are
  internal, so the capability is reachable only through the coordinator's own choreography (SC4).
- **T-15-28-02 (Tampering, the `#if DEBUG` seam)** — mitigated: the seam is compiled out of release
  builds by the `DEBUG` condition and carries only thin forwarders for members a suite consumes.

No new security-relevant surface was introduced; this plan only removed surface.

## Known Stubs

None.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `db02a03d` | `test(15-28): split out the expiration case family` |
| 2 | `7a37e40b` | `refactor(15-28): make session mutators module-internal` |

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- Commit `db02a03d` — FOUND in `git log`
- Commit `7a37e40b` — FOUND in `git log`
