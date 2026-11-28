---
phase: 19-visual-regression-marketing-export
plan: "26"
subsystem: testing
tags: [visual-regression, full-page-capture, committed-heights, sheet-fitting, measuring-mode]

requires:
  - phase: 19-25
    provides: "the app fixes of 19-21 to 19-25 and 19-31 the matrix was measured after"
  - phase: 19-20
    provides: "the measuring mode and `snapshot_heights.py` (propose, apply, check-sources, export)"
  - phase: 19-30
    provides: "the two step stages every measurement and capture runs through"
provides:
  - "Every state of every `*ViewSnapshot.swift` carries its committed full-page heights from `apply` (98 `.committed`, 7 `.screen`) or the owner's screen height with the owner's words (29 `.viewport(reason:)`); the four keyboard states are out of the matrix (134 states, 18,936 pictures, 72 shards)"
  - "`PageHeights.viewport(reason:)`: taken at the device height, skipped by the `page-height` check, never overwritten by `snapshot_heights.py`, its reason validated"
  - "The `page-height` check runs in candidate mode only; compare mode compares pictures"
  - "`SheetFitter`: every floating iPad form sheet is fitted to its content, in whole device pixels; the page of a sheet state is the front-most sheet"
  - "The page need ignores a text view's own scrolling (`HostedHierarchy.scrollsThePage`)"
  - "The freeze check judges the frozen read by the settle's own still-window rule (`readsMatch`)"
  - "19-27's inputs: the timing ratio per device (iPhone 2.89, iPad 1.13, medians) and the storage projection (7.897 GB)"
affects: [19-27, 19-28, 19-29, 19-12, 19-13]

actuals:
  tasks: 3
  commits: 24

plan_head_before: b8bc1e8450c20039933eae7d6effd714820df04c
plan_head_after: 2ab8e0c8aaa90d61a77b42304ed0bed4647face0

key-files:
  created:
    - .planning/phases/19-visual-regression-marketing-export/19-26-HEIGHTS.md
    - .planning/phases/19-visual-regression-marketing-export/19-26-HANDOFF.md
    - AppPackage/Sources/VisualSnapshotSupport/SheetFitting.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/FreezeCheckTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SheetFittingTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/TextViewNeedTests.swift
    - AppPackage/Tests/HostedViewTests/SearchRootSparseHeightTests.swift
    - AppPackage/Tests/SearchFeatureTests/FiltersResetConfirmationTests.swift
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Snapshots (46 provider files, `SnapshotProvider.swift` among them)
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/TallWindow.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
    - AppPackage/Sources/SearchFeature/SearchRootView.swift
    - AppPackage/Sources/FiltersFeature/FiltersReducer.swift
    - Scripts/visual/snapshot_heights.py
    - Scripts/visual/snapshot-shards.json
    - Scripts/visual/README.md
    - .planning/phases/19-visual-regression-marketing-export/19-FULL-PAGE-CAPTURE-DESIGN.md
    - .planning/phases/19-visual-regression-marketing-export/19-CONTEXT.md

key-decisions:
  - "Owner, 2026-11-27 and 11-28 (five rounds, `19-26-HEIGHTS.md` \"## Owner decisions\"): the reader's eight states, the seventeen alerts and confirmation dialogs and the four menus keep the screen height as `.viewport(reason:)`, each with the owner's words; the four keyboard states leave the matrix; sheets are measured and fitted at their own content; the `page-height` check is a baseline tool, not the gate; `proposal-sheets.json` approved (「核准，進入 Task 3（建議）」)."
  - "Two app defects found by the measurement were fixed outside the harness on the owner's go-ahead, tests first: the sparse Search root's padding outside its floor (`86c47193b`) and the Filters Reset dialog's state left set on dismissal (`eb8f4ee04`)."
  - "The proposal was made against the inventory before the keyboard states' removal, since `propose` refuses runs holding states the inventory no longer has; `apply --only` names none of the four."
  - "19-18's after-sample was gone (the main checkout's `.capture` was wiped on 2026-11-24), so the timing reference was taken again from 19-18's own tree (`git archive 0d24cc3e4`) with 19-18's two commands on today's simulators."

requirements-completed: [VIS-18-01, CAP-17-02]
status: complete
---

# Phase 19 Plan 26: The committed full-page heights Summary

**Every page of the matrix now has its committed height: 98 states carry measured heights, 7 fit the screen everywhere, and 29 keep the screen height by the owner's decision, with the owner's words in the source; the four keyboard states left the matrix. The candidate verification sample records all 930 coordinates, and the plan's verify command passes.**

All local runs ran on the iOS 27.2 simulator runtime (owner decision 2026-11-24/25); every measured value is a 27.2 value, which the hosted run A of 19-27 (27.0) checks. Evidence is in `$W` (`.capture/agent-work/phase19-26` of the worktree, ignored by git).

## Accomplishments

