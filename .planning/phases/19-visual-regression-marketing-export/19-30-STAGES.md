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

(Task 4.)

## Dialogs presented on hosting

(Task 4.)

## Popover proof

(Task 4.)
