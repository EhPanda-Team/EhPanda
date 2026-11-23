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
  19-27's variation work). Intermittent in the measuring mode too; must be resolved before 19-26's full measurement, or
  19-26 will record these as errors (orchestrator decision; the orchestrator decides when the fix happens).
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

One row per state (138), in the order of `ScenarioCatalog.providers` and each provider's `states`, as the provider files
pass them after this plan. A step cell names what the file passes (an inline closure by the helpers it calls, in order;
`RevealStep` helpers with `(…)` where they take arguments; `.restingAtTop()` as `restingAtTop(<inner step>)`); `none`
where a stage is empty.

| state | provider | still | interact |
| --- | --- | --- | --- |
| `agewall-unticked` | AgeWallViewSnapshot | none | none |
| `agewall-ticked` | AgeWallViewSnapshot | none | none |
| `analytics-choice-none` | AnalyticsChoiceViewSnapshot | none | none |
| `analytics-choice-minimal` | AnalyticsChoiceViewSnapshot | none | `RevealStep.reveal(…)` |
| `analytics-choice-basic` | AnalyticsChoiceViewSnapshot | none | `RevealStep.reveal(…)` |
| `analytics-choice-full` | AnalyticsChoiceViewSnapshot | none | `RevealStep.reveal(…)` |
| `shell-library-sidebar` | LibraryViewSnapshot | none | none |
| `shell-library-title-menu` | LibraryViewSnapshot | none | `restingAtTop(BrowsingScenarios.activate)` |
| `home-populated` | HomeViewSnapshot | none | none |
| `home-loading` | HomeViewSnapshot | `BrowsingScenarios.freezeIndicators` | none |
| `home-error` | HomeViewSnapshot | none | none |
| `front-page-list` | FrontPageViewSnapshot | none | none |
| `front-page-grid` | FrontPageViewSnapshot | none | none |
| `front-page-loading` | FrontPageViewSnapshot | `BrowsingScenarios.freezeIndicators` | none |
| `front-page-error` | FrontPageViewSnapshot | none | none |
| `front-page-empty` | FrontPageViewSnapshot | none | none |
| `front-page-search` | FrontPageViewSnapshot | none | `BrowsingScenarios.focusSearchFieldOnceSettled` |
| `popular-list` | PopularViewSnapshot | none | none |
| `popular-grid` | PopularViewSnapshot | none | none |
| `popular-loading` | PopularViewSnapshot | `BrowsingScenarios.freezeIndicators` | none |
| `popular-error` | PopularViewSnapshot | none | none |
| `watched-list` | WatchedViewSnapshot | none | none |
| `watched-grid` | WatchedViewSnapshot | none | none |
| `watched-empty` | WatchedViewSnapshot | none | none |
| `watched-error` | WatchedViewSnapshot | none | none |
| `watched-signed-out` | WatchedViewSnapshot | none | none |
| `toplists-list` | ToplistsViewSnapshot | none | none |
| `toplists-grid` | ToplistsViewSnapshot | none | none |
| `toplists-error` | ToplistsViewSnapshot | none | none |
| `toplists-period-menu` | ToplistsViewSnapshot | none | `BrowsingScenarios.activate` |
| `app-wide-app-alert` | ToplistsViewSnapshot | `SettingsScenarios.holdAlertCaret` | none |
| `history-list` | HistoryViewSnapshot | none | none |
| `history-grid` | HistoryViewSnapshot | none | none |
| `history-empty` | HistoryViewSnapshot | none | none |
| `history-clear-confirmation` | HistoryViewSnapshot | none | `BrowsingScenarios.activate; RevealStep.awaitDialogPlatter()` |
| `search-root-empty` | SearchRootViewSnapshot | none | none |
| `search-root-history` | SearchRootViewSnapshot | none | none |
| `search-clear-confirmation` | SearchRootViewSnapshot | none | `BrowsingScenarios.activate; RevealStep.awaitDialogPlatter()` |
| `search-typing-suggestions` | SearchRootViewSnapshot | none | `LibraryScenarios.type` |
| `search-results-list` | SearchViewSnapshot | none | `restingAtTop()` |
| `search-results-grid` | SearchViewSnapshot | none | `restingAtTop()` |
| `search-results-empty` | SearchViewSnapshot | none | `restingAtTop()` |
| `search-results-error` | SearchViewSnapshot | none | `restingAtTop()` |
| `quick-search-list` | QuickSearchViewSnapshot | none | none |
| `quick-search-empty` | QuickSearchViewSnapshot | none | none |
| `quick-search-delete-confirmation` | QuickSearchViewSnapshot | none | none |
| `quick-search-word-editor` | QuickSearchViewSnapshot | `LibraryScenarios.holdCaret` | none |
| `quick-search-filters` | FiltersViewSnapshot | none | none |
| `quick-search-filters-reset-confirmation` | FiltersViewSnapshot | none | `RevealStep.reveal(…)` |
| `quick-search-date-seek` | DateSeekPickerViewSnapshot | none | none |
| `favorites-list` | FavoritesViewSnapshot | none | `restingAtTop()` |
| `favorites-grid` | FavoritesViewSnapshot | none | `restingAtTop()` |
| `favorites-empty` | FavoritesViewSnapshot | none | `restingAtTop()` |
| `favorites-signed-out` | FavoritesViewSnapshot | none | `restingAtTop()` |
| `favorites-category-menu` | FavoritesViewSnapshot | none | `restingAtTop(LibraryScenarios.openCategoryMenu)` |
| `downloads-list` | DownloadsViewSnapshot | none | `restingAtTop()` |
| `downloads-grid` | DownloadsViewSnapshot | none | `restingAtTop()` |
| `downloads-empty` | DownloadsViewSnapshot | none | `restingAtTop()` |
| `downloads-active-failed` | DownloadsViewSnapshot | none | `restingAtTop()` |
| `downloads-delete-confirmation` | DownloadsViewSnapshot | none | `restingAtTop(LibraryScenarios.tapHeldRow)` |
| `downloads-move-confirmation` | DownloadsViewSnapshot | none | `restingAtTop(LibraryScenarios.tapHeldRow)` |
| `downloads-inspector` | DownloadInspectorViewSnapshot | none | `restingAtTop(LibraryScenarios.tapHeldRow)` |
| `downloads-inspector-error` | DownloadInspectorViewSnapshot | none | `restingAtTop(LibraryScenarios.tapHeldRow)` |
| `gallery-detail-loaded` | DetailViewSnapshot | none | none |
| `gallery-detail-loading` | DetailViewSnapshot | `BrowsingScenarios.freezeIndicators` | none |
| `gallery-detail-error` | DetailViewSnapshot | none | none |
| `gallery-detail-rating` | DetailViewSnapshot | none | `RevealStep.reveal(…)` |
| `gallery-detail-downloading` | DetailViewSnapshot | none | `RevealStep.reveal(…)` |
| `gallery-detail-delete-download-confirmation` | DetailViewSnapshot | none | none |
| `gallery-detail-retry-confirmation` | DetailViewSnapshot | none | none |
| `gallery-detail-sheet` | GallerySheetViewSnapshot | none | none |
| `settings-root` | SettingViewSnapshot | none | none |
| `comments-list` | CommentsViewSnapshot | none | none |
| `comments-menu` | CommentsViewSnapshot | none | `GalleryScenarios.openFirstRowMenu` |
| `comments-block-confirmation` | CommentsViewSnapshot | none | `TracerScenarios.chooseBlock` |
| `comments-blocked-row-collapsed` | CommentsViewSnapshot | none | none |
| `comments-blocked-row-shown` | CommentsViewSnapshot | none | none |
| `comments-post-empty` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | none |
| `comments-post-filled` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | none |
| `comments-posting-warning` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | none |
| `report-form-loading` | ReportFormViewSnapshot | `GalleryScenarios.holdStill` | none |
| `report-form-ready` | ReportFormViewSnapshot | none | none |
| `report-form-filled` | ReportFormViewSnapshot | none | none |
| `report-form-sending` | ReportFormViewSnapshot | `GalleryScenarios.holdStill` | none |
| `report-form-sent` | ReportFormViewSnapshot | none | none |
| `report-form-unavailable` | ReportFormViewSnapshot | none | none |
| `report-form-error-alert` | ReportFormViewSnapshot | none | `GalleryScenarios.presentHeldReportFailure` |
| `detail-pages-previews` | PreviewsViewSnapshot | none | none |
| `detail-pages-previews-loading` | PreviewsViewSnapshot | `GalleryScenarios.holdStill` | none |
| `detail-pages-gallery-info` | GalleryInfoViewSnapshot | none | none |
| `detail-pages-detail-search-list` | DetailSearchViewSnapshot | none | none |
| `detail-pages-detail-search-grid` | DetailSearchViewSnapshot | none | none |
| `detail-pages-archives` | ArchivesViewSnapshot | none | `RevealStep.showLargeTitle()` |
| `detail-pages-archives-insufficient-funds` | ArchivesViewSnapshot | none | `RevealStep.showLargeTitle(…); RevealStep.reveal(…)` |
| `detail-pages-torrents` | TorrentsViewSnapshot | none | `RevealStep.showLargeTitle()` |
| `detail-pages-torrents-empty` | TorrentsViewSnapshot | none | none |
| `detail-pages-tag-detail` | TagDetailViewSnapshot | none | none |
| `detail-pages-new-dawn` | NewDawnViewSnapshot | none | none |
| `detail-pages-folder-manager` | FolderManagerViewSnapshot | none | none |
| `detail-pages-folder-delete-confirmation` | FolderManagerViewSnapshot | none | none |
| `reader-vertical` | ReadingViewSnapshot | none | none |
| `reader-horizontal` | ReadingViewSnapshot | none | none |
| `reader-two-page-spread` | ReadingViewSnapshot | none | none |
| `reader-controls` | ReadingViewSnapshot | `SettingsScenarios.waitForGlassShadow` | none |
| `reader-slider-scrub` | ReadingViewSnapshot | `SettingsScenarios.waitForGlassShadow` | none |
| `reader-page-failed` | ReadingViewSnapshot | none | none |
| `reader-loading` | ReadingViewSnapshot | `GalleryScenarios.holdStill` | none |
| `reader-live-text` | ReadingViewSnapshot | none | none |
| `reader-settings-sheet` | ReadingSettingViewSnapshot | none | none |
| `settings-pages-reading` | ReadingSettingViewSnapshot | none | none |
| `settings-account-signed-in` | AccountSettingViewSnapshot | none | none |
| `settings-account-invalid-cookies` | AccountSettingViewSnapshot | none | `RevealStep.reveal(…)` |
| `settings-account-signed-out` | AccountSettingViewSnapshot | none | none |
| `settings-account-logout-confirmation` | AccountSettingViewSnapshot | none | `RevealStep.awaitDialogPlatter()` |
| `blocked-users-filled` | BlockedUsersViewSnapshot | none | none |
| `blocked-users-empty` | BlockedUsersViewSnapshot | none | none |
| `settings-login-empty` | LoginViewSnapshot | none | none |
| `settings-login-filled` | LoginViewSnapshot | `LibraryScenarios.holdCaret` | none |
| `settings-login-error` | LoginViewSnapshot | none | none |
| `settings-pages-general-minimal` | GeneralSettingViewSnapshot | none | `SettingsScenarios.scrollToBottom` |
| `settings-pages-general-basic` | GeneralSettingViewSnapshot | none | `SettingsScenarios.scrollToBottom` |
| `settings-pages-general-full` | GeneralSettingViewSnapshot | none | `SettingsScenarios.scrollToBottom` |
| `settings-pages-general-cache-confirmation` | GeneralSettingViewSnapshot | none | `RevealStep.reveal(…)` |
| `settings-pages-general-translations-confirmation` | GeneralSettingViewSnapshot | none | `RevealStep.reveal(…)` |
| `settings-pages-activity-logs` | AppActivityLogsViewSnapshot | none | none |
| `settings-pages-activity-logs-empty` | AppActivityLogsViewSnapshot | none | none |
| `settings-pages-activity-logs-run-picker` | AppActivityLogsViewSnapshot | none | `SettingsScenarios.openRunsMenu` |
| `settings-pages-appearance` | AppearanceSettingViewSnapshot | none | none |
| `settings-pages-app-icon` | AppIconViewSnapshot | none | none |
| `settings-pages-download` | DownloadSettingViewSnapshot | none | none |
| `settings-pages-laboratory` | LaboratorySettingViewSnapshot | `SettingsScenarios.waitForGlassShadow` | none |
| `settings-pages-about` | AboutViewSnapshot | none | none |
| `settings-pages-site-settings` | EhSettingViewSnapshot | none | none |
| `settings-pages-site-settings-confirmation` | EhSettingViewSnapshot | none | `RevealStep.reveal(…)` |
| `settings-pages-site-settings-error` | EhSettingViewSnapshot | none | none |
| `app-wide-error-info` | ErrorInfoViewSnapshot | none | none |
| `app-wide-toast-success` | ToastMessageViewSnapshot | none | none |
| `app-wide-toast-failure` | ToastMessageViewSnapshot | none | none |

