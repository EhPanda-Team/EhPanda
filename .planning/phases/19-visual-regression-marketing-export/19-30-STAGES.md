# 19-30 stages

Plan 19-30 splits every scenario's steps into two stages, a stillness stage (`still:`) and an operating stage
(`interact:`), so that a page whose step makes it still settles at screen size before the window grows, and a step that
operates the page runs in the grown window (owner decision 2026-11-23, 「把步驟拆成兩種」, split the steps into two
kinds; D-08 amendment). Notation: `$MAIN` is the main checkout's root (reached through the git common directory) and
`$W` is `$MAIN/.capture/agent-work/phase19-30`, ignored by git; no picture is in the repository.

The rule. A step is a stillness step (`still:`) when all it does is let what `make` built finish and hold it still, so
the page can settle at screen size: it stops a spinner or a caret's blink, or waits for a keyboard, an alert or a glass
shadow the state itself brought up, and re-focuses only a field the state itself focused. Every other step is an
operating step (`interact:`): a user's action (a tap or activation, a held tap, opening a menu or a dialog, scrolling,
typing, focusing a field the state did not focus), or a check or correction the page does not need in order to settle
(`RevealStep.showLargeTitle()` names the shown list as the bar's scroll view; a lone `RevealStep.awaitDialogPlatter()`
checks the platter of a dialog `make` presented), together with everything the same step does after its action: a hold of
what the action brought up belongs to that step, in its order. A step moves between stages by its argument label only.

