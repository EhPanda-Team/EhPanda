---
phase: 19-visual-regression-marketing-export
plan: "19"
subsystem: testing
tags: [tall-window, full-page-capture, render-server, page-height-check, snapshot-matrix]

requires:
  - phase: 19-18
    provides: "per-view SnapshotProvider files, `PageHeights`, the exact-name runner"
provides:
  - "`TallWindow.swift`: `CaptureHeight`, `StatusBarCompanion`, `HostedHierarchy.pageNeed(in:)`"
  - "`HostedWindowCapture.captureAndCompare(height:)`: the tall-window path (status bar companion, size-class pins, viewport freeze, geometry check), the render-server path above 8191 device pixels, and the `page-height: needs <n> pt, committed <m> pt` check"
  - "the matrix passes each coordinate's committed height and a per-coordinate `VisibleViewportSampling`"
  - "`RenderServerCapture` accepts a window as the drawn view"
  - "`settings-root`'s tracer heights; `19-19-TALL-WINDOW.md`"
affects: [19-20, 19-26, 19-27]

actuals:
  tokens: 16400
  tasks: 3
  commits: 4

plan_head_before: 939b552d43ec401aa32857ae7841d041359bc938
plan_head_after: 427a92872b0213b02237bcd08f3165f43b736574

key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/TallWindow.swift
    - .planning/phases/19-visual-regression-marketing-export/19-19-TALL-WINDOW.md
  modified:
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift
    - AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift
    - AppPackage/Tests/VisualSnapshotTests/RenderServerCaptureTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Snapshots/SettingViewSnapshot.swift
    - Scripts/visual/run-snapshot-local.sh

key-decisions:
  - "A committed height at or under the window's own takes today's screen-sized path; only a taller one resizes the window (design section 2, orchestrator-approved)."
  - "A page shorter than the screen keeps the screen height, so a portrait `settings-root` picture is not taller than the screen: the verify's `taller` condition applies per coordinate (orchestrator decision)."

requirements-completed: [VIS-18-01, CAP-17-02]
status: complete
---

# Phase 19 Plan 19: Tall window and page-height check Summary

**Each coordinate is now taken in the hosted key window resized to the scene's width and its committed page height, with
the Phase 17 remedies (status bar companion, pinned size classes, frozen viewport sampling, verified geometry); a page
that needs more fails with `page-height: needs <n> pt, committed <m> pt` and keeps its picture; heights above 8191
device pixels are settled on owned-row digests and composed from native-size reads. Every `.screen` picture of the
19-18 sample is unchanged on both devices: 0 differences attributable to the change over 160 iPhone and 40 iPad keys.**

## Accomplishments

- **Task 1** (`6bbb0e25f`, tracer): `TallWindow.swift`; the tall-window attempt and the check in `HostedWindowCapture`;
  `StatusBarAppearanceController` moved out of `FullContentHost` (count 0 there), wrapped as `StatusBarCompanion`;
  matrix wiring (`CaptureHeight`, one `VisibleViewportSampling` per coordinate); four behaviour tests (needed height and
  exact picture size, the same bytes as no height at the device height, hidden or transparent scroll views never count,
  the window and its size-class pins are restored); `settings-root`'s tracer heights; first section of
  `19-19-TALL-WINDOW.md`. Strict comparison tolerance line unchanged (`precision: 0.9999, perceptualPrecision: 1`,
  count 1).
- **Task 2** (`6e43d6e64`): the render-server path for heights above 8191 device pixels (owned-row settle, then the
  composite of native-size reads of the window itself); the `RenderServerCapture` window-as-host change; AX5 iPhone
  runs; the iPhone regression proof.
- **Runner fix** (`8b30ec452`, owner-approved): the iPad turn step runs serially, so it turns the capturing device.
- **Task 3** (`427a92872`): iPad `settings-root` runs, the sheet probe, the iPad regression proof, completed record.

## Verification

- `HostedWindowCaptureTests`, `RenderServerCaptureTests`, `ScenarioInventoryTests` on the project iPhone:
  `** TEST SUCCEEDED ** [106.306 sec]` (the log also holds non-fatal "Simulator device failed to launch app.ehpanda"
  lines).
