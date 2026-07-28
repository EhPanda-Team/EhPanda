---
phase: 15-continued-background-downloads
plan: 05
subsystem: infra
tags: [backgroundtasks, download-queue, asyncstream, privacy, lifecycle]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plan 15-04's injected session client, its three coordinator state fields, the two localized card keys and the drivable spy — this plan is the first code to read or write any of them"
provides:
  - "A coordinator-owned session lifecycle: start, event policy, end marker, progress arithmetic and pause-all"
  - "ContinuedSessionProgress, the counts-only transport value the card's string builder consumes"
  - "Four ensure-session call sites, one per queue-mobilizing user action, all inside the coordinator"
  - "A session-liveness probe for tests"
  - "An internal schedulability predicate shared by the scheduler and the session"
affects: [15-06, 15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "The liveness flag is set synchronously after the last guard and before the first point another caller could interleave, so the guard itself is the whole double-start defense and nothing rolls it back"
    - "A queue-wide side effect (pause-all) iterates the existing per-gallery primitive rather than adding a bulk mutation, so one set of invariants stays in one place"
    - "A monotonic clamp on the pushed completed count lives in the domain-aware caller, not in the domain-agnostic client"

key-files:
  created:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "The session lifecycle methods are public, matching every other DownloadCoordinator extension method in the module; the plan's internal spelling would have made three of its five required lifecycle cases unreachable, because the test target does not use @testable import DownloadClient."
  - "The pushed total is held at or above the monotonic completed count, so the rare queue shrink that drops the summed total below pages the session already finished still cannot report a fraction above one."
  - "The pause-toggle's resume branch ensures a session only after the resume returns success, so a not-found resume cannot mint an identifier for work that does not exist."

patterns-established:
  - "A private schedulableDownloads() helper reads the index exactly the way the schedulable-work predicate does, so progress, pause-all and the scheduler can never describe different gallery sets"

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "A queue-mobilizing user action starts exactly one continued-processing session when schedulable work exists"
    requirement: SC1
    verification:
      - kind: unit
        ref: "testResumingWithSchedulableWorkStartsExactlyOneSession drives the pause toggle's resume branch on an inactive fixture download; the spy records startCount == 1 and testingHasContinuedSession() reports true"
        status: pass
      - kind: other
        ref: "grep -c 'ensureContinuedSession' on DownloadClient+PublicAPI.swift => 2 and on DownloadClient+RetryHelpers.swift => 2; four call sites, one per mobilizing entry point"
        status: pass
    human_judgment: false
  - id: D2
    description: "A second queue-mobilizing action taken while a session is live starts no second session"
    requirement: SC1
    verification:
      - kind: unit
        ref: "testSecondMobilizingActionDuringLiveSessionStartsNoSecondSession follows the resume with a per-page retry and then a direct ensure call; startCount stays 1 and startTitles.count stays 1"
        status: pass
    human_judgment: false
  - id: D3
    description: "No session is started when the schedulable-work predicate is false, and none is started from a non-user path such as the queue resuming at cold launch"
    requirement: SC1
    verification:
      - kind: unit
        ref: "testNoSessionStartsWithoutSchedulableWork calls the ensure path on a coordinator with an empty queue and no active task; startCount == 0 and the liveness probe reports false"
        status: pass
      - kind: other
        ref: "grep -c 'ensureContinuedSession' DownloadClient+Scheduling.swift => 0, so the convergence point (which also runs from cold-launch queue resume) never submits"
        status: pass
      - kind: other
        ref: "grep -rn 'ensureContinuedSession' AppPackage/Sources/DownloadsFeature AppPackage/Sources/DetailFeature | wc -l => 0, so no reducer was touched"
        status: pass
    human_judgment: false
  - id: D4
    description: "Within one session the client call order is start, then zero or more progress updates; no progress update is recorded before start"
    requirement: SC1
    verification:
      - kind: unit
        ref: "testStartIsRecordedBeforeAnyProgressUpdate pushes progress before the tap (nothing recorded), asserts progressUpdates is still empty at the moment startCount becomes 1, then pushes again and sees exactly one update"
        status: pass
    human_judgment: false
  - id: D5
    description: "The card's strings carry no gallery-identifying text"
    requirement: SC1
    verification:
      - kind: unit
        ref: "testStartStringsCarryNoGalleryIdentity asserts the recorded title equals 'Downloading galleries' and the recorded subtitle equals '0 / 2 pages · 1 gallery', and that neither contains the fixture title 'Unmistakable Fixture Gallery Name' or its identifier"
        status: pass
      - kind: other
        ref: "grep -Ec 'gallery\\.title|download\\.title|\\.title\\b' DownloadClient+ContinuedSession.swift => 0; no gallery accessor is reachable from the string builder"
        status: pass
    human_judgment: false
  - id: D6
    description: "Downloads begin immediately on the user action and never wait on the session being granted"
    verification:
      - kind: other
        ref: "Each of the four call sites runs after its entry point has already enqueued and awaited scheduleNextIfNeeded(); the granted event's handler starts nothing, and no code path awaits a grant before doing work"
        status: pass
      - kind: unit
        ref: "The fixture's blocking download is already installed as the active task by the time the spy records the start call, which is what makes hasPendingWork() true in the lifecycle cases"
        status: pass
    human_judgment: false
  - id: D7
    description: "An expiration translates into the same queue state a user would get by pausing each gallery in the app"
    verification:
      - kind: other
        ref: "pauseAllSchedulable() iterates the existing per-gallery pause primitive over the schedulable set; behavioral coverage of the expiration path is plan 15-06's Task 3, which drives the spy's expire()"
        status: deferred
    human_judgment: false
  - id: D8
    description: "The existing queue behavior is unchanged by the four new call sites"
    verification:
      - kind: unit
        ref: "Full DownloadsFeatureTests => Test run with 267 tests in 54 suites passed (262 baseline + 5 new lifecycle cases), including DownloadSchedulingTests and DownloadPauseAndReconcileTests"
        status: pass
      - kind: other
        ref: "xcodebuild clean build -scheme EhPanda => BUILD SUCCEEDED with zero warning:/error: lines, so the SwiftLint build-tool plugin reported no violations"
        status: pass
    human_judgment: false

# Metrics
duration: 15min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 05: Coordinator Session Lifecycle Summary

**The download coordinator now owns a queue-wide continued-processing session end to end — starting it from the four taps that mobilize the queue, summing its counts, translating an expiration into an in-app pause of every schedulable gallery, and refusing to ever run two at once.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-28T09:46:00Z
- **Completed:** 2026-07-28T10:00:57Z
- **Tasks:** 2
- **Files modified:** 6 (1 created)

## Accomplishments

- `DownloadClient+ContinuedSession.swift` (208 lines) holds the whole lifecycle: `ensureContinuedSession()`, `handleContinuedSessionEvent(_:)`, `markContinuedSessionEnded()`, `pauseAllSchedulable()`, `reconcileContinuedSession()`, `pushContinuedSessionProgress()`, `schedulableProgress()`, `continuedSessionSubtitle(for:)`, and one private `schedulableDownloads()` helper.
- `ContinuedSessionProgress` carries a `DownloadProgress` and a gallery count. It is a named value rather than a pair because an unlabeled tuple type is banned at error severity here, and because `DownloadProgress` already owns the clamping (`displayPageCount`, `displayCompletedPageCount`) that keeps a corrupt manifest from producing a zero denominator or a negative numerator (T-15-04).
- `ensureContinuedSession()` guards on liveness and on the schedulable-work predicate, then sets `hasLiveContinuedSession` and zeroes `lastPushedCompletedPageCount` before the first point another caller could interleave. Its doc comment records why that synchronous set *is* the guard: identifiers are minted per session and a second launch-handler registration for one terminates the app (T-15-09).
- The consuming `Task` forwards each event to the handler and calls the end marker once the stream finishes. Nothing cancels it — the client's stream is self-finishing, which the seeded contract case already proved.
- The expiration case is documented at length, because it is the phase's most deliberate-looking-like-a-bug decision (D-11): a user cancel on the card and a system resource reclaim arrive through the same callback with nothing to tell them apart, so one policy serves both. The comment states which half is fully honored (the deliberate cancel) and which cost is accepted (a reclaim also leaves the queue paused), and why the cost is acceptable at all (with no fallback tier the work could not have continued after a reclaim anyway).
- `pauseAllSchedulable()` snapshots the schedulable identifiers and then pauses each through the existing per-gallery primitive. No bulk mutation path was added: that primitive already maintains the scheduling-blocked set, the manifest state and observer notification, and reusing it is what makes the card's cancel literally the same operation as an in-app pause (T-15-10).
- `pushContinuedSessionProgress()` takes one snapshot, raises the completed count to `max(lastPushed, snapshotCompleted)`, stores it back, and pushes both counts as `Int64`. The doc comment explains why the clamp lives in the coordinator rather than the client: the client is domain-agnostic and cannot know that a shrinking total is legal while a rewinding completed count is not — and the scheduler reads a steadily advancing completed count as evidence the task is not stalled.
- `isSchedulableDownload(_:)` went private → internal with a comment saying why: the session must select the very same gallery set the scheduler runs, and a second divergent predicate is exactly the bug this avoids.
- `testingHasContinuedSession()` joined the debug-guarded probe extension.
- Four ensure call sites, all inside the coordinator, all on success paths after the entry point's own work is committed: the enqueue entry point, the pause toggle's `.inactive` (resume) branch only, the retry entry point and the per-page retry entry point. No reducer was touched; every one of the four already flows from an existing reducer action through the existing façade endpoint.
- A comment at the enqueue site records the deliberate gap: only a foreground user action can submit a session, so work that becomes schedulable without a tap runs foreground-only until the next qualifying tap.
- The session suite grew from 3 seam-contract cases to 8, adding start-once, no-second-session, no-work-no-session, neutral strings and call ordering. Every case is fully awaited — no sleeps, and no polling helper was needed, because each assertion follows a completed `await` rather than a background task.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the coordinator session lifecycle** - `dc031fdf` (feat)
2. **Task 2: Ensure a session from every queue-mobilizing user action, with lifecycle coverage** - `b3d2b2b1` (feat)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` (created, 208 lines) - The whole session lifecycle plus the counts-only transport value.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` (modified) - `isSchedulableDownload(_:)` private → internal, with the reason.
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` (modified) - `testingHasContinuedSession()`.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` (modified) - Ensure calls on the enqueue success path and the resume branch of the pause toggle.
- `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` (modified) - Ensure calls on the retry and per-page-retry success paths.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` (modified, 77 → 214 lines) - Five lifecycle cases and the inactive-coordinator fixture wrapper.

## Decisions Made

- **The session lifecycle methods are `public`.** The plan spelled them `func`. The test target imports `DownloadClient` plainly — there is no `@testable import DownloadClient` anywhere in `DownloadsFeatureTests` — so internal methods are invisible to it, and three of the plan's five required lifecycle cases (no-work-no-session, the direct half of no-second-session, and the ordering case's progress push) would have had no reachable trigger. Public also matches the module's dominant convention: `hasPendingWork()`, `pause(gid:)`, `resume(gid:)`, `shouldSchedule(download:)` and `notifyObservers()` are all public on the same actor. The alternative — a second debug-only test hook that performs an action — would have hidden production behavior behind a `#if DEBUG` shim purely to keep a narrower access level that nothing else in the file's neighborhood observes.
- **The pushed total is `max(snapshotTotal, monotonicCompleted)`.** The plan specified the monotonic completed count and the snapshot's clamped total. Those two rules can disagree: if a gallery with many completed pages leaves the queue while a small one remains, the summed total drops below pages the session already finished, and the system's `Progress` would report a fraction above one. Raising the total to the completed count preserves every property the plan asked for — one snapshot, a never-regressing completed count, a recomputed total — and removes the only way this arithmetic could produce a nonsensical fraction. It is a one-expression widening, documented inline.
- **The resume branch ensures only on success.** `resume(gid:)` can return `.failure(.notFound)`, and the plan's "on the successful path only" is load-bearing here rather than decorative: an ensure on a failed resume would mint an identifier and put a card on screen for a gallery that no longer exists.
- **The tests never poll.** The plan asked for the shared async-condition helper rather than fixed sleeps. Neither was needed: `ensureContinuedSession()` awaits the client's `start` inline, so the spy's counters are settled the moment the entry point returns. A `waitUntil` here would have bounded a hang that cannot occur and hidden a real ordering bug behind a retry loop.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] The pushed total is held at or above the monotonic completed count**

