---
phase: 15-continued-background-downloads
plan: 38
subsystem: downloads
tags: [continued-processing, test-doubles, gap-closure, G-15-17, SC2, SC3]
requires:
  - "15-37's post-WR-08 ordering in ContinuedProcessingSession.start (identity recorded before submission)"
  - "15-26's active-gallery union in schedulableDownloads()"
provides:
  - "A scheduling spy that can refuse a registration and throw from a submission, one-shot each"
  - "An injectable bundle identifier on the session store's internal initializer"
  - "Five cases executing all three .unavailable producers and both nil-launch arms"
  - "The WR-07 companion driving the expiration pause-all under the persisted-queue-lag staging"
affects:
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
tech-stack:
  added: []
  patterns:
    - "One-shot double controls consumed only by the call they change (G-15-10 discipline)"
    - "Bounded rendezvous before unbounded rendezvous, so a regression fails rather than hangs"
key-files:
  created: []
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
decisions:
  - "The throwing-submission case asserts a take-back, not the gap's cancels-nothing expectation: that expectation predates 15-37's reorder."
  - "A submission that threw is recorded as no submission at all, because it never reached the scheduler's queue."
  - "A refused registration IS recorded as an attempt but stores no launch handler, because the real scheduler registers nothing it refused."
  - "The companion's bounded waitUntil precedes its unbounded cancellation rendezvous, so the WR-07 regression fails in 10s instead of hanging the suite."
metrics:
  duration: 105min
  completed: 2026-08-05
status: complete
---

# Phase 15 Plan 38: Contract-Faithful Scheduling Double and the Driven Pause-All Summary

The scheduling spy can now refuse and throw, so every `.unavailable` producer in
`ContinuedProcessingSession.start` and both arms of `handleLaunch`'s nil-task path are executed by
the suite rather than assumed; and WR-07's narrated SC2 cancel half is now an assertion, proved
falsifiable by disarming the union it depends on.

## What Was Built

**Task 1 — the producers and the launch arms** (commit `acc2f41a`)

- `ContinuedTaskSchedulingSpy` gained two one-shot controls, `refusesNextRegistration` and
  `nextSubmissionError`. The always-succeeds premise comment is retired
  (`grep -c 'Registration always succeeds here' … → 0`) and replaced by the controls' contract.
- `ContinuedProcessingSession`'s internal initializer gained `bundleIdentifier: String?`,
  defaulting to the main bundle's. `start` reads the stored value; `shared` still resolves with no
  argument, so production behavior is untouched.
- Five new cases, all following the suite's drive-then-drain determinism idiom.
- `BackgroundProcessingClient`'s every-endpoint sentence was verified and scoped (below).

**Task 2 — the WR-07 companion** (commit `84522e08`)

- `testAnExpirationPausesTheRunningGalleryWhenThePersistedQueueLagsBehindIt` stages the identical
  lag as the sibling case, then issues the expiration's bulk pause through
  `testingPauseAllSchedulable(expiring:)` and asserts both galleries carry the paused shape.
- The sibling's doc block no longer narrates the pause-all consequence; it points at the companion.

## Case-to-Arm Execution Map

Each case is mapped to the production arm it executes by that arm's distinct observable side
effects — the spy's three lists take a different shape for every arm, so no two cases can be
confused for one another.

