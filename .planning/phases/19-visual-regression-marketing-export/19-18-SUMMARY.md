---
phase: 19-visual-regression-marketing-export
plan: "18"
subsystem: testing
tags: [snapshot-provider, per-view-snapshots, scenario-catalog, runner, move-proof]

requires:
  - phase: 19-17
    provides: "the in-process runner, README and the phase gate"
provides:
  - "`AppPackage/Tests/VisualSnapshotTests/Snapshots/`: 46 `<View>ViewSnapshot.swift` providers and `SnapshotProvider.swift` (`SnapshotProvider`, `SnapshotState`, `PageHeights`), all 138 states at `heights: .screen`"
  - "`ScenarioCatalog` reduced to an explicit provider list (`providers`, `states`, `registeredIDs`, `state(_:)`)"
  - "`Matrix/BrowsingScenarios.swift`, `LibraryScenarios.swift`, `GalleryScenarios.swift`, `SettingsScenarios.swift`: the helper enums, unchanged, without the registration extensions"
  - "`run-snapshot-local.sh` finds its simulator by exact name (`--simulator NAME`) and passes `-collect-test-diagnostics never`"
  - "`19-18-MOVE-PROOF.md`: before/after identity of the 21-scenario sample"
affects: [19-19, 19-20, 19-27]

actuals:
  tokens: 32700
  tasks: 3
  commits: 3

plan_head_before: da6495e8172363e895b732d7decb99ce61ed3150
plan_head_after: 0d24cc3e48329e32cef14f5f910e64c398544b3b

key-files:
  created:
    - AppPackage/Tests/VisualSnapshotTests/Snapshots/SnapshotProvider.swift
    - AppPackage/Tests/VisualSnapshotTests/Snapshots/ (46 `*ViewSnapshot.swift`)
    - .planning/phases/19-visual-regression-marketing-export/19-18-MOVE-PROOF.md
  modified:
    - Scripts/visual/run-snapshot-local.sh
    - Scripts/visual/test_run_snapshot_local.py
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioInventoryTests.swift
  renamed:
    - "Matrix/ScenarioCatalog+Browsing.swift to BrowsingScenarios.swift (and +Library, +Gallery, +Settings alike)"

key-decisions:
  - "`PageHeights` is an enum (`.screen`, `.committed(iphone:ipad:)`), not the design sketch's struct, so `.screen` needs no sentinel (plan step 4)."
  - "`firstLaunchMinimumReads` lives in `BrowsingScenarios` as `nonisolated static let` (orchestrator-approved)."

requirements-completed: [VIS-18-01, CAP-17-02]
status: complete
---

# Phase 19 Plan 18: Per-view snapshot providers Summary

**All 138 scenario states are declared in 46 per-view `SnapshotProvider` files at `heights: .screen`; the four
`ScenarioCatalog+*.swift` files are gone; the runner can only use the exactly named simulator. The sample's pictures
did not change by the move: 166 of 168 phone and 38 of 42 iPad pictures are byte-identical to the before capture, and
every difference is accounted for below.**

## Accomplishments

- **Task 1** (`24b860297`, tracer): exact-name runner with `--simulator`, `-collect-test-diagnostics never` on both
  `xcodebuild` calls, three stub-based tests in `test_run_snapshot_local.py` (5 tests, OK); `SnapshotProvider.swift`;
  `SettingViewSnapshot` with `settings-root`; catalog and `ScenarioInventoryTests` rewritten (no duplicate IDs, every
  committed height at least the pinned device height). The two project simulators were created
  (`EhPanda iPhone Air (phase19)`, `EhPanda iPad Pro 11-inch (M5) (phase19)`, both iOS 27.0, left shut down). The
  tracer run of `settings-root` on the iPhone had 4 of 4 pictures byte-identical to the before sample.
- **Task 2** (`45b94b6c0`): the 19 Browsing and Library providers; helper enums renamed with `git mv`.
- **Task 3** (`0d24cc3e4`): the 26 Gallery and Settings providers, `app-wide-app-alert` added to
  `ToplistsViewSnapshot`, the group struct and group path removed from `ScenarioCatalog`, the whole
  `VisualSnapshotTests` target green (`** TEST SUCCEEDED ** [295.455 sec]`), and `19-18-MOVE-PROOF.md`.

## Verification

- Runner unit tests: OK (5).
- `ScenarioInventoryTests`: 5 of 5 pass after each task; 46 provider files; no `ScenarioCatalog+*.swift`;
  `grep -c ScenarioGroup ScenarioCatalog.swift` is 0; `snapshot_shard.py classes` prints 22.
