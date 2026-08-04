---
status: diagnosed
trigger: "it now doesn't complete the background task when one of the tasks finished, but still the notification description updated to \"1 gallery\" when both completed"
created: 2026-08-04
updated: 2026-08-04
---

## Current Focus

hypothesis: CONFIRMED - "1 gallery" at drain is a STALE value, not a wrong count. The card's
  subtitle is only ever written by `updateProgress`, whose single call site is
  `pushContinuedSessionProgress`. That function has exactly two callers, and neither is
  reachable once the queue has drained: `reconcileContinuedSession` pushes only on its
  `hasPendingWork() == true` branch, and the throttled flush runs only inside a live page
  loop. The drain branch marks the session ended and calls `finish`, which carries no
  subtitle. The last string the card ever receives is therefore the one pushed while the
  final gallery was still schedulable - and the running gallery is always schedulable
  (`displayStatus == .active`), so that string always ends "1 gallery".
test: exhaustive call-site enumeration of the subtitle write path (`updateProgress` ->
  `pushContinuedSessionProgress` -> its 2 callers), plus a step-by-step trace of the
  two-gallery device sequence through `completeDownload` -> `settleCompletedDownload` ->
  `finishActiveTaskIfOwned` -> `scheduleNextIfNeeded` -> `reconcileContinuedSession`.
expecting: if the hypothesis holds, the last recorded push in a real drain is
  `"N / N pages · 1 gallery"` and zero pushes follow it. Confirmed statically; the value
  matches the user's verbatim report exactly.
next_action: none - diagnosis complete, hand to `/gsd-plan-phase --gaps` for G-15-2B.

## Symptoms