| Case | Production arm | Distinct observable signature |
|------|----------------|-------------------------------|
| `testAMissingBundleIdentifierYieldsUnavailableAndReleasesTheStore` | `start`'s `guard let bundleIdentifier` | `registeredIdentifiers == []`, `submissions == []`, `cancelledIdentifiers == []`, `cancelAllCount == 1` — the only arm that reaches the stale-build sweep and then touches the scheduler no further |
| `testARefusedRegistrationYieldsUnavailableAndReleasesTheStore` | `start`'s `guard registered` | one attempted registration, `submissions == []`, `cancelledIdentifiers == []` — the only arm with a registration and no submission and no cancel |
| `testAThrowingSubmissionYieldsUnavailableTakesItsRequestBackAndReleasesTheStore` | `start`'s `catch` around `scheduling.submit` | one attempted registration, `submissions == []`, `cancelledIdentifiers == [thatIdentifier]` — the only arm that cancels without ever submitting |
| `testANilLaunchForTheAwaitedRequestYieldsUnavailable` | `handleLaunch`'s `guard let task` with `pendingIdentifier == identifier` | a RECORDED submission followed by a cancel — the only `.unavailable` with `submissions == [identifier]` |
| `testAStaleNilLaunchCannotEndALiveSession` | `handleLaunch`'s identity gate (`pendingIdentifier != identifier` → return) | two submissions, one cancel, and the live stream draining `[.granted]` rather than `[.unavailable]` |

The last row is the discriminating one for the gate: without it the stale nil launch ends session
B, so B's own launch would be turned away and completed unsuccessfully
(`liveTask.completionSuccesses == [false]`) and B's stream would drain `[.unavailable]`. Both
assertions are present and both would flip.

Every producer case asserts the full release contract, not just the event: the drained events are
compared as a whole array (a second event or a stream left open both fail, and the drain loop
exiting at all is what proves the self-finish ran), all three spy lists are compared whole rather
than sampled, and a follow-up `start` is asserted non-`nil`.

## The Take-Back Rationale, Quoted

G-15-17's suggested fix expects every producer to "cancel nothing". That expectation was written
against the ordering 15-37 replaced, and the throwing-submission case records the inherited
disposition where it changed the assertion:

> **The cancelled list is the POST-WR-08 contract, deliberately.** G-15-17's suggested fix expects
> every producer to cancel nothing; that expectation was written against the ordering 15-37
> replaced. `start` now records `pendingIdentifier` BEFORE handing the request over, so this arm —
> and only this one of the three — arrives at `endSession` holding an identifier and the take-back
> fires. `endSession`'s own paragraph states why that is deliberate rather than an oversight: "a
> throw is exactly the case where the store cannot know how far the submission got — so taking the
> request back covers a half-submitted request, while the alternative ordering covers nothing and
> risks leaving one behind."

The other two producers still cancel nothing, exactly as `endSession`'s paragraph says, and both
cases assert `cancelledIdentifiers == []` to hold that line.

## The Spy's One-Shot Discipline, Quoted

```swift
register: { identifier, launchHandler in
    self.registeredIdentifiers.append(identifier)
    guard !self.refusesNextRegistration else {
        // Consumed on the refusing branch alone, and no handler is kept: the real
        // scheduler registers nothing it refused, so a later launch under this
        // identifier is impossible rather than merely unused.
        self.refusesNextRegistration = false
        return false
    }
    self.launchHandlers[identifier] = launchHandler
    return true
},
submit: { identifier, title, subtitle in
    if let error = self.nextSubmissionError {
        // Cleared by the submission that throws it, and recorded as no submission at
        // all: a request whose `submit` threw never reached the scheduler's queue, so
        // listing it beside accepted ones would model an acceptance that did not happen.
        self.nextSubmissionError = nil
        throw error
    }
    self.submissions.append(
        Submission(identifier: identifier, title: title, subtitle: subtitle)
    )
},
```

Both decisions the plan asked to be made and documented are made here: the refusal arm is consumed
only on the branch that refuses, and a thrown submission is recorded as no submission.

## The Companion's Paused-Set Assertions

