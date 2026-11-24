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
| `app-wide-app-alert` | ToplistsViewSnapshot | none | `RevealStep.reveal(…); SettingsScenarios.holdAlertCaret` |
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
| `quick-search-delete-confirmation` | QuickSearchViewSnapshot | none | `RevealStep.reveal(…)` |
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
| `gallery-detail-delete-download-confirmation` | DetailViewSnapshot | none | `RevealStep.reveal(…)` |
| `gallery-detail-retry-confirmation` | DetailViewSnapshot | none | `RevealStep.reveal(…)` |
| `gallery-detail-sheet` | GallerySheetViewSnapshot | none | none |
| `settings-root` | SettingViewSnapshot | none | none |
| `comments-list` | CommentsViewSnapshot | none | none |
| `comments-menu` | CommentsViewSnapshot | none | `GalleryScenarios.openFirstRowMenu` |
| `comments-block-confirmation` | CommentsViewSnapshot | none | `TracerScenarios.chooseBlock` |
| `comments-blocked-row-collapsed` | CommentsViewSnapshot | none | none |
| `comments-blocked-row-shown` | CommentsViewSnapshot | none | none |
| `comments-post-empty` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | none |
| `comments-post-filled` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | none |
| `comments-posting-warning` | PostCommentViewSnapshot | `GalleryScenarios.holdStillOverKeyboard` | `RevealStep.reveal(…); awaitDialogPlatter; waitForRest; stopCaretBlink; holdStill` |
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
| `detail-pages-folder-delete-confirmation` | FolderManagerViewSnapshot | none | `RevealStep.reveal(…)` |
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
| `settings-account-logout-confirmation` | AccountSettingViewSnapshot | none | `RevealStep.reveal(…); RevealStep.awaitDialogPlatter()` |
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

Counts: 16 states with a `still` step, 50 with an `interact` step, 72 with no step; one state has both,
`comments-posting-warning` (Task 3 counted 17, 44 and 77; Task 5 converted seven dialog states, so `app-wide-app-alert`
left `still:` and six states gained an `interact:`; `comments-posting-warning` keeps its `still:` and gains an
`interact:`, see below). The plan's count gate expected `still` 16 and no state with both; the orchestrator's ruling of
2026-11-23 on the posting warning (see below) makes the literal numbers `still:` 16, `interact:` 36 and one state with
both, the gate changing by exactly this one state.

Mixed closures: none. No state combines a stillness helper with an operating one. Seven operating helpers end with a
hold of what their own action brought up, and stay whole in the operating stage, in their order:
`BrowsingScenarios.focusSearchFieldOnceSettled` (freezes after the focus), `LibraryScenarios.type` (solid caret and freeze
after the typing), `SettingsScenarios.openRunsMenu` and `LibraryScenarios.openCategoryMenu` (menu scroll indicators hidden
after opening), `LibraryScenarios.tapHeldRow` and the two inline clear steps of `history-clear-confirmation` and
`search-clear-confirmation` (the platter wait after the tap), `GalleryScenarios.presentHeldReportFailure` (the rest wait
after the alert), and `restingAtTop()` (the clear button wait after the pull).

Dialogs (Task 5, owner decision 2026-11-23, 「改成拉高後由步驟點開」): no state is built with a dialog, confirmation,
popover, menu or alert open. The dialogs of `settings-account-logout-confirmation`, `quick-search-delete-confirmation`,
`gallery-detail-delete-download-confirmation`, `gallery-detail-retry-confirmation`,
`detail-pages-folder-delete-confirmation`, `app-wide-app-alert` and `comments-posting-warning` are opened by the state's
operating step after the window grows, through the held tap (`RevealStep.tap`, performed by `RevealStep.reveal`), as the
four held-tap confirmations already were. The stated exception to keeping every stillness step in `still:`: the hold of what the opening brought up,
`SettingsScenarios.holdAlertCaret` (app alert), runs in that operating step right after the tap, because there is nothing
to hold before the dialog opens. The posting warning's step is ordered as the user acts (orchestrator decision
2026-11-23): its stillness step is the one it always had, `GalleryScenarios.holdStillOverKeyboard`, which waits for the
editor to be focused and the keyboard up and at rest, stops the caret and freezes, before the window grows (an earlier
form waited in the operating step; the measuring mode and a capture at a committed height above native then timed
out in the growth's settle on the blinking caret, see the posting-warning record below); then the operating step's
`RevealStep.reveal` taps Post, and the warning is waited for and held still (`awaitDialogPlatter`, `waitForRest`,
`stopCaretBlink`, `holdStill`). The warning takes the focus and the keyboard goes down behind it, so the state is no
keyboard state: its page-height lines carry no
`cannot-cover:keyboard` suffix, and the owner's B1 decision of 2026-11-22 (19-13-PRECHECK, keep as is, the system
keyboard is a separate window) was given on the keyboard picture for this one state.

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
- accepted: `gallery-detail-delete-download-confirmation__ja__accessibility5__landscape__iphone__light`: the control that opens the alert was below the fold; the step scrolls to it as a user must before tapping (orchestrator, 2026-11-23, second run identical)
- accepted: `gallery-detail-delete-download-confirmation__ja__accessibility5__landscape__iphone__dark`: the control that opens the alert was below the fold; the step scrolls to it as a user must before tapping (orchestrator, 2026-11-23, second run identical)
- accepted: `gallery-detail-retry-confirmation__ja__accessibility5__landscape__iphone__light`: the control that opens the alert was below the fold; the step scrolls to it as a user must before tapping (orchestrator, 2026-11-23, second run identical)
- accepted: `gallery-detail-retry-confirmation__ja__accessibility5__landscape__iphone__dark`: the control that opens the alert was below the fold; the step scrolls to it as a user must before tapping (orchestrator, 2026-11-23, second run identical)
- accepted: `comments-posting-warning__en__large__portrait__iphone__light`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__en__large__portrait__iphone__dark`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__en__large__landscape__iphone__light`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__en__large__landscape__iphone__dark`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__ja__accessibility5__portrait__iphone__light`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__ja__accessibility5__portrait__iphone__dark`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__ja__accessibility5__landscape__iphone__light`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `comments-posting-warning__ja__accessibility5__landscape__iphone__dark`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down (orchestrator, 2026-11-23, two runs identical)
- accepted: `quick-search-delete-confirmation__ja__accessibility5__landscape__iphone__light`: after the step fix `08fe18cad` (the element search starts at the front-most presentation) the step scrolls the sheet's own list to the saved-search row, which the fold cut before and is now fully in view; the popover not pointing at it is C7 (19-24) (orchestrator, 2026-11-24, both pictures opened; `$W/rv-before-phone` against `$W/rv-after-phone`: 174,820 and 181,128 differing pixels; `$W/rv-after-phone-v1` and `$W/rv-after-phone` pixel-identical)
- accepted: `quick-search-delete-confirmation__ja__accessibility5__landscape__iphone__dark`: after the step fix `08fe18cad` (the element search starts at the front-most presentation) the step scrolls the sheet's own list to the saved-search row, which the fold cut before and is now fully in view; the popover not pointing at it is C7 (19-24) (orchestrator, 2026-11-24, both pictures opened; `$W/rv-before-phone` against `$W/rv-after-phone`: 174,820 and 181,128 differing pixels; `$W/rv-after-phone-v1` and `$W/rv-after-phone` pixel-identical)
- accepted: `comments-posting-warning__en__large__portrait__ipad__light`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down; the same ruling as the eight iPhone keys (orchestrator, 2026-11-24, light opened before and after; `$W/final-dialog-pad` equal to `$W/fix-dialog-pad`)
- accepted: `comments-posting-warning__en__large__portrait__ipad__dark`: the editor is focused and the keyboard up before Post is tapped, as a user acts; the warning takes the focus and the keyboard goes down; the same ruling as the eight iPhone keys (orchestrator, 2026-11-24, light opened before and after; `$W/final-dialog-pad` equal to `$W/fix-dialog-pad`)
- accepted: `gallery-detail-rating__en__large__landscape__iphone__light`: the old baselines drew the page signed out after a step (Rate Gallery and Post Comment disabled) and the fix draws it signed in, as the portrait pictures were before and after: a HEAD defect the logout fix corrects, the same mechanism proven by the logout subsection (orchestrator, 2026-11-24; `$W/pre-didlogin-phone` against `$W/fix-didlogin-phone`: 14,775 and 9,565 differing pixels; of the 192 compared keys (196 lines, 4 `notApplicable`) 186 are pixel-identical, 4 of them the logout keys, and 6 differ: these two and the four `en` `large` posting-warning keys accepted above)
- accepted: `gallery-detail-rating__en__large__landscape__iphone__dark`: the old baselines drew the page signed out after a step (Rate Gallery and Post Comment disabled) and the fix draws it signed in, as the portrait pictures were before and after: a HEAD defect the logout fix corrects, the same mechanism proven by the logout subsection (orchestrator, 2026-11-24; `$W/pre-didlogin-phone` against `$W/fix-didlogin-phone`: 14,775 and 9,565 differing pixels; of the 192 compared keys (196 lines, 4 `notApplicable`) 186 are pixel-identical, 4 of them the logout keys, and 6 differ: these two and the four `en` `large` posting-warning keys accepted above)

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
1038 pt landscape, 0 steps; Task 5 reordered the posting warning's step, which is no keyboard state any more, see
`## Dialogs opened after growth`); `quick-search-word-editor` is not a keyboard state (finding above); `settings-login-filled`
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