expected: When every queued gallery has completed, the continued-processing session's
  subtitle must describe the galleries that actually remain schedulable - it must NOT
  report a leftover "1 gallery" once the queue has fully drained. Throughout the run the
  subtitle must keep naming the remaining galleries (this part now works across the first
  gallery's completion).
actual: Two galleries run to completion on a physical iOS device. The session correctly
  stays alive past the first gallery's completion, but the final subtitle still reads
  "1 gallery" after BOTH galleries are done.
errors: none (no crash, no visible error - a wrong count in a system-rendered subtitle)
reproduction: Test 2 in
  .planning/phases/15-continued-background-downloads/15-UAT.md - queue two galleries,
  start downloading, background the app, watch the system progress card's subtitle as
  galleries complete, observe the subtitle after both have completed.
started: Retest 2026-08-04 on feature/gsd-phase-15 at a8c5b212, after the G-15-2 fix
  commits 425b5a8b, 925669bf, b76c310c, 00bfd9ad (plans 15-20 and 15-21). The prior round
  reported the broader defect (early session end + subtitle collapse); the retirement
  ledger fixed the session-liveness half only.

## Eliminated

- hypothesis: The pushed `galleryCount` is arithmetically wrong at drain - an off-by-one,
    or a count read before `settleCompletedDownload` removes the last gallery from
    `queueStore`.
  evidence: `pushContinuedSessionProgress`
    (`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:385-420`)
    sets `galleryCount: snapshot.sessionProgress.galleryCount`, which is
    `schedulableDownloads().count` from the single snapshot taken at `:387`. Every value
    it can carry is correct *for the instant it was taken*: while the second gallery is
    still running, exactly one gallery is genuinely schedulable. The count is never
    computed from a stale or pre-removal read. The defect is that no later, more accurate
    value is ever pushed.
  timestamp: 2026-08-04

- hypothesis: The retirement ledger's push-time membership sweep corrupts or freezes the
    gallery count (the G-15-2 fix over-reaching).
  evidence: `reconcileRetiredSessionPages` (`DownloadClient+ContinuedSession.swift:323-350`)
    reads and writes only `retiredSessionPages` and `observedSchedulablePages`, both of
    which feed `retiredPageCount` (`:397`) and therefore only the numerator and the
    denominator. `galleryCount` is taken straight from the snapshot and never touches the
    ledger. Answering investigation lead 3 directly: the sweep runs at `:389`, *after* the
    snapshot at `:387` that carries the count, but the ordering is irrelevant because the
    ledger cannot influence the count either way.
  timestamp: 2026-08-04

- hypothesis: `finish()` repaints the card - so the terminal state is something the
    completion call chose, and the fix belongs in the client.
  evidence: `BackgroundProcessingClient.finish` takes only `(sessionID, success)`
    (`AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:57`)
    and routes to `ContinuedProcessingSession.finish`
    (`ContinuedProcessingSession.swift:185-188`) -> `endSession(yielding: nil, success:)`
    (`:250-272`), whose only task-facing call is `setTaskCompleted(success:)` at `:267`.
    `task.updateTitle(_:subtitle:)` is called from exactly one place in the whole module,
    `updateProgress` at `:178`. Completion cannot change the subtitle.
  timestamp: 2026-08-04

- hypothesis: A push with `galleryCount == 0` does reach the card in production, but is
    then overwritten or lost.
  evidence: A zero-gallery push requires `hasPendingWork() == true` with an empty
    schedulable set, i.e. `activeTask != nil` while nothing is schedulable
    (`DownloadClient+PendingWork.swift:10-15`). That state is unreachable during a normal
    gallery run: `displayStatus(for:)` returns `.active` whenever `activeGalleryID == gid`
    (`DownloadClient+Persistence.swift:97-99`), and `shouldSchedule` returns true
    immediately for `.active` (`DownloadClient+Scheduling.swift:125-127`), so the gallery
    currently downloading is always in its own schedulable set. Every push taken during
    the last gallery's page loop therefore reports at least one gallery.
  timestamp: 2026-08-04

## Evidence

- timestamp: 2026-08-04
  checked: prior debug session
    .planning/debug/continued-session-ends-on-first-gallery-completion.md
  found: The earlier root cause was a schedulable-set accounting basis whose numerator
    floor (`lastPushedCompletedPageCount`) was never rebased when a gallery left the
    queue. It also recorded that the committed tests then asserted
    `"6 / 6 pages · 1 gallery"` and `"2 / 2 pages · 0 galleries"` as expected values.
  implication: A "0 galleries" expectation already existed in the suite, so the question
    is not whether the code *can* produce that string but whether the product ever reaches
    the call that produces it.

- timestamp: 2026-08-04
  checked: the complete subtitle write path, by exhaustive grep over AppPackage/Sources
  found: `task.updateTitle(_:subtitle:)` has one call site
    (`BackgroundProcessingClient/ContinuedProcessingSession.swift:178`, inside
    `updateProgress`); `backgroundProcessingClient.updateProgress` has one call site
    (`DownloadClient+ContinuedSession.swift:414`, inside `pushContinuedSessionProgress`);
    `pushContinuedSessionProgress` has exactly two callers -
    `DownloadClient+ContinuedSession.swift:291` and `DownloadClient+Persistence.swift:224`.
  implication: The card's subtitle is a pure function of those two call sites. Anything the
    user sees on the card was written by one of them.

- timestamp: 2026-08-04
  checked: `DownloadClient+ContinuedSession.swift:275-292` (`reconcileContinuedSession`)
  found: `guard await hasPendingWork() else { ... markContinuedSessionEnded(...);
    await backgroundProcessingClient.finish(clientSessionID, true); return }`, with
    `await pushContinuedSessionProgress(sessionID:)` on the *other* side of the guard.
  implication: THE DEFECT. The drain branch - the only branch a fully drained queue can
    take - ends the session without ever pushing. There is no terminal push, by
    construction. This is caller 1 of 2, disqualified at drain.

- timestamp: 2026-08-04
  checked: `DownloadClient+Persistence.swift:201-226` (`flushDownloadProgress`) and its two
    call sites in `DownloadClient+PageDownload.swift:61` and `:194`
  found: The push at `:224` rides the manifest flush inside a gallery's page loop, and
    `:61` is a `force: true` flush issued after the last page of a batch resolves, still
    inside `processDownload`.
  implication: Caller 2 of 2 can only fire while a gallery is actively downloading, so it
    is also unreachable after the queue drains. It is, however, the source of the LAST push
    of every session.

- timestamp: 2026-08-04
  checked: end-to-end trace of the reported two-gallery device run
  found: (1) session starts, subtitle "0 / N pages · 2 galleries". (2) The first gallery
    completes: `completeDownload` -> `settleCompletedDownload` removes it from `queueStore`
    (`DownloadClient+Execution.swift:238-242`), the deferred `finishActiveTaskIfOwned`
    (`:244-271`) clears ownership and calls `scheduleNextIfNeeded`, whose tail
    (`DownloadClient+Scheduling.swift:34-36`) reconciles: pending work exists, so it pushes
    "1 gallery" - correct at that instant. (3) The second gallery downloads; every
    throttled flush pushes "1 gallery". (4) Its final `force: true` flush pushes
    `"N / N pages · 1 gallery"`, with the numerator complete because the first gallery's
    pages are retired into the ledger and the second's are all finished. (5) The second
    gallery settles, ownership clears, `scheduleNextIfNeeded` reconciles, `hasPendingWork()`
    is now false -> the drain branch -> `finish` with no push.
  implication: The predicted terminal string is exactly `"N / N pages · 1 gallery"` - a
    complete fraction beside a stale gallery count. That is the user's verbatim report,
    including why the fraction looked done while the description did not.

- timestamp: 2026-08-04
  checked: `DownloadClient+Persistence.swift:90-114` (`displayStatus(for:)`) and
    `DownloadClient+Scheduling.swift:118-135` (`isSchedulableDownload`/`shouldSchedule`)
  found: `activeGalleryID == gid` forces `.active`, and `.active` short-circuits
    `shouldSchedule` to true.
  implication: The gallery being downloaded is always inside its own schedulable set, so
    the smallest gallery count any in-flight push can carry is 1. The card can never reach
    "0 galleries" without a push taken after the active task is cleared - which is
    precisely the push that does not exist.

- timestamp: 2026-08-04
  checked: `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift:32-106`
    (`drainedPair`, `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount`)
  found: The suite pins a drained value of `"20 / 20 pages · 0 galleries"` and asserts the
    four-push series ending in it - but it produces that fourth push by calling
    `await fixture.manager.pushContinuedSessionProgress(sessionID:)` directly at `:93`,
    immediately after `settleCompletedDownload(gid: small.gid)`. The product never makes
    that call: at that point `reconcileContinuedSession` would take the drain branch. The
    file's own header comment states the choice openly - "progress is pushed explicitly
    between steps, so the recorded update list is a fact about the arithmetic rather than
    about scheduling timing" (`:17-18`).
  implication: The test harness synthesizes the terminal push the product omits. That is
    why the ledger work shipped green on a value the device cannot render - the same
    contract-unfaithful-double failure mode recorded for the earlier gap rounds.

- timestamp: 2026-08-04
  checked: every test that drives a real drain through a production entry point -
    `DownloadContinuedSessionTests.swift:221-236`
    (`testDrainingTheQueueCompletesTheSessionWithSuccess`), `:263-279`
    (`testSchedulingPassesAfterTheDrainAddNoSecondCompletion`), `:805-835`
    (`testCancellingTheLastQueuedWorkItemCompletesTheSession`)
  found: All three assert only `finishCount`, `finishSuccesses` and
    `testingHasContinuedSession()`. Not one of them inspects `spy.progressUpdates` at all,
    so none observes what the card was left showing.
  implication: Answering investigation lead 4: NO test covers the terminal push. Every
    subtitle assertion in the suite comes from a directly-invoked push (mid-queue or
    synthesized), and every real-drain assertion ignores the subtitle. The missing coverage
    is the reason the defect survived plans 15-20 and 15-21.

- timestamp: 2026-08-04
  checked: `DownloadContinuedSessionLedgerTests.swift:194-282` (the pause and delete cases,
    the two that do drive production entry points and assert a subtitle)
  found: Both leave a surviving gallery and assert `departedPair` =
    `"6 / 10 pages · 1 gallery"`. Neither reaches an empty queue.
  implication: The production-path subtitle coverage that exists stops one gallery short of
    the drain - exactly the state the device run fails in.

- timestamp: 2026-08-04
  checked: `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings`, key
    `continued_session.subtitle`
  found: The `galleries` substitution has `one`/`other` plural variants, so a count of 0
    renders "0 galleries" through the `other` category.
  implication: No string work is needed for a terminal push; the catalog already renders
    the value correctly.

- timestamp: 2026-08-04
  checked: `DownloadClient+ContinuedSession.swift:229-239` (`markContinuedSessionEnded`)
    against the drain branch's ordering at `:287-288`
  found: `markContinuedSessionEnded` clears `continuedSessionID`, `retiredSessionPages` and
    `lastPushedCompletedPageCount`, and `pushContinuedSessionProgress` guards on
    `continuedSessionID == sessionID` at `:386`.
  implication: A fix must push BEFORE `markContinuedSessionEnded`, or the ownership guard
    rejects it and the ledger it needs is already zeroed. Note also the existing
    `continuedClientSessionID == nil` deferral at `:281-284`, which a terminal push must
    sit behind rather than in front of.

- timestamp: 2026-08-04
  checked: `ContinuedSessionProgress` doc comment
    (`DownloadClient+ContinuedSession.swift:8-19`) against the ledger arithmetic at
    `:396-413`
  found: After the G-15-2 fix the pushed pair mixes two bases by design - the fraction is
    session-cumulative (live sum plus retired pages, so it describes every gallery the
    session covered) while `galleryCount` stays live-only ("the remaining schedulable
    galleries and only those"). Mid-run this already reads e.g. `"16 / 20 pages · 1 gallery"`,
    where the 20 spans three galleries.
  implication: A secondary, non-blocking observation rather than the reported defect. It
    does bear on the fix: under the documented "remaining" semantics a terminal push reads
    `"N / N pages · 0 galleries"`, which satisfies G-15-2B's truth; a planner who instead
    wanted the count to describe the session's whole coverage would be changing the
    documented contract, not fixing this bug.

## Resolution

root_cause: >
  There is no terminal push. The card's subtitle can only be written by
  `backgroundProcessingClient.updateProgress`, whose single call site is inside
  `pushContinuedSessionProgress`, which in turn has exactly two callers - the
  `hasPendingWork() == true` branch of `reconcileContinuedSession`
  (`DownloadClient+ContinuedSession.swift:291`) and the throttled manifest flush inside a
  live page loop (`DownloadClient+Persistence.swift:224`). When the last gallery settles,
  `finishActiveTaskIfOwned` clears the active task and converges on `scheduleNextIfNeeded`,
  whose tail reconciles the session; `hasPendingWork()` is now false, so control takes the
  drain branch at `DownloadClient+ContinuedSession.swift:277-289`, which calls
  `markContinuedSessionEnded` and `backgroundProcessingClient.finish` - and `finish` carries
  no subtitle (`ContinuedProcessingSession.swift:185-188` -> `endSession` ->
  `setTaskCompleted` only). The last string the card ever receives is therefore the one
  written by the `force: true` flush at the end of the final gallery's page loop
  (`DownloadClient+PageDownload.swift:61`), taken while `activeGalleryID` still names that
  gallery - and a gallery being downloaded is always `.active`
  (`DownloadClient+Persistence.swift:97-99`) and therefore always schedulable
  (`DownloadClient+Scheduling.swift:125-127`), so that string always ends "1 gallery". The
  count in that push is correct for the moment it was taken; it goes stale because nothing
  repaints the card after the queue empties. Of the two competing explanations, the evidence
  supports STALE VALUE / MISSING TERMINAL PUSH and rules out a wrong count: every value ever
  pushed is accurate at its instant, and a "0 galleries" push is structurally unreachable in
  production. The suite hid this because `DownloadContinuedSessionLedgerTests` synthesizes
  the terminal push by calling `pushContinuedSessionProgress` directly after the last
  `settleCompletedDownload`, while the three tests that drive a real drain assert only
  `finishCount` and never inspect the recorded subtitle - so no test covers the terminal
  push at all.
fix: (not applied - diagnose-only mode)
verification: (not applied)
files_changed: []
