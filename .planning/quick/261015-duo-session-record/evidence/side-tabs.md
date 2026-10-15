> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build/duo-sidebar`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# Restore native Duo side tabs

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Reproduction prerequisite: set `POSE_DRIVER` to the absolute executable path of your simulator
pose driver before running the commands below. The runner requires that path explicitly.

The previous Home navigation policy disabled the vertical bar for both navigation stacks. UIKit forwards this preference through navigation and tab controllers to the window, so the Home policy also moved the native tab bar to the bottom.

Removing that policy reproduced the underlying problem: a list pushed in portrait was resized into Home's left pane after rotating into partial-fold landscape. Its native Back and list tools disappeared because the navigation host no longer reached the display's vertical bar. `baseline.log` and `baseline.png` capture the settled failure.

The correction confines the two-pane layout to the Home root. Existing pushed destinations retain the full navigation host; returning Home restores its two panes and crease. Home's left Reload item alone requests a horizontal axis. Native side tabs and their existing toolbar-first compression policy remain enabled. Opposite-pane sheet routing is unchanged.

## Checks

- `build-final.log`: warning-free UI test build, `TEST BUILD SUCCEEDED` (14.689 seconds).
- `rotation-fix.log`: portrait list push → landscape Back and list tools → native Back returns to split Home → portrait navigation. The test checks actual vertical tab positions, not only existence. `TEST EXECUTE SUCCEEDED` (31.356 seconds).
- `baseline.log`: expected failure before the layout correction; native Back did not exist after rotation. The diagnostic source is retained only in this ignored directory.
- Read-only review found no source issues. The primary navigation stack retains structural identity across changes; all Home split-dependent content uses the same visibility condition.

Commands are run from the worktree:

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda \
  -testPlan UITests -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/duo-dd ARCHS=arm64
python3 Scripts/run-duo-ui-tests.py --pose-driver "$POSE_DRIVER" --device 05422A43-8575-4BA6-A791-FAC2D5D3BA19 \
  --xctestrun .build/duo-dd/Build/Products/EhPanda_DuoSidebar.xctestrun -- \
  -derivedDataPath .build/duo-dd -collect-test-diagnostics never \
  -only-testing:EhPandaUITests/DuoHomeUITests/testPortraitUsesOnePaneAndPushesLists
```

- `home-regressions.log`: all seven remaining Duo Home tests passed, zero failures (223.254 seconds; total test execution 230.183 seconds). These cover opposite-pane lists and nested details, reader return to the presenting side, six rankings, right-scroll title/left-content isolation at standard/AX1/AX3/AX5, root titles/pane geometry at those sizes, and a warm link while a Home sheet is open.
- Final explicit SwiftLint on the three changed Swift files and `git diff --check` passed.

- `cover-toolbar.log`: cover-display landscape compression test passed (17.667 seconds; total execution 25.060 seconds). List tools remained accessible, compressed tabs expanded, and Favorites navigation succeeded.
- All nine relevant UI tests passed. No app compiler or SwiftLint warnings. Runtime checks used the dedicated Duo simulator; physical hardware was not tested in this follow-up.
- `restored-side-tabs.png`: half-fold landscape Home with native side tabs, using the existing synthetic cover fixtures for visual inspection.
- After capture, the dedicated Duo was restored to its entry posture (closed, hardware portrait) and the app was relaunched normally. Process-environment inspection confirmed no remaining `EHPANDA_*` test launch flags. No Device Hub access or data clearing was used.

This supersedes the fixed horizontal Home toolbar policy described in `../reader-followup/VERIFICATION.md`.

Local commit: `0b72a1db9d` (`fix(home): restore Duo side tabs`). Working tree clean; no push or pull request. Final normal launch PID 21376 has no test environment flags, and the cover Home loaded live content successfully.

The first visual capture opened the inner display before its orientation had settled. It is retained as `capture-before-orientation-settled.png`, not as landscape evidence. Reapplying the native pose events produced the verified landscape capture `restored-side-tabs.png`; no app workaround was added.