- **Task 1, the measurement** (`cd5191b4d`): the whole matrix in the measuring mode, 18 configurations, both themes, both devices and orientations; the proposal, the findings and the first storage projection in `19-26-HEIGHTS.md`.
- **Task 2, the owner's decisions** (five rounds, 2026-11-27 and 11-28, asked in Taiwanese Mandarin, quoted in `19-26-HEIGHTS.md`). The work they started, each tests first:
  - the freeze check by the settle's still-window rule (`4a87dc8b3`, 「改用靜止判斷的規則（建議）」);
  - the Search root kept within its view (`86c47193b`, 「修 App（建議）」) and the Filters Reset dialog cleared on dismissal (`eb8f4ee04`, 「先修這個」);
  - the iPad sheets fitted to their content (`063a110d8`, 「貼合內容（建議）」, 「開始實作」), then measured at the sheet, not the page behind it (`abd193abd`), and fitted in whole device pixels (`4a40eebfb`);
  - the warnings of the tall window cleared (`539a3866b`);
  - three re-measures (the touched states, then the 30 sheet states twice), and `proposal-sheets.json`, approved.
- **Task 3, the heights**, the plan amended first with the decisions (`5244df187`):
  1. `PageHeights.viewport(reason:)` on the 29 exempt states, with the parser, `apply` and `export` rules in `snapshot_heights.py` (`ce64f786a`);
  2. compare mode without the `page-height` check (`0a22617eb`);
  3. the four keyboard states removed from the inventory, providers, tests, scenarios, README totals and shard plan (`2a220c751`; 134 states, 18,936 pictures, 72 shards);
  4. the page need ignores a text view's own scrolling (`c382434e9`; the empty "Excluded Uploaders" editor had added the window plus 23 pt at every height);
  5. the five text-view states re-measured (720 lines, all `measured`);
  6. `proposal-final.json` applied to the 105 states that are neither `viewport` nor removed (`2ab8e0c8a`, 43 provider files);
  7. the candidate verification sample and the timing reference;
  8. `19-26-HEIGHTS.md` "## Applied heights (Task 3)".

## Verification

- The plan's Task 3 `<verify>` command at `2ab8e0c8a` (the records uncommitted, documentation only): `check=0`, `** TEST SUCCEEDED **` (VisualSnapshotTests on the iPhone, 225 s), the sample `{('recorded', ''): 930}`, 98 `.committed(`, 29 `.viewport(`, 0 removed IDs. No `fails_when` holds. The command's own exit status is 1 because its last `grep -c` counts zero, the expected result.
- The gate after every Task 3 commit: VisualSnapshotTests in FeatureTests on both phase simulators passed with no warning (309 tests after the last).
- `cd Scripts/visual && python3 -m unittest discover -p 'test_*.py'`: 512 tests OK; `snapshot_shards.py --check` passes.
- Strict SwiftLint of the touched modules prints nothing; no rule was disabled.
- Verification sample (candidate mode, no `--workers`): iPhone 744 and iPad portrait 186 coordinates, all `recorded`.

## Measured results

| | iPhone | iPad |
| --- | ---: | ---: |
| Median s per picture, committed heights (168 / 42 keys) | 3.241 | 1.426 |
| Median s per picture, 19-18's after-sample taken again | 1.123 | 1.260 |
| Ratio of medians (19-27's cost projection) | 2.89 | 1.13 |
| Ratio of sums | 2.34 | 1.20 |

Storage, `baseline2` scaled by the committed heights: 7.897 GB for the 18,936 kept pictures (4.842 GB at the device height, a factor of 1.63), 2.897 GB over 19-12's 5 GB line, so 19-12 Task 3's storage choice comes back to the owner; every slice is under 1.8 GB (largest `ipad/de`, 0.830 GB).

## Deviations from the plan

1. **The iPhone text-view re-measure** is two runs, `remeasure-textview/phone-portrait` and `phone-landscape`, where the plan named one `remeasure-textview/phone`; they are listed in its place in the proposal's `--runs`.
2. **The proposal's inventory**: `propose` refuses runs holding a state the inventory lacks, and the earlier runs hold the four removed keyboard states. It was run with `--inventory` set to `scenarios.json` before `2a220c751` (which differs by exactly those four lines); `apply --only` names none of them, so no removed state was written.
3. **The timing reference**: 19-18's after-sample no longer exists. It was taken again from `0d24cc3e4`'s tree with 19-18's commands, on the same simulators (27.2, where 19-18's ran on 27.0); it reproduced 19-18's 168 and 42 keys, all `recorded`. The ratio therefore covers the committed heights and every harness change since 19-18, on one Mac and one runtime.

Each was decided by the orchestrator within the approved plan; none changes a height, a state or a rule.

## Next

19-27: run-to-run comparison tooling, native policy and shard cost, with the timing ratio above; then the owner's go-ahead for the push and hosted run A. `origin` holds the branch up to `4a40eebfb`; every later commit is local.

## Self-Check: PASSED

- `19-26-HEIGHTS.md` holds the applied counts, the text-view re-measure, the verification result, the timing ratio per device and the recomputed storage projection.
- `19-FULL-PAGE-CAPTURE-DESIGN.md` §2 and `19-CONTEXT.md` D-08 name every `viewport` group, quote the owner's amendment of C4 and record the check's role in compare mode.
- Every Task 3 change is in its own commit (`git show --stat ce64f786a 0a22617eb 2a220c751 c382434e9 2ab8e0c8a`).
