---
status: complete
phase: 15-continued-background-downloads
source: [15-VERIFICATION.md, 15-54-SUMMARY.md]
started: 2026-07-29T03:54:41Z
updated: 2026-08-08T09:55:33Z
---

## Current Test

[testing complete]

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

test: Observe the system progress card across a multi-gallery queue — including a `.repair`
re-download — then cancel from the card, foreground, and compare queue state against pausing each
gallery by hand.
expected: One neutral card whose counts advance with real work and never fall back within a
reporting regime; the subtitle names the galleries that actually remain, reaching zero when the
queue drains; a repair of a gallery whose files were deleted outside the app climbs from its
announce rather than freezing at the record's stale claim; card-cancel state matches the in-app
per-gallery pause baseline.
why_human: The card and its cancel affordance are system-owned and do not render or fire in the simulator.
covers: SC2
result: issue
reported: "After both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages."
severity: major
retest_round_3_result: issue
retest_round_3_reported: "After both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages."
retest_round_3_severity: major
user_hypothesis: |
  The gallery count is derived from the current active queue membership rather than the same
  cumulative session basis as totalUnitCount. If totalUnitCount Y represents pages from Z
  galleries, the subtitle should display Z galleries, including galleries that already completed.
retest_round: 3
retest_reason: |
  Both gaps this test produced are now closed in code. G-15-2's liveness clause was confirmed on
  device at the round-2 retest; G-15-2B (the stale "1 gallery" subtitle at drain) was closed by
  plan 15-22's terminal push and is reconciled resolved above. Since that retest the phase ran
  rounds 9-18 of gap closure over the same surface, ending in plan 15-54's numerator REDESIGN
  (commits a6105b0b, d155236a, 5df56a8e, d4d568c6): the fraction the card shows is no longer
  inferred from the on-disk index record and corrected, it is measured by a run-owned
  `RunProgressBasis`. That changes what this run should observe (see expected), so the previous
  device observation does not carry forward. Deterministic in tests — 888/0 green, 374 in the
  downloads target — but the card is system-rendered and has surprised this phase twice, and
  15-VERIFICATION.md holds SC2 at failed until a device says otherwise.
retest_steps: |
  1. Queue at least two galleries, start in the foreground, then background the app.
  2. Watch the card across the FIRST gallery's completion: counts keep advancing, subtitle keeps
     naming the galleries that actually remain.
  3. Watch the card as the LAST gallery completes: the final subtitle must describe zero remaining
     galleries (e.g. "N / N pages · 0 galleries"), not a leftover "1 gallery".
  4. Exercise a re-download of a gallery whose files were deleted outside the app (Files.app) while
     its record still claims pages — the `.repair` route. The progress series must CLIMB from the
     announce; it must not sit frozen at the record's old claim.
  5. Pause one gallery mid-queue and confirm the card can still reach completion.
  6. Cancel from the card, foreground, and compare queue state against pausing each gallery by hand.
prior_round_2_result: issue
prior_round_2_reported: "it now doesn't complete the background task when one of the tasks finished, but still the notification description updated to \"1 gallery\" when both completed"
prior_round_2_severity: major
prior_round_2_outcome: |
  Liveness half of G-15-2 confirmed fixed on device: the session no longer finishes when the first
  gallery of the queue completes. Subtitle half still failing — narrowed to G-15-2B.
prior_round_1_result: issue
prior_round_1_reported: "pass but please note the following issue: when there are multiple galleries and one of them finished earlier than others, the background task report completion and the description become \"1 gallery\" only. leaving other tasks in active status but probably not continuing in background."
prior_round_1_severity: major
note: "Card rendering (one neutral card) and card-cancel parity with the in-app pause baseline matched on the round-1 run; every defect since has been in the numbers and the subtitle, not the affordance."

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

### 5. Repair progress climbs from the current run's measured work

test: Delete files outside the app while a completed gallery's persisted record still claims
those pages, trigger its `.repair` re-download, background the app, and observe the system card.
expected: The progress series climbs from the current run's measured starting point instead of
freezing at the persisted record's stale completed-page claim.
why_human: The continued-processing card is system-owned and does not render in the simulator.
covers: SC2 repair progress
result: issue
reported: "After Validate Image Data marked 10 missing pages as pending, Pause and Retry Failed Pages were both disabled, and no Resume or other action was available to start the repair download. After relaunching the app, the yellow missing-page state disappeared and the page count displayed 36 / 36 even though 10 pages remained pending, leaving the persisted and displayed state inconsistent."
severity: major

