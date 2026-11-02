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

Source HEAD: `c5bc2c98b`. Landing commits `e03456839a` ("pick layouts by size class, not idiom")
and `30ef583d21` ("size NewDawn sun for wide sheets") are both ancestors of HEAD (exit 0 each).
Decisions: `261015-duo-session-record` DISCUSSION-LOG D01 (size classes for ordinary layout),
D28 (NewDawn ratio by canvas width).

| Site | File and line at HEAD | Read at HEAD | Landed by | Notes |
|---|---|---|---|---|
| Home Toplists | `AppPackage/Sources/HomeFeature/HomeView+Sections.swift:397`, `:484` | `@Environment(\.horizontalSizeClass)`; `else if horizontalSizeClass == .regular` selects `regularWidthGrid`, otherwise `VerticalToplistsStack` | `e03456839a` dropped the `deviceClient.deviceType() == .pad` conjunct | The same file also reads `horizontalSizeClass` for the stack width fraction (`:552`, `:591`) and the slideshow viewport (`:25`, `:207`); no idiom read. |
| GalleryCardCell | `AppPackage/Sources/HomeFeature/GalleryCardCell.swift:119`, `:172` | Container fitting: `ViewThatFits(in: .vertical)` picks the 4-line, 2-line or compact card arrangement; `ViewThatFits(in: .horizontal)` picks the rating form. The compact arrangement is chosen by the parent through `usesCompactInformation` (from `GalleryViewport` and the horizontal size class, `HomeView+Sections.swift:207`) | `e03456839a` replaced the idiom title-trim read with `horizontalSizeClass`; `1cc211aee` later replaced that read with the title-simplification setting | No size-class or idiom read remains in the cell itself. |
| Search keywords | `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift:9`, `:43` | `@Environment(\.horizontalSizeClass)`; `if horizontalSizeClass == .regular` lays out two keyword columns, otherwise one | `e03456839a` | |
| TagSuggestion | `AppPackage/Sources/AppComponents/TagSuggestionView.swift:17`, `:34`, `:57`, `:96` | `@Environment(\.searchSuggestionsPlacement)`; `searchSuggestionsPlacement != .menu` shows the inline count header and inline completing rows, the menu placement shows plain completions | `e03456839a` | Reads the system's suggestion placement, which follows the room around the search field, not the device. |
| NewDawn | `AppPackage/Sources/AppComponents/NewDawnView.swift:42` | Container fitting inside `Canvas`: `size.width >= 500 ? 0.5 : 0.6` sun width | `e03456839a` (size class), then `30ef583d21` (canvas width, D28) | A compact-class iPad form sheet is 580 pt wide, so the canvas width rather than the size class decides. |

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

Source HEAD: `4ea5dbd22` (no app source change since `c5bc2c98b`). Landing commit `605b4e4749`
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

Source HEAD: `d37f4bd19` (no app source change since `c5bc2c98b`). Landing commit `605b4e4749` is an
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
`topReadingFlush` and `readingFlushAction`. `605b4e4749` removed only `routeGalleryDetail` and its
`AppTools` import from this file.

Invariants: in `605b4e4749` the Downloads and Search reducer diffs change only the tap route, the
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
