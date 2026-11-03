# Phase 17 Layout Audit

Verification record for CAP-17-07 (amended 2026-11-03, owner msg 1305). The device-idiom to
size-class migration landed in quick task `261015-duo-session-record` before snapshot coverage
existed; plans 17-16 to 17-18 confirm it at HEAD. This record describes the source as read and
tested; it does not imply owner acceptance of any layout.

Evidence conventions: commits are checked with `git merge-base --is-ancestor <commit> HEAD`;
tests run through the project's `runtest` recipe (`airbuild-xcode test`, which adds
`-collect-test-diagnostics never` and no retry or repetition flags), one invocation at a time,
phone before tablet. Result bundles are kept locally under `/tmp/ehpanda-17-16-18/` and are not
tracked. Devices were created for this audit on the iOS 27.2 runtime (Xcode 27.2, 27B52):
`EhPanda iPhone Air` (PHONE) and `EhPanda iPad Pro 11-inch (M5)` (TABLET); their run-local UDIDs
are not recorded.

## View layouts (17-16)

Source HEAD: `39397e500`. Landing commits `e89e896634` ("pick layouts by size class, not idiom")
and `0a42b7fbb4` ("size NewDawn sun for wide sheets") are both ancestors of HEAD (exit 0 each).
Decisions: `261015-duo-session-record` DISCUSSION-LOG D01 (size classes for ordinary layout),
D28 (NewDawn ratio by canvas width).

| Site | File and line at HEAD | Read at HEAD | Landed by | Notes |
|---|---|---|---|---|
| Home Toplists | `AppPackage/Sources/HomeFeature/HomeView+Sections.swift:397`, `:484` | `@Environment(\.horizontalSizeClass)`; `else if horizontalSizeClass == .regular` selects `regularWidthGrid`, otherwise `VerticalToplistsStack` | `e89e896634` dropped the `deviceClient.deviceType() == .pad` conjunct | The same file also reads `horizontalSizeClass` for the stack width fraction (`:552`, `:591`) and the slideshow viewport (`:25`, `:207`); no idiom read. |
| GalleryCardCell | `AppPackage/Sources/HomeFeature/GalleryCardCell.swift:119`, `:172` | Container fitting: `ViewThatFits(in: .vertical)` picks the 4-line, 2-line or compact card arrangement; `ViewThatFits(in: .horizontal)` picks the rating form. The compact arrangement is chosen by the parent through `usesCompactInformation` (from `GalleryViewport` and the horizontal size class, `HomeView+Sections.swift:207`) | `e89e896634` replaced the idiom title-trim read with `horizontalSizeClass`; `7545d6c89` later replaced that read with the title-simplification setting | No size-class or idiom read remains in the cell itself. |
| Search keywords | `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift:9`, `:43` | `@Environment(\.horizontalSizeClass)`; `if horizontalSizeClass == .regular` lays out two keyword columns, otherwise one | `e89e896634` | |
| TagSuggestion | `AppPackage/Sources/AppComponents/TagSuggestionView.swift:17`, `:34`, `:57`, `:96` | `@Environment(\.searchSuggestionsPlacement)`; `searchSuggestionsPlacement != .menu` shows the inline count header and inline completing rows, the menu placement shows plain completions | `e89e896634` | Reads the system's suggestion placement, which follows the room around the search field, not the device. |
| NewDawn | `AppPackage/Sources/AppComponents/NewDawnView.swift:42` | Container fitting inside `Canvas`: `size.width >= 500 ? 0.5 : 0.6` sun width | `e89e896634` (size class), then `0a42b7fbb4` (canvas width, D28) | A compact-class iPad form sheet is 580 pt wide, so the canvas width rather than the size class decides. |

Idiom check, as run:

```sh
cd AppPackage/Sources
grep -nE 'userInterfaceIdiom|deviceType|DeviceClient|\.pad\b' \
  HomeFeature/HomeView+Sections.swift HomeFeature/GalleryCardCell.swift \
  SearchFeature/SearchRootView+Keywords.swift AppComponents/TagSuggestionView.swift \
  AppComponents/NewDawnView.swift
```

