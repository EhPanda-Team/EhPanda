> Historical evidence snapshot. Final decisions in [DISCUSSION-LOG](../DISCUSSION-LOG.md) supersede obsolete posture, toolbar, separator and cleanup statements below. Log/capture paths are relative to the original local evidence directory `.build`, not this tracked report. Commit links identify replayed implementations; MIGRATION.md maps each to the original tested tree. This is not a fresh integration test.

# iPhone Duo verification — 2026-10-14

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Worktree: `$HOME/Fork/EhPanda/.claude/worktrees/iphone-duo-support-c0b23d`.
Branch: `claude/iphone-duo-support-c0b23d`. Starting commit: `1c79f36368`.
No push or pull request is authorized.

## Outcome

Committed `4191a6bb09` — `fix(reader): support Duo toolbar behavior`.
The final build is warning-free and both full reader suites passed all eight tests on their
first attempt. The commit includes the four helper corrections and the owner-approved native
toolbar setting that keeps the page indicator visible while the control panel is shown.

Open and folded-landscape Duo poses were verified with `sim-pose`. The iPad NewDawn sheet is
compact (60% sun), and the inspected dual-page resume preserved its spread while normalizing
the indicator to the spread's first page. Remaining owner decisions and coverage limits are
listed at the end. All diagnostic files remain local and ignored; no push or PR was made.

## Reader helper

The initial throwaway hierarchy test established that the reader's navigation bar and vertical
toolbar are siblings inside `reading_view`. The vertical toolbar's More identifier is
`BottomOverflowBarButtonItem`; the classic bar uses `OverflowBarButtonItem`. Detail can expose
another More button behind the reader. The helper now scopes both identifiers to `reading_view`
and still requires exactly one combined result. See `duo-hierarchy.log`.

Three other test-driver assumptions were exposed after that lookup worked:

- The fixed next-page point overlapped the vertical toolbar's More button. The helper now picks
  an unobstructed point in the same trailing fifth of the pages, retaining the original page assertion.
- Reading Setting dismissal assumed a device idiom and requested orientation. The helper now
  uses the actual navigation-bar Close button when present and otherwise drags the sheet title.
- The Duo exposes a full-screen `StatusBar` frame. The old normalized tap hit the reading page,
  hid the entire panel, and stayed on page 73. Its hierarchy exposes a distinct SpringBoard
  `Scroll To Top Region` at `(0, 0, 466, 20)`. The helper targets that system element when present
  and uses the classic status-bar tap otherwise; the Probe iPhone has no named region and exposes
  a normal `(0, 0, 420, 54)` status bar. No device-idiom or orientation branch was added.
  `duo-status-hierarchy.log`: the diagnostic passed (29.383 seconds),
  `** TEST SUCCEEDED ** [69.914 sec]`. Regression checks are recorded below.

The attempted change to the vertical drag endpoints did not fix the missing page indicator and
was reverted. No page assertions or retries were relaxed.

## Pose verification

Tool: `$HOME/Fork/.scripts/sim-pose/sim-pose`.
Duo: `05422A43-8575-4BA6-A791-FAC2D5D3BA19`.

```sh
sim-pose 05422A43-8575-4BA6-A791-FAC2D5D3BA19 --hinge open --orientation portrait
sim-pose 05422A43-8575-4BA6-A791-FAC2D5D3BA19 --hinge closed --orientation landscape-left
```

- Open at 180 degrees, physical portrait: inner display 951 × 669 points. Setting and cold gallery
  deep-link Detail presented as centered sheets; reader, More and Reading Setting were usable.
  `duo-open-screen/test.log`: `testCurrentPosePresentation` passed, `** TEST SUCCEEDED ** [100.146 sec]`.
  Visual evidence is in `duo-open-screen/pose-*.png`.
- Closed at 0 degrees, landscape-left: cover display 678 × 466 points. Setting inline, reader controls
  usable, Reading Setting showed its chevron. `duo-folded-landscape-reboot/test.log`:
  `testCurrentPosePresentation` passed (69.409 seconds), `** TEST EXECUTE SUCCEEDED ** [84.045 sec]`.
- Home → Frontpage → gallery in folded landscape: Detail pushed and exposed Back, Setting inline.
  `duo-folded-host-route/test.log`: passed (68.515 seconds),
  `** TEST EXECUTE SUCCEEDED ** [78.609 sec]`.
- Home → Frontpage → gallery while open: Detail presented in a centered sheet over Frontpage,
  Setting presented over Home, and the reader and Reading Setting remained usable.
  `duo-open-host-route/test.log`: passed (81.484 seconds),
  `** TEST EXECUTE SUCCEEDED ** [93.131 sec]`.

