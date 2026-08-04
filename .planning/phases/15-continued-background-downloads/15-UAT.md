---
status: testing
phase: 15-continued-background-downloads
source: [15-VERIFICATION.md]
started: 2026-07-29T03:54:41Z
updated: 2026-08-04T07:40:00Z
---

## Current Test

number: 2
name: System progress card renders real progress and its cancel matches the in-app pause baseline
expected: |
  One neutral card whose counts keep advancing past the first gallery's completion, whose subtitle
  keeps naming the remaining galleries, and which still reaches completion after a mid-queue pause.
  Card-cancel state still matches the in-app per-gallery pause baseline.
awaiting: user response

## Tests

### 1. Backgrounded queue outlasts the old grace window

test: On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages,
start in the foreground, background the app for more than 60 seconds, then foreground and compare
persisted page counts against the queue.
expected: Pages keep landing while backgrounded, well past the old grace window; no page lost or duplicated.
why_human: The simulator neither grants continued-processing tasks nor suspends the process as a device does.
covers: SC1
result: pass

### 2. System progress card renders real progress and its cancel matches the in-app pause baseline

test: Observe the system progress card during that run, then cancel from the card, foreground, and
compare queue state against pausing each gallery by hand.
expected: One neutral card with real, monotonically advancing counts; card-cancel state matches the
in-app per-gallery pause baseline.
why_human: The card and its cancel affordance are system-owned and do not render or fire in the simulator.
covers: SC2
result: pending
retest_reason: |
  G-15-2's fix landed in plans 15-20 and 15-21 (commits 425b5a8b, 925669bf, b76c310c, 00bfd9ad).
  The accounting basis was replaced with a session-scoped retirement ledger, so this item needs a
  fresh device run. Deterministic in tests; the card itself is system-rendered and has already
  surprised this phase once, so 15-VERIFICATION.md holds SC2 at present-behavior-unverified until
  a device confirms it.
retest_steps: |
  Queue several galleries, background the app, and watch the card across the first gallery's
  completion (counts must keep advancing, subtitle must keep naming the remaining galleries),
  then pause one gallery mid-queue and confirm the card can still reach completion. Finally
  cancel from the card and compare against the in-app per-gallery pause baseline.
prior_result: issue
prior_reported: "pass but please note the following issue: when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
prior_severity: major
note: "Card rendering (one neutral card, monotonically advancing counts) and card-cancel parity with the in-app pause baseline were observed to match on the first run; the defect was the session ending early on first-gallery completion."

### 3. Refusal, indefinite queuing, expiration and process death lose no work and show no error

test: Exercise a refused or indefinitely queued submission and a system expiration; force-quit
mid-session and relaunch.
expected: No crash, no visible error, no duplicated or lost pages, and persisted work resuming on foreground.
why_human: Real scheduler decisions and process death are not reproducible in unit tests.
covers: SC3
result: pass
note: "Duplicate pages are structurally precluded by index-keyed page filenames; lost pages were checked via the inspector's per-page status and its hash-verifying Validate action."

### 4. Collected diagnostics carry no gallery title and no unmasked identifier

test: Take a sysdiagnose or collected log archive after a real download session and search it for
gallery titles and unmasked gallery identifiers.
expected: No gallery title and no unmasked identifier from the DownloadClient module appears in
collected diagnostics.
why_human: The invariant suite proves the source spellings; only a real collected archive proves
what the system actually persists.
covers: Privacy gate (gap C closure)
result: pass

## Summary

total: 4
passed: 3
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

- gap_id: G-15-2
  truth: "One queue-wide continued-processing session stays alive until the whole queue drains; its subtitle keeps describing the remaining galleries, not just one."
  status: fix_landed_awaiting_retest
  fix_plans: [15-20, 15-21]
  fix_commits: [425b5a8b, 925669bf, b76c310c, 00bfd9ad]
  fix_note: |
    All five `missing[]` items below are addressed in code and covered by tests. The fix is a
    cumulative session-scoped retirement ledger (`retiredSessionPages` +
    `reconcileRetiredSessionPages`), applied as a push-time membership sweep at the single point
    that already reads the schedulable set — so completion, pause, delete, cancel and a scheduling
    block all retire through one formula with no departure-reason branch in production code.
    The three defect-encoding test expectations were rewritten, not supplemented. Removing the
    ledger's contribution was observed to fail 8 cases, so the coverage is not vacuous.
    NOT marked `resolved`: the fix has never been re-observed on a physical device, and the card
    is system-rendered. Test 2 above is the confirming run.
  reason: "User reported: when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
  severity: major
  test: 2
  root_cause: "Session progress is summed over the *currently schedulable* gallery set, so a finished gallery leaves the numerator and denominator together, while the monotonic floor `lastPushedCompletedPageCount` holds the numerator at its pre-shrink queue-wide value. The second clamp then lifts the denominator back up to meet that stale floor, pinning the fraction at exactly 1.0 and collapsing the subtitle to the remaining gallery count."
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      issue: "schedulableProgress() (33-42) builds numerator, denominator and galleryCount from one shrinking basis; pushContinuedSessionProgress() (267-286) clamps completed against a monotonic floor and then raises pageCount to match it"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
      issue: "settleCompletedDownload (238-242) removes the finished gallery from queueStore — the shrink trigger; correct in itself and must stay"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      issue: "tests at 342-372 and 413-435 assert the defective output ('6 / 6 pages · 1 gallery', '2 / 2 pages · 0 galleries') as expected — the bug is encoded in the suite, which is why it shipped green; must be rewritten, not supplemented"
  missing:
    - "Replace the shrinking accounting basis with a cumulative session-scoped ledger: when a gallery leaves the schedulable set by completing, fold its pageCount and final completedPageCount into a retired-work accumulator added to BOTH numerator and denominator of every later push"
    - "Let completedUnitCount rise naturally and monotonically across gallery boundaries so the max() floor becomes redundant defence rather than the mechanism"
    - "Keep the denominator growing only when galleries join (preserves D-06/D-10); keep subtitle galleryCount as the remaining schedulable count (already correct)"
    - "Decide during planning whether a gallery leaving by pause/delete also retires into the ledger — it must not inflate the denominator with work that will never be done"
    - "Rewrite DownloadContinuedSessionTests expectations at 342-372 and 413-435 to assert queue-wide progress across a gallery completion"
  debug_session: ".planning/debug/continued-session-ends-on-first-gallery-completion.md"
  liveness_note: "No per-gallery completion predicate exists — finish() is gated on hasPendingWork() == false, so the session's end condition is genuinely queue-wide. The hazard is indirect: every later flush pushes the same frozen completedUnitCount, destroying the liveness signal the scheduler uses to detect a stalled task, which invites a forced expiration that routes to pauseAllSchedulable and pauses the remaining galleries. Not cosmetic."
