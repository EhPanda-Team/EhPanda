# Phase 17 Plan 05: Inline review

Scope: every source and test change of 17-05, from the card color fixes (`fae3b53761`) to the
frame source change (`b292211a37`), against the plan's truths (marketing drives current actual app
views at normal device dimensions; screen and image readiness are verified before each frame;
9:41, absent capsule and byte-identical cold reruns are measured gates), AGENTS.md, the root
SwiftLint rules and the 120-column width of the `Scripts/visual` Python files.

The review ran in two rounds. Round one reread every change through the settle launch
(`d82c4f57fa`) after its gate passed. The final gate on the round-one fixes then failed on iPad,
and the owner chose system screenshots as frames (17-05-PLAN.md, decision 4); round two reread
that change (`b292211a37`).

## Findings

All findings are fixed: R-1 and R-2 in `e9685dc751`, R-3 and R-4 in `1fc626c2f5`, R-5 to R-8 in
`051cc01132`. Nothing is open.

### R-1: One failed restore step skipped the next

`capture-native.py` restored the simulator in one `try` block: clearing the status bar, then
putting back the appearance. A failed clear, or overrides that survived it, raised before the
appearance was restored, although the plan asks for simulator-owned settings to be restored on
failure too. Fix: the restore steps are callbacks on an `ExitStack`, which runs each of them even
when one before it fails and then raises the failure. A test fails the clear and checks that
the appearance and portrait still come back.

### R-2: The portrait restore ran with the last launch's capture parameters

Each launch wrote its coordinate, fixture version and handshake directory into the shared
single-pass UI test run, and the closing portrait restore reused that run. The orientation test
ignores those variables, but the restore was not the plain invocation its name claims. Fix: the
restore writes a fresh single-pass run first. The tests check that the restore run carries none
of the capture variables.

### R-3: A missing blank line before `CaptureRoute`

`AppLaunchAutomation.swift` declared the new `CaptureRoute` enum directly after the
initializer's closing brace, unlike every other member of the type. Fix: a blank line.

### R-4: Two doc comments still named one image cache

`CaptureDiagnostics.pendingImages` and `CaptureDiagnosticsElement` described "the image cache",
although readiness now asks Kingfisher's, SDWebImage's and the reader's own cache through
`LibraryClient.isCached`. Fix: "no image cache holds" and "the image caches", as the README
already says.

### R-5: Lines past the scripts' 120-column width

The new comment on `FRAME_PNG` ran to 121 columns, and the plan's two Python files each kept one
older line past 120 (the `Gate` construction in `capture-native.py`, a `patch` in
`test_different_cold_frames_fail`), while the other `Scripts/visual` files wrap at 120. Fix: all
three wrap.

### R-6: The RGBA rejection test matched any header mismatch

The dispatch test that feeds an RGBA screenshot expected only the word "expected", which every
PNG header failure contains. Fix: it matches the observed RGBA color type and the expected RGB
one.

### R-7: An unclear comment on the frame attachment

`MarketingCaptureUITests` explained the PNG attachment as "The rendered PNG bytes unchanged,
which the native runner compares across cold launches", a fragment. Fix: "The PNG exactly as the
system rendered it: the native runner compares these bytes across cold launches."

### R-8: Two runner checks had no failing test

Mutations of the new launch path showed that no test failed when a launch's attachments held two
screenshots (the runner requires exactly one) or when the launch's result reported a runtime
warning (`contracts.validate_test_result`). Fix: a test for zero and two screenshots, and one for
a result with a runtime warning. All seven mutations of the launch path (skipping the frame,
diagnostics, runtime or result checks, accepting RGBA frames or a duplicate attachment, and
checking the settle screenshots as frames) now fail the suite.

## Checked without findings

- **Routes.** `AppReducer.captureRouteEffect` and `DetailReducer`'s capture continuation send
  the same actions as the taps they stand for, sequence them in `.run` effects (no deprecated
  `concatenate`), run only for a capture launch (DEBUG), and leave the existing download
  automation's guards unchanged.
- **Diagnostics.** The screen comes from navigation state, never from the configuration; each
  screen's readiness waits for its content and every image it must show; a refused request, a
  failed load, a highlighted comment, non-default Filters or the bypass off fail the screen.
  `DataCache.containsData(forKey:)` is nonisolated and touches only `FileManager.default`.
- **Card colors.** Equal color counts rank by packed value; under Reduce Motion the gradient's
  points take the R2 arrangement and a late palette applies at once, both owner-approved and
  recorded in the Reduce Motion inventory test.
- **Launcher and frame.** A coordinate decodes with exactly five keys; the launcher verifies
  family, rendering and content. The test then takes `XCUIScreen` screenshots a second apart, at
  most ten, until two are byte-identical, fails when they never agree, and attaches the PNG
  bytes unchanged next to the diagnostics, so a failed capture still leaves its evidence. The
  PNG's only metadata is a generic "Screenshot" description and its pixel size, nothing of the
  host or the run.
- **Native runner.** The pin is validated before any launch and never written; output may not
  overlap its inputs; each launch must pass exactly one single-pass test on the pinned model and
  runtime; its diagnostics and screenshot come from that launch's own exported attachments, one
  of each; the diagnostics must name the coordinate and the frame must be a complete 8-bit RGB
  PNG at the pin's portrait size; sources, pin and fixture must not change; existing status bar
  overrides are refused rather than overwritten. Settings' settle screenshots still come from
  simctl and are checked as RGBA.
- **Fixture derivation.** `fixtures.prefetch_window` mirrors `ReadingReducer.prefetchImages` at
  the default limit, and every reader page a loaded batch lists is required.
- **Visual simulators.** Resolution needs exactly one available simulator per reserved name,
  model and runtime; the names stay out of the tracked pin.
