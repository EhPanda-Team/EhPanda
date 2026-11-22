---
phase: 19-visual-regression-marketing-export
plan: "20"
subsystem: testing
tags: [measuring-mode, page-heights, snapshot-heights, precheck, probes]

requires:
  - phase: 19-19
    provides: "the tall window, `pageNeed`, the page-height check, the render-server path"
provides:
  - "`run-snapshot-local.sh --measure-heights`: the measuring mode, one `heights.jsonl` line per coordinate (`measured`, `cannot-cover`, `did-not-converge`, `error`, `notApplicable`), no picture and no `results.jsonl` line"
  - "`SnapshotMode.measure`, `HostedWindowCapture.measure`, `PageMeasurement`, `SnapshotHeightLine`, `SnapshotResultWriter.appendHeight`; `GrownWindow`, `freezeAtNativeSize` shared with the tall window"
  - "`Scripts/visual/snapshot_heights.py`: `propose`, `apply`, `check-sources`, `export`"
  - "`snapshot_precheck.py --heights`: the `committed-height` check"
  - "`test_snapshot_gate.py`: the gate and `run-shard.sh` can never select the measuring mode"
  - "D-08 amendment, README sections, design status line; `19-20-PROBES.md` (tracer, nine probes, the order-B experiment)"
affects: [19-21, 19-26, 19-27]

actuals:
  tokens: 25900
  tasks: 3
  commits: 3

plan_head_before: 9276413dfd992f9da06f2e9182f73b533782417c
plan_head_after: d6425773fedde94557fdf0f3c2d37c44a9a1f69c

key-files:
  created:
    - Scripts/visual/snapshot_heights.py
    - Scripts/visual/test_snapshot_heights.py
    - .planning/phases/19-visual-regression-marketing-export/19-20-PROBES.md
  modified:
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/TallWindow.swift
    - AppPackage/Sources/VisualSnapshotSupport/SnapshotResultWriter.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift
    - Scripts/visual/run-snapshot-local.sh
    - Scripts/visual/test_run_snapshot_local.py
    - Scripts/visual/test_snapshot_gate.py
    - Scripts/visual/snapshot_precheck.py
    - Scripts/visual/test_snapshot_precheck.py
    - Scripts/visual/README.md
    - .planning/phases/19-visual-regression-marketing-export/19-CONTEXT.md
    - .planning/phases/19-visual-regression-marketing-export/19-FULL-PAGE-CAPTURE-DESIGN.md

key-decisions:
  - "The measuring mode is local only; the gate and `run-shard.sh` can never select it (`test_snapshot_gate.py`, T-19-47)."
  - "Owner decision 2026-11-23: steps that make a page still run at screen size before the window grows, steps that operate the page run after it grows. A separate plan implements it; 19-20 changes no harness code for it."

requirements-completed: [VIS-18-01, CAP-17-02]
status: complete
---

# Phase 19 Plan 20: Measuring mode and heights tool Summary

**`run-snapshot-local.sh --measure-heights` finds each coordinate's needed window height without a picture (the window is grown until the need holds still, at most 12 steps); `snapshot_heights.py` turns measuring runs into the committed heights, writes them into the view files in the canonical layout, checks them and exports them for the pre-check. The tracer's measured needs equal 19-19's committed values, and nine probes found which hard cases the measurement cannot cover: keyboard states, form sheets, and states whose user step makes the page still.**

## Accomplishments

- **Task 1** (`a7b89ad93`, tracer): `SnapshotMode.measure`; `HostedWindowCapture.measure` (`PageMeasurement`: `measured`, `cannot-cover:<class>` when the most-overflowing scroll view grew less than the window did minus one device pixel, `did-not-converge`, `error`); `SnapshotResultWriter.appendHeight` (own file, same `O_APPEND` and `flock` discipline, first final line kept, `error` provisional); the matrix routes every line of a measuring run to `heights.jsonl`; `--measure-heights` in the runner (refused with `--mode`, summary per status, fails on a missing or empty file or an `error` or `did-not-converge` line); gate test that no non-comment line of `snapshot-gate.yml` or `run-shard.sh` selects the mode (with a mutation guard test).
- **Task 2** (`3b0b0978a`): `snapshot_heights.py` and 22 tests; the pre-check's `committed-height` check behind `--heights FILE`.
- **Task 3** (`d6425773f`): D-08 amendment (append only), design status line, README sections, `19-20-PROBES.md` with the probes and the order-B experiment.

## Verification