## Dialog inventory

Every state that shows a dialog, confirmation dialog, popover, menu, alert or toast, read from the provider files and
the builders and helpers they call (Task 5, step 1). `presented by`: `make` (an action sent or a state set while
building), `held tap` (held by `RevealStep.tap` and performed by `RevealStep.reveal` after the growth) or `step`.

| state | class | presented by | mechanism | control that opens it | directly tappable | conversion |
| --- | --- | --- | --- | --- | --- | --- |
| `settings-account-logout-confirmation` | `SettingsSnapshotTests/testAccountLogoutConfirmation` | make | `account(confirmingLogout: true)` appends `.account(.logoutButtonTapped)` to the actions `settings(_:actions:tap:)` sends while building; the confirmation is a popover from the row | the Log Out row (`logoutDialogAction`) | yes | converted |
| `quick-search-delete-confirmation` | `QuickSearchSnapshotTests/testDeleteConfirmation` | make | `quickSearch(.deleteConfirmation)` sends `.deleteSavedSearchButtonTapped(first)` while building | the saved search row's trailing swipe action Delete | no (a swipe action) | converted (held tap after revealing the row, orchestrator answer 2026-11-23) |
| `gallery-detail-delete-download-confirmation` | `GalleryDetailSnapshotTests/testDeleteDownloadConfirmation` | make | `detail(.deleteDownloadConfirmation)` sends `.deleteDownloadButtonTapped` while building; the confirmation is the reducer's alert | the download button (`handleDownloadAction`, status completed) | yes | converted |
| `gallery-detail-retry-confirmation` | `GalleryDetailSnapshotTests/testRetryConfirmation` | make | `detail(.retryConfirmation)` sends `.retryDownloadButtonTapped(.redownload)` while building; the confirmation is the reducer's alert | the download button (`handleDownloadAction`, status error) | yes | converted |
| `detail-pages-folder-delete-confirmation` | `DetailPagesMoreSnapshotTests/testFolderDeleteConfirmation` | make | `folderManager(confirmingDelete: true)` passes `.folderManager(.deleteButtonTapped(folder))` to `detailPage(presenting:then:)`, which sends it while building | the folder row's trailing swipe action Delete | no (a swipe action) | converted (held tap after revealing the row, orchestrator answer 2026-11-23) |
| `app-wide-app-alert` | `AppWideSnapshotTests/testAppAlert` | make | `jumpPageAlert()` sends `.presentJumpPageAlert` while building | the toolbar's `JumpPageButton` (Jump Page) | yes | converted |
| `comments-posting-warning` | `CommentsSnapshotTests/testPostingWarning` | make | `comments(.postingWarning)` sends `.postTapped` over the filtered draft while building; the reducer presents the posting warning, an `appAlert` over the Post Comment sheet | the sheet's Post (confirm) toolbar button | yes | converted (a ninth `make` row, found by this inventory; orchestrator decision 2026-11-23) |
| `app-wide-toast-success` | `AppWideSnapshotTests/testToastSuccess` | make | `app(.successToast)` sets `presentationState.toast` | none (no control on the page opens it) | no | not converted: toast (no control) |
| `app-wide-toast-failure` | `AppWideSnapshotTests/testToastFailure` | make | `app(.failureToast)` sets `presentationState.toast` | none (no control on the page opens it) | no | not converted: toast (no control) |
| `settings-pages-general-cache-confirmation` | `SettingsPagesSnapshotTests/testGeneralCacheConfirmation` | held tap | `general(level:action:)` passes the action as `tap:`; `RevealStep.reveal(…, holdingPlacement: true)` performs it after the growth | the Clear Image Cache row | yes | none (held tap) |
| `settings-pages-general-translations-confirmation` | `SettingsPagesSnapshotTests/testGeneralTranslationsConfirmation` | held tap | `general(level:action:)` passes the action as `tap:`; `RevealStep.reveal` performs it | the Remove Custom Translations row | yes | none (held tap) |
| `settings-pages-site-settings-confirmation` | `SettingsPagesMoreSnapshotTests/testSiteSettingsConfirmation` | held tap | `siteSettings(.deleteConfirmation)` passes `.ehSetting(.deleteProfileButtonTapped)` as `tap:`; `RevealStep.reveal` performs it | the profile's Delete control | yes | none (held tap) |
| `quick-search-filters-reset-confirmation` | `QuickSearchSnapshotTests/testFiltersResetConfirmation` | held tap | `filters(confirmingReset: true)` holds `.resetFiltersButtonTapped` with `RevealStep.tap`; `RevealStep.reveal` performs it | the Reset Filters row | yes | none (held tap) |
| `settings-pages-activity-logs-run-picker` | `SettingsPagesSnapshotTests/testActivityLogsRunPicker` | step | `SettingsScenarios.openRunsMenu` opens the Runs menu | the Runs menu in the bar | yes | none (step) |
| `comments-menu` | `CommentsSnapshotTests/testMenu` | step | `GalleryScenarios.openFirstRowMenu` opens the first comment's moderation menu | the first comment's `…` menu button | yes | none (step) |
| `toplists-period-menu` | `ToplistsSnapshotTests/testPeriodMenu` | step | `BrowsingScenarios.activate` of the time range control | the time range menu | yes | none (step) |
| `shell-library-title-menu` | `ShellSnapshotTests/testLibraryTitleMenu` | step | `restingAtTop(BrowsingScenarios.activate)` of the Library title | the Library title menu | yes | none (step) |
| `favorites-category-menu` | `FavoritesSnapshotTests/testCategoryMenu` | step | `restingAtTop(LibraryScenarios.openCategoryMenu)` | the overflow menu | yes | none (step) |
| `comments-block-confirmation` | `CommentsSnapshotTests/testBlockConfirmation` | step | `TracerScenarios.chooseBlock` runs the row's Block accessibility action | the first comment row's Block action | yes | none (step) |
| `history-clear-confirmation` | `HistorySnapshotTests/testClearConfirmation` | step | inline step: `BrowsingScenarios.activate` of Clear, then `RevealStep.awaitDialogPlatter()` | the Clear button | yes | none (step) |
| `search-clear-confirmation` | `SearchSnapshotTests/testClearConfirmation` | step | inline step: `BrowsingScenarios.activate` of Remove All, then `RevealStep.awaitDialogPlatter()` | the Remove All button | yes | none (step) |
| `report-form-error-alert` | `ReportFormSnapshotTests/testErrorAlert` | step | `GalleryScenarios.presentHeldReportFailure` sends the held Send tap, then waits for the alert | the report sheet's Send button | yes | none (step) |
| `downloads-delete-confirmation` | `DownloadsSnapshotTests/testDeleteConfirmation` | step | `restingAtTop(LibraryScenarios.tapHeldRow)` taps the held row Delete | the row's Delete button | yes | none (step) |
| `downloads-move-confirmation` | `DownloadsSnapshotTests/testMoveConfirmation` | step | `restingAtTop(LibraryScenarios.tapHeldRow)` taps the held row Move | the row's Move button | yes | none (step) |