The cold gallery deep-link path is independently fixed to a sheet in `PresentationFeature`.
It does not exercise `AppReducer.openGalleryDetail`'s size-class routing. That existing behavior
was not changed. Home gallery taps must be used to verify the new host routing policy.

`XCUIDevice.orientation` did not rotate the folded Duo, including Apple's Settings app control
experiment. The new CLI did rotate it. After an open-to-closed transition, XCTest initially saw
an app hierarchy while the cover still showed SpringBoard and controls were not hittable.
Rebooting only the dedicated Duo simulator resolved that state. Continuous live folding remains
unverified; successful cold-pose checks do not establish it.

XCTest app screenshots were black for the inner display. `XCUIScreen.main` captured the cover.
For visual verification the throwaway tests emitted capture markers and the host used
`xcrun simctl io <Duo> screenshot --display=primary-1` (open) or `--display=primary` (closed).

## iPad NewDawn

Probe iPad: `114E0258-098C-4C26-B2FF-0B5CECEA4810`, iOS 27.0.
A temporary environment-triggered presentation and accessibility identifier measured the actual
NewDawn sheet's horizontal size class. Both temporary product edits were removed after measurement.

`ipad-inspection.log` records:

```text
NEW_DAWN_PROBE portrait class=probe_new_dawn_Optional(SwiftUI.UserInterfaceSizeClass.compact) frame=(127.0, 275.0, 580.0, 660.0)
NEW_DAWN_PROBE landscape class=probe_new_dawn_Optional(SwiftUI.UserInterfaceSizeClass.compact) frame=(315.0, 87.0, 580.0, 660.0)
testNewDawnSheet passed (11.399 seconds)
```

Owner decision: the size-class rule selects a 60% sun in this compact sheet, versus the former
iPad-specific 50%. Product behavior remains unchanged.

## iPad dual-page landscape resume

Manually compared full-screen attachments from the temporary UI probe. With dual-page mode on,
left-to-right direction and Except the Cover off, a slider jump to 78 displayed pages 77 and 78.
Closing the reader and reading again kept the identical 77–78 spread. The indicator changed
from 78 to the spread's first page, 77.

Evidence:
- Before: `ipad-dual-screen-attachments/3B0AA9A4-A1EA-4535-AE27-FD625A73CF11.png`.
- After: `ipad-dual-screen-attachments/7B944144-442F-4EF4-BFB3-FB7D6B6A8D30.png`.

The temporary exact-indicator assertion failed on this normalization. Its automatic retry inherited
the dual-page setting and toggled it off, so the later passing retry is not evidence for dual-page
resume. The conclusion above comes from the first attempt's two visible page numbers. No permanent
dual-page test was added; one should explicitly establish both toggles and compare the displayed
spread, while separately specifying the intended indicator normalization.

## Reader scrolling failure and approved fix

`duo-gestures.log`: vertical scroll failed all three attempts with a missing page indicator;
next-page tap passed (43.485 seconds) after avoiding the More button.

The diagnostic `duo-scroll-inspect/test.log` and its screenshots show:
- Before: indicator visible, panel visible.
- After upward drag: indicator absent, panel and vertical toolbar still visible.
- After reversing the scroll: indicator restored without toggling the panel.
- Navigation bar frame remained `(0, 24, 466, 58)`.

This was consistent with native toolbar minimization; at that point the exact runtime cause
was still unproven. The approved change and passing test below established the working correction.
The installed SDK provides `toolbarMinimizationBehavior(.never, for: .navigationBar)` (the 27.0
skill used the older spelling `toolbarMinimizeBehavior`). A standalone Swift typecheck passed
for the installed spelling. The proposed one-line patch is `reader-toolbar-minimization.patch`.
The owner explicitly approved applying and verifying the proposal. The installed SDK's one-line
modifier was then applied to `ReadingView`, retaining the existing `showsPanel` visibility control.

The same arm64 generic test build command passed (`duo-toolbar-build.log`):
`** TEST BUILD SUCCEEDED ** [14.642 sec]`, with no warning or error lines.
The previously failing scrolling test passed on its first attempt (`duo-toolbar-scroll.log`):

```text
testScrollingKeepsTheIndicatorOnThePageShown passed (62.632 seconds).
Executed 1 test, with 0 failures (0 unexpected) in 62.632 (62.640) seconds
** TEST EXECUTE SUCCEEDED ** [67.479 sec]
```

Both reading directions kept a visible indicator matching the drawn page after scrolling.
The test command was the single-method `test-without-building` command below, selecting
`ReaderPageSyncUITests/testScrollingKeepsTheIndicatorOnThePageShown` on the Duo.

## Commands

All simulator runs first checked `xcrun simctl list devices` and `pgrep -x xcodebuild`.
Only the named EhPanda simulators were controlled; this work's test runs were sequential.