- `test_run_snapshot_local.py`: `OK` (13 tests); `test_snapshot_gate.py`: `OK` (49 tests); `test_snapshot_heights.py`: `Ran 22 tests`, `OK`; `test_snapshot_precheck.py`: `OK` (17 tests); whole `Scripts/visual` suite: `Ran 507 tests ... OK`.
- `HostedWindowCaptureTests` on the project iPhone: `** TEST SUCCEEDED ** [131.869 sec]`, including the five new measuring and writer tests and every 19-19 tall-window test.
- Strict SwiftLint of `VisualSnapshotSupport` and `VisualSnapshotTests`: 0 lines.
- Tracer (`settings-root`, iPhone, `en-large` and `en-accessibility5`, both orientations and themes): `measured=8 cannot-cover=0 did-not-converge=0 error=0 notApplicable=0`, no `results.jsonl`, no picture. Needs equal 19-19's committed values: 912 / 633 (`large`, portrait / landscape) and 912 / 850 (`accessibility5`).
- `check-sources` prints `138 states, heights read back`, exit 0; `export` lists 138 scenarios with `settings-root` iPhone portrait `{'xSmall': 912, 'large': 912, 'accessibility5': 912}`.
- Task 3 verify: `page-height: needs` count 1 in `19-CONTEXT.md` and 1 in the README; README `--measure-heights` count 2; `/Users/` matches 0; probe conclusion count 11 (>= 9); the D-08 commit removes no line (`grep -c '^-[^-]'` is 0).
- Probes (iPhone `en-large`, iPad `en-accessibility5` portrait unless stated): home-populated taller, coverable (1755 / 1725 pt); `comments-post-filled`, `search-typing-suggestions` and `app-wide-app-alert` cannot cover (a keyboard is up); `reader-vertical` measures taller than `.screen` (4672 / 10214 pt); general cache confirmation taller, coverable (939 / 884 pt); Error Info and the download inspector cannot cover (form sheets); iPad home-populated taller, coverable (1858 pt, equal to 19-19's check). Details in `19-20-PROBES.md`.

## Deviations (orchestrator-approved)

1. **`19-20-PROBES.md` is created in Task 1's commit** (Task 1's acceptance requires it to start with the tracer), though it is not in Task 1's `<files>`.
2. **Access changes in `HostedWindowCapture`:** `settleRead`, `SettledRead`, `settleOwnedRows` and `nextSample` lost `private` so the measuring code can live in `TallWindow.swift` (this keeps `HostedWindowCapture.swift` at 834 lines, under the 1000-line limit); new `settleTimeoutReason` and `PageNeed` (`pageNeed(in:)` now returns the need and the scroll view that sets it).
3. **Shared helpers refactored out of 19-19's tall path:** `GrownWindow` (companion window, size-class pins, resize, restore) and `freezeAtNativeSize`. Operation order unchanged; every 19-19 tall-window test passes.
4. **`SnapshotResultWriter`'s append generalized** into one private function used by `append` and `appendHeight`; only an `error` height line is provisional; results behaviour unchanged.
5. **Matrix wiring:** `SnapshotMatrixCase` gained `inScenarioDependencies`, `measureCoordinate` and `recordNotApplicable` / `recordFailure`; in the measuring mode not-applicable and failure lines go to `heights.jsonl` and never to `results.jsonl`. `HostedWindowCapture.conclude` returns `measure-mode-takes-no-picture` for `.measure` (unreachable in practice).
6. **`snapshot_heights.py` choices:** hidden `--sources` and `--inventory` options (used by the tests); `propose` exits 1 and writes nothing when an expected coordinate is missing, findings (`cannot-cover`, `did-not-converge`, `error`) exit 0 with those groups left out; `apply` refuses atomically; `check-sources` also treats an all-device-height `.committed` literal as non-canonical.
7. **TDD process:** tests were written with the code in each task's commit, not as separate RED commits; the Python tests were run red first.
8. **iPad probes** used the owner-approved `-parallel-testing-enabled NO` turn step already in the runner; no serial flag was added anywhere else.
9. **The order-B experiment (uncommitted).** At the orchestrator's request, the user step was temporarily moved before the native settle in both the measuring mode and the tall window's attempt, scroll-offset attachments and a per-step print were added, and two states were captured at one-off `.committed` heights. Nothing was committed; the four touched Swift files were restored with `git checkout -- <file>` and their md5 checksums equal the ones taken before (`git diff -- AppPackage` empty). Results are in `19-20-PROBES.md` (Tables 1 to 3, restore checksums).

## Auth gates

None.

## Known Stubs

None.

## Open items

- **(a) The interact-order defect** in 19-19's tall path and in the measuring mode: both settle and freeze at native size before the user step, so a state whose step makes the page still (`holdStill`, `freezeIndicators`, `waitForGlassShadow`, `holdStillOverKeyboard`, `holdCaret`, `holdAlertCaret`) times out in the native settle (`comments-post-filled`, `app-wide-app-alert`, `home-loading` under the current order). Owner decision 2026-11-23: split the steps into two kinds. Steps that make the page still run at screen size before the window grows; steps that operate the page (taps, menus, dialogs, scrolling) run after it grows. Handed to a separate new plan after 19-20; 19-20 changes no harness code for it. Facts for that plan, from the experiment: after growth the scroll offset is always clamped to the top (the position a scrolling step reached is lost); the cache-confirmation popover loses its anchor in iPhone landscape when presented before growth.
- **(b) Keyboard states cannot be covered.** `comments-post-filled`, `search-typing-suggestions` and `app-wide-app-alert` have a keyboard up; it stays at the screen bottom, so the scroll view's adjusted bottom inset grows by exactly the window's growth and the need never converges, under either order. The measuring mode should name them `cannot-cover:keyboard` (new plan) instead of `did-not-converge`. Whether they keep the screen height is an owner decision in 19-26.
- **(c) The real-page composite above 8191 px is still not proven.** The settle half of the sliced path ran on a real page (`reader-vertical`: the window set to 4672 pt = 14,016 px in portrait, 10,214 pt = 30,642 px in landscape); the measuring mode takes no picture, so the composite of native-size reads of a real page is still owed (19-26's verification sample).
- **(d) `general-full`'s content grows 12 pt at offset 0** (758 to 770 pt in iPhone landscape after the page returns to the top in the grown window).
- **(e) Known findings:** a form sheet does not grow with the window (Error Info and the download inspector, `cannot-cover:UpdateCoalescingCollectionView`; for 19-26's owner decision); `reader-vertical` needs 4672 / 4666 pt (iPhone portrait), 10214 / 10201 pt (iPhone landscape) and 9265 pt (iPad portrait) although the design lists it as `.screen`.
- The two phase simulators stay for the rest of the chain and are shut down, not deleted.

## Threat Flags

None.

## Self-Check: PASSED

Commits `a7b89ad93`, `3b0b0978a` and `d6425773f` are in the branch history (signed, +08:00 dates); the files named above exist; `git status` is clean apart from this summary.