The plan named eight `make` rows; the inventory found a ninth, `comments-posting-warning`, an alert over the Post Comment
sheet that `make` opens through `.postTapped`. Orchestrator decision 2026-11-23: it is converted like the others (the
owner's 「還是照做，規則一致」), so seven rows are `converted`.

Sheets `make` presents, outside the owner's decision and not converted: Error Info (`app-wide-error-info`), Post Comment
(`comments-post-empty`, `comments-post-filled`), Report Form (the `report-form-*` states), Quick Search
(`quick-search-list`, `quick-search-empty`, `quick-search-word-editor`), Filters (`quick-search-filters`), Date Seek
(`quick-search-date-seek`), Reading Settings (`reader-settings-sheet`) and the gallery page's own sheets
(`gallery-detail-sheet`, `detail-pages-*`); the Downloads inspectors (`downloads-inspector`,
`downloads-inspector-error`) are sheets opened by the held row tap of their step.

## Dialogs opened after growth

RED, before the classification (Task 5 step 3): `CaptureStageTests` with the injected `popoverSource` and the stub
`presentedPopoverSource(in:) -> nil`, `popoverSource` only declared on `CaptureHeight` and `measure`, never read. 10 of 12
cases passed (the 8 earlier ones, and the new `testAPopoverWhoseSourceLiesInsideTheSceneIsNoReason` and
`testAnAlertStylePresentationIsNotReadAsAPopover`, which are no-ops before the rule). Two failed:
- `testAPopoverWhoseSourceLiesBelowTheSceneCannotBeCovered`: the capture at 1512 pt was `recorded`, not `error`, with no
  reason (expected `page-height: needs 1512 pt, committed 1512 pt, cannot-cover:popover`); the measuring mode returned
  `measured`, not `cannotCover`, and reason nil, not `cannot-cover:popover`; and its last assertion, a test fault, expected
  the page's need at the window's own height as 1312 pt (912 + 400) where the check reads 1414 pt (the page's insets);
  the test now compares that capture with and without the popover source instead of assuming the number.
- `testAPopoverThatIsNotAdaptedIsReadWithItsSourceInWindowCoordinates`: `XCTUnwrap failed: expected non-nil value of type
  "CGRect"` (the stub).

### Identity at `.screen`, the dialog table and the findings (Task 5 steps 6 and 8)

Step 6, judged by SHA-256 and by decoded pixels against `$W/dialog-before-phone` and `-pad` (runs `fix-dialog-phone-1`, `fix-dialog-phone-2`, `fix-dialog-pad`, after the logout fix; every error is a `page-height` error with a picture, the stated expectation, except the iPad app alert):
- iPhone `fix-dialog-phone-2` against the before-sample: 42 keys pixel-identical, 14 differing: the 8 `comments-posting-warning` keys (the ordered form, accepted below; the stillness step is unchanged and the pictures are identical to the ordered form's first pictures), the 4 `ja` `accessibility5` landscape keys of delete-download and retry (accepted above), and the 2 `quick-search-delete-confirmation` `ja` `accessibility5` portrait keys (a step defect, not accepted: after the step fix `08fe18cad` both equal the before-sample pixel for pixel; see the front-presentation subsection). `fix-dialog-phone-1` differs from the before-sample in the same 14 keys and also in `app-wide-app-alert` `en` `large` landscape (see the app alert open item: a squeezed layout, taken first, on the loaded host); `fix-dialog-phone-1` against `-2`: 54 identical, 2 differing (those two).
- iPad `fix-dialog-pad` against the before-sample: 10 keys pixel-identical, 2 differing: `comments-posting-warning__en__large__portrait__ipad__light` and `__dark` (511,098 and 656,164 differing pixels): before, an `error` `page-height: needs 1419 pt, committed 1210 pt, cannot-cover:keyboard` with the keyboard up and the warning open at make; now `recorded` at 1210 pt, no keyboard (the warning takes the focus). Accepted above (orchestrator, 2026-11-24: the same ruling as the eight iPhone keys).
- the iPad app alert pair keeps `error` and `interaction:no-keyboard`, with the reason changed (see the app alert open item).
- two further iPhone keys are byte-different in all three iPhone runs and in the final-tree run `final-dialog-phone`, with identical decoded 8-bit pixels (0 differing pixels): `quick-search-delete-confirmation__en__large__landscape__iphone__dark` and `quick-search-delete-confirmation__ja__accessibility5__landscape__iphone__dark`. Evidence, not an acceptance: the runner's compare mode against exactly the before-sample's eight pictures of the state (`$W/refs-qs2`, new sources, D-10 unchanged, `$W/cmp-qs2`) wrote a `difference` picture only for the two `ja` `accessibility5` portrait keys (the accepted ones) and none for these two; so the captures differ below the 8-bit read and within D-10. Orchestrator, 2026-11-24: nothing to accept, the pixels are identical; recorded as encoded bytes differ, pixels identical (19-27: encoded vs decoded bytes). After the step fix `08fe18cad` the `ja` `accessibility5` landscape dark key differs in pixels as well (the sheet's own list scrolled to the row, accepted above); the `en` `large` landscape dark key stays byte-different and pixel-identical.
- final tree (`$W/final-dialog-phone`, `$W/final-dialog-pad`, taken after the last source change and after the clean run `clean9`): iPhone 42 keys identical and 14 differing, the same 14 keys as above (plus the two byte-different ones counted inside the 42), identical to `fix-dialog-phone-2` in all 56 pictures; iPad 10 identical and 2 differing (the posting-warning pair); the iPad app alert pair `error` with `interaction:no-keyboard:never-announced`.

The table: one row per state and coordinate whose measured need is above the device height (every other coordinate fits the screen: the dialog is at its `.screen` place), captured once at a one-off committed height equal to the measured need (`$W/oneoff-dialogs-5.json`, `$W/cand-dialogs-5`, `$W/cand-dialogs-pad-5`; the 17 provider files were restored byte for byte (restore rc 0, `check-sources` rc 0, `GeneralSettingViewSnapshot.swift` equal to HEAD). Every one-off capture of a page whose need follows the window ends `page-height: needs N+32 pt, committed N pt` or similar: the check measures again at the taller height (the table's `need` cell is the measuring mode's line). A `timeout` is not in the table (posting warning, see below). `against .screen` is only given for the states Task 5 converted (step 6 captures those); the others are not captured at `.screen` in this task.

| state | coordinate | need | one-off committed | where the dialog sits | where its arrow points | against .screen |
| --- | --- | --- | --- | --- | --- | --- |
| `app-wide-app-alert` | iphone landscape `en-large` | cannot-cover cannot-cover:keyboard, need 749 pt, 0 step(s) | 749 pt: error: page-height: needs 750 pt, committed 749 pt | an alert card (Jump to Page, a text field with its caret, Cancel and Go) in the upper part of the page, above the window centre, over the dimmed Toplists page | none (an alert card) | card sits above the window centre; with the keyboard it is the `cannot-cover:keyboard` state, so the committed height is only an evidence one-off |
| `app-wide-app-alert` | iphone portrait `en-large` | cannot-cover cannot-cover:keyboard, need 995 pt, 0 step(s) | 995 pt: error: page-height: needs 996 pt, committed 995 pt | an alert card (Jump to Page, a text field with its caret, Cancel and Go) in the upper part of the page, above the window centre, over the dimmed Toplists page | none (an alert card) | card sits above the window centre; with the keyboard it is the `cannot-cover:keyboard` state, so the committed height is only an evidence one-off |
| `comments-block-confirmation` | iphone landscape `en-large` | measured, need 1203 pt, 3 step(s) | 1203 pt: recorded | a centred card (Block Visual Member 1?) over the dimmed Comments page, near the middle of the grown window | none (a card) | not captured at `.screen` here (step 6 covers the converted states) |
| `comments-block-confirmation` | iphone portrait `en-large` | measured, need 1664 pt, 3 step(s) | 1664 pt: recorded | a centred card (Block Visual Member 1?) over the dimmed Comments page, near the middle of the grown window | none (a card) | not captured at `.screen` here (step 6 covers the converted states) |
| `comments-menu` | iphone landscape `en-large` | measured, need 1203 pt, 3 step(s) | 1203 pt: recorded | the moderation menu (Vote Up, Vote Down, Report, Block) at the top right under the first comment's menu button | a menu, no arrow; it opens at the first comment's menu button | not captured at `.screen` here (step 6 covers the converted states) |
| `comments-menu` | iphone portrait `en-large` | measured, need 1664 pt, 3 step(s) | 1664 pt: recorded | the moderation menu (Vote Up, Vote Down, Report, Block) at the top right under the first comment's menu button | a menu, no arrow; it opens at the first comment's menu button | not captured at `.screen` here (step 6 covers the converted states) |
| `detail-pages-folder-delete-confirmation` | iphone landscape `en-large` | cannot-cover cannot-cover:popover, need 656 pt, 1 step(s) | 656 pt: error: page-height: needs 656 pt, committed 656 pt, cannot-cover:popover | an arrowed popover at the top centre over the folder list, its arrow on the second row's top edge | points down at the list between Visual Folder A and B (the picture is arrowed although the line says `cannot-cover:popover`; the source rect was not logged) | the same placement as `.screen` (arrow at the same place); the window is 656 pt tall, the scene 420 pt |
| `downloads-delete-confirmation` | iphone landscape `en-large` | measured, need 1132 pt, 3 step(s) | 1132 pt: recorded | an arrowed popover (Delete Download? with Delete) just under the first download row | points up at the first row (the held row's control) | not captured at `.screen` here (step 6 covers the converted states) |
| `downloads-delete-confirmation` | iphone portrait `en-large` | measured, need 1190 pt, 2 step(s) | 1190 pt: recorded | an arrowed popover (Delete Download? with Delete) just under the first download row | points up at the first row (the held row's control) | not captured at `.screen` here (step 6 covers the converted states) |
| `downloads-move-confirmation` | iphone landscape `en-large` | measured, need 1132 pt, 3 step(s) | 1132 pt: recorded | an arrowed popover (a folder list, Visual Folder B and C) just under the first download row | points up at the first row (the held row's control) | not captured at `.screen` here (step 6 covers the converted states) |
| `downloads-move-confirmation` | iphone portrait `en-large` | measured, need 1190 pt, 2 step(s) | 1190 pt: recorded | an arrowed popover (a folder list, Visual Folder B and C) just under the first download row | points up at the first row (the held row's control) | not captured at `.screen` here (step 6 covers the converted states) |
| `favorites-category-menu` | iphone landscape `en-large` | did-not-converge, need 1802 pt, 12 step(s) | 1802 pt: error: page-height: needs 1869 pt, committed 1802 pt | the categories menu (All, Favorites 0 to 9, Seek to Date) at the top right under the overflow button | a menu, no arrow; it opens at the overflow button | not captured at `.screen` here (step 6 covers the converted states) |
| `favorites-category-menu` | iphone portrait `en-large` | did-not-converge, need 1927 pt, 12 step(s) | 1927 pt: error: page-height: needs 1994 pt, committed 1927 pt | the categories menu (All, Favorites 0 to 9, Seek to Date) at the top right under the overflow button | a menu, no arrow; it opens at the overflow button | not captured at `.screen` here (step 6 covers the converted states) |
| `gallery-detail-delete-download-confirmation` | iphone landscape `en-large` | measured, need 656 pt, 1 step(s) | 656 pt: recorded | a card (Delete Download?, Cancel, Delete) centred in the 656 pt window, about y 232 to 405 | none (a card) | at `.screen` (420 pt) the card sits at about y 115 to 285: it moved down with the window centre (finding for 19-26) |
| `gallery-detail-retry-confirmation` | iphone landscape `en-large` | measured, need 656 pt, 1 step(s) | 656 pt: recorded | a card (Redownload Gallery?, Cancel, Redownload) centred in the 656 pt window, about y 232 to 405 | none (a card) | at `.screen` the card sits at about y 115 to 285: it moved down with the window centre (finding for 19-26) |
| `history-clear-confirmation` | iphone landscape `en-large` | measured, need 1130 pt, 4 step(s) | 1130 pt: recorded | a bubble (Clear your history? with Clear) at the top right under the trash button | no arrow; it hangs under the trash button | not captured at `.screen` here (step 6 covers the converted states) |
| `history-clear-confirmation` | iphone portrait `en-large` | measured, need 1240 pt, 2 step(s) | 1240 pt: recorded | a bubble (Clear your history? with Clear) at the top right under the trash button | no arrow; it hangs under the trash button | not captured at `.screen` here (step 6 covers the converted states) |
| `quick-search-delete-confirmation` | ipad portrait `en-large` | did-not-converge, need 1626 pt, 12 step(s) | 1626 pt: error: page-height: needs 1658 pt, committed 1626 pt | a popover with an arrow above the Quick Search sheet | points down at the top edge of the sheet, not at a saved-search row | not captured at `.screen` here (step 6 covers the converted states) |
| `quick-search-delete-confirmation` | iphone landscape `en-large` | cannot-cover cannot-cover:popover, need 741 pt, 1 step(s) | 741 pt: error: page-height: needs 773 pt, committed 741 pt, cannot-cover:popover | an arrowed popover at the top centre (Delete this saved search?) | points down at the first saved-search row; the picture is arrowed although the line says `cannot-cover:popover` (source rect not logged) | the same placement as `.screen` |
| `quick-search-delete-confirmation` | iphone portrait `en-large` | cannot-cover cannot-cover:popover, need 1008 pt, 2 step(s) | 1008 pt: error: page-height: needs 1040 pt, committed 1008 pt, cannot-cover:popover | a popover without an arrow, under the list over the last row (public sample) | none: not anchored on its row (`cannot-cover:popover`) | at `.screen` (912 pt) the popover is also without an arrow, a little lower; the 19-24 C7 note covers it |
| `quick-search-filters-reset-confirmation` | ipad portrait `en-large` | cannot-cover cannot-cover:UpdateCoalescingCollectionView, need 1946 pt, 1 step(s) | 1946 pt: error: page-height: needs 2314 pt, committed 1946 pt | a popover (Reset these filters to their defaults?) at the left over the category chips of the Filters sheet | points at the Reset Filters row (arrow at its upper left) | not captured at `.screen` here (step 6 covers the converted states) |
| `quick-search-filters-reset-confirmation` | iphone landscape `en-large` | did-not-converge, need 1420 pt, 12 step(s) | 1420 pt: error: page-height: needs 1452 pt, committed 1420 pt | a popover (Reset these filters to their defaults?) right of the Reset Filters row, over the chips and Advanced Settings | points left at the Reset Filters row | not captured at `.screen` here (step 6 covers the converted states) |
| `quick-search-filters-reset-confirmation` | iphone portrait `en-large` | did-not-converge, need 1601 pt, 12 step(s) | 1601 pt: error: page-height: needs 1633 pt, committed 1601 pt | a popover (Reset these filters to their defaults?) right of the Reset Filters row, over the chips and Advanced Settings | points left at the Reset Filters row | not captured at `.screen` here (step 6 covers the converted states) |
| `report-form-error-alert` | ipad portrait `en-large` | cannot-cover cannot-cover:UpdateCoalescingCollectionView, need 1432 pt, 1 step(s) | 1432 pt: error: page-height: needs 1543 pt, committed 1432 pt | an alert card (Couldn't Send Report: Retry, Open Report Page, Cancel) centred over the report sheet | none (an alert card) | not captured at `.screen` here (step 6 covers the converted states) |
| `report-form-error-alert` | iphone landscape `en-large` | measured, need 1203 pt, 3 step(s) | 1203 pt: recorded | an alert card (Couldn't Send Report: Retry, Open Report Page, Cancel) centred over the report sheet | none (an alert card) | not captured at `.screen` here (step 6 covers the converted states) |
| `report-form-error-alert` | iphone portrait `en-large` | measured, need 1664 pt, 3 step(s) | 1664 pt: recorded | an alert card (Couldn't Send Report: Retry, Open Report Page, Cancel) centred over the report sheet | none (an alert card) | not captured at `.screen` here (step 6 covers the converted states) |
| `search-clear-confirmation` | ipad portrait `en-large` | did-not-converge, need 1626 pt, 12 step(s) | 1626 pt: error: page-height: needs 1658 pt, committed 1626 pt | a popover (Remove all recent searches?) at the upper right of the Search page | points right at Remove All | not captured at `.screen` here (step 6 covers the converted states) |
| `search-clear-confirmation` | iphone landscape `en-large` | did-not-converge, need 1087 pt, 12 step(s) | 1087 pt: error: page-height: needs 1119 pt, committed 1087 pt | a popover (Remove all recent searches?) over Recent Searches, right of the search field | points right at Remove All | not captured at `.screen` here (step 6 covers the converted states) |
| `search-clear-confirmation` | iphone portrait `en-large` | did-not-converge, need 1328 pt, 12 step(s) | 1328 pt: error: page-height: needs 1360 pt, committed 1328 pt | a popover (Remove all recent searches?) over Recent Searches, right of the search field | points right at Remove All | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-account-logout-confirmation` | iphone landscape `en-large` | measured, need 969 pt, 2 step(s) | 969 pt: recorded | an arrowed popover (Are you sure you want to log out?) right of the Log Out row | points left at the Log Out row | the same place relative to the row as `.screen`; the page below it is longer |
| `settings-account-logout-confirmation` | iphone portrait `en-large` | measured, need 1044 pt, 1 step(s) | 1044 pt: recorded | an arrowed popover (Are you sure you want to log out?) right of the Log Out row | points left at the Log Out row | the same place relative to the row as `.screen`; the page below it is longer |
| `settings-pages-activity-logs-run-picker` | iphone landscape `en-large` | measured, need 526 pt, 2 step(s) | 526 pt: recorded | the Runs menu (Run 3 to Run 1, More Logs) at the top right | a menu, no arrow | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-general-cache-confirmation` | iphone landscape `en-large` | cannot-cover cannot-cover:popover, need 884 pt, 1 step(s) | 884 pt: error: page-height: needs 884 pt, committed 884 pt, cannot-cover:popover | a popover (Clear the image cache?) at the upper left over the Navigation section | none: not anchored (`cannot-cover:popover`); the row is about 110 pt below it | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-general-cache-confirmation` | iphone portrait `en-large` | measured, need 939 pt, 1 step(s) | 939 pt: recorded | an arrowed popover just above the Clear Image Cache row | points down at the Clear Image Cache row (popover proof) | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-general-translations-confirmation` | iphone landscape `en-large` | cannot-cover cannot-cover:popover, need 1092 pt, 1 step(s) | 1092 pt: error: page-height: needs 1092 pt, committed 1092 pt, cannot-cover:popover | a popover (Remove your custom translations?) at the upper left over the Tags section | none: not anchored (`cannot-cover:popover`) | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-general-translations-confirmation` | iphone portrait `en-large` | measured, need 1199 pt, 2 step(s) | 1199 pt: recorded | an arrowed popover above the Remove Custom Translations row | points down at the Remove Custom Translations row | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-site-settings-confirmation` | ipad portrait `en-large` | cannot-cover cannot-cover:TextEditorTextView, need 6103 pt, 4 step(s) | 6103 pt: error: page-height: needs 6125 pt, committed 6103 pt | a small popover (Delete this profile?) at the top of the long E-Hentai Settings page, over the Profile section (read at thumbnail scale: the page is 6103 to 7233 pt tall) | at the Delete control of the profile (thumbnail scale) | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-site-settings-confirmation` | iphone landscape `en-large` | cannot-cover cannot-cover:TextEditorTextView, need 6115 pt, 5 step(s) | 6115 pt: error: page-height: needs 6138 pt, committed 6115 pt | a small popover (Delete this profile?) at the top of the long E-Hentai Settings page, over the Profile section (read at thumbnail scale: the page is 6103 to 7233 pt tall) | at the Delete control of the profile (thumbnail scale) | not captured at `.screen` here (step 6 covers the converted states) |
| `settings-pages-site-settings-confirmation` | iphone portrait `en-large` | cannot-cover cannot-cover:TextEditorTextView, need 7233 pt, 5 step(s) | 7233 pt: error: page-height: needs 7256 pt, committed 7233 pt | a small popover (Delete this profile?) at the top of the long E-Hentai Settings page, over the Profile section (read at thumbnail scale: the page is 6103 to 7233 pt tall) | at the Delete control of the profile (thumbnail scale) | not captured at `.screen` here (step 6 covers the converted states) |
| `shell-library-title-menu` | iphone landscape `en-large` | measured, need 1132 pt, 3 step(s) | 1132 pt: recorded | the Library title menu (Favorites, Downloads) at the upper left under the title | a menu, no arrow | not captured at `.screen` here (step 6 covers the converted states) |
| `shell-library-title-menu` | iphone portrait `en-large` | measured, need 1190 pt, 2 step(s) | 1190 pt: recorded | the Library title menu (Favorites, Downloads) at the upper left under the title | a menu, no arrow | not captured at `.screen` here (step 6 covers the converted states) |
| `toplists-period-menu` | iphone landscape `en-large` | measured, need 598 pt, 1 step(s) | 598 pt: recorded | the time range menu (Yesterday, Past Month, Past Year, All-Time) at the top right | a menu, no arrow | not captured at `.screen` here (step 6 covers the converted states) |
| `comments-posting-warning` | iphone portrait `en-large` | measured 1977 pt, 3 step(s) (the earlier form ended `error` `settle-timeout:pixels:33,187,4x25` at the first growth; see the posting-warning record) | 1290 pt (the native need, not the measured 1977 pt): error: page-height: needs 1790 pt, committed 1290 pt | a card (Post this comment?, Edit, Post Anyway) centred in the grown window over the dimmed Post Comment sheet, which follows the window (its page grows with it: 1290, 1790, 1977 pt) | none (an alert card) | at `.screen` (912 pt) the card sits at about y 388 to 558; at 1290 pt about y 575 to 750: it moved down with the window centre (finding for 19-26) |
| `comments-posting-warning` | iphone landscape `en-large` | measured 1407 pt, 3 step(s) | 834 pt (the native need): error: page-height: needs 1284 pt, committed 834 pt | a card (Post this comment?, Edit, Post Anyway) centred in the grown window, about y 322 to 492 of 834 | none (an alert card) | at `.screen` (420 pt) the card sits at about y 115 to 285: it moved down with the window centre (finding for 19-26) |

`cannot-cover:popover` states, a finding for 19-26, which decides those pages one by one (owner decision 「標出來，19-26 逐頁決定」):
- `settings-pages-general-cache-confirmation`: iPhone `en-large` landscape (884 pt, `cannot-cover:popover`, the expected one)
- `settings-pages-general-translations-confirmation`: iPhone `en-large` landscape (1092 pt)
- `detail-pages-folder-delete-confirmation`: iPhone `en-large` landscape (656 pt)
- `quick-search-delete-confirmation`: iPhone `en-large` portrait (1008 pt) and landscape (741 pt); under the old order it ended `did-not-converge` (1328 pt and 1093 pt) in the Task 4 measure
In the two iPhone landscape pictures of `detail-pages-folder-delete-confirmation` and `quick-search-delete-confirmation` the popover is drawn with an arrow, at the same place as in the `.screen` picture, although the measuring mode and the check name `cannot-cover:popover`; the source rect the classification read was not logged (an observation for 19-26 and 19-24, no cause work here). The iPad `quick-search-delete-confirmation` popover (portrait, `did-not-converge`, not `cannot-cover:popover`) is arrowed but points at the top edge of the Quick Search sheet, not at a saved-search row: the plan's "a popover not anchored on its control at a coordinate that is not `cannot-cover:popover`" clause applies to it; it is the iPad side of the 19-24 C7 note (the popover is found anchored below the first screen), reported to the orchestrator, no cause work here.

Centred cards (`gallery-detail-delete-download-confirmation`, `gallery-detail-retry-confirmation`, `comments-posting-warning`, `comments-block-confirmation`, `report-form-error-alert`, `app-wide-app-alert`) centre in the window they are presented in, so on a taller window they sit lower on the page than at `.screen` (delete-download and retry: about y 115 to 285 at 420 pt, y 232 to 405 at 656 pt): a finding for 19-26's owner decision on alerts and cards; this task does not decide it.

The plan's expectation for step 8: met. `app-wide-app-alert`'s four iPhone `en-large` measuring lines are `cannot-cover:keyboard` (995 pt portrait, 749 pt landscape, both themes); the cache confirmation in iPhone landscape is among the `cannot-cover:popover` states; every converted state has a row. Not met, reported instead of resolved: the iPad app alert pair stays `error` (no need) and the iPad `quick-search-delete-confirmation` popover above.

`error`, `did-not-converge` and `cannot-cover` lines of the step 8 measure that are not `cannot-cover:popover` or `cannot-cover:keyboard`, as findings for 19-26 (the sequences are the needs of successive hostings, logged by a one-off print in `$W/diag-seq-phone` and `$W/diag-seq-pad`, now removed; a constant increment is a page whose content follows the window height):
- finding: `app-wide-app-alert__en__large__landscape__iphone__dark`: `cannot-cover`, reason `cannot-cover:keyboard`, need 749 pt after 0 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `app-wide-app-alert__en__large__landscape__iphone__light`: `cannot-cover`, reason `cannot-cover:keyboard`, need 749 pt after 0 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `app-wide-app-alert__en__large__portrait__ipad__dark`: `error`, reason `interaction:no-keyboard:never-announced announced=0`, no need (0 steps); the alert's keyboard step fails on the iPad (open item (ii)); both readings are recorded in the app alert open item below
- finding: `app-wide-app-alert__en__large__portrait__ipad__light`: `error`, reason `interaction:no-keyboard:announced-hidden announced=1`, no need (0 steps); the alert's keyboard step fails on the iPad (open item (ii)); both readings are recorded in the app alert open item below
- finding: `app-wide-app-alert__en__large__portrait__iphone__dark`: `cannot-cover`, reason `cannot-cover:keyboard`, need 995 pt after 0 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `app-wide-app-alert__en__large__portrait__iphone__light`: `cannot-cover`, reason `cannot-cover:keyboard`, need 995 pt after 0 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `favorites-category-menu__en__large__landscape__iphone__dark`: `did-not-converge`, 12 steps, last need 1802 pt; the content follows the window height, not slow settling: 420 -> 808, 808 -> 1024, 1024 -> 1132, then a constant +67 pt per step (`UICollectionView`), 13 hostings, last 1735 -> 1802 (19-26 decides; no cause work in 19-30)
- finding: `favorites-category-menu__en__large__landscape__iphone__light`: `did-not-converge`, 12 steps, last need 1802 pt; the content follows the window height, not slow settling: 420 -> 808, 808 -> 1024, 1024 -> 1132, then a constant +67 pt per step (`UICollectionView`), 13 hostings, last 1735 -> 1802 (19-26 decides; no cause work in 19-30)
- finding: `favorites-category-menu__en__large__portrait__iphone__dark`: `did-not-converge`, 12 steps, last need 1927 pt; the content follows the window height, not slow settling: 912 -> 1082, 1082 -> 1190, then a constant +67 pt per step (`UICollectionView`), 13 hostings, last 1860 -> 1927 (19-26 decides; no cause work in 19-30)
- finding: `favorites-category-menu__en__large__portrait__iphone__light`: `did-not-converge`, 12 steps, last need 1927 pt; the content follows the window height, not slow settling: 912 -> 1082, 1082 -> 1190, then a constant +67 pt per step (`UICollectionView`), 13 hostings, last 1860 -> 1927 (19-26 decides; no cause work in 19-30)
- finding: `quick-search-delete-confirmation__en__large__portrait__ipad__dark`: `did-not-converge`, 12 steps, last need 1626 pt; the content follows the window height, not slow settling: 1210 -> 1242, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1594 -> 1626 (the same sequence as `search-clear-confirmation`) (19-26 decides; no cause work in 19-30)
- finding: `quick-search-delete-confirmation__en__large__portrait__ipad__light`: `did-not-converge`, 12 steps, last need 1626 pt; the content follows the window height, not slow settling: 1210 -> 1242, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1594 -> 1626 (the same sequence as `search-clear-confirmation`) (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__landscape__iphone__dark`: `did-not-converge`, 12 steps, last need 1420 pt; the content follows the window height, not slow settling: 420 -> 1023, 1023 -> 1068, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1388 -> 1420 (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__landscape__iphone__light`: `did-not-converge`, 12 steps, last need 1420 pt; the content follows the window height, not slow settling: 420 -> 1023, 1023 -> 1068, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1388 -> 1420 (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__portrait__ipad__dark`: `cannot-cover`, reason `cannot-cover:UpdateCoalescingCollectionView`, need 1946 pt after 1 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__portrait__ipad__light`: `cannot-cover`, reason `cannot-cover:UpdateCoalescingCollectionView`, need 1946 pt after 1 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__portrait__iphone__dark`: `did-not-converge`, 12 steps, last need 1601 pt; the content follows the window height, not slow settling: 912 -> 1217 (`UpdateCoalescingCollectionView`), then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1569 -> 1601 (19-26 decides; no cause work in 19-30)
- finding: `quick-search-filters-reset-confirmation__en__large__portrait__iphone__light`: `did-not-converge`, 12 steps, last need 1601 pt; the content follows the window height, not slow settling: 912 -> 1217 (`UpdateCoalescingCollectionView`), then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1569 -> 1601 (19-26 decides; no cause work in 19-30)
- finding: `report-form-error-alert__en__large__portrait__ipad__dark`: `cannot-cover`, reason `cannot-cover:UpdateCoalescingCollectionView`, need 1432 pt after 1 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `report-form-error-alert__en__large__portrait__ipad__light`: `cannot-cover`, reason `cannot-cover:UpdateCoalescingCollectionView`, need 1432 pt after 1 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__landscape__iphone__dark`: `did-not-converge`, 12 steps, last need 1087 pt; the content follows the window height, not slow settling: 420 -> 703, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1055 -> 1087 (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__landscape__iphone__light`: `did-not-converge`, 12 steps, last need 1087 pt; the content follows the window height, not slow settling: 420 -> 703, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1055 -> 1087 (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__portrait__ipad__dark`: `did-not-converge`, 12 steps, last need 1626 pt; the content follows the window height, not slow settling: 1210 -> 1242, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1594 -> 1626 (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__portrait__ipad__light`: `did-not-converge`, 12 steps, last need 1626 pt; the content follows the window height, not slow settling: 1210 -> 1242, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1594 -> 1626 (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__portrait__iphone__dark`: `did-not-converge`, 12 steps, last need 1328 pt; the content follows the window height, not slow settling: 912 -> 944, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1296 -> 1328 (19-26 decides; no cause work in 19-30)
- finding: `search-clear-confirmation__en__large__portrait__iphone__light`: `did-not-converge`, 12 steps, last need 1328 pt; the content follows the window height, not slow settling: 912 -> 944, then a constant +32 pt per step (`HostingScrollView`), 13 hostings, last 1296 -> 1328 (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__landscape__iphone__dark`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 6115 pt after 5 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__landscape__iphone__light`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 6115 pt after 5 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__portrait__ipad__dark`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 6103 pt after 4 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__portrait__ipad__light`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 6103 pt after 4 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__portrait__iphone__dark`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 7233 pt after 5 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)
- finding: `settings-pages-site-settings-confirmation__en__large__portrait__iphone__light`: `cannot-cover`, reason `cannot-cover:TextEditorTextView`, need 7233 pt after 5 step(s); a state not measured before this task (19-26 decides; no cause work in 19-30)

### Posting warning: the measuring mode and a capture above native

The first ordered form (orchestrator decision 2026-11-23) waited for the keyboard in the operating step. The measuring mode ended `error` `settle-timeout:pixels:33,187,4x25` (portrait light; `32,186,6x27`/`33,186,5x27` dark; `466,101,4x25` landscape) after 1 step, and a capture at a committed height above native ended `timeout` with the same pixels (`$W/cand-dialogs-5`: 4 `timeout` lines, no picture). A one-off log (`$W/diag-pw-measure`, removed): the hosting at 912 pt read a need of 1290 pt (`UpdateCoalescingCollectionView`), then `hosting height=1290.0 stage=grow-settle outcome=unsettled(... timeout(samples: 40, seconds: 6.99))`, and for landscape `height=834.0` the same: the timeout is the settle of the window's growth (`prepareGrownWindow`, `freezeAtNativeSize`), before the operating step, on the page's blinking caret, because the editor was focused by then and no stillness step had stopped the caret. A capture at the native height never grows the window, so it passed. The capture path grows the same way, so it fails the same way (the four `timeout` lines above).

Allowed fix, inside the step the state owns (orchestrator ruling 2026-11-24): the state keeps the stillness step it had at HEAD, `GalleryScenarios.holdStillOverKeyboard` (wait for the focus and the keyboard, stop the caret, freeze), and its operating step starts at the tap: `RevealStep.reveal`, `awaitDialogPlatter`, `waitForRest`, `stopCaretBlink`, `holdStill`. `GalleryScenarios.awaitKeyboardUp` is not extracted any more (`holdStillOverKeyboard` is HEAD's again). The gate counts change by exactly this one state: `still:` 16 and `interact:` 36 literally, and one state has both.
- measuring (`$W/pw-measure`): `measured` at 1977 pt portrait and 1407 pt landscape after 3 steps, no suffix, both themes (the 1290 and 834 pt of the native hosting are the first read; the sheet follows the window, so the page needs more as the window grows: 1290, 1790, 1977 pt).
- capture at `.screen`, two identical runs (`$W/pw-cap-1`, `$W/pw-cap-2`: 8 keys pixel-identical), `en` `large` and `ja` `accessibility5`, both orientations and themes: `error` `page-height: needs 1290 pt, committed 912 pt` / `needs 834 pt, committed 420 pt` for `en`, `needs 4549 pt, committed 912 pt` / `needs 2449 pt, committed 420 pt` for `ja`; no `cannot-cover:keyboard` suffix on any of the eight lines; the pictures are pixel-identical to `$W/fix-dialog-phone-2` (the first ordered form's pictures, accepted); iPad (`$W/pw-cap-pad`): `recorded`, pixel-identical to `$W/fix-dialog-pad`.
- capture above native (`$W/pw-tall`, a one-off committed 1290 pt and 834 pt, restored byte for byte, `check-sources` rc 0): no `timeout` any more; `page-height: needs 1790 pt, committed 1290 pt` and `needs 1284 pt, committed 834 pt` with pictures (the card centred in the grown window, the sheet following the window). What changed against the earlier 1290 and 834 pt candidates (`$W/cand-dialogs-5`): they were `timeout` with no picture; now they are pictures, and the need is read as 1790 and 1284 pt.

### Quick Search delete confirmation, `ja` `accessibility5` portrait: the strip above the sheet

The two keys differ from the before-sample in a strip above the sheet (22,330 and 19,635 pixels): the new picture shows text ("ギャラリー") at the top of the strip, the old one does not. Two one-off logs (not committed, removed after each run, the md5 of `RevealStep.swift` and the tree verified after each). The first (`$W/diag-qs`) listed the views whose class names contain `LargeTitle` at four points: after the native settle, after `reveal`'s settle, right before the tap and after the tap at rest. It found only the sheet's own large title (`NavigationBarLargeTitleView`, hidden false, alpha 1.0, frame 0, 142, 420 by 73, in the test window; none at the first point, present from the second on, none in landscape), not the Search root's. The second (`$W/diag-qs2`) listed every view intersecting the strip, with its owner view controller and superview chain. Between `reveal`'s settle and the tap (`bringIntoView` and `restWhereTitleSnaps`) the Search root's scroll host (owner `NavigationStackHostingController` titled 検索, the page behind the sheet) was scrolled: its `PlatformGroupContainer` moved to y -415.3 (height 1293.3) and its `ScrollEdgeEffectView` went from alpha 0.0 to 1.0, the `_UITouchPassthroughView` and `BackdropView` of that host re-laid out. The title view of the sheet did not change. After the tap only the popover's dimming views were added. So the text in the strip is the Search root's content, scrolled under the strip by the step's reveal; the root has its own Quick Search row with the saved searches' names, which the label of the step (the first saved search's name) can match behind the sheet (the match itself was not logged). The old picture was built open, with no step. HEAD has no step for this state, so it has no such points. Landscape is not affected (the root's content is not below the fold there, `found=0`/no scroll), and `en` `large` neither (the picture is identical).

### The step searches only the front-most presentation (`08fe18cad`)

The diagnosis above is a step defect, not a difference to accept: no user can scroll the page behind a sheet, and
VoiceOver reaches only the front-most presentation. The orchestrator withdrew the acceptance of the two `ja`
`accessibility5` portrait keys (2026-11-24) and ordered the fix as its own commit.

- **The rule.** `RevealStep`'s element search starts at the front-most presentation's view when something is presented,
  else the window. One lookup feeds `reveal`, `isInView`, `holdPlacement`, `bringIntoView`, `element(_:in:)`,
  `view(of:)` and the front scroll view. A presentation that is being dismissed no longer counts.
- **The search controller.** An active `UISearchController` is walked through but is never the answer: it hosts the
  search bar, and the Search page's typing suggestions are rows of the page's own list, outside the search controller's
  view (one-off log `$W/diag8-typing`: under the first form of the rule all ten `search-typing-suggestions` keys failed
  `interaction:no-suggestions`). A sheet, alert or popover presented over an active search is still the front-most
  presentation (orchestrator, 2026-11-24, option A).
- **Tests first.** `testTheStepScrollsTheFrontPresentationAndNotThePageBehindIt` was RED before the fix (the page
  behind the sheet scrolled from 0 to 1830 pt, the sheet stayed at -68 pt) and now also checks that the row is inside
  the sheet list's visible area. `testTheStepScrollsThePageUnderAnActiveSearch` was RED against the first form of the
  rule (`$W/search-red`: the row was not found). `testTheStepScrollsASheetOverAnActiveSearch` hosts a sheet presented
  from the window's root while a search is active; a search controller that presents a sheet of its own cannot be hosted
  in a unit host (presenting one by hand ends the process). `RevealStepTests` 6 of 6 green (`$W/search-green2`).
- **Platter state.** `frontPresentation` also feeds `platterState`, `largeTitleShown` and `followShownList`. With only a
  search controller up, `platterState` now reads `.notPresented` where it read `.ready`. Checked by grep: the five
  callers of `awaitDialogPlatter` (`comments-posting-warning`, `search-clear-confirmation`, `history-clear-confirmation`,
  `settings-account-logout-confirmation`, `LibraryScenarios.tapHeldRow`) each tap a dialog's control first, and none of
  them activates a search, so no state waits for a platter with only a search controller up.
- **Identity, before (`dda0e8348` sources, `$W/rv-before-*`) against after (`$W/rv-after-*`).** The 15
  `RevealStep.reveal` states, the four analytics-choice states and `search-typing-suggestions`; iPhone `en-large` and
  `ja-accessibility5`, iPad `en-large` portrait.
  - iPhone: 155 keys pixel-identical, 5 differ. The two `quick-search-delete-confirmation` `ja` `accessibility5`
    portrait keys now equal `$W/dialog-before-phone` pixel for pixel (the strip is gone). The two landscape keys show the
    sheet's own list scrolled to the row (accepted above). `settings-pages-general-translations-confirmation__ja__accessibility5__landscape__iphone__dark`
    differs in 6 pixels by 1 unit.
  - iPad: 35 keys pixel-identical, 3 differ: `analytics-choice-basic`, `-full` and `-minimal`
    `__en__large__portrait__ipad__light`, 2 pixels each by 1 unit. The first after-run (`$W/rv-after-pad-v1`) was
    pixel-identical to the before-run for all eight analytics keys. The two iPad app alert keys have no picture in
    either run (the allowed iPad error).
  - All ten `search-typing-suggestions` keys are pixel-identical to the before-run, with their old `page-height ...
    cannot-cover:keyboard` reasons.
- **Variation evidence for 19-27 (orchestrator rule: the runner's compare mode against the before picture, D-10
  unchanged).** The three analytics keys: `$W/cmp5-analytics` against exactly the three before pictures (`$W/refs-5`)
  reports `passed` for all three, with no `difference` picture (the three dark keys read `missing-reference` because the
  reference directory held only the light pictures; they are pixel-identical). The translations key: the runner cannot
  compare it, because its `page-height` error (`needs 1720 pt, committed 420 pt`) is raised before the comparison
  (`$W/cmp4-translations`: all four keys `error`, no comparison made). By calculation, 6 differing pixels are at most 24 differing
  bytes, within D-10's budget of 153 bytes (precision 0.9999 of 912 by 420 by 4 bytes, perceptual precision 1). Recorded as
  variation evidence, not as a pass of the runner.
- **Final tree.** `VisualSnapshotTests` and `CookieClientTests` green (`$W/clean10`: 181 passed, 0 failed, 141
  skipped), strict lint 0 on every touched module, `RevealStep.swift` md5 `dd6d174309d9d70a8148865db9aa4df1`.

### Logout: a page created again outside the scenario's scope

`settings-account-logout-confirmation` failed at all 8 iPhone keys (`en` `large` and `ja` `accessibility5`, both
orientations and themes) with `interaction:not-found:popover-platter:not-presented chain=UIHostingController` after the
held tap. Evidence (instrumented runs `$W/dbg5` and `$W/dialog-after-phone-2`, prints removed):
- the held tap existed and fired (`reveal tap=true`), and the reducer logged `logoutButtonTapped dialog=false`: the
  action reached `AccountSettingReducer`;
- the element the label matched is the `AccessibilityNode` "Log Out" (frame 20, 235, 380, 52 in `en` portrait; 84, 174,
  744, 52 in landscape; ログアウト at 20, 256, 380, 93.3 in `ja`);
- `AccountSection` printed `didLogin=true resolvedClientDidLogin=true` 16 times before the tap and `didLogin=false
  resolvedClientDidLogin=false` 16 times, 5 to 9 ms after `logoutButtonTapped`; the presentation chain stayed
  `UIHostingController` right after the tap and 1 s later. The `if !didLogin { Login } else { Log Out }` flipped, so the
  Log Out button, which carries `.confirmationDialog`, left the hierarchy and nothing was presented.

Cause (a harness defect, not a fixture, step or provider one): `@SharedReader(.didLogin)` resolves `cookieClient` when its
key is created (`DidLoginKey.init`). `SnapshotMatrixCase.inScenarioDependencies` installed the scenario's client only in a
task-local scope, which covers the first render and the step. A page a step changes renders again from the main run
loop, outside the scope, and a view created again there read the process context's `.noop`. Built open, the page was
rendered once, inside the scope, so no such render existed. `DidLoginKey` documents one cookie client per process.

Fix (orchestrator ruling 2026-11-23; not option (a), `prepareDependencies` of that key, because `configureVisualTestHost`
has already prepared `cookieClient = .noop` for the live context and a second preparation of a key is reported and dropped):
- `CookieClient.forwarding(to:)` (`#if DEBUG`, beside `testing(...)`, in the file that owns the private closures)
  forwards each closure to `current()` at call time;
- `UITestAutomation.prepareIfNeeded(cookieClient:)` and `configureVisualTestHost(_:firstLaunch:cookieClient:)` take the
  client the visual host prepares, default `.noop`, so every other caller is unchanged;
- `ScenarioCookieClient` (test-side, `Mutex`) holds the running scenario's jar, `.noop` between scenarios; `setUp` passes
  the forwarding client to `prepareIfNeeded`; `inScenarioDependencies` (now `static`) chooses the client once, sets it in
  the holder and in `withDependencies`, and the holder is `.noop` again on every way out. Capture and measure both use it.

RED (`$W/red6`, sources with `forwarding` returning `.noop`): `testAViewCreatedAgainOutsideTheScopeStaysSignedInIn…`
failed with `[Read(tick: 0, didLogin: true), Read(tick: 1, didLogin: false)]` against the same with `true` at tick 1 (the
logout defect, reproduced); `testTheHolderIsTheScenarioJarWhileItRunsAndInertAfter` failed twice;
`forwardingClientReadsTheCurrentClientAtEveryCall` failed 5 expectations; the signed-out test passed. The first version of
the signed-in test passed in RED because it waited with `settle`, which renders in place inside the task, hence inside the
scope; it now waits on a condition across a real suspension, so the render comes from the run loop.

Limit, found by a leak test (a signed-in then a signed-out scenario in one test method: the second read `didLogin: true` at
tick 1 although the holder and the resolved dependency were both signed out). Sharing's reference table is itself a
dependency (`@Dependency(PersistentReferences.self)`, `SharedReaderKey.swift:163`), cached per context
(`DependencyValues.swift:475`, `:519`): a page renders in the scope's `.preview` table at first and, once a step changed it,
in the process context's table, where a weak entry of the first scenario was still alive. XCTest's `testCaseWillStart`
calls `resetCache()` (`DependencyValues.swift:37`, `:154`), so the next test method has new tables. A reference therefore
outlives its scenario only inside one test method; every matrix method makes one `capture(scenario:)` call, whose jar is
constant over its coordinates and attempts. A property of Sharing, not created by the forwarding client. Enforced, not only
documented: `SnapshotMatrixCase` fails (`XCTFail`, no capture) when a second, different scenario id arrives in one method
(`OneScenarioPerMethod`, unit tested). The leak test was replaced (orchestrator ruling): the signed-in and signed-out
methods each start from a reset cache, so either order is the guard that the next method reads its own jar.

One-off confirmation of the contexts (`ContextProbe5`, included in the clean run `clean8`, `** TEST SUCCEEDED **` in
510 s; deleted after its output was read, so it is in no commit). Its output, as attached to the test:

```
scenario1-signedIn
tick=0 didLogin=true context=preview
tick=1 didLogin=true context=test
scenario2-signedOut
tick=0 didLogin=false context=preview
tick=1 didLogin=true context=test
```

Tick 0 (the first render, inside the scope) resolved the scope's `.preview` context; tick 1 (a render from the run loop
after a state change) resolved the `.test` context, so a view created again outside the scope does not read the scope.
In the second scenario of the same method tick 1 read the first scenario's `true`: the mechanism of the Limit above.

## Popover proof after the conversion

Task 4 step 3's one-off (`$W/oneoff-general.json`: the cache confirmation at 939 pt in portrait and 884 pt in landscape),
applied to the two general states, captured in `$W/cand-general-5` after the conversion, restored (file equal to HEAD,
`check-sources` exit 0). The pictures were opened with the Read tool.

- portrait light: yes (`recorded`, 939 pt, `portrait-light.png`): the confirmation is an arrowed popover, "Clear the image cache?" over a red Clear button, whose arrow points down at the Clear Image Cache row (the row's trailing "0 KB" line, directly under the arrow tip), and it sits over the Navigation and Cache section headers
- portrait dark: yes (`recorded`, 939 pt, `portrait-dark.png`): the same picture in the dark theme, arrow on the Clear Image Cache row
- landscape light: `error`, reason `page-height: needs 884 pt, committed 884 pt, cannot-cover:popover` (picture in `actual/`: the popover is drawn at the upper left over the Navigation section with no arrow and no row near it; the Clear Image Cache row lies about 110 pt below it, in the Cache section, so the popover is not anchored on its control)
- landscape dark: `error`, reason `page-height: needs 884 pt, committed 884 pt, cannot-cover:popover` (the same, dark)

The runner appends `; picture <n> of <m>` to the reason of an `error` line that carries a picture (the aggregation format of
`Scripts/visual/`), so the plan's verify compares the part before it.

## Open items from Task 5

- 19-27 (variation work): the general form of the logout defect is NOT fixed. A view created again outside the scenario's
  scope also reads the process context's storage (`defaultAppStorage`, `defaultInMemoryStorage`), `date.now` and `uuid`,
  not the scenario's: the scope sets them (`inScenarioDependencies`) but the process context keeps the host's. Only the
  cookie client is forwarded. Any page that a step changes and that builds a reader of such a dependency in the new render
  could draw from the host's values; none is known.
- 19-24 (C7): the quick-search delete (portrait) and folder-delete (portrait) confirmations are popovers found
  anchored below the first screen; C7 anchors these confirmations on their rows, so 19-24 must re-measure both after its fix.
  On the iPad the quick-search delete popover's arrow points at the top of the sheet, not the row: the same finding C7
  (the app attaches the dialog to the List), not a new question; 19-24 re-measures and re-opens the iPad coordinate too
  (orchestrator, 2026-11-24).
- 19-26: the states with a `cannot-cover:popover` line are listed with the table above (step 8); a centred card
  (delete-download, retry) centres in the window it is presented in; `comments-posting-warning` no longer has a keyboard
  reason (heights stay `.screen`, whether it grows is 19-26's).


- Quick Search delete step: fixed in `08fe18cad` (see the front-presentation subsection); no open item remains.
- App alert keyboard, before 19-26: four iPhone `en-large` runs of the alert on the current tree, all `cannot-cover:keyboard`-class lines (needs 995 pt portrait, 749 pt landscape in three of them): `fix-dialog-phone-1` (the first run after the logout fix, on the loaded host) drew a squeezed landscape layout (needs 793 pt, 63,356 and 79,056 differing pixels against the before-sample); `fix-dialog-phone-2`, `sample-alert-1` and `sample-alert-2` (two further single-class runs, gated on no other `xcodebuild`, load averages 64.97 / 37.31 / 144.53 at 04:49) are pixel-identical to the before-sample and to each other. The iPhone app alert layout is not shown to be nondeterministic by three of four runs; the one outlier is recorded, not explained.
- iPad app alert pair: the reasons were `interaction:no-keyboard:announced-hidden announced=1 refocused=0 began=1 ended=0` (the before-sample, both themes, and the step 8 measuring run, light) and `interaction:no-keyboard:never-announced announced=0 refocused=0 began=1 ended=0` (the step 8 measuring run, dark; the identity runs `fix-dialog-pad` and `final-dialog-pad`, the one-off run `cand-dialogs-pad-5` and the single-class run `pad-alert-sample`, both themes each); both are the allowed iPad error at the alert's keyboard step. Whether the Task 5 tree or the host load changed the reason is not separated.