Exit 1, no matches. **For 17-19 census:** none from these five files.

Tests, as run (one at a time, phone then tablet):

```sh
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:HomeFeatureTests -only-testing:SearchFeatureTests'
```

| Device | Exit | Result | Tests (HomeFeatureTests + SearchFeatureTests) | Failed / skipped | Repetition nodes | Result bundle |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | TEST SUCCEEDED | 90 (74 + 16) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-16-phone.xcresult` |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | TEST SUCCEEDED | 90 (74 + 16) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-16-tablet.xcresult` |

Counts come from `xcrun xcresulttool get test-results summary` and `tests`. App source diff
after the runs: none (`git status --short` lists only the owner's untracked `.claude/`).

## Home and Library routing (17-17)

Source HEAD: `55119b1ec` (no app source change since `39397e500`). Landing commit `8fb2374536`
("route screens by window size classes") is an ancestor of HEAD (exit 0). Decisions:
`261015-duo-session-record` DISCUSSION-LOG D01–D02 (modal only when both window size classes are
regular), D63–D64 (Favorites lives in the merged Library tab, which keeps its own Favorites and
Downloads reducers).

| Item | File and line at HEAD | Behavior at HEAD |
|---|---|---|
| Rule | `AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift:17-19` | `presentsModally` is `horizontal == .regular && vertical == .regular`. |
| Report | `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:66-71`; `AppReducer.swift:175-178` | The root view reports `WindowSizeClasses(horizontal:vertical:)` from its environment with `.onChange(of:initial: true)`, so once at first appearance and again on every change; the reducer stores it in `state.windowSizeClasses`. |
| Apply | `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift:521-529` (`openGalleryDetail`) | `guard state.windowSizeClasses?.presentsModally == true else { return .send(push) }`, otherwise `.presentation(.presentGalleryDetail(...))`. One decision at the app root; no per-feature `isRegularWidth` state. |
| Home | `AppReducer.swift:292-293` | `.home(.delegate(.openGalleryDetail))` → `openGalleryDetail(..., push: .home(.pushGalleryDetail))`. Home's slideshow and section taps (`HomeReducer+Body.swift:46`, `:61`) send that delegate. |
| Library (Favorites) | `AppReducer.swift:298-299` | `.favorites(.delegate(.openGalleryDetail))` → `openGalleryDetail(..., push: .favorites(.pushGalleryDetail))`; `FavoritesReducer.swift:162` sends the delegate. Library's Downloads source is covered in 17-18. |

Covering tests (Swift Testing, all in `AppPackage/Tests/AppFeatureTests/`):

| Test | Window | Asserts |
|---|---|---|
| `GalleryDetailRoutingTests.favoritesPushesInAWindowCompactInEitherDimension` | `.compactWidth`, `.compactHeight` | Favorites path count 1; no modal gallery |
| `GalleryDetailRoutingTests.favoritesPresentsInARegularWindow` | `.regular` | Modal gallery holds the tapped gallery; Favorites path empty |
| `GalleryDetailRoutingTests.searchPushesInAWindowCompactInEitherDimension` / `searchPresentsInARegularWindow` | same three | Same pair for Search (recorded again in 17-18) |
| `CaptureRouteTests.aGalleryScreenStartsWithATapOnItsCardThatACompactWindowPushes` | `.compactWidth` | Home tap → `home.pushGalleryDetail`; Home path top is the detail; no modal |
| `CaptureRouteTests.aGalleryScreenStartsWithATapOnItsCardThatARegularWindowPresents` | `.regular` | Home tap → `presentation.presentGalleryDetail`; Home path empty |
| `CaptureRouteTests.theLaboratoryOpensInTheSettingTabInACompactWindow` / `...InTheSettingSheetInARegularWindow` and the other capture routes | `.compactWidth`, `.regular` | Launch automation routes through the same root decision |

Window fixtures (`WindowSizeClasses+Fixtures.swift`): `.regular` = regular/regular (full-screen
iPad), `.compactWidth` = compact/regular (iPhone portrait, folded Duo, narrow iPad window),
`.compactHeight` = regular/compact (large iPhone landscape).

Coverage observation (not a defect): no test drives a Home tap in `.compactHeight`. Home shares
`openGalleryDetail` with Favorites, Search and Downloads, whose `.compactHeight` cases pass, so the
rule is exercised; only Home's own entry for iPhone landscape is unasserted.

**For 17-19 census:** `AppPackage/Sources/HomeFeature/HomeReducer.swift:32-35` —
`usesSplitLayout` reads `WindowDevice` (`.duo`) and, when true, Home opens the gallery in its own
opposite-pane sheet (`HomeReducer+Body.swift:46`) instead of asking the app root. This is the
recorded Duo capability exception (D31); `HomeDuoPresentationTests` covered it in the 17-16 runs.
It is listed for the census, not changed.

Tests, as run (one at a time, phone then tablet):

```sh
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:AppFeatureTests/GalleryDetailRoutingTests -only-testing:AppFeatureTests/CaptureRouteTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:AppFeatureTests/GalleryDetailRoutingTests -only-testing:AppFeatureTests/CaptureRouteTests'
```

| Device | Exit | Result | Test cases (argument runs) | Failed / skipped | Repetition nodes | Result bundle |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | TEST SUCCEEDED | 15 (GalleryDetailRouting 4 with 4 argument runs; CaptureRoute 11 with 16 argument runs) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-17-phone.xcresult` |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | TEST SUCCEEDED | 15 (same) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-17-tablet.xcresult` |

App source diff after the runs: none.

## Search and Downloads routing (17-18)

Source HEAD: `b1119beef` (no app source change since `39397e500`). Landing commit `8fb2374536` is an
ancestor of HEAD (exit 0). Decisions: `261015-duo-session-record` DISCUSSION-LOG D01–D02.

| Item | File and line at HEAD | Behavior at HEAD |
|---|---|---|
| Search tap | `AppPackage/Sources/SearchFeature/SearchRootReducer.swift:133` | `galleryTapped` and a nested search result's `pushDetail` send `.delegate(.openGalleryDetail(gallery))`; no device read. |
| Search route | `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift:295-296` | `openGalleryDetail(gallery, push: .searchRoot(.pushGalleryDetail(gallery)), state:)` — the same `presentsModally` decision as 17-17. |
| Downloads tap | `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift:184` | After the existing vanished-download guard, sends `.delegate(.openGalleryDetail(download))`. |
| Downloads route | `AppReducer.swift:301-307` | `openGalleryDetail(download.gallery, downloaded: download, push: .downloads(.pushGalleryDetail(download)), state:)`; the modal is seeded from the download, so it renders offline. |

Helper removal, as run:

```sh
git grep -n routeGalleryDetail -- AppPackage            # exit 1, no matches
git grep -n routeGalleryDetail -- . ':!.planning'       # exit 1, no matches outside planning records
```

`AppPackage/Sources/DetailFeature/GalleryNavigation.swift` still provides
`GalleryNavigation.presentationEffect(id:screen:embed:)` (`:14`), `GalleryNavigation.nextScreen(for:)`
(`:23`), the `GalleryRouteIdentifiable` protocol with `StackState.appendGuardingDuplicate(_:)` (`:76`),
`GalleryPath.State.onPresentedAction` and `routeKey`, `StackState.detailID(forGID:)` (`:125`),
`topReadingFlush` and `readingFlushAction`. `8fb2374536` removed only `routeGalleryDetail` and its
`AppTools` import from this file.

Invariants: in `8fb2374536` the Downloads and Search reducer diffs change only the tap route, the
delegate case and the removed `DeviceClient` dependency (plus an analytics comment in Search). No
download manifest, folder deletion or confirmation-dialog code is touched, and no app source has
changed since. The Downloads automation tests (foreground reconcile, launch automation) pass below.

Covering tests:

| Test | Window | Asserts |
|---|---|---|
| `DownloadsFeatureTests/AppDownloadDetailRoutingTests.aRegularWindowPresentsTheDownloadModally` | regular/regular | Modal detail carries the download's completed badge; Downloads path empty |
| `DownloadsFeatureTests/AppDownloadDetailRoutingTests.aWindowCompactInEitherDimensionPushesTheDownload` | compact/regular, regular/compact | Downloads path count 1; no modal |
| `AppFeatureTests/GalleryDetailRoutingTests.searchPushesInAWindowCompactInEitherDimension` / `searchPresentsInARegularWindow` | `.compactWidth`, `.compactHeight`, `.regular` | Search push vs. modal (run in 17-17) |
| `DownloadsFeatureTests/DownloadAutomationTests` (8 cases) | — | Foreground-return reconcile and launch-automation behavior unchanged |
| `DetailFeatureTests/GalleryNavigationTests.appendGuardingDuplicateSkipsOnlyAdjacentDuplicates` | — | Adjacent-duplicate guard only |

Coverage observation (not a defect): `GalleryNavigationTests` holds one case, for
`appendGuardingDuplicate`. `presentationEffect` and `nextScreen` are exercised through the host
lifecycle suites (for example `HomePresentationLifecycleTests.pushingGalleryDetailStartsItsLoad`,
passed in the 17-16 runs), not in this file.

Tests, as run (one at a time, phone then tablet):

```sh
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:DownloadsFeatureTests/AppDownloadDetailRoutingTests -only-testing:DownloadsFeatureTests/DownloadAutomationTests -only-testing:DetailFeatureTests/GalleryNavigationTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:DownloadsFeatureTests/AppDownloadDetailRoutingTests -only-testing:DownloadsFeatureTests/DownloadAutomationTests -only-testing:DetailFeatureTests/GalleryNavigationTests'
```

| Device | Exit | Result | Test cases | Failed / skipped | Repetition nodes | Result bundle |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | TEST SUCCEEDED | 11 (AppDownloadDetailRouting 2 with 2 argument runs, DownloadAutomation 8, GalleryNavigation 1) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-18-phone.xcresult` |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | TEST SUCCEEDED | 11 (same) | 0 / 0 | 0 | `/tmp/ehpanda-17-16-18/17-18-tablet.xcresult` |

App source diff after the runs: none.

## Settings presentation (17-19)

Source HEAD: `5a7fe7f13`. App source is unchanged since `6bccf8468` apart from two DEBUG-only
UI-test support files (`UITestStubURLProtocol.swift`, `CaptureScenePreparation.swift`, quick task
261103-test-plan-repairs). Landing commit `8fb2374536` is an ancestor of HEAD (exit 0). Decision:
`261015-duo-session-record` DISCUSSION-LOG D02.

| Item | File and line at HEAD | Behavior at HEAD |
|---|---|---|
| Rule | `AppPackage/Sources/AppFeature/DataFlow/WindowSizeClasses.swift:17-19` | `presentsModally` is `horizontal == .regular && vertical == .regular`. |
| Settings decision | `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift:514-516` | `opensSettingAsSheet` holds only when `presentsModally` holds **and** the selected tab is not already Settings. |
| Settings route | `AppReducer.swift:248-251` | `.tabBar(.delegate(.openSetting))` sends `.presentation(.presentSetting)` when `opensSettingAsSheet`, otherwise `.tabBar(.selectSettingInline)`. |
| Inline selection | `AppReducer.swift:253-258` | `setTabBarItemType(.setting)` is ignored; only `selectSettingInline` selects the tab, through `tabSelectionEffect(type: .setting, …)`. |

Tests, as run (one at a time, phone then tablet):

```sh
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$PHONE_UDID -only-testing:AppFeatureTests/TabBarSettingPresentationTests'
runtest <project-id> --script app --additional-options \
  '-testPlan FeatureTests -destination id=$TABLET_UDID -only-testing:AppFeatureTests/TabBarSettingPresentationTests'
```

| Device | Exit | Result | Test cases | Failed / skipped | Repetition nodes | Result bundle |
|---|---|---|---|---|---|---|
| EhPanda iPhone Air, iOS 27.2 | 0 | TEST SUCCEEDED | 8 (7 tests; `aWindowCompactInEitherDimensionSelectsTheTab` runs `.compactWidth` and `.compactHeight`) | 0 / 0 | 0 | `/tmp/ehp-17finish/runs/1719-settings-phone.xcresult` |
| EhPanda iPad Pro 11-inch (M5), iOS 27.2 | 0 | TEST SUCCEEDED | 8 (same) | 0 / 0 | 0 | `/tmp/ehp-17finish/runs/1719-settings-tablet.xcresult` |

App source diff after the runs: none.

## Simulator pass (17-19)

One throwaway UI-test driver, kept in a scratch worktree under `.airbuild/worktree/` and never
committed, drove the Debug app through its stubbed UI-test launch. It records each observation as
an attachment and asserts nothing about layout. Screenshots stay local, outside the repository.
Window shapes, on `EhPanda iPad Pro 11-inch (M5)` and `EhPanda iPhone Air` (iOS 27.2):

1. **iPad full width**: landscape, 1210×834 pt (regular/regular).
2. **iPad narrow window**: Windowed Apps on, landscape, the window dragged to 375×834 pt (compact
   width). The driver switched Multitasking back to Full Screen Apps afterwards.
3. **iPhone landscape**: 912×420 pt (compact height).

The census observations (Home, Library, reader and error details) come from the first pass at
`6bccf8468`. Its stubbed lists failed to load, so no gallery could be opened then: the stub had no
`api.php` route, fixed by quick task 261103-test-plan-repairs (`e6e725fd1`). The Detail rows below
come from a second pass on 2026-11-03 at HEAD `5a7fe7f13`'s source.

| Shape | Settings expected | Settings observed | Detail expected | Detail observed |
|---|---|---|---|---|
| iPad full width | sheet | sheet: navigation bar at x 315, width 580; no bottom tab bar | sheet | **sheet**: `detail_view` is a 580×660 pt form sheet at (315, 87) over the Library split view; no Back control, no tab bar in the sheet |
| iPad narrow window | inline tab | inline: full-width bar, bottom tab bar at y 757 | push | **push**: `detail_view` fills the 375×834 pt window, with a Back control at (496, 32) and the bottom tab bar |
| iPhone landscape | inline tab | inline: bar 912 pt wide, bottom tab bar at y 356 | push | **push**: `detail_view` fills the 912×420 pt window, with a Back control at (38, 24) and the tab bar |

Every observed routing matches the D02 rule. In the second pass, the tablet run passed both shapes
(`TEST SUCCEEDED`, 2 tests). The phone run recorded the Detail and Settings rows above, then failed
in the driver's own reader step, which this pass did not need: `reading_view` didn't appear after
the warm deep link, and the plan's retry ran the driver three times. The reader rows below come from
the first pass. Result bundles: `/tmp/ehp-17finish/runs/1719-pass-{phone,tablet}.xcresult`.

## Remaining idiom census and owner decisions (17-19)

Command, at HEAD `5a7fe7f13`:

```sh
git grep -nE "userInterfaceIdiom|deviceState|deviceType|== \.pad|case \.pad" -- AppPackage/Sources
```

The hits are the same files and lines as at `6bccf8468`. The owner was asked about the five places
on 2026-11-03 (msg 1408) and answered **keep all five** on 2026-11-03 (msg 1409).

| # | Place (code at HEAD) | What the device read decides | Earlier decision | Observed in the pass | Owner decision |
|---|---|---|---|---|---|
| 1 | Reader lower Close: `ReadingFeature/ReadingView.swift:204,212`, `showsCloseButton: !usesHalfWidth \|\| deviceState == .pad` | The lower Close disappears only in the half-width landscape layout. The `.pad` term keeps it on iPad there, so only an open Duo in landscape loses it. | D36 | iPad full width: two pages, lower panel half-width, Close centered above the slider, top Close also shown. iPad narrow window: one page, lower Close shown. iPhone landscape: lower Close shown. | Owner decision: **keep** (2026-11-03, msg 1409). Reason: it does what D36 asks, and a size-class rule can't tell iPad landscape from an open Duo. |
| 2 | Library sidebar: `AppFeature/View/Library/LibraryFeature.swift:16-22`, `usesSidebar` | Split view with a category sidebar, or a single stack with the title menu; also whether Favorites opens at launch. | D132 | iPad full width: 320 pt sidebar. iPad narrow window: the split view collapses as the system does in compact width (category list root, Favorites pushed). iPhone landscape: no sidebar, title menu. | Owner decision: **keep** (2026-11-03, msg 1409). Reason: it matches D132; the narrow iPad window is handled by the split view's own collapse. |
| 3 | Home title: `HomeFeature/HomeNavigationView.swift:19`, `hidesTitle = store.device == .pad && tabBarPlacement == .topBar` | Hides the Home title when the tabs sit at the top of an iPad window. | D118 | iPad full width: top tabs, no title. iPad narrow window and iPhone landscape: bottom tab bar, title shown. | Owner decision: **keep** (2026-11-03, msg 1409). Reason: it behaves as D118 says. The optional cleanup (dropping the redundant `.pad` term) is not taken. |
| 4 | Device name in error details: `AppComponents/ErrorInfoView.swift:19-21` (`deviceClient.deviceType()`, `DeviceClient/DeviceClient.swift:36`, mapped in `AppTools/DeviceType.swift:15`) | The Environment section's "Device" text. Diagnostics, not layout. | None | "iPad" at full width and in the narrow window; "iPhone" in iPhone landscape. | Owner decision: **keep** (2026-11-03, msg 1409). Reason: a bug report names the hardware, not the window size. |
| 5 | Duo/iPad capability: `AppComponents/WindowDevice.swift:15-25`, `AppComponents/WindowDeviceObservation.swift:63` | The one place that tells Duo, iPad and other devices apart; it feeds rows 1 and 2, `HomeReducer.usesSplitLayout` (`HomeReducer.swift:32-35`) and the reader's automatic dual page (`ReadingView.swift:229-232`). | D91, D26 | iPad full width: single-column Home, two reader pages in landscape. iPad narrow window: one reader page. Duo can't be simulated; unit tests cover its branch. | Owner decision: **keep** (2026-11-03, msg 1409). Reason: a hinge isn't a size class, and D91 and D26 depend on telling an open Duo from an iPad. |

Other grep hits, classified (no decision needed):

| Hit | Classification |
|---|---|
| `ErrorInfoView.swift:19,21` | Row 4. |
| `WindowDevice.swift:22`, `WindowDeviceObservation.swift:63` | Row 5. |
| `LibraryFeature.swift:18` | Row 2. |
| `HomeNavigationView.swift:19` | Row 3. |
| `ReadingView.swift:38,75,76,163,204,212,229,232` | Row 1 (204, 212) and row 5 (229, 232). Lines 38, 75, 76 and 163 store the measured `WindowDevice` and wait for it before the first layout; they make no idiom decision. |
| `DeviceClient.swift:6,16,19,26,36,65,72`, `AppTools/DeviceType.swift:15` | The source mapping behind row 4: the live client (36), the preview value (65) and the test placeholder (72). No other consumer. |
| `AppFeature/UITestSupport/CaptureDiagnostics.swift:208,264` | DEBUG-only capture diagnostics, not compiled into Release (17-RELEASE-ISOLATION.md). No user-visible behavior. |

No row is "change", so 17-19 hands nothing to a separate plan. The iPad Toplists gap was resolved
by the owner on 2026-11-03 as fixture-caused and is not asked again. The Duo branch is not covered
by the simulator pass.