Standard UI build-and-test command used for diagnostic methods:

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -only-testing:EhPandaUITests/DuoInspectionUITests/<method> \
  -destination 'platform=iOS Simulator,id=<device>' \
  -derivedDataPath .build/duo-dd -collect-test-diagnostics never
```

Methods included `testReaderHierarchy`, `testRotation`, `testNewDawnSheet`,
`testDualPageControls`, `testCurrentPosePresentation`, and `testScrollToolbarVisibility`.
The later status-bar hierarchy probes used the same command with
`-only-testing:EhPandaUITests/DuoStatusBarInspectionUITests/testStatusBarHierarchy`, once per device.
The throwaway test source was removed from the target before the final build and preserved only
as the ignored diagnostic artifact `DuoInspectionUITests.swift` beside this report.

Subsequent pose runs used:

```sh
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_UITests_iphonesimulator27.1-arm64.xctestrun \
  -derivedDataPath .build/duo-dd \
  -only-testing:EhPandaUITests/DuoInspectionUITests/testCurrentPosePresentation \
  -destination 'platform=iOS Simulator,id=05422A43-8575-4BA6-A791-FAC2D5D3BA19' \
  -collect-test-diagnostics never
```

## Final validation

The source contains the four helper changes and the approved native toolbar modifier. The temporary product
instrumentation and throwaway test class were removed. Read-only review found no actionable issue
and confirmed the page assertions were not weakened.

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/duo-dd
```

`duo-final-build.log`: `** TEST BUILD SUCCEEDED ** [196.182 sec]`; no `warning:` or `error:` lines.
Explicit SwiftLint of `EhPandaUITests` and `git diff --check` also passed.

Full reader regression command (Probe iPhone):

```sh
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_UITests_iphonesimulator27.1-arm64-x86_64.xctestrun \
  -derivedDataPath .build/duo-dd \
  -only-testing:EhPandaUITests/ReaderPageSyncUITests \
  -destination 'platform=iOS Simulator,id=6CE1E40A-7090-484E-8C49-B7BCBDC5E684' \
  -collect-test-diagnostics never
```

`iphone-reader-final.log`:

```text
Executed 8 tests, with 0 failures (0 unexpected) in 494.094 (494.109) seconds
** TEST EXECUTE SUCCEEDED ** [532.834 sec]
```

All eight passed on their first attempt.

Full reader regression command (Duo, closed/portrait after a dedicated-device reboot):

```sh
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_UITests_iphonesimulator27.1-arm64-x86_64.xctestrun \
  -derivedDataPath .build/duo-dd \
  -only-testing:EhPandaUITests/ReaderPageSyncUITests \
  -destination 'platform=iOS Simulator,id=05422A43-8575-4BA6-A791-FAC2D5D3BA19' \
  -collect-test-diagnostics never
```

`duo-reader-complete.log` (before the status-bar helper correction):

```text
Executed 12 tests, with 6 failures (0 unexpected) in 606.655 (606.706) seconds
** TEST EXECUTE FAILED **
```

Six unique tests passed on their first attempt; scrolling and status-bar tests each failed all
three attempts. The 12 execution count includes retries. The turning test passing does not
establish real Duo rotation: XCTest orientation requests do not change its physical pose.

The status-bar failure screenshot is
`duo-complete-attachments/DA2EC061-CCC4-44D5-BB65-F84BCF3E43D2.png`.
It shows page 73 with the whole panel hidden, unlike the scrolling failure where lower controls
stay visible. Log coordinates and a subsequent SpringBoard hierarchy inspection established
the wrong tap target, which was corrected in the helper without changing product behavior.

After the status-bar correction, the same generic `build-for-testing` command passed again:
`duo-status-build.log`: `** TEST BUILD SUCCEEDED ** [88.332 sec]`, with no compiler/lint warnings
or errors. Explicit UI-test SwiftLint and `git diff --check` passed. Read-only review found no
actionable issue in the fourth helper change.

The affected test was rerun with:

```sh
xcodebuild test-without-building \
  -xctestrun .build/duo-dd/Build/Products/EhPanda_UITests_iphonesimulator27.1-arm64-x86_64.xctestrun \
  -derivedDataPath .build/duo-dd \
  -only-testing:EhPandaUITests/ReaderPageSyncUITests/testTheStatusBarScrollsTheStripToItsFirstPageAndTheIndicatorFollows \
  -destination 'platform=iOS Simulator,id=05422A43-8575-4BA6-A791-FAC2D5D3BA19' \
  -collect-test-diagnostics never
```

`duo-status-final.log`:

```text
testTheStatusBarScrollsTheStripToItsFirstPageAndTheIndicatorFollows passed (31.594 seconds).
Executed 1 test, with 0 failures (0 unexpected) in 31.594 (31.599) seconds
** TEST EXECUTE SUCCEEDED ** [37.934 sec]
```

The initial region-only implementation failed on Probe iPhone (`iphone-status-final.log`),
because that system element was not exposed. Two failed attempts completed and the third was
interrupted normally with SIGINT. The subsequent diagnostic (`iphone-status-hierarchy.log`)
passed (33.603 seconds), `** TEST SUCCEEDED ** [109.402 sec]`, and showed the classic status
bar's actual frame and absence of the named region. The final helper chooses by element
existence, keeping the previously passing classic tap for that hierarchy.

Final source build command:

```sh
xcodebuild build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/duo-dd ARCHS=arm64
```

`duo-helper-final-build.log`: `** TEST BUILD SUCCEEDED ** [34.809 sec]`; no warnings or errors.
The command uses the architecture of both test devices. The generated test-run file is
`EhPanda_UITests_iphonesimulator27.1-arm64.xctestrun`.

Final affected-test reruns use the single-test command above with that arm64 test-run file:

- Probe iPhone (`6CE1E40A-7090-484E-8C49-B7BCBDC5E684`), `iphone-status-adaptive.log`:
  `Executed 1 test, with 0 failures (0 unexpected) in 33.613 (33.619) seconds`;
  `** TEST EXECUTE SUCCEEDED ** [53.032 sec]`.
- Duo (`05422A43-8575-4BA6-A791-FAC2D5D3BA19`), `duo-status-adaptive.log`:
  `Executed 1 test, with 0 failures (0 unexpected) in 38.236 (38.244) seconds`;
  `** TEST EXECUTE SUCCEEDED ** [45.387 sec]`.

Both affected-test reruns passed on their first attempt. At that point, helper-only coverage
was eight passing methods on Probe iPhone and seven on Duo, with scrolling still failing.
That failure was subsequently fixed by the owner-approved product modifier described above.
Explicit UI-test SwiftLint and `git diff --check` also passed.

## Full regression after the approved product fix

Both full reader runs use the full-class `test-without-building` command documented above,
with the current `EhPanda_UITests_iphonesimulator27.1-arm64.xctestrun` file:

- Duo: `duo-reader-approved-final.log`:
  `Executed 8 tests, with 0 failures (0 unexpected) in 424.857 (424.873) seconds`;
  `** TEST EXECUTE SUCCEEDED ** [429.540 sec]`. All eight passed on their first attempt.
- Probe iPhone: `iphone-reader-approved-final.log`:
  `Executed 8 tests, with 0 failures (0 unexpected) in 459.370 (459.380) seconds`;
  `** TEST EXECUTE SUCCEEDED ** [474.869 sec]`. All eight passed on their first attempt.

## Commit status and remaining decisions

Created `4191a6bb09` — `fix(reader): support Duo toolbar behavior`, changing only
`EhPandaUITests/Support/ReaderPageProbe.swift` and `AppPackage/Sources/ReadingFeature/ReadingView.swift`.
No push or pull request was made. Both throwaway diagnostic test classes and all product instrumentation were removed
from the source targets. Diagnostic files and this report remain under ignored `.build/`.

The four pre-existing commits remain unchanged:

- `7cf9ff16ef` — `fix(reader): seed the pager from its measured size`
- `605b4e4749` — `feat(app): route screens by window size classes`
- `e03456839a` — `fix(layout): pick layouts by size class, not idiom`
- `1c79f36368` — `fix(ui): keep prose inside horizontal safe areas`

The commit was gated on the warning-free test build, both complete eight-test reader regressions,
explicit SwiftLint of the UI tests and ReadingView, and `git diff --check`. All passed on the
final source. The approved product and helper changes were committed together as the completed
Duo reader correction. The worktree has no tracked or untracked source changes remaining.

The owner also needs to decide whether the compact NewDawn sheet's 60% sun is desired. This
session made no product adjustment to that existing branch behavior.

Still unverified: continuous live folding and true orientation transitions through XCTest on Duo.
The successful CLI-controlled cold poses are
documented separately above. Dual-page resume preserved the visible spread in the inspected
case; a permanent test and a decision on even-page indicator normalization remain open.


## Later follow-up

The later Home work verified continuous folding with a presented list (`DUO-HOME-VERIFICATION.md`). The reader orientation work added permanent spread/page checks on rotation and reentry (`reader-followup/VERIFICATION.md`). The final cover-display checks now pass after restarting the dedicated simulator. The owner reviewed actual 60% and 50% iPad NewDawn captures and selected 50%; see `duo-final-verification/VERIFICATION.md` for implementation and final evidence. Earlier unresolved notes above describe the state at the original verification, not the final outcome.
