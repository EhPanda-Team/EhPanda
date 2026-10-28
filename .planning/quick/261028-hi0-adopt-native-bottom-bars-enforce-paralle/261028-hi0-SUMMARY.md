---
phase: quick-261028-hi0
plan: 01
subsystem: ui-testing-and-build
tags: [swiftui, swift-testing, swiftlint, size-audit, size-reduction, screenshots]
status: incomplete
checkpoint_date: 2026-10-28
provides:
  - Approved native bottom edges and Archives safeAreaBar, with 18 before/after screenshot pairs
  - Restored persistent Library title menu with a scaled custom system-style chevron
  - Serialization lint enforcement and explicit normal test-plan parallelism
  - Isolated hosted-app test dependencies and repaired simulator-lock tests
  - Reproducible unsigned Release measurements and a verified 12.35 percent reduction
affects: [test-runners, ui-review, release-size]
requirements-completed: [QUICK-UI-REVIEW, QUICK-SIZE-AUDIT]
requirements-pending: [QUICK-PARALLEL-TESTS]
key-decisions:
  - Owner selected B1–B6; the subsequent persistent title menu replaces the compact bottom picker.
  - Existing serial runner settings are pending decisions, not grandfathered exceptions.
  - Archive payload, installed footprint and download size are separate measurements.
  - The unavailable configured executor was not silently replaced with another model.
---

# Quick task 261028-hi0 checkpoint

**The approved bottom-edge changes and Archives footer are implemented. The final persistent Library
title menu is restored with its custom circular chevron. The size-only revision saves 4.20 MB
(12.35%). Device-bound serialization exceptions remain unapproved; the owner deferred discussion.**

## Delivered

- [UI-IMPLEMENTATION.md](UI-IMPLEMENTATION.md) records B1–B6 adoption and the later title-menu
  request, which supersedes B1's bottom picker. Home, Search, Settings and Library use soft bottom
  edges only with bottom tabs. Archives uses a native bottom bar at standard text sizes and retains
  its accessibility scrolling column. Compact Library roots restore the final persistent native
  title design, source subtitle and scaled custom arrow; expanded sidebar routing is unchanged.
- [SCREENSHOTS.md](SCREENSHOTS.md) links the original review and the implemented comparison gallery:
  18 baseline/implemented pairs plus 18 additional native captures. Originals remain outside Git.
- [PARALLEL-TESTS.md](PARALLEL-TESTS.md) records the new error-level `no_serialized_test` rule,
  owner-approval policy, explicit parallelism on 24 FeatureTests targets and the normal UI target,
  the hosted Store fixture repair, Python test repair, and the remaining runner coupling.
- [SIZE-AUDIT.md](SIZE-AUDIT.md) and [SIZE-MEASUREMENTS.json](SIZE-MEASUREMENTS.json) record an unsigned
  Release archive: 33,989,732 logical bytes, including 22,126,576 executable bytes and 9,488,728 asset
  catalog bytes. This is the original baseline.
- The owner-directed [follow-up](FOLLOW-UP-PLAN.md) implements build-wide Release `-Osize` and excludes
  preview-only helpers and the frozen identifier table from Release. The measured `-Osize` payload with preview cleanup represented by `279897ed0c` was
  **29,793,340 bytes**, saving **4,196,392 bytes (12.35%)**. Debug keeps `-Onone` and all preview IDs.
  [SIZE-REDUCTION.md](SIZE-REDUCTION.md) records each measured stage and five optional approaches.
  No shipping feature, resource or dependency was removed. Signed thinning is still unmeasured:
  export of the unsigned archive returned **No Team Found in Archive**.

## Verification

- New SwiftLint rule: ordinary, backtick, spaced and parameterized spellings rejected; comments and
  strings accepted. Both actual test trees pass; changed Swift files pass strict lint.
- Python visual-tooling suite: 206 passed after replacing stale process-polling checks with actual
  simulator-lock behavior tests.
- Initial parallel FeatureTests: 1,431 identities, 1,422 passed, 9 existing expected outcomes, no
  unexpected failures or skips, and no Repetition nodes. Parameter expansion yields 2,059 executions.
- Two selected normal UI methods pass on separate cloned workers on each of iPhone and iPad:
  four executions, no failures/skips/repetitions. The distinction between concurrent
  destinations and concurrent workers, exact identities and evidence locations is recorded in
  [PARALLEL-TESTS.md](PARALLEL-TESTS.md).