```swift
        // The bounded wait comes FIRST deliberately. A regression that drops the runner out of the
        // selected set leaves its task parked forever, and `cancellationObserved()` is an unbounded
        // rendezvous: reaching it before anything bounded would turn that regression into a hung
        // suite rather than a failure. `waitUntil` throws at its deadline, so the case ends there,
        // and once it has passed the handler has necessarily already recorded — the pause awaits
        // the cancelled task, whose `onCancel` runs before that await returns.
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        await control.cancellationObserved()
        #expect(await manager.testingActiveGalleryID() == nil)

        let pausedRunner = try #require(await manager.fetchDownload(gid: running.gid))
        #expect(pausedRunner.displayStatus == .inactive)
        #expect(pausedRunner.isIncomplete)
        // The set, not one member: the expiration pauses every schedulable download.
        let pausedSibling = try #require(await manager.fetchDownload(gid: queued.gid))
        #expect(pausedSibling.displayStatus == .inactive)
        #expect(pausedSibling.isIncomplete)
```

The shapes are derived from the pause path, not invented: `writeInitialPauseRecord` cancels the
active task, clears the gid's session state and drops it from the queue store, so
`displayStatus(for:)` resolves an incomplete, unerrored, unqueued, non-active record to `.inactive`.

**Production-issued.** The case body's only pause-related call is
`testingPauseAllSchedulable(expiring: sessionID)` — the forwarder wrapping the production bulk
pause. There is no `pause(gid:)`, no `togglePause`, and no hand-mutation of either gallery's state
between the lag step and the assertions. The session id it expires is read from
`testingContinuedSessionID()`, so the expiration names the live session rather than a synthesized
one.

## Falsifiability, Measured

The plan asked to "watch the selection matter". The 15-26 active-gallery union in
`schedulableDownloads()` was temporarily removed (locally, never committed; reverted before the
green run) and the basis suite re-run in a single invocation:

```
✘ testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt
    (spy.startSubtitles.last → "0 / 4 pages · 1 gallery") == "6 / 14 pages · 2 galleries"
✘ testAnExpirationPausesTheRunningGalleryWhenThePersistedQueueLagsBehindIt
    (spy.startSubtitles.last → "0 / 4 pages · 1 gallery") == "6 / 14 pages · 2 galleries"
✘ testAnExpirationPausesTheRunningGalleryWhenThePersistedQueueLagsBehindIt
    DownloadFeatureTestHelpers.swift:729 Expectation failed: await condition()   (after 10.086s)
```

The sibling fails on its subtitle alone — which is the gap: the pause-all consequence it documents
is invisible to it. The companion fails on the subtitle AND on the pause never happening, which is
the WR-07 claim itself. The 10.086s figure is the reordering working: the bounded `waitUntil`
deadline ends the case instead of the unbounded cancellation rendezvous hanging it.

## The Client Doc Claim, Verified

The sentence "the client tests exercise that behavior for every endpoint" was checked against the
suite. It is TRUE as scoped — `testUnimplementedClientReportsAnIssueForEveryEndpoint` calls all
three endpoints (`start`, `updateProgress`, `finish`) of the macro-synthesized value. What it was
not was unambiguous: read loosely it sounds like a claim about the store's lifecycle, which is how
the review read it. It now names the case that discharges it and states explicitly what it does not
claim, pointing at `ContinuedProcessingSessionTests` for the store's own arms. No false claim was
found; the ambiguity that made a reviewer see one is gone.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] A new spy doc comment broke the scheduler-scope invariant**

- **Found during:** Task 2's first full FeatureTests run.
- **Issue:** the Task 1 doc for `refusesNextRegistration` spelled the system scheduler's type name
  to explain what the control models. `BackgroundExecutionInvariantTests/testTheSystemSchedulerIsNamedOnlyByTheClientSeam()`
  scans file CONTENTS, comments included, and correctly flagged
  `ContinuedProcessingSessionTests.swift` as naming the scheduler outside the client module. The
  targeted Task 1 run did not include that suite, so it surfaced only at the full run.