The orders. Screen-sized path (committed height at or under the window's own): host, `still`, `interact`, settle, capture,
check. Tall path: host, `still`, native settle, freeze and verify, grow (status bar companion, size-class pins, resize,
one sample, geometry check), `interact`, settle, capture, check. Measuring mode: the window's own height in a
screen-sized hosting, then each taller height in a fresh tall hosting, the need read after the settle. An operating step
cannot be undone and the owner's order grows the window before it, so a taller height needs a fresh hosting; and because
the previous hosting's scroll view is gone by then, "a scroll view that does not grow with the window" is read as the
most-overflowing scroll view keeping its class and its height (within one device pixel) from one hosting to the next
while the window grew.

The keyboard rule (evidence, not guesswork). Two conditions, both read while the page is hosted, after the settle, on the
scroll view that sets the need (`PageNeed.scrollView`): (1) a keyboard is up: the frame UIKit last announced in
`UIResponder.keyboardDidChangeFrameNotification` (`keyboardFrameEndUserInfoKey`, screen coordinates), recorded by
`KeyboardWatch` from the first matrix case on, has a height above 0 and a top above the screen's bottom less one point
(`GalleryScenarios.keyboardIsUp(over:)`, the rule the three keyboard steps already wait on); (2) that scroll view avoids
the keyboard: the keyboard's top lies at least one device pixel above the scroll view's bottom edge (in screen
coordinates), and the scroll view's `adjustedContentInset.bottom` covers that overlap within one device pixel (the
mechanism 19-20's experiment measured). When both hold and the page needs more than its window, no height covers it:
the measuring mode says so at that hosting (`cannot-cover`, reason `cannot-cover:keyboard`), and the check appends
`, cannot-cover:keyboard` to its reason. A classification, never an adjustment; whether keyboard states keep the screen
height is decided in 19-26.

## Before-sample

Taken at `849222540` (sources of `c9ec46771`, no source changed by this plan yet), screen-sized, candidate mode, the 17
stillness states (`$STAGE` of the plan), the phase simulators by exact name:

```
Scripts/visual/run-snapshot-local.sh --device phone --simulator 'EhPanda iPhone Air (phase19)' --config en-large,ja-accessibility5 --classes "$STAGE" --mode candidate --out "$W/stage-before-phone"
Scripts/visual/run-snapshot-local.sh --device pad --simulator 'EhPanda iPad Pro 11-inch (M5) (phase19)' --orientation portrait --config en-large --classes "$STAGE" --mode candidate --out "$W/stage-before-pad"
```

| device | keys | recorded | error `page-height` | timeout | other error |
| --- | --- | --- | --- | --- | --- |
| phone | 136 | 32 | 103 | 1 | 0 |
| pad | 34 | 14 | 18 | 0 | 2 |

The before-sample is kept exactly as captured (orchestrator decision: running it again for a nicer reference would be a
blind re-run).

Non-recorded at base (neither `recorded` nor a `page-height` error; base behaviour of the sources of `c9ec46771`, not
caused by 19-30):

- phone `reader-slider-scrub__en__large__landscape__iphone__light`: status `timeout`, 2 attempts, 40 settle samples
  (last attempt), 29.4 s. Attempt 2: `settle-timeout:pixels:0,307,912x113`; attempt 1: `settle-timeout:pixels:0,307,912x113`
  (the slider preview strip keeps changing). The same state's portrait light key had a first attempt
  `settle-timeout:pixels:405,810,15x79` and ended as `page-height` on its second.
- pad `app-wide-app-alert__en__large__portrait__ipad__light`: status `error`, 2 attempts, 0 settle samples, 63.3 s.
  Attempt 2: `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=30.3s turned=30.3s polls=48`;
  attempt 1: `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=31.6s turned=30.6s polls=48`.
- pad `app-wide-app-alert__en__large__portrait__ipad__dark`: status `error`, 2 attempts, 0 settle samples, 61.2 s.
  Attempt 2: `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=30.4s turned=30.4s polls=48`;
  attempt 1: `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=30.1s turned=30.1s polls=47`.

Identity rule for these 3 keys (orchestrator decision): no picture comparison, because a timeout or error picture is not
a settled capture. Wherever a later after-capture covers one of these keys, it must end with the same status and the same
reason prefix as at base: `settle-timeout:pixels` for reader-slider-scrub iPhone landscape light, and
`interaction:no-keyboard:announced-hidden` for the iPad app-alert pair. Any other outcome, including `recorded`, is a
difference: report it and pause.

Open items (base behaviour, for the summary):

- (i) reader-slider-scrub iPhone landscape: the slider preview strip keeps changing and never settles (an input for
  19-27's variation work).
- (ii) the iPad app-alert text field begins editing, but UIKit announces the keyboard hidden, while the other iPad
  keyboard states pass (to be investigated before 19-26 measures it, and possibly a hosted-gate failure too).

## Capture path

Sources of `849222540` plus `still:` on the capture path (Task 1).

**RED of the real page (step 2, today's order).** One-off committed heights for `home-loading` (iPhone portrait
`large` 941, landscape `large` 903, every other value the device height; 19-20's order-B needs), applied with
`snapshot_heights.py apply --only home-loading`, candidate run of `HomeSnapshotTests/testHomeLoading`, iPhone `en-large`
(`$W/tracer-red`): `passed=0 recorded=0 timeout=4 error=0`. Every line is `timeout`, both attempts, reason
`settle-timeout:animation:UIImageView:contents` (the native settle before the step, 19-20 open item a). The provider was
restored with `git checkout --`; `check-sources` printed `138 states, heights read back`, exit 0.

**RED of the unit cases (step 3).** `CaptureStageTests` with `still:` only run immediately before `interact` (the stage
order not yet implemented), `$W/stage-red.xcresult`: 2 of 3 cases fail, as expected.

- `testAStillnessStepRunsAtNativeSizeAndAnOperatingStepInTheGrownWindow`: still saw the grown window,
  `("[1512.0]") is not equal to ("[912.0]") - still at committed 1512.0`.
- `testAPageOnlyItsStillnessStepHoldsStillIsTakenTallerThanTheScreen`: `("timeout") is not equal to ("recorded") -
  settle-timeout:pixels:105,102,17x50`, and no picture.
- `testOnTheScreenSizedPathTheTwoStagesAreTheOneStepOfBefore` passes before and after (the screen-sized path already runs
  the two back to back).

(My first draft of the first case let the page overflow at the window's own committed height, which the check reports as
`page-height`; the page is now `committed - 200` pt of content, so it fits the window in both iterations.)

**GREEN (step 5).** `CaptureStageTests`, `HostedWindowCaptureTests` and `ScenarioInventoryTests` on the project iPhone:
`** TEST SUCCEEDED ** [184.175 sec]` (`$W/stage-tests-1.xcresult`); strict lint of `VisualSnapshotSupport` and
`VisualSnapshotTests`: 0 lines each.

**Tracer table (step 6, the same one-off input as the RED, `$W/tracer-green`).**

| coordinate (iPhone `en`, `large`) | committed one-off | status | picture height |
| --- | --- | --- | --- |
| portrait, light | 941 | recorded | 941 |
| portrait, dark | 941 | recorded | 941 |
| landscape, light | 903 | recorded | 903 |
| landscape, dark | 903 | recorded | 903 |

The provider was restored from the backup (`cmp -s` equal) and `check-sources` exited 0.

**`home-loading` screen-sized identity (step 7).** `$W/home-after-phone` (`en-large,ja-accessibility5`) and
`$W/home-after-pad` (portrait, `en-large`) against `$W/stage-before-phone` and `$W/stage-before-pad`, SHA-256 per key:

| device | keys | status | same bytes as before | differing keys |
| --- | --- | --- | --- | --- |
| phone | 8 | 8 `page-height` errors (picture kept, as before) | 8 of 8 | none |
| pad | 2 | 2 `recorded` | 2 of 2 | none |

## Measuring mode

**RED (step 1).** `CaptureStageTests` with the five new cases and `keyboardTop` added to `CaptureHeight` and `measure` but
not yet read, `$W/stage-red2.xcresult`: 4 of the 5 new cases fail, as expected (the 3 capture-path cases of Task 1 still
pass).

- `testAPageOnlyItsStillnessStepHoldsStillIsMeasured`: `("error") is not equal to ("measured") - settle-timeout:pixels:23,102,99x49`
  (the taller hosting's native settle runs before the step), need nil, steps 0.
- `testEachMeasuredHeightIsItsOwnHostingInTheCaptureOrder`: `make` called once (not twice), still saw `[912.0]` not
  `[912.0, 912.0]`, interact saw `[912.0]` not `[912.0, 1422.0]`.
- `testAKeyboardTheScrollViewAvoidsCannotBeCoveredAndIsFoundAtTheFirstHosting`: `("measured") is not equal to ("cannotCover")`,
  reason nil, steps 1 not 0.
- `testTheChecksReasonNamesAKeyboardTheScrollViewAvoids`: reason `page-height: needs 1714 pt, committed 912 pt` without
  `, cannot-cover:keyboard`.
- `testAKeyboardTheScrollViewDoesNotAvoidIsNoReason` passes before and after (the old code has no keyboard reason).

(A first RED run had a fixture fault of mine: the synthetic scroll view was not resized with its page, so it also failed
the keyboard-less cases with `cannot-cover:UIScrollView`. The fixture now keeps the scroll view the size of its page in
`layoutSubviews`, and the RED above is the run after that fix.)

**GREEN (step 3).** `CaptureStageTests` (8 cases), `HostedWindowCaptureTests` and `ScenarioInventoryTests` on the project
iPhone: `** TEST SUCCEEDED ** [248.927 sec]`; strict lint of `VisualSnapshotSupport` and `VisualSnapshotTests`: 0 lines
each. Implementation: `ScenarioFactory` unchanged in this task; `TallWindow.swift` gains `CaptureHeight.keyboardTop`,
`PageNeed.avoidsKeyboard(topAt:in:)`, `GrownPreparation` and `prepareGrownWindow`, and `measure` is rewritten as one
hosting per height; `HostedWindowCapture.attemptTall` calls `prepareGrownWindow` and `checked` takes the `CaptureHeight`;
`SnapshotMatrixCase` supplies `keyboardTop` from `KeyboardWatch`.

**Tracer, measuring mode (step 4, `$W/tracer-measure`, `home-loading`, iPhone `en-large`).**

| coordinate | status | need (pt) | steps |
| --- | --- | --- | --- |
| portrait, light | measured | 941 | 1 |
| portrait, dark | measured | 941 | 1 |
| landscape, light | measured | 903 | 1 |
| landscape, dark | measured | 903 | 1 |

Under the old order 19-20 had `error` (`settle-timeout:animation:UIImageView:contents`) for all four. The larger of light
and dark is 941 in portrait and 903 in landscape, the values Task 1 captured at.

**Tracer, tall capture through `prepareGrownWindow` (`$W/tracer-green-2`).** The same one-off input as Task 1's
`$W/tracer-green`: 4 of 4 `recorded`, every key's status and SHA-256 equal to `$W/tracer-green`'s (0 differing keys). The
provider was restored with `git checkout --`; `check-sources` printed `138 states, heights read back`, exit 0.

## Stage inventory

(Task 3.)

## Screen-sized path

(Task 3.)

## The 19-18 sample

(Task 3.)

## Accepted differences

none

## Probes under the two stages

(Task 4.)

## Dialogs presented on hosting

(Task 4.)

## Popover proof

(Task 4.)