- Strict lint of `AppPackage/Sources/VisualSnapshotSupport` and `AppPackage/Tests/VisualSnapshotTests`:
  `--quiet | wc -l` is 0 for both. `Scripts/visual/test_run_snapshot_local.py`: 5 tests, OK.
- Tracer, iPhone, `settings-root` at `en-large` (`tracer-2`): 4 of 4 `recorded`; portrait 912 px (byte-identical to the
  `.screen` capture, `098431aa`, `92c3d612`), landscape 633 px = committed 633.
- AX5, iPhone (`ax5-2`, `ax5-3`): `ax5-not-recorded 0`, `ax5-nondeterministic 0`; landscape 850 px = committed 850.
- iPhone regression proof (`regress-phone`): `regress-keys 160`, `regress-differs 2` (accepted below),
  `regress-other-errors 0`; 126 `page-height` errors, 34 `recorded`.
- iPad: `pad-portrait-2` and `pad-landscape-2` 8 of 8 `recorded`, pixel height = committed (landscape AX5 865), width =
  scene width; iPad regression proof (`regress-pad`): `regress-keys 40`, `regress-differs 0`, `regress-other-errors 0`;
  10 `page-height` errors, 30 `recorded`.
- Sheet probe: restored (`git diff --quiet` on `ErrorInfoViewSnapshot.swift` prints `probe-restored`); the commit
  touches no such file. Finding: the form sheet does not grow with the window (needs 1570 pt, then 1930 pt = 1570 + 360).

## Tracer heights committed (tracer-only; 19-26's `apply` replaces them)

`settings-root`: iPhone portrait 912 at every size, landscape 633 (xSmall), 633 (large), 850 (AX5); iPad portrait 1210
at every size, landscape 834, 834, 865 (AX5).

## Deviations (orchestrator-approved)

1. **Per-coordinate `taller` in the Task 1 verify.** `settings-root` portrait fits the screen at every text size, so by
   design section 2 its pictures stay at the device height and are byte-identical to the `.screen` capture. The verify's
   expectation applies per coordinate: where the observed need exceeds the device height the picture equals the
   committed height and is taller; where it fits the picture is exactly the device height and byte-identical to
   `.screen`. Only landscape overflows on the iPhone (633 at xSmall and Large, 850 at AX5).
2. **Measured values only.** iPhone landscape xSmall is committed at 633 (measured in `probe-ax5`), not 420; landscape
   AX5 (850) was committed in Task 2.
3. **Bottom safe-area inset from test code.** The tall-window test attaches the observed `safeAreaInsets`
   (`XCTAttachment`, `.keepAlways`), read with `xcresulttool`: a 420 x 1000 pt window on the 912 pt iPhone has top 68,
   left 0, bottom 34, right 0 (recorded in `19-19-TALL-WINDOW.md`).