The rule is the one at the top of this file: a step is a stillness step (`still:`) when all it does is let what `make`
built finish and hold it still; every other step is an operating step (`interact:`), together with everything the same
step does after its action. A step moves between stages by its argument label only.

Counts: 17 states with a `still` step, 44 with an `interact` step, 77 with no step; no state has both (checked by
`both` 0 in Task 3's verify).

Mixed closures: none. No state combines a stillness helper with an operating one. Seven operating helpers end with a
hold of what their own action brought up, and stay whole in the operating stage, in their order:
`BrowsingScenarios.focusSearchFieldOnceSettled` (freezes after the focus), `LibraryScenarios.type` (solid caret and freeze
after the typing), `SettingsScenarios.openRunsMenu` and `LibraryScenarios.openCategoryMenu` (menu scroll indicators hidden
after opening), `LibraryScenarios.tapHeldRow` and the two inline clear steps of `history-clear-confirmation` and
`search-clear-confirmation` (the platter wait after the tap), `GalleryScenarios.presentHeldReportFailure` (the rest wait
after the alert), and `restingAtTop()` (the clear button wait after the pull).

Not steps (presented by `make` at hosting, before any growth; this plan does not move them): the dialogs or alerts of
`settings-account-logout-confirmation`, `quick-search-delete-confirmation`, `gallery-detail-delete-download-confirmation`,
`gallery-detail-retry-confirmation`, `detail-pages-folder-delete-confirmation` and `app-wide-app-alert`.

## Screen-sized path

After-captures with the sources of this plan (`still:` on the 17 stillness states), the two commands of the before-sample
with `--out "$W/stage-after-phone"` and `--out "$W/stage-after-pad"`, judged by SHA-256 per key against
`$W/stage-before-phone` and `$W/stage-before-pad`.

| device | keys | statuses (now) | same bytes as before | differing keys |
| --- | --- | --- | --- | --- |
| phone | 136 | 32 `recorded`, 104 `page-height` errors | 123 | 13 |
| pad | 34 | 14 `recorded`, 18 `page-height`, 2 `interaction:no-keyboard:announced-hidden` | 30 | 4 |

The three non-recorded keys of the base (Before-sample, identity rule of the orchestrator):

- pad `app-wide-app-alert__en__large__portrait__ipad__light` and `__dark`: `error`, reason still
  `interaction:no-keyboard:announced-hidden`: the rule holds.
- phone `reader-slider-scrub__en__large__landscape__iphone__light`: base `timeout` (`settle-timeout:pixels:0,307,912x113`),
  now `error` `page-height: needs 10230 pt, committed 420 pt` with a picture. The rule asks for `settle-timeout:pixels`,
  so this is a difference. The old sources captured again on the same warm simulator also end `page-height` with the same
  need (10230 pt), and the new picture is byte-identical to that re-run. Accepted by the orchestrator's controlled-outcome
  decision: the base `settle-timeout` was a one-time cold outcome; this supersedes the same-reason rule for this one key
  (the rule stays in force for the iPad app-alert pair).

Differing keys, with the standing rule's evidence. (a) is the decoded 8-bit RGBA comparison; (b) is whether the new picture
is byte-identical to a capture the old sources produced (here the old sources captured again on the same warm simulator,
the `$W/old-phone` and `$W/old-pad` runs of (d)); (c) does not apply (no iPad Library page); (d) is that re-run: the
sources of `c9ec46771` for `VisualSnapshotSupport` and `VisualSnapshotTests` were swapped in from a copy, the classes of
the differing keys captured, and the working tree restored with identical checksums (`swap-before.sha` equals
`swap-after.sha`); nothing was committed.

Phone (`en-large`, `ja-accessibility5`):

| key | status now / base | decoded pixels differing, largest channel difference (new vs base) | old sources re-run (warm) equals new | old re-run equals base |
| --- | --- | --- | --- | --- |
| `app-wide-app-alert__en__large__landscape__iphone__dark` | error / error | 3 px, 1 | no | yes |
| `comments-posting-warning__en__large__portrait__iphone__dark` | error / error | 16 px, 1 | yes | no |
| `reader-controls__en__large__portrait__iphone__light` | error / error | 77 px, 1 | yes | no |
| `reader-controls__en__large__portrait__iphone__dark` | error / error | 52 px, 1 | no | yes |
| `reader-controls__en__large__landscape__iphone__light` | error / error | 14056 px, 2 | yes | no |
| `reader-controls__en__large__landscape__iphone__dark` | error / error | 4525 px, 2 | yes | no |
| `reader-slider-scrub__en__large__portrait__iphone__light` | error / error | 78 px, 1 | yes | no |
| `reader-slider-scrub__en__large__landscape__iphone__light` | error / timeout | 9829 px, 2 | yes | no |
| `reader-slider-scrub__en__large__landscape__iphone__dark` | error / error | 3927 px, 1 | yes | no |
| `reader-slider-scrub__ja__accessibility5__portrait__iphone__light` | error / error | 4 px, 1 | yes | no |
| `reader-slider-scrub__ja__accessibility5__portrait__iphone__dark` | error / error | 49 px, 1 | yes | no |
| `reader-slider-scrub__ja__accessibility5__landscape__iphone__light` | error / error | 10203 px, 2 | yes | no |
| `reader-slider-scrub__ja__accessibility5__landscape__iphone__dark` | error / error | 3346 px, 1 | yes | no |

Pad (portrait, `en-large`):

| key | status now / base | decoded pixels differing, largest channel difference (new vs base) | old sources re-run (warm) equals new | old re-run equals base |
| --- | --- | --- | --- | --- |
| `reader-controls__en__large__portrait__ipad__light` | error / error | 949 px, 1 | yes | no |
| `reader-controls__en__large__portrait__ipad__dark` | error / error | 589 px, 2 | yes | no |
| `reader-slider-scrub__en__large__portrait__ipad__light` | error / error | 928 px, 1 | yes | no |
| `reader-slider-scrub__en__large__portrait__ipad__dark` | error / error | 538 px, 2 | yes | no |

Reading. For 15 of the 17 differing keys (11 phone, 4 pad) the old sources captured again on the same warm simulator give
the new bytes: the before-sample differs from every later capture of the same sources, as 19-18 found for a cold first
capture, so the stage split is not what changed those pictures. Two phone keys remain unexplained by (d): for
`app-wide-app-alert__en__large__landscape__iphone__dark` (3 px, largest channel difference 1) and
`reader-controls__en__large__portrait__iphone__dark` (52 px, 1) the old sources captured again equal the base, and the
new capture differs from both by at most one step per channel. The screen-sized path runs the same steps in the same
order for both. Decided by the orchestrator: the 15 keys whose old-source re-run equals the new bytes are accepted (cold
before-sample); the two unexplained keys were then compared with the runner's compare mode against the before-sample
(D-10 unchanged) and are accepted as run-to-run variation (see Accepted differences).

## The 19-18 sample

The two sample commands with `--out "$W/sample-phone"` and `--out "$W/sample-pad"` (20 classes, 19-18's sample without
`settings-root`), judged against 19-19's `regress-phone` and `regress-pad`.

| device | keys | statuses | same bytes as 19-19's capture | differing keys |
| --- | --- | --- | --- | --- |
| phone | 160 | 34 `recorded`, 126 `page-height` | 158 | 2 |
| pad | 40 | 30 `recorded`, 10 `page-height` | 40 | 0 |

Phone differing keys (the two 19-18 recorded as flipping on unchanged code are
`app-wide-error-info__en__large__portrait__iphone__dark` and `detail-pages-archives__ja__accessibility5__landscape__iphone__light`):

| key | status now / base | decoded pixels differing, largest channel difference (new vs base) | old sources re-run (warm) equals new | old re-run equals base |
| --- | --- | --- | --- | --- |
| `app-wide-error-info__en__large__portrait__iphone__dark` | error / error | 1 px, 1 | not captured | not captured |
| `detail-pages-archives__ja__accessibility5__landscape__iphone__dark` | error / error | 64 px, 1 | no | yes |

- `app-wide-error-info__en__large__portrait__iphone__dark`: 1 differing pixel, largest channel difference 1; the new
  picture is byte-identical to 19-18's `after-phone` capture of the old sources, so by the standing rule (19-19
  deviation 7) it is one of the two known flips. (This key was not in `old-phone`'s classes.)
- `detail-pages-archives__ja__accessibility5__landscape__iphone__dark` is not one of the two known keys (the known one is
  `__light`; its bytes equal 19-19's capture now, while the old sources captured again differ from both with 0 decoded
  pixels, a PNG-encoding-only difference). The `__dark` key differs from 19-19's capture by 64 pixels (largest channel
  difference 1), and the old sources captured again equal 19-19's capture, so (d) does not explain it. Compared with the
  runner's compare mode against 19-19's picture on the new sources (D-10 unchanged), it shows no difference: accepted as
  run-to-run variation (orchestrator decision; see Accepted differences).

