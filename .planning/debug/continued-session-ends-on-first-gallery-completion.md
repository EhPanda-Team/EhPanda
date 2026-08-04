---
status: diagnosed
trigger: "when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
created: 2026-08-04
updated: 2026-08-04
---

## Current Focus

hypothesis: CONFIRMED - the monotonic clamp in `pushContinuedSessionProgress` is applied
to a numerator whose basis shrinks every time a gallery completes, because
`schedulableProgress()` sums only galleries still in the *schedulable* set and
`settleCompletedDownload` removes a finished gallery from `queueStore`. The clamp holds
the numerator at its pre-shrink queue-wide value while the denominator drops to the
remaining galleries, and the second clamp (`pageCount = max(snapshotTotal, completed)`)
then raises the denominator to meet it - producing an exact 1.0 fraction.
test: traced the arithmetic across a 2- and 3-gallery queue and matched it against the
committed unit test that encodes the same numbers.
expecting: a pushed pair of `N / N pages - 1 gallery` at the point the user reported it.
next_action: none - diagnosis complete, handing to `/gsd-plan-phase --gaps`.

## Symptoms

expected: One queue-wide continued-processing session stays alive until the whole
download queue drains; subtitle keeps describing the remaining galleries.
actual: When one gallery of several finishes first, the system card reports completion
and the subtitle collapses to "1 gallery"; other galleries remain shown as active in
app but appear not to continue in background.
errors: none (no crash, no error surface)
reproduction: Test 2 in 15-UAT.md - queue 3+ galleries, background the app, let one
gallery finish before the others. Physical device, iOS 26.
started: Discovered during phase-15 device UAT, 2026-08-04.

## Eliminated

- hypothesis: The session's gallery set / totals are snapshotted once at submit time and
    never recomputed.
  evidence: `DownloadClient+ContinuedSession.swift:258-293` recomputes
    `schedulableProgress()` on every push, and `schedulableProgress()` (33-42) reads a
    fresh index each call. Nothing is captured at submission.
  timestamp: 2026-08-04

- hypothesis: The coordinator itself tears the session down when the first gallery
    completes (a per-gallery rather than queue-empty completion predicate).
  evidence: The only `finish` call sites are
    `DownloadClient+ContinuedSession.swift:244` (guarded by `hasPendingWork() == false`)
    and `:117` (ownership loss during start). `hasPendingWork()`
    (`DownloadClient+PendingWork.swift:10-15`) stays true while any gallery remains in
    `queueStore` and passes `shouldSchedule`. Remaining galleries keep `displayStatus
    == .queued` (`DownloadClient+Persistence.swift:100`), so the predicate is queue-wide
    and correct. No app-side early completion exists.
  timestamp: 2026-08-04

- hypothesis: The remaining galleries silently leave `queueStore` via the background
    hand-off / `IncompleteDownloadError` path, shrinking the schedulable set.
  evidence: Page downloads are awaited in-process (`DownloadClient+PageDownload.swift`,
    `+PageDownloadHelpers.swift`); there is no hand-off that dequeues a still-pending
    gallery. `handleProcessDownloadIncompleteError`
    (`DownloadClient+Execution.swift:205-218`) only fires for the gallery that just
    finished its own batch, not for its queue-mates.
  timestamp: 2026-08-04

## Evidence

- timestamp: 2026-08-04
  checked: `DownloadClient+ContinuedSession.swift:33-42` (`schedulableProgress`)
  found: Both the numerator and the denominator are summed over
    `schedulableDownloads()`, and `galleryCount` is that set's `count`.
  implication: A gallery that finishes leaves BOTH sides of the fraction, not just the
    denominator. This is the structural premise of the defect.

- timestamp: 2026-08-04
  checked: `DownloadClient+Execution.swift:238-242` (`settleCompletedDownload`)
  found: On completion the gallery is removed from `queueStore`; its manifest is then
    complete, so `displayStatus` becomes `.completed`
    (`DownloadClient+Persistence.swift:103-109`) and `shouldSchedule`
    (`DownloadClient+Scheduling.swift:125-135`) rejects it.
  implication: Every gallery completion shrinks the schedulable set - this is the
    ordinary path, not a rare one.