- The original unsigned Release baseline precedes the hosted fixture fix and is tied to `3572963941`.
  A fresh baseline at `f195b7eaaf` reproduces its exact 33,989,732 bytes. All four follow-up archive
  stages succeed with zero compiler/lint warnings; observed compiler commands confirm every shipping
  Swift module uses `-Osize` in the optimized stages.
- Optimized parallel FeatureTests: 1,431 identities, 1,421 passed and 10 existing expected outcomes;
  zero unexpected failures, skips or Repetition nodes. The extra expected diagnostic is an existing
  explicit in-flight-effect skip when a live request remains active. The result and unused worker
  launch diagnostics are explained in [SIZE-REDUCTION.md](SIZE-REDUCTION.md).
- Final normal Debug compilation and strict lint pass. All 1,000 frozen UUID literals are unchanged;
  the identifier table is absent from the final Release executable. Both deployment YAML files parse.
- Native baseline/proposal UI builds pass with zero compiler/lint warnings. All 36 original PNGs have
  matching dimensions within their pair and recorded hashes. The gallery's selector and original-image
  links were checked in the browser. This is bounded proposal evidence, not full UI acceptance.

- UI adoption: 20 initial UI executions pass; the two Search audit failures expose existing small
  header-action bounds. After the label hit regions are corrected, all six selected follow-up
  executions pass once. Final Debug build and strict lint pass; native live-size and footer checks
  are recorded in [UI-IMPLEMENTATION.md](UI-IMPLEMENTATION.md).

The initial parallel feature failure and intermediate compile error are retained in the test report;
the final successful bundle comes from corrected source. No retry, serial switch or expected-failure
annotation was used to conceal a new failure. Existing snapshot/capture skips remain unchanged.

## Implementation commits

1. `93060cd6af` — error-level serialization rule and explicit owner-approval policy.
2. `b3434f9999` — bind the hosted application Store to its inert fixtures and add a scope-change regression.
3. `16732691a0` — replace obsolete process-window tests with simulator-lock behavior checks.
4. `4d4b04d756` — enable parallel execution in every normal feature/UI test-plan target.
5. `32bf2a30` — use `-Osize` across Release app/package compilation and both deployment workflows.
6. `279897ed0c` — exclude preview helpers and the preserved identifier table from Release.
7. `25649f32c2` — restore the persistent Library title menu with the custom system-style arrow.
8. `adaf3d6017` — adopt bottom edges and Archives safeAreaBar; repair Search header hit regions.

The original review checkpoint is `f195b7eaaf`. Follow-up measurements and screenshots are recorded
in a separate documentation commit after implementation verification.

## Execution adjustments

The GSD planner was dispatched with its resolved model and inherited effort. Authoritative runtime
model/effort metadata is unavailable, so actual settings remain unverified. The resolved executor
model was unavailable in this session's spawn tool; the orchestrator disclosed that mismatch and
executed inline rather than substituting an executor. No executor subagent chose a deviation.

The plan amendment records the two concrete validation defects and their bounded repairs. Task 3
paused at its explicit fixed-device coupling checkpoint: a blanket parallel switch would disconnect
host-driven orientation/capture operations from cloned workers and race the Duo pose mailbox.

## Pending owner decisions and continuation

1. UI adoption and the restored title menu are implemented; inspect the final captures through
   [UI-IMPLEMENTATION.md](UI-IMPLEMENTATION.md). Bounded checks do not claim a full Duo or VoiceOver matrix.
2. The owner deferred this discussion. Later, decide whether to approve serialization only for the
   existing full-content/geometry capture sequence, host-driven Duo pose runner and one-test external Appshot capture plan. The alternative
   is a separate implementation that routes state and pose commands to isolated workers. No exception
   is approved or recorded as accepted yet; the authority requirement comes from the owner's request.
3. Once that decision arrives, change the shared Gate and normal runner callers together, preserving
   strict test identity/count/repetition checks and proving result-device attribution for cloned workers.
   Verify the affected runner contracts and native selections before completing QUICK-PARALLEL-TESTS.

Task 1 and Task 2 are complete; Task 3 is partial. This record does not complete the quick task or
Phase 17, and it is intentionally absent from the completed-quick-task table. The existing Phase 17
visual review and explicit-gallery selection gate remains unchanged.
