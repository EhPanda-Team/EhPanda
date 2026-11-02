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

Source HEAD: `c5bc2c98b`. Landing commits `e89e896634` ("pick layouts by size class, not idiom")
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