### 6. Pause and system-card cancellation converge on the in-app baseline

test: During a multi-gallery queue, pause one gallery in the app and confirm the remaining work
can finish. Start another queue, cancel from the system card, foreground the app, and compare its
queue state with pausing every gallery individually in the app.
expected: Pausing one gallery does not strand the remaining session; cancelling from the system
card leaves the same queue state as the in-app per-gallery pause baseline.
why_human: The system-owned cancel affordance does not fire in the simulator.
covers: SC2 pause and cancel parity
result: pass

## Summary

total: 6
passed: 4
issues: 2
pending: 0
skipped: 0
blocked: 0

## Gaps

- gap_id: G-15-2
  truth: "One queue-wide continued-processing session stays alive until the whole queue drains; its subtitle keeps describing the remaining galleries, not just one."
  status: partially_resolved
  resolved_by: [15-20-PLAN.md, 15-21-PLAN.md]
  resolved_at: 2026-08-04
  retest_verdict: |
    Device retest 2026-08-04 confirms the liveness clause: the session no longer finishes when the
    first gallery of the queue completes. The subtitle clause is still failing and continues as the
    narrowed gap G-15-2B below.
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

- gap_id: G-15-2B
  truth: "When the queue drains, the card's subtitle describes the galleries that actually remain schedulable — it must not report a leftover gallery once every queued gallery has completed."
  status: resolved
  resolved_by: 15-22-PLAN.md
  resolved_at: 2026-08-08
  resolution_note: |
    Plan 15-22 (`gap_ids: [G-15-2B]`) added the terminal push to the drain branch of
    `reconcileContinuedSession` and executed to a matching 15-22-SUMMARY.md. Reconciled here on
    resume per the gap-closure protocol. NOT independently re-observed on a device — test 2 below
    is the confirming run, and its expectation has since been widened by the round-18 redesign.
    The push itself was subsequently hardened across rounds 9-18 (15-23 made the drain re-check
    drain-ness rather than session identity; 15-54 replaced the numerator basis the push reports).
  reason: "User reported: it now doesn't complete the background task when one of the tasks finished, but still the notification description updated to \"1 gallery\" when both completed"
  severity: major
  test: 2
  observed: |
    Two galleries queued and run to completion on a physical device. The session correctly stays
    alive past the first gallery's completion (G-15-2's liveness clause is fixed), but the final
    subtitle still reads "1 gallery" after both galleries have completed, rather than describing
    zero remaining schedulable galleries.
  narrowed_from: G-15-2
  root_cause: |
    There is no terminal push. The subtitle can only be written by
    `backgroundProcessingClient.updateProgress`, whose single call site is inside
    `pushContinuedSessionProgress`, which has exactly two callers — the `hasPendingWork() == true`
    branch of `reconcileContinuedSession`, and the throttled manifest flush inside a live page
    loop. When the last gallery settles, `finishActiveTaskIfOwned` converges on
    `scheduleNextIfNeeded`, whose tail reconciles the session; `hasPendingWork()` is now false, so
    control takes the drain branch, which calls `markContinuedSessionEnded` and `finish` — and
    `finish` carries no subtitle (it only reaches `setTaskCompleted(success:)`). The last string
    the card ever receives is the one written by the `force: true` flush at the end of the final
    gallery's page loop, taken while `activeGalleryID` still names that gallery. A gallery being
    downloaded is always `.active` and therefore always schedulable, so that string always ends
    "1 gallery".
  diagnosis_verdict: |
    Stale value from a MISSING terminal push — not a wrong count. Every value ever pushed is
    correct for the instant it was taken, `galleryCount` comes straight from the snapshot's
    `schedulableDownloads().count` and is never derived from a pre-removal or cached read, and a
    `galleryCount == 0` push is structurally unreachable in production (it would need
    `activeTask != nil` with an empty schedulable set, but `displayStatus(for:)` forces `.active`
    whenever `activeGalleryID == gid` and `shouldSchedule` short-circuits `.active` to true).
    The retirement ledger is NOT implicated: `reconcileRetiredSessionPages` touches only
    `retiredSessionPages`/`observedSchedulablePages`, which feed numerator and denominator only.
  coverage_gap: |
    No test covers the terminal push, which is why this shipped green.
    `DownloadContinuedSessionLedgerTests.swift:93` pins a drained
    "20 / 20 pages · 0 galleries" but manufactures that fourth push by calling
    `pushContinuedSessionProgress(sessionID:)` DIRECTLY after the last `settleCompletedDownload` —
    a call the product never makes, because at that point `reconcileContinuedSession` takes the
    drain branch. The three tests that do drive a real drain through production entry points
    assert only `finishCount`/`finishSuccesses` and never inspect `spy.progressUpdates`; the two
    production-path cases that do assert a subtitle (pause, delete) both stop one gallery short of
    an empty queue. Contract-unfaithful test double, same failure mode as the earlier gap rounds.
  artifacts:
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
      issue: "277-289 — the drain branch of reconcileContinuedSession ends the session with no push. This is the defect. (385-420 pushContinuedSessionProgress is correct in itself, simply never invoked at drain.)"
    - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
      issue: "185-188, 250-272 — finish/endSession carry no subtitle (endSession(yielding: nil,) → setTaskCompleted only), confirming the last updateProgress is terminal"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift"
      issue: "61 — the force: true flush that writes the stale final string"
    - path: "AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift"
      issue: "97-99 — .active derivation that keeps the running gallery permanently in its own schedulable set, making a 0-gallery push structurally unreachable"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift"
      issue: "93 — synthesizes the terminal push the product omits, by invoking pushContinuedSessionProgress directly"
    - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
      issue: "221-236, 263-279, 805-835 — the three real-drain tests, none asserting a subtitle"
  missing:
    - "Emit one final push in the drain branch of reconcileContinuedSession before ending the session. Order is load-bearing: it must sit AFTER the existing `continuedClientSessionID == nil` deferral (281-284) and BEFORE markContinuedSessionEnded, which clears continuedSessionID (failing the push's own ownership guard) and zeroes retiredSessionPages (the ledger the terminal fraction needs). With the ledger intact this yields \"N / N pages · 0 galleries\"."
    - "Decide during planning whether a push immediately followed by setTaskCompleted actually repaints on device — a real empirical risk, since the card is system-rendered and has surprised this phase twice. If it does not repaint, the alternative is to change galleryCount's basis to the session's whole coverage so no stale value is possible — that is a documented-contract change, not a bug fix, and must be decided deliberately."
    - "Assert the last recorded subtitle on a PRODUCTION-PATH drain — extend testDrainingTheQueueCompletesTheSessionWithSuccess and testCancellingTheLastQueuedWorkItemCompletesTheSession to inspect spy.progressUpdates.last. Do NOT add another directly-invoked push, or the same blind spot reopens."
    - "No localization work needed: the string catalog already renders 0 correctly via the plural `other` category."
  secondary_note: |
    Non-blocking, but it constrains the fix choice: post-ledger the pushed pair mixes bases — the
    fraction is session-cumulative while the count is live-only — so a mid-run read is e.g.
    "16 / 20 pages · 1 gallery" where the 20 spans three galleries. Documented as deliberate.
  debug_session: ".planning/debug/continued-session-subtitle-stuck-at-one-gallery.md"

