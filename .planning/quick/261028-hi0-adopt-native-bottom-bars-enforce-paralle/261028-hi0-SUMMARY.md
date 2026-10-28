---
phase: quick-261028-hi0
plan: 01
subsystem: testing
tags: [swiftui, swift-testing, swiftlint, size-audit]
status: incomplete
checkpoint_date: 2026-10-28
provides:
  - Page-specific native bottom-bar and edge-effect proposals
  - Serialization lint enforcement and explicit normal test-plan parallelism
  - Isolated hosted-app test dependencies and repaired simulator-lock tests
  - Reproducible unsigned Release payload measurements
affects: [test-runners, ui-review, release-size]
requirements-completed: [QUICK-UI-REVIEW, QUICK-SIZE-AUDIT]
requirements-pending: [QUICK-PARALLEL-TESTS]
key-decisions:
  - UI source changes follow the requested page-selection review.
  - Existing serial runner settings are pending decisions, not grandfathered exceptions.
  - Archive payload, installed footprint and download size are separate measurements.
  - The unavailable configured executor was not silently replaced with another model.
---

# Quick task 261028-hi0 checkpoint

**The review inventory and size audit are delivered; lint enforcement and normal test plans now
favor parallel execution. Three device-bound workflow exceptions await an explicit owner decision.**

## Delivered

- [UI-CANDIDATES.md](UI-CANDIDATES.md) classifies all discovered bottom-control contexts. B1 replaces
  the compact Library picker inset with `safeAreaBar`; B2–B5 apply soft bottom effects only where
  actual native tab chrome warrants them. B6 optionally moves the standard-size Archives footer.
  Reader controls, toasts and independent presentations retain their existing behavior. These are
  proposals, with an iPhone/iPad accessibility and navigation verification matrix; no UI was changed.
- [PARALLEL-TESTS.md](PARALLEL-TESTS.md) records the new error-level `no_serialized_test` rule,
  owner-approval policy, explicit parallelism on 24 FeatureTests targets and the normal UI target,
  the hosted Store fixture repair, Python test repair, and the remaining runner coupling.
- [SIZE-AUDIT.md](SIZE-AUDIT.md) and [SIZE-MEASUREMENTS.json](SIZE-MEASUREMENTS.json) record an unsigned
  Release archive: 33,989,732 logical bytes, including 22,126,576 executable bytes and 9,488,728 asset
  catalog bytes. No compiler setting, shipping resource or dependency was removed or changed.
  Build-wide `-Osize` comparison and device thinning measurements are the first recommended experiments.

## Verification

- New SwiftLint rule: ordinary, backtick, spaced and parameterized spellings rejected; comments and
  strings accepted. Both actual test trees pass; changed Swift files pass strict lint.
- Python visual-tooling suite: 206 passed after replacing stale process-polling checks with actual
  simulator-lock behavior tests.
- Final parallel FeatureTests: 1,431 identities, 1,422 passed, 9 existing expected outcomes, no
  unexpected failures or skips, and no Repetition nodes. Parameter expansion yields 2,059 executions.
- Two selected normal UI methods pass on separate cloned workers on each of iPhone and iPad:
  four executions, no failures/skips/repetitions. The distinction between concurrent
  destinations and concurrent workers, exact identities and evidence locations is recorded in
  [PARALLEL-TESTS.md](PARALLEL-TESTS.md).
- Unsigned Release archive succeeded with zero compiler/lint warnings. The size baseline precedes
  the Debug-only fixture fix and remains tied to source revision `3572963941`.

The initial parallel feature failure and intermediate compile error are retained in the test report;
the final successful bundle comes from corrected source. No retry, serial switch or expected-failure
annotation was used to conceal a new failure. Existing snapshot/capture skips remain unchanged.

## Implementation commits

1. `93060cd6af` — error-level serialization rule and explicit owner-approval policy.
2. `b3434f9999` — bind the hosted application Store to its inert fixtures and add a scope-change regression.
3. `16732691a0` — replace obsolete process-window tests with simulator-lock behavior checks.
4. `4d4b04d756` — enable parallel execution in every normal feature/UI test-plan target.

This review checkpoint is committed separately after verification.

## Execution adjustments

The GSD planner was dispatched with its resolved model and inherited effort. Authoritative runtime
model/effort metadata is unavailable, so actual settings remain unverified. The resolved executor
model was unavailable in this session's spawn tool; the orchestrator disclosed that mismatch and
executed inline rather than substituting an executor. No executor subagent chose a deviation.

The plan amendment records the two concrete validation defects and their bounded repairs. Task 3
paused at its explicit fixed-device coupling checkpoint: a blanket parallel switch would disconnect
host-driven orientation/capture operations from cloned workers and race the Duo pose mailbox.

## Pending owner decisions and continuation

1. Review UI candidates: recommended B1–B5, optionally include B6, or retain the inventory for now.
   The inventory itself fulfills this task's requested UI review deliverable.
2. Decide whether to approve serialization only for the existing full-content/geometry capture
   sequence, host-driven Duo pose runner and one-test external Appshot capture plan. The alternative
   is a separate implementation that routes state and pose commands to isolated workers. No exception
   is approved or recorded as accepted yet; the authority requirement comes from the owner's request.
3. Once that decision arrives, change the shared Gate and normal runner callers together, preserving
   strict test identity/count/repetition checks and proving result-device attribution for cloned workers.
   Verify the affected runner contracts and native selections before completing QUICK-PARALLEL-TESTS.

Task 1 and Task 2 are complete; Task 3 is partial. This record does not complete the quick task or
Phase 17, and it is intentionally absent from the completed-quick-task table. The existing Phase 17
visual review and explicit-gallery selection gate remains unchanged.