4. **Judgement calls:** a committed height at or under the window's own height takes today's path (`<=`, not `==`); the
   check applies to attempts that have a picture (recorded, passed, changed, missing baseline), while timeouts and
   failed steps are left as they are for the retry rules; the need is quantized to a device pixel before it is rounded
   up; a window with no scene fails `tall-window-geometry`, and a settle that times out before the resize reports
   `timeout` with the usual `settle-timeout` reason; the tall-window test derives its numbers from the window (the
   plan's 1000 and 1500 pt on the 912 pt phone); providers that commit `CGFloat` heights need `import CoreGraphics`.
5. **`RenderServerCapture.swift` added to the files.** A window passed as the drawn view was rejected with
   `detachedView` (a window has no `window` of its own). Both entry points resolve the host as
   `view as? UIWindow ?? view.window`; nothing else in the file changed, a detached plain view still throws. Tests first:
   `testAWindowPassedAsTheViewIsItsOwnHost` failed before the change, `testADetachedPlainViewStillThrowsDetachedView`
   passed before and after. Presented sheets, alerts and menus stay in the picture.
6. **Sliced path proven on synthetic pages.** No `settings-root` coordinate exceeds 8191 px (largest 850 pt at 3x), so
   the render-server path is proven by hosted synthetic pages (picture exactly the committed height, two captures
   byte-identical, no direct draw after the user step; a page under the limit keeps the direct path).
7. **iPhone regression differences accepted, no rerun.** `regress-differs` 2 of 160:
   `app-wide-error-info__en__large__portrait__iphone__dark` and
   `detail-pages-archives__ja__accessibility5__landscape__iphone__light`, the two keys 19-18 recorded as flipping on
   unchanged code. Each current picture is byte-identical to a capture the old sources already produced (19-18's
   `before`); decoded pixel differences against `after-phone`: 1 pixel with a largest channel difference of 1, and 0
   pixels (a PNG-encoding-only difference). Conclusion: 0 differences attributable to the change over 160 keys (lineage
   table in `19-19-TALL-WINDOW.md`).
8. **Runner: `-parallel-testing-enabled NO` on the iPad turn call, owner-approved (2026-11-22, "approved, for the turn
   step only").** The turn ran in a parallel-testing clone and never turned the capturing device; every iPad landscape
   coordinate failed `geometry`. Adds `Scripts/visual/run-snapshot-local.sh` to the files (`8b30ec452`, comment states
   the reason and the approval; no other call touched). `test_run_snapshot_local.py` has no stub that checks the turn
   call (its `xcodebuild` stub only runs `--device phone`), so no test machinery was added. The re-run landscape
   `orientation.log` names no clone and shows the turn on the device itself.
9. **Black-slice check reading.** The plan's "top and bottom 64 rows not all one colour" cannot hold for a page that
   ends in blank background. A tall picture passes when it is fully opaque (alpha 255), its bottom 64 rows equal the
   page's own background at that theme (sampled at the left margin, mid-height, recorded: white in light, black in
   dark), and it and its top 64 rows are not one colour. All 8 iPad pictures and the 4 tall iPhone pictures pass.
10. **Process note.** Tests were written with their code in each task's commit, not as a separate RED commit; the new
    `RenderServerCaptureTests` window case was run red first. A premature Task 3 commit of the heights alone was undone
    with a soft reset before the real Task 3 commit, so each task is one commit.

## Auth gates

None.

## Known Stubs

None.

## Open inputs

**For 19-27**
1. **Identical decoded pixels can encode to different PNG bytes** (19-19: the archives key's picture differs from
   19-18's `after-phone` by SHA-256 with 0 differing decoded pixels). Byte-level comparisons (move proofs,
   fingerprints) must state whether they compare encoded or decoded bytes.
2. **Cold first capture** (from 19-18): a fresh iPad simulator's first capture shows the selected Library sidebar row in
   the accent colour, later captures in grey. The iPad regression proof here ran on a warm simulator and matched
   19-18's `after-pad` in all 40 keys.

**For 19-20 and 19-26**
3. **A real-page proof of the sliced (render-server) path is still owed.** No `settings-root` coordinate is above
   8191 px; only synthetic hosted pages prove it. 19-20's probes or 19-26's verification sample must include a real
   page past the limit.
4. **`import CoreGraphics`** is needed in a provider file that commits `CGFloat` heights; 19-20's `apply` must write it.
5. **A form sheet does not grow with the window** (the Error Info sheet on the iPad at AX5: needs 1570 pt at 1210 pt,
   1930 pt at 1570 pt). Its need follows the window, so no committed height can satisfy it; for 19-20's probes and
   19-26's owner decision. The harness is unchanged.
6. **`reader-vertical` needs 9265 pt on the iPad** (portrait, Large), although the design lists the reader among pages
   that never scroll; the measuring mode and 19-26 should decide its height.
7. The two phase simulators stay for 19-20 to 19-29; deleted at the end of 19-29, or when the chain stops early.

## Threat Flags

None.

## Self-Check: PASSED

Commits `6bbb0e25f`, `6e43d6e64`, `8b30ec452` and `427a92872` are in the branch history (signed, +08:00 dates); the files
named above exist; `git status` is clean apart from this summary.