- gap_id: G-15-2C
  truth: "The gallery count displayed beside X / Y pages equals the number of galleries whose pages are represented by denominator Y, including galleries that already completed during the session."
  status: failed
  reason: "User reported: after both galleries completed, the card still displayed 1 gallery. The count appears to describe only the currently active gallery set, but it should describe every gallery represented by the denominator in X / Y pages."
  severity: major
  test: 2
  user_hypothesis: "The subtitle count uses live queue membership while totalUnitCount uses a cumulative session basis; both should use the same gallery coverage basis."
  artifacts: []
  missing: []

- gap_id: G-15-5
  truth: "After validation marks missing image files as pending, the user can immediately start a repair download, and the missing-page indicator, displayed page count, and persisted pending-page state remain consistent across relaunch."
  status: failed
  reason: "User reported: after Validate Image Data marked 10 missing pages as pending, Pause and Retry Failed Pages were disabled and no Resume or other repair-start action was available. After relaunch, the yellow missing state disappeared and the UI displayed 36 / 36 while 10 pages were still pending."
  severity: major
  test: 5
  artifacts: []
  missing: []

## Deferred Follow-Ups

- test: 6
  idea: "Rename the logs folder so its displayed name begins with an uppercase letter."
  scope: out_of_scope
  deferred_at: 2026-08-08

- test: 6
  idea: |
    Keep a DownloadsView gallery row's swipe-action offset in place while its deletion alert is
    presented. Cancelling should return the row to its resting position; confirming deletion
    should continue the row in the swipe direction and remove it. Eliminate the current
    disappear-reappear-disappear sequence in which the row vanishes when the alert appears,
    returns while awaiting confirmation, and vanishes again only after Delete is confirmed.
  scope: out_of_scope
  deferred_at: 2026-08-08