- **Found during:** Task 1
- **Issue:** The plan's two stated rules (a never-regressing completed count, and the snapshot's clamped total) can produce `completed > total` when a mostly-finished gallery leaves the queue and a small one remains. `Progress.fractionCompleted` would then exceed one.
- **Fix:** The pushed total is `Int64(max(snapshot.progress.displayPageCount, completedPageCount))`, with an inline comment stating why.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`
- **Commit:** `dc031fdf`

**2. [Rule 3 - Blocking] The session lifecycle methods are `public` rather than internal**

- **Found during:** Task 2
- **Issue:** `DownloadsFeatureTests` imports `DownloadClient` without `@testable`, so internal coordinator methods cannot be called from the suite. Three of the plan's five required lifecycle cases had no reachable trigger.
- **Fix:** Declared the session lifecycle methods `public`, consistent with every other `DownloadCoordinator` extension method in the module. `isSchedulableDownload(_:)` stayed internal exactly as the plan specified.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`
- **Commit:** `dc031fdf`

## Deferred Items

None. `reconcileContinuedSession()` and `pushContinuedSessionProgress()` are defined here but not yet called from any queue path — plan 15-06 wires the reconcile into the scheduling convergence point and the execution collision branch, and the progress push into the throttled manifest flush. That split is the plan's, not a shortfall: 15-06's Task 1 reads "the reconcile method added in plan 15-05".