- timestamp: 2026-08-04
  checked: `DownloadClient+ContinuedSession.swift:267-286` (the two clamps)
  found: `completedPageCount = max(lastPushedCompletedPageCount, snapshotCompleted)` and
    `pageCount = max(snapshotTotal, completedPageCount)`.
    `lastPushedCompletedPageCount` is written only at `:95`, `:121` and `:271` - never
    reset on gallery completion (verified by grep across Sources and Tests).
  implication: Once the numerator floor P is set from the whole queue, a shrink to a
    remaining total T < P forces `completed == total == P`, i.e. a literal 100% card.

- timestamp: 2026-08-04
  checked: arithmetic trace, 2 galleries A(100 pages) + B(100 pages)
  found: while A runs the card reaches 100/200. A completes and leaves the queue, so the
    snapshot becomes completed 0 / total 100. Clamps yield completed = max(100, 0) = 100
    and total = max(100, 100) = 100 -> pushed pair `100 / 100 pages - 1 gallery`.
  implication: Exactly the user's verbatim report: card shows complete, subtitle "1
    gallery". With 3 similarly-sized galleries the same state is reached one completion
    later (`a / max(c, a)` with `a >= c`), which is why the user saw it with "multiple".

- timestamp: 2026-08-04
  checked: `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift:342-372`
    (`testPushedCompletedCountNeverDecreasesWithinASession`)
  found: The committed test asserts
    `["6 / 14 pages - 2 galleries", "6 / 6 pages - 1 gallery"]` after the leading gallery
    leaves the queue - the defect encoded as the expected outcome. Its sibling at
    `:413-435` asserts `"2 / 2 pages - 0 galleries"` for the same reason.
  implication: This is why the bug shipped with a green suite. Any fix must rewrite these
    two expectations, not merely add a case.

- timestamp: 2026-08-04
  checked: `15-RESEARCH.md:565-575` (Pattern 3) vs `15-CONTEXT.md:98-100` (D-10)
  found: The research prescribed BOTH "clamp completedUnitCount to be non-decreasing"
    AND "clamp completedUnitCount <= totalUnitCount", and D-10 only anticipated totals
    recomputing when galleries *join*. Neither considered a gallery leaving by
    completing, where the two clamps become jointly unsatisfiable without pinning the
    fraction at 1.0.
  implication: The defect originates in the design guidance, so the fix is a change of
    accounting basis rather than a local patch to the clamp.

- timestamp: 2026-08-04
  checked: liveness consequence - `ContinuedProcessingSession.swift:164-179`,
    `DownloadClient+Persistence.swift:223-225`, `15-RESEARCH.md:301`
  found: Every throttled flush pushes the same frozen `completedUnitCount` to
    `task.progress`. `BGTask.h` states tasks that appear stalled may be forcibly expired.
    A forced expiration reaches `handleContinuedSessionEvent(.expired)`
    (`DownloadClient+ContinuedSession.swift:162-165`) which runs `pauseAllSchedulable`
    (`:210-220`), pausing every remaining gallery.
  implication: The defect is not purely cosmetic. It does not itself stop the queue, but
    it permanently disables the one liveness signal the scheduler reads, which invites the
    forced expiry that does stop it. Confirms "major" severity.

## Resolution

root_cause: >
  `schedulableProgress()` builds the session's progress from the *currently schedulable*
  gallery set, so a finished gallery's pages leave the numerator and the denominator
  together (`settleCompletedDownload` -> `queueStore.remove`). The monotonic floor
  `lastPushedCompletedPageCount` is never rebased for that departure, and
  `pageCount = max(snapshotTotal, completedPageCount)` then lifts the denominator to meet
  the stale floor. The pushed pair therefore becomes `P / P` - a 100% card - as soon as
  the remaining galleries' total drops below the pages already counted, and the numerator
  can never advance again until the survivors collectively re-earn P pages. The subtitle's
  `galleryCount` collapses in the same push because it is `schedulableDownloads().count`.
  Both reported symptoms are this one cause.
fix: (not applied - diagnose-only mode)
verification: (not applied)
files_changed: []