- Strict lint of `AppPackage/Tests/VisualSnapshotTests`: `--quiet | wc -l` is 0 (the new files are among the 34 linted).
- No picture in the repository (`git status --porcelain -- '*.png'` is empty).
- Move proof (`19-18-MOVE-PROOF.md`), sample of 21 scenarios:

| Device | keys | after = before | before = baseline2 | after = baseline2 among those |
| --- | --- | --- | --- | --- |
| phone | 168 | 166 | 99 | 99 (all) |
| pad | 42 | 38 | 20 | 20 (all) |

  Both before and after runs ended with every coordinate `recorded`. The six differing keys are explained in the
  deviations below and in the proof.

## Deviations (orchestrator-approved)

1. **Lint verify pattern.** Task 1's `grep -cE "Snapshots/(SnapshotProvider|SettingViewSnapshot)\.swift"` always prints
   0 because SwiftLint prints bare quoted file names. Used `grep -cE "'(SnapshotProvider|SettingViewSnapshot)\.swift'"`
   (prints 2) together with the `--quiet | wc -l` = 0 evidence. The plan file is unchanged.
2. **`BrowsingStepTests.swift`** (not in `files_modified`): `testEveryScenarioSettlesOnAtLeastSixReads` is now
   `@MainActor` and loops over `ScenarioCatalog.states`, because step 6 removes `ScenarioCatalog.factories` and
   `SnapshotProvider.states` is main-actor isolated.
3. **`firstLaunchMinimumReads`** moved into `BrowsingScenarios` as `nonisolated static let`; both references
   (`BrowsingStepTests.swift`, `HostedWindowCaptureTests.swift`, neither in `files_modified`) were requalified.
4. **`TracerSnapshotTests.swift`**: one comment updated, because it named the removed group files.
5. **Commit guard:** treated as sequential execution on `claude/phase19-deferred-0c4fb6`; only the agent-namespace
   allow-list assertion was skipped. Hooks ran, commits are signed with +08:00 dates.
6. **D-10 comparison for the 6 differing keys, instead of byte identity.** The plan's criterion (after = before for
   every key) failed: unchanged code does not repeat byte for byte locally (the old and the new sources each flip keys
   between runs). The six keys were compared with the gate's own comparison (runner compare mode against the before
   sample, precision 0.9999, perceptual precision 1, unchanged; it captures again, so a fresh capture after the move is
   compared). The two phone keys are within tolerance (`passed=16`, 0 changed); the four iPad keys are beyond tolerance
   against the cold before capture (see 7). No tolerance, tooling or test code was written for this.
7. **Controlled old-versus-new reference for the 4 iPad keys** (`downloads-list` and `favorites-list`, light and dark).
   The before capture was the first capture on a freshly created simulator. The reference used instead is the capture
   made with the old sources (`da6495e81`) on the same simulator in the same state as the after capture. Old and new
   are byte-identical for all four keys (and the stored after capture equals them), so the move changes none of these
   pictures. The cold first capture is beyond tolerance (about 1.5% of the pixels in one 291 x 56 box). For this check
   only, `AppPackage/Tests/VisualSnapshotTests` was temporarily swapped to the base commit and restored from a copy
   (checksums identical); nothing of it is in a commit.

## Auth gates

None.

## Known Stubs

None.

## Open inputs

1. **For 19-27 (first): Cold first capture differs.** On a freshly created simulator, the first capture of the iPad
   Library pages differs from every later capture with the same sources: the selected Library sidebar row (291 x 56
   pixels) is drawn in the accent colour cold and in the inactive grey afterwards. Hosted runners always start from
   fresh simulators, so this may be a cause of hosted run-to-run variation. Crops are under
   `$MAIN/.capture/agent-work/phase19-18/cold-vs-warm/` (not committed); details in `19-18-MOVE-PROOF.md`.
2. Local run-to-run variation on unchanged code: `app-wide-error-info` (phone, en large portrait dark) and
   `detail-pages-archives` (phone, ja accessibility5 landscape light) flip between runs on both the old and the new
   sources, within tolerance.
3. `SnapshotState.heights` is `.screen` everywhere; committed heights come with 19-19 and 19-20.
4. The two phase19 simulators stay for 19-19 to 19-29; deleted at the end of 19-29, or when the chain stops early.

## Self-Check: PASSED

Commits `24b860297`, `45b94b6c0` and `0d24cc3e4` are in the branch history; the files named above exist.