## Accepted differences

- accepted: `comments-posting-warning__en__large__portrait__iphone__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-controls__en__large__portrait__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-controls__en__large__landscape__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-controls__en__large__landscape__iphone__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__en__large__portrait__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__en__large__landscape__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule); old and new both end `page-height: needs 10230 pt, committed 420 pt`; runner compare mode against the old re-run's picture reports no difference (D-10, precision 0.9999, perceptual precision 1); the base `settle-timeout` was a one-time cold outcome (orchestrator decision, supersedes the same-reason rule for this one key)
- accepted: `reader-slider-scrub__en__large__landscape__iphone__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__ja__accessibility5__portrait__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__ja__accessibility5__portrait__iphone__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__ja__accessibility5__landscape__iphone__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__ja__accessibility5__landscape__iphone__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-controls__en__large__portrait__ipad__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-controls__en__large__portrait__ipad__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__en__large__portrait__ipad__light`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `reader-slider-scrub__en__large__portrait__ipad__dark`: old sources re-run on the same warm simulator equal the new bytes (cold before-sample, 19-18 rule)
- accepted: `app-wide-app-alert__en__large__landscape__iphone__dark`: 3 differing pixels, largest channel difference 1 (3 bytes of a budget of 153); runner compare mode on the new sources against the before-sample picture: no difference (D-10 passed), and that capture was byte-identical to the before-sample; run-to-run variation (orchestrator decision)
- accepted: `reader-controls__en__large__portrait__iphone__dark`: 52 differing pixels, largest channel difference 1 (62 bytes of a budget of 153); runner compare mode on the new sources against the before-sample picture: no difference (D-10 passed), and that capture was byte-identical to the before-sample; run-to-run variation (orchestrator decision)
- accepted: `detail-pages-archives__ja__accessibility5__landscape__iphone__dark`: 64 differing pixels, largest channel difference 1 (64 bytes of a budget of 153); runner compare mode on the new sources against 19-19's `regress-phone` picture: no difference (D-10 passed); run-to-run variation (orchestrator decision)
- accepted: `app-wide-error-info__en__large__portrait__iphone__dark`: 1 differing pixel, largest channel difference 1; the new picture is byte-identical to 19-18's `after-phone` capture of the old sources (19-19 deviation 7 rule for the two known flips)

Evidence behind the three variation lines: the runner's compare mode (`--mode compare --refs`, a reference directory of
exactly the base pictures: the before-sample's for the two stage keys, 19-19's for the archives key), new sources, D-10
unchanged; `$W/cmp3-en`, `$W/cmp3-ja`. No `difference` picture was written. A control run with a deliberately wrong
reference for the archives key (`$W/cmp3-ctl`) did write one, so the references were read and compared. In the
compare run the two stage keys even came out byte-identical to the before-sample.

Open input for 19-27 (variation work): the three keys `app-wide-app-alert__en__large__landscape__iphone__dark`,
`reader-controls__en__large__portrait__iphone__dark` and `detail-pages-archives__ja__accessibility5__landscape__iphone__dark`
differ between captures of the same order by 1 unit in a few pixels (3, 52 and 64 pixels): variation evidence, not an effect
of the stage split.

## Probes under the two stages

Measuring runs of step 1 (`$W/measure-phone`, `$W/measure-pad-large`, `$W/measure-pad-ax5`), recorded before the
orchestrator's decision on their `error` and `did-not-converge` lines.

- iPhone `en-large`, 88 lines: `measured=60 cannot-cover=20 did-not-converge=4 error=4`. iPad: `measure-pad-large` 2 lines
  `measured` (`home-populated` 1858 pt, 1 step); `measure-pad-ax5` 4 lines `cannot-cover:UpdateCoalescingCollectionView`
  (Error Info 1930 pt after 1 step, download inspector 4357 pt after 3).
- The three required keyboard probes (`comments-post-filled`, `search-typing-suggestions`, `app-wide-app-alert`): all 12
  lines `cannot-cover` with reason `cannot-cover:keyboard` in 0 steps.
- `error` and `did-not-converge` lines (the step stops here and asks the orchestrator):
  - `quick-search-word-editor`, all 4 iPhone lines: `did-not-converge` after 12 steps, last need 1328 pt (portrait) and
    1093 pt (landscape); the keyboard rule did not classify it.
  - `reader-controls` portrait light: `error` `settle-timeout:pixels:3,803,417x86`, 0 steps; landscape light: `error`
    `settle-timeout:pixels:0,307,912x113`, need 10230 pt, 1 step.
  - `reader-slider-scrub` portrait light: `error` `settle-timeout:pixels:405,810,15x79`, need 4672 pt, 1 step; landscape
    dark: `error` `settle-timeout:pixels:0,310,912x110`, need 10230 pt, 1 step.

Diagnosis of `quick-search-word-editor` (iPhone `en-large`, portrait, light; uncommitted instrumentation, a `print` per
hosting in `measureHosted`, `$W/diag-qs`, `TallWindow.swift` restored by checksum, md5 `beee7474...` before and after):
at all 13 hostings `keyboardTop` is `nil` (no keyboard frame announced up, so condition 1 never holds and the rule has
nothing to classify). The need-setting scroll view is the sheet's `HostingScrollView`, frame on screen
`(0, 0, 420, window)`, bounds origin y -176, `adjustedContentInset` top 176 and bottom 34, `contentInset.bottom` 0; its
content height is the window height less 178 pt at every hosting (734 pt at window 912, 766 at 944, ..., 1118 at 1296), so
its overflow is a constant 32 pt (content + insets - bounds) and the need is always the window plus 32 pt: it grows by
exactly the window's growth (+32 pt per hosting, 944, 976, ..., 1328 after 12 hostings). The page's other scroll views
do not overflow (the collection view: content 222 pt in 844 to 1228 pt; the text view: 38 pt in 22 pt). The captured
picture shows no keyboard.

Per-hosting table of that diagnosis (portrait, light, `$W/diag-qs`; the first 13 hostings, the window of each being the previous need):

| hosting | window (pt) | need (pt) | `HostingScrollView` content (pt) | overflow (pt) | `keyboardTop` |
| --- | --- | --- | --- | --- | --- |
| 0 | 912 | 944 | 734 | 32 | nil |
| 1 | 944 | 976 | 766 | 32 | nil |
| 2 | 976 | 1008 | 798 | 32 | nil |
| 3 | 1008 | 1040 | 830 | 32 | nil |
| 4 | 1040 | 1072 | 862 | 32 | nil |
| 5 | 1072 | 1104 | 894 | 32 | nil |
| 6 | 1104 | 1136 | 926 | 32 | nil |
| 7 | 1136 | 1168 | 958 | 32 | nil |
| 8 | 1168 | 1200 | 990 | 32 | nil |
| 9 | 1200 | 1232 | 1022 | 32 | nil |
| 10 | 1232 | 1264 | 1054 | 32 | nil |
| 11 | 1264 | 1296 | 1086 | 32 | nil |
| 12 | 1296 | 1328 | 1118 | 32 | nil |

Restore proof: `TallWindow.swift` md5 `beee7474323aca402ec13bfea40d8621` before the instrumentation and after
`git checkout --`; `git diff -- AppPackage` was empty.

Orchestrator decision: `quick-search-word-editor` is a recorded finding, not a keyboard state (`keyboardTop` is nil and no
keyboard is in the picture), so the keyboard rule has no gap; it is a page-layout defect, very likely the owner's C1 item
(the Search Terms field), which 19-21 fixes.

- finding: `quick-search-word-editor__en__large__portrait__iphone__light`: `did-not-converge`, 12 steps, need 1328 pt; content follows the window (content = window - 178 pt, overflow a constant 32 pt in `HostingScrollView`), not keyboard
- finding: `quick-search-word-editor__en__large__portrait__iphone__dark`: `did-not-converge`, 12 steps, need 1328 pt; content follows the window (content = window - 178 pt, overflow a constant 32 pt in `HostingScrollView`), not keyboard
- finding: `quick-search-word-editor__en__large__landscape__iphone__light`: `did-not-converge`, 12 steps, need 1093 pt; content follows the window (content = window - 178 pt, overflow a constant 32 pt in `HostingScrollView`), not keyboard
- finding: `quick-search-word-editor__en__large__landscape__iphone__dark`: `did-not-converge`, 12 steps, need 1093 pt; content follows the window (content = window - 178 pt, overflow a constant 32 pt in `HostingScrollView`), not keyboard

Open item: quick-search-word-editor's content follows the window with a constant 32 pt overflow; hand to 19-21 (C1), which
must re-measure the state after its fix (`--measure-heights`, iPhone en-large, both orientations) and record whether it
converges.

Findings (orchestrator decision: the four reader timeouts are accepted as recorded findings, no re-run; the same
intermittent glass-shadow and slider-preview instability as open item (i), base behaviour, not caused by the two stages:
the other 4 lines of those states measured):

- finding: `reader-controls__en__large__portrait__iphone__light`: `error`, reason `settle-timeout:pixels:3,803,417x86`, no need (0 steps)
- finding: `reader-controls__en__large__landscape__iphone__light`: `error`, reason `settle-timeout:pixels:0,307,912x113`, need 10230 pt (1 step)
- finding: `reader-slider-scrub__en__large__portrait__iphone__light`: `error`, reason `settle-timeout:pixels:405,810,15x79`, need 4672 pt (1 step)
- finding: `reader-slider-scrub__en__large__landscape__iphone__dark`: `error`, reason `settle-timeout:pixels:0,310,912x110`, need 10230 pt (1 step)

Dialogs step 3a measurement of `quick-search-delete-confirmation` (`$W/measure-dialogs-phone`, `$W/measure-dialogs-pad`,
`en-large`): the same signature as `quick-search-word-editor`. On the iPhone it is `did-not-converge` after 12 steps with
the same needs (1328 pt portrait, 1093 pt landscape); on the iPad portrait `did-not-converge` after 12 steps, need
1626 pt (1210 pt plus 13 hostings of 32 pt). It is the same Quick Search sheet, so it is not diagnosed separately.
Orchestrator decision: record it as a finding, no re-run.

- finding: `quick-search-delete-confirmation__en__large__portrait__iphone__light`: `did-not-converge`, 12 steps, need 1328 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard
- finding: `quick-search-delete-confirmation__en__large__portrait__iphone__dark`: `did-not-converge`, 12 steps, need 1328 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard
- finding: `quick-search-delete-confirmation__en__large__landscape__iphone__light`: `did-not-converge`, 12 steps, need 1093 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard
- finding: `quick-search-delete-confirmation__en__large__landscape__iphone__dark`: `did-not-converge`, 12 steps, need 1093 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard
- finding: `quick-search-delete-confirmation__en__large__portrait__ipad__light`: `did-not-converge`, 12 steps, need 1626 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard
- finding: `quick-search-delete-confirmation__en__large__portrait__ipad__dark`: `did-not-converge`, 12 steps, need 1626 pt; the same signature as `quick-search-word-editor` (the need keeps growing with the window), not keyboard

iPad `app-wide-app-alert` (`$W/measure-dialogs-pad`, step 3a measurement; orchestrator decision: recorded as findings, base behaviour):

- finding: `app-wide-app-alert__en__large__portrait__ipad__light`: `error`, reason `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=30.3s`, no need (0 steps); the alert's keyboard step fails on the iPad at base (open item (ii)), not caused by the two stages
- finding: `app-wide-app-alert__en__large__portrait__ipad__dark`: `error`, reason `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0 waited=30.3s`, no need (0 steps); the alert's keyboard step fails on the iPad at base (open item (ii)), not caused by the two stages

Open item (extended): `quick-search-word-editor` and `quick-search-delete-confirmation` both hand to 19-21 (C1), which
must re-measure both states after its fix (`--measure-heights`, iPhone `en-large`, both orientations, and the iPad
portrait for the delete confirmation) and record whether they converge.

### Table A: 19-20 Table 1's six states, under 19-19's order, order B and the two stages

19-19's order and order B are copied from `19-20-PROBES.md` Table 1; the two-stage column is from `$W/measure-phone`
(iPhone `en-large`, status, need in pt, steps; light and dark listed where they differ).

| state | coordinate | 19-19 order (19-20) | order B (19-20) | two stages (19-30) |
| --- | --- | --- | --- | --- |
| `comments-post-filled` | iPhone `large`, portrait | error `settle-timeout:pixels:78,187,4x25`, 0 | did-not-converge 14383, 12 | cannot-cover 1603, 0, `cannot-cover:keyboard` |
| `comments-post-filled` | iPhone `large`, landscape | error `settle-timeout:pixels:504,101,5x25`, 0 | did-not-converge 12882, 12 | cannot-cover 1038, 0, `cannot-cover:keyboard` |
| `search-typing-suggestions` | iPhone `large`, portrait | did-not-converge 3980, 12 | did-not-converge 3980, 12 | cannot-cover 1148, 0, `cannot-cover:keyboard` |
| `search-typing-suggestions` | iPhone `large`, landscape | did-not-converge 6049, 12 | did-not-converge 6049, 12 | cannot-cover 853, 0, `cannot-cover:keyboard` |
| `app-wide-app-alert` | iPhone `large`, portrait | error `settle-timeout:animation:UIImageView:contents`, 0 | did-not-converge 1991, 12 | cannot-cover 995, 0, `cannot-cover:keyboard` |
| `app-wide-app-alert` | iPhone `large`, landscape | error `settle-timeout:animation:UIImageView:contents`, 0 | did-not-converge 4697, 12 | cannot-cover 749, 0, `cannot-cover:keyboard` |
| `settings-pages-general-full` | iPhone `large`, portrait | measured 912, 0 | measured 912, 0 | measured 912, 0 |
| `settings-pages-general-full` | iPhone `large`, landscape | measured 868, 2 | measured 868, 2 | measured 868, 2 |
| `settings-pages-general-cache-confirmation` | iPhone `large`, portrait | measured 939, 1 | measured 939, 1 | measured 939, 1 |
| `settings-pages-general-cache-confirmation` | iPhone `large`, landscape | measured 884, 1 | measured 884, 1 | measured 884, 1 |
| `home-loading` | iPhone `large`, portrait | error `settle-timeout:animation:UIImageView:contents`, 0 | measured 941, 1 | measured 941, 1 |
| `home-loading` | iPhone `large`, landscape | error `settle-timeout:animation:UIImageView:contents`, 0 | measured 903, 1 | measured 903, 1 |

Under the two stages the three keyboard states leave `error` and `did-not-converge`: each is `cannot-cover` with reason
`cannot-cover:keyboard` at its first hosting, in 0 steps, at all 12 lines (3 states x 2 orientations x 2 themes).
`home-loading` measures (941 pt portrait, 903 pt landscape, 1 step) because its `still:` step runs at screen size.
`settings-pages-general-full` and `settings-pages-general-cache-confirmation` measure the same as before. The other
keyboard states: `comments-post-empty` and `comments-posting-warning` are `cannot-cover:keyboard` (1603 pt portrait,
1038 pt landscape, 0 steps); `quick-search-word-editor` is not a keyboard state (finding above); `settings-login-filled`
is `measured` (912 pt portrait, 420 pt landscape, 0 steps), so the rule's condition 2 did not hold for it and it is
recorded as it came.

### The nine probes under the two stages

| # | probe | 19-20 | under the two stages |
| --- | --- | --- | --- |
| 1 | `HomeSnapshotTests/testHomePopulated`, iPhone `en-large` | taller, coverable: 1755 pt portrait, 1725 pt landscape, 1 step | the same: 1755 pt, 1725 pt, 1 step each, light = dark |
| 2 | `CommentsSnapshotTests/testPostFilled`, iPhone `en-large` | cannot cover: keyboard; `error` under 19-19's order, `did-not-converge` under order B | `cannot-cover:keyboard`, need 1603 pt portrait and 1038 pt landscape, 0 steps |
| 3 | `SearchSnapshotTests/testTypingSuggestions`, iPhone `en-large` | `did-not-converge`, 3980 pt portrait, 6049 pt landscape | `cannot-cover:keyboard`, need 1148 pt and 853 pt, 0 steps |
| 4 | `ReaderSnapshotTests/testVertical`, iPhone `en-large` | measured 4672 pt portrait, 10214 pt landscape | the same: 4672 pt light and 4666 pt dark portrait, 10214 pt light and 10201 pt dark landscape, 1 step |
| 5 | `AppWideSnapshotTests/testAppAlert`, iPhone `en-large` | `error` under 19-19's order, `did-not-converge` under order B | `cannot-cover:keyboard`, need 995 pt portrait and 749 pt landscape, 0 steps |
| 6 | `SettingsPagesSnapshotTests/testGeneralCacheConfirmation`, iPhone `en-large` | taller, coverable: 939 pt portrait, 884 pt landscape, 1 step | the same need; the landscape popover loses its anchor (see `Popover proof` below) |
| 7 | `AppWideSnapshotTests/testErrorInfo`, iPad `en-accessibility5` portrait | cannot cover: the form sheet's collection view does not grow (1930 pt, 1 step) | the same: `cannot-cover:UpdateCoalescingCollectionView`, 1930 pt, 1 step |
| 8 | `DownloadsSnapshotTests/testInspector`, iPad `en-accessibility5` portrait | cannot cover (4357 pt, 3 steps) | the same: `cannot-cover:UpdateCoalescingCollectionView`, 4357 pt, 3 steps |
| 9 | `HomeSnapshotTests/testHomePopulated`, iPad `en-large` portrait | taller, coverable: 1858 pt, 1 step | the same: 1858 pt, 1 step, light = dark |

### The 17 stillness states

Status, need in pt and steps of the 17 states whose `still:` step now runs at screen size (`$W/measure-phone`, iPhone
`en-large`; light and dark listed where they differ). The reader lines with `error` are the four findings above.

| state | portrait | landscape |
| --- | --- | --- |
| `home-loading` | measured 941, 1 | measured 903, 1 |
| `front-page-loading` | measured 912, 0 | measured 420, 0 |
| `popular-loading` | measured 912, 0 | measured 420, 0 |
| `gallery-detail-loading` | measured 912, 0 | measured 562, 1 |
| `detail-pages-previews-loading` | measured 1748, 1 | measured 2805, 1 |
| `reader-loading` | light: measured 4736, 1; dark: measured 4733, 1 | measured 10424, 1 |
| `reader-controls` | light: error, 0, `settle-timeout:pixels:3,803,417x86`; dark: measured 4666, 1 | light: error 10230, 1, `settle-timeout:pixels:0,307,912x113`; dark: measured 10214, 1 |
| `reader-slider-scrub` | light: error 4672, 1, `settle-timeout:pixels:405,810,15x79`; dark: measured 4672, 1 | light: measured 10230, 1; dark: error 10230, 1, `settle-timeout:pixels:0,310,912x110` |
| `report-form-loading` | measured 1664, 3 | measured 1203, 3 |
| `report-form-sending` | measured 1664, 3 | measured 1203, 3 |
| `comments-post-empty` | cannot-cover 1603, 0, `cannot-cover:keyboard` | cannot-cover 1038, 0, `cannot-cover:keyboard` |
| `comments-post-filled` | cannot-cover 1603, 0, `cannot-cover:keyboard` | cannot-cover 1038, 0, `cannot-cover:keyboard` |
| `comments-posting-warning` | cannot-cover 1603, 0, `cannot-cover:keyboard` | cannot-cover 1038, 0, `cannot-cover:keyboard` |
| `settings-pages-laboratory` | measured 912, 0 | measured 420, 0 |
| `quick-search-word-editor` | did-not-converge 1328, 12 | did-not-converge 1093, 12 |
| `settings-login-filled` | measured 912, 0 | measured 420, 0 |
| `app-wide-app-alert` | cannot-cover 995, 0, `cannot-cover:keyboard` | cannot-cover 749, 0, `cannot-cover:keyboard` |

Table 2 of 19-20 is not re-run: it needed instrumentation that 19-20 removed, and the pictures of step 3 show what it
measured.

### Table B: pictures at one-off heights (iPhone `en-large`, `$W/cand-general`)

The one-off `.committed` heights are the step-1 needs (the larger of light and dark): general-full 912 pt portrait and
868 pt landscape, cache-confirmation 939 pt and 884 pt; every other value the device height. All eight pictures were
recorded (`passed=0 recorded=8`), opened and read.

| picture | size | top of the picture | where the popover's arrow points |
| --- | --- | --- | --- |
| `general-full`, portrait, light and dark | 420 x 912 | back button, "General" title, Language row | no popover |
| `general-full`, landscape, light and dark | 912 x 868 | back button, "General" title, Language row; the whole page down to the footer text | no popover |
| `cache-confirmation`, portrait, light and dark | 420 x 939 | back button, "General" title, Language row | at "Clear Image Cache" |
| `cache-confirmation`, landscape, light and dark | 912 x 884 | back button, "General" title, Language row | nowhere: no arrow; the popover sits at the upper left (x 100 to 340, y 400 to 523) over the Navigation rows, "Clear Image Cache" is at y 631, with some blur at the popover's left edge |

Restore: `GeneralSettingViewSnapshot.swift` restored with `git checkout --`; the whole-directory gate
(`git diff --quiet -- AppPackage/Tests/VisualSnapshotTests/Snapshots && python3 Scripts/visual/snapshot_heights.py check-sources`)
exited 0 ("138 states, heights read back").

## Dialogs presented on hosting

Six states present their dialog in `make` (no step presents it), so the two stages do not move them. Their scenario IDs
(as the provider files spell them in `id: "..."`) and classes:

| scenario ID | provider file | class |
| --- | --- | --- |
| `settings-account-logout-confirmation` | `AccountSettingViewSnapshot.swift` | `SettingsSnapshotTests/testAccountLogoutConfirmation` |
| `quick-search-delete-confirmation` | `QuickSearchViewSnapshot.swift` | `QuickSearchSnapshotTests/testDeleteConfirmation` |
| `gallery-detail-delete-download-confirmation` | `DetailViewSnapshot.swift` | `GalleryDetailSnapshotTests/testDeleteDownloadConfirmation` |
| `gallery-detail-retry-confirmation` | `DetailViewSnapshot.swift` | `GalleryDetailSnapshotTests/testRetryConfirmation` |
| `detail-pages-folder-delete-confirmation` | `FolderManagerViewSnapshot.swift` | `DetailPagesMoreSnapshotTests/testFolderDeleteConfirmation` |
| `app-wide-app-alert` | `ToplistsViewSnapshot.swift` | `AppWideSnapshotTests/testAppAlert` |

Measured with `--measure-heights` at `en-large` on the iPhone (both orientations, `$W/measure-dialogs-phone`) and on the
iPad portrait (`$W/measure-dialogs-pad`); light and dark agree on every line. Every coordinate whose need is above the
device height was captured once at that need (`$W/cand-dialogs`: logout portrait 1044 pt and landscape 969 pt, the three
detail confirmations landscape 656 pt) with a one-off local `.committed` value, applied with `snapshot_heights.py apply
--only` and restored with `git checkout --`; the whole-directory restore gate exited 0 ("138 states, heights read back")
afterwards. All 10 tall pictures were opened. Their `.screen` counterparts come from a second candidate run at the
committed (screen) heights (`$W/cand-dialogs-screen`); that run flags the 10 taller coordinates `error` with
`page-height: needs N pt, committed M pt` (the check refusing the committed screen height) and still writes their
pictures, which were opened too.

| state | class | coordinate | need | one-off committed | where the dialog sits | where its arrow points |
| --- | --- | --- | --- | --- | --- | --- |
| `settings-account-logout-confirmation` | `SettingsSnapshotTests/testAccountLogoutConfirmation` | iPhone portrait | 1044 pt | 1044 pt | at the top of the page, over the first card (the dialog's left edge at x 115, y 190 to 335), the same place as in its 420 x 912 `.screen` picture | left, at the "Log Out" row |
| | | iPhone landscape | 969 pt | 969 pt | at the upper left of the first card (x 175 to 413, y 128 to 273), the same place as in its 912 x 420 `.screen` picture | left, at the "Log Out" row |
| | | iPad portrait | 1210 pt | none (the device height) | not above the device height, not captured here | |
| `quick-search-delete-confirmation` | `QuickSearchSnapshotTests/testDeleteConfirmation` | iPhone portrait, landscape; iPad portrait | `did-not-converge` (1328 pt, 1093 pt, 1626 pt after 12 steps) | none | not captured: a recorded finding, the page does not converge | |
| `gallery-detail-delete-download-confirmation` | `GalleryDetailSnapshotTests/testDeleteDownloadConfirmation` | iPhone portrait | 912 pt | none (the device height) | not above the device height | |
| | | iPhone landscape | 656 pt | 656 pt | centred in the 656 pt window (x 296 to 616, y 232 to 404, an alert-style card with Cancel and Delete) over the page's metrics row, with the description text ghosted over the row beneath it; in the `.screen` picture (420 pt) it is centred on the screen (y 115 to 285), over the title and the rating row | none (a centred alert card has no arrow) |
| | | iPad portrait | 1210 pt | none (the device height) | not above the device height | |
| `gallery-detail-retry-confirmation` | `GalleryDetailSnapshotTests/testRetryConfirmation` | iPhone portrait | 912 pt | none (the device height) | not above the device height | |
| | | iPhone landscape | 656 pt | 656 pt | the same as the delete-download card ("Redownload Gallery?", Cancel and Redownload): centred in the 656 pt window (y 232 to 404) over the metrics row with ghosted description text; centred on the screen (y 115 to 285) in the `.screen` picture | none |
| | | iPad portrait | 1210 pt | none (the device height) | not above the device height | |
| `detail-pages-folder-delete-confirmation` | `DetailPagesMoreSnapshotTests/testFolderDeleteConfirmation` | iPhone portrait | 912 pt | none (the device height) | not above the device height | |
| | | iPhone landscape | 656 pt | 656 pt | a popover at the top of the page (x 336 to 576, y 10 to 200), over the folder list's first rows, the same place as in the 912 x 420 `.screen` picture | down, at the top of the folder list below the navigation bar's title area, centred at x 456 |
| | | iPad portrait | 1210 pt | none (the device height) | not above the device height | |
| `app-wide-app-alert` | `AppWideSnapshotTests/testAppAlert` | iPhone portrait, landscape | `cannot-cover:keyboard` (995 pt, 749 pt, 0 steps) | none | not captured: a keyboard state, the page cannot be covered | |
| | | iPad portrait | `error` | none | not captured: the keyboard step fails at base on the iPad (`interaction:no-keyboard:announced-hidden`, 30 s wait) | |

What the pictures show: the two popovers anchored to a control (logout and folder delete) sit where their `.screen`
pictures show, with their arrows on the same controls, so a taller window does not move them (their anchors are near the
top of a page that is not scrolled). The two alert-style cards (delete-download and retry) are centred in whatever window
they are presented in, so on a 656 pt window they sit lower on the page than in the 420 pt `.screen` picture, over
different content. Pixels differ slightly between the tall and `.screen` runs of the same state (glass and antialiasing);
no layout difference was found by inspection other than the cards' centring.

## Popover proof

The cache confirmation (`settings-pages-general-cache-confirmation`, `SettingsPagesSnapshotTests/testGeneralCacheConfirmation`),
iPhone `en-large`, landscape, at its one-off height of 884 pt (912 x 884 px pictures; `$W/cand-general`):

- light: no. The popover sits at the upper left (x 100 to 340, y 400 to 523, in the picture's points) over the Navigation rows with no arrow; "Clear Image Cache" is at y 631, so the popover is not on its control. There is some blur at the popover's left edge.
- dark: no. The same: the popover at the upper left over the Navigation rows with no arrow toward "Clear Image Cache", with the same blur at its left edge.

In portrait (420 x 939) the popover's arrow points at "Clear Image Cache" in light and dark. The landscape pictures equal
the one 19-20 Table 3 recorded under order B ("the popover loses its anchor").

Cause (the orchestrator's diagnosis of 2026-11-23, replacing the earlier reading that `make` presents the dialog; its
instrumentation was uncommitted and restored by checksum afterwards, its logs are `$W/popdiag.lines` (the 939 pt and
884 pt runs) and `$W/popdiag-screen.lines` (the control at the `.screen` height)): the dialog is opened by the state's
operating step after the growth (the held tap `RevealStep.reveal` performs; `general(level:action:)` passes its action as
`tap:`). In all three runs the presented controller is a `PlatformAlertController` in popover style
(`modalPresentationStyle` 7), not adapted (adaptive style 2), with `permittedArrowDirections` 15. The readings:

| run | window | screen and scene bounds | source rect (window coordinates) | arrow | popover frame |
| --- | --- | --- | --- | --- | --- |
| portrait, 939 pt | 420 x 939 | 420 x 912 | y 629.7 to 650, x 40 to 380: inside the screen | 2 (down), centred on the source | (90, 492.3, 240 x 124.3) |
| landscape, 884 pt | 912 x 884 | 912 x 420 | y 620.7 to 641, x 100 to 812: below the screen | 0 (none) | (100, 399.7, 240 x 124.3), not centred |
| landscape at the `.screen` height, 420 pt | 912 x 420 | 912 x 420 | y 156.7 to 177, x 100 to 812: inside the screen | 2 (down), centred on the source | (336, 19.3, 240 x 124.3) |

The scene's `coordinateSpace` and `effectiveGeometry` bounds stay at the screen's size (420 x 912 in portrait, 912 x 420
in landscape) while the window is taller, so UIKit places an arrowed popover only within the screen's bounds: a platform
constraint the harness cannot remove. Same state, same popover, same presenter: only the source row's position relative
to the screen differs. Orchestrator decisions: recorded as found (`no` in both themes), the provider is not changed, and
Task 5 re-runs this proof.