## Acceptance-Criteria Notes

- The `grep -Ec 'gallery\.title|download\.title|\.title\b'` criterion on the session file returns `0` including comments; the localized symbol is spelled `.continuedSessionTitle`, whose capital `T` the case-sensitive pattern does not match.
- Task 2's "at least five lifecycle cases in addition to the seam contract cases" is satisfied exactly: the suite runs 8 cases, 3 of them the contract cases plan 15-04 seeded (which is where the run's 3 known issues come from — they are the deliberate `withKnownIssue` expectations against the unimplemented test value, not failures).

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands were run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5); the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed — project, scheme, test plan and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.
- The Simulator does not support continued background processing, so nothing here exercises the framework end to end. Everything asserted is coordinator behavior against the spy.

## Issues Encountered

None.

## Verification Evidence

- `grep -c 'func ensureContinuedSession' …/DownloadClient+ContinuedSession.swift` -> `1`; the same command returns `1` for `handleContinuedSessionEvent`, `markContinuedSessionEnded`, `pauseAllSchedulable`, `reconcileContinuedSession`, `pushContinuedSessionProgress`, `schedulableProgress` and `continuedSessionSubtitle`.
- `grep -c 'struct ContinuedSessionProgress' …/DownloadClient+ContinuedSession.swift` -> `1`.
- `grep -c 'testingHasContinuedSession' …/DownloadClient+Testing.swift` -> `1`.
- `grep -c 'private func isSchedulableDownload' …/DownloadClient+Scheduling.swift` -> `0`.
- `grep -Ec 'gallery\.title|download\.title|\.title\b' …/DownloadClient+ContinuedSession.swift` -> `0`.
- `grep -rn 'analyticsClient\|AnalyticsClient' AppPackage/Sources/DownloadClient | wc -l` -> `0` (T-15-07).
- `grep -rn 'swiftlint:disable' AppPackage/Sources/DownloadClient | wc -l` -> `0`.
- `grep -c 'ensureContinuedSession' …/DownloadClient+PublicAPI.swift` -> `2`; `…/DownloadClient+RetryHelpers.swift` -> `2`; `…/DownloadClient+Scheduling.swift` -> `0`.
- `grep -rn 'ensureContinuedSession' AppPackage/Sources/DownloadsFeature AppPackage/Sources/DetailFeature | wc -l` -> `0`.
- `wc -l …/DownloadClient+ContinuedSession.swift` -> `208` (the plan's artifact minimum is 110).
- `awk 'length > 120'` over every file this plan created or modified -> no output.
- Task 1 run: `-only-testing:DownloadsFeatureTests` -> `Test run with 262 tests in 54 suites passed`, `** TEST SUCCEEDED **`.
- Task 2 targeted run: `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` -> `Test run with 8 tests in 1 suite passed ... with 3 known issues`, `** TEST SUCCEEDED **`.
- Task 2 full target: `-only-testing:DownloadsFeatureTests` -> `Test run with 267 tests in 54 suites passed ... with 3 known issues`, `** TEST SUCCEEDED **`, including `DownloadSchedulingTests` and `DownloadPauseAndReconcileTests`.
- `xcodebuild clean build -scheme EhPanda` -> `** BUILD SUCCEEDED **`, zero `warning:`/`error:` lines.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-06 has both of its hooks waiting: `reconcileContinuedSession()` for the scheduling convergence point and the execution collision branch, and `pushContinuedSessionProgress()` for the throttled manifest flush. Neither has a caller yet, so 15-06 is a pure wiring change plus coverage.
- The expiration path is implemented and documented but not yet behaviorally covered; 15-06's Task 3 drives it through the spy's `expire()` and asserts the resulting per-gallery display status.
- `makeInactiveCoordinator(gid:spy:galleryTitle:)` in the session suite is the shape later cases can reuse: the blocking fixture with its queue cleared, so a tap under test is the only thing that can produce schedulable work.
- The monotonic clamp and the total-floor are both in place, so 15-06's monotonicity and clamping cases have production behavior to assert rather than to add.

## Self-Check: PASSED

All six files exist on disk with the expected contents, and both task commits (`dc031fdf`, `b3d2b2b1`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