- **Fix:** the comment now describes the scheduler generically and says why it is described rather
  than spelled. No exemption was added and the invariant was not weakened — an exemption here would
  have been exactly the escape hatch the plan prohibits.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift`
- **Commit:** `84522e08`

**2. [Rule 2 — Missing correctness] The companion's rendezvous order**

- **Found during:** Task 2's falsifiability probe.
- **Issue:** as first written the case awaited `control.cancellationObserved()` — an UNBOUNDED
  rendezvous — before any bounded wait. Under the regression the case exists to catch, the runner is
  never cancelled, so that await never returns: the regression would have hung the suite rather than
  failed it. This is the choreography axis of the standing mandate applied to the case's own
  structure, and it was only visible because the probe was run.
- **Fix:** the bounded `try await waitUntil { testingHasActiveTask() == false }` now comes first and
  throws at its 10s deadline; the unbounded rendezvous follows, where it is guaranteed to return
  immediately because the pause awaits the cancelled task and `onCancel` runs before that await
  returns. The comment names the reason so a later edit cannot reorder it back innocently.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift`
- **Commit:** `84522e08`

### Prescriptions Deliberately Not Followed

- **G-15-17's "cancels nothing" for all three producers.** Followed for two of the three; the
  throwing-submission arm asserts the take-back that 15-37's reorder introduced, with the inherited
  disposition recorded in the case doc and quoted above. Writing the gap's expectation would have
  asserted a contract the code no longer has.

## Verification

| Run | Scope | Result |
|-----|-------|--------|
| Targeted | `DownloadsFeatureTests/ContinuedProcessingSessionTests` | 12 tests, 1 suite, passed — `** TEST SUCCEEDED **` |
| Targeted | `DownloadsFeatureTests/DownloadContinuedSessionBasisTests` | 10 tests, 1 suite, passed — `** TEST SUCCEEDED **` |
| Probe (union disarmed, reverted) | same basis suite | 3 issues, both lag cases failed — evidence above |
| Full | `FeatureTests`, whole plan | `** TEST SUCCEEDED **` [65.666 sec], exit 0, zero `✘` lines |
| Lint | `swiftlint --strict` over `AppPackage/Sources` and `AppPackage/Tests` | clean, zero violations |

Each was a single invocation; none overlapped another.

Acceptance greps:

- `grep -c 'Registration always succeeds here' …/ContinuedProcessingSessionTests.swift` → `0`
- each of the five case names → `1`
- `grep -c 'testAnExpirationPausesTheRunningGalleryWhenThePersistedQueueLagsBehindIt' …/DownloadContinuedSessionBasisTests.swift` → `1`
- `grep -c 'bundleIdentifier' …/ContinuedProcessingSession.swift` → `5` (property, doc, parameter, assignment, read site); `shared` still resolves with no argument
- `wc -l …/DownloadContinuedSessionBasisTests.swift` → `996` (below the 1000-line error threshold)
- `wc -l …/ContinuedProcessingSessionTests.swift` → `820`

## Prohibitions

| Prohibition | Status |
|-------------|--------|
| No production behavior change beyond the injectable bundle identifier | Held — `shared` resolves with no argument, every pre-existing case passes unchanged, no existing literal moved |
| No hand-issued pause in the WR-07 companion | Held — the body's only pause-related call is the forwarder; no pre-pause, no state hand-mutation |
| No existing store or basis case weakened or deleted | Held — the only edit to an existing case is the sibling's doc block, which keeps every assertion it had |
| No concurrency or lint escape hatch, no SwiftLint suppression | Held — the one invariant violation was fixed at its root by rewording, not exempted |

## Threat Mitigations

| Threat ID | Disposition | How |
|-----------|-------------|-----|
| T-15-38-01 | mitigated | The three producer cases pin yield-and-self-finish end to end, each against the arm's distinct spy signature |
| T-15-38-02 | mitigated | `testAStaleNilLaunchCannotEndALiveSession` drives the identity gate; `testANilLaunchForTheAwaitedRequestYieldsUnavailable` pins the honest teardown |
| T-15-38-03 | mitigated | The parameter sits on the already-internal initializer, is defaulted, and `shared` resolves unchanged |

## Self-Check: PASSED

- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` — FOUND
- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — FOUND
- Commit `acc2f41a` — FOUND
- Commit `84522e08` — FOUND
