# Phone Home information and Library source switch — 2026-10-23

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decisions

- D130: Apply the iPad Frontpage, Toplists and Other section changes to iPhone for review.
  Show the established cover sizes and metadata, the ranking fields and flexible gaps, and
  the Other description/divider/footnote cards. Slideshow remains outside this change.
- D131: Replace Library's collapsed navigation split view on ordinary iPhone with a glass
  Downloads/Favorites toggle at the lower trailing edge, above the native tab bar.
- D132: Final Duo policy: portrait/landscape closed, portrait partially open and portrait
  fully open use the phone layout. Only landscape partially/fully open retains the current
  native sidebar. iPad keeps its sidebar. This supersedes the intermediate closed-only rule.

## Implementation and verification plan

Home reuses the existing information components. Other cards keep their three-across sizing
at widths of at least 744 points and use 70% of the local viewport below that threshold.
Duo's existing split Home and opposite-pane navigation remain intact.

Library observes local window device/hinge information and the available viewport. The native
segmented Picker uses Liquid Glass and a bottom safe-area inset, with no assumed tab-bar height.
It is shown only at the selected source's navigation root. Favorites categories and download
folder management remain reachable through the source's native menus when the sidebar is absent.
Both sources keep their existing reducer-owned paths, filters, queries and scroll anchors.
An initially unselected phone Library opens the remembered Favorites category.

Verify exact pose rules and source state in focused Library tests; compile and lint the affected
modules. Check the normal app on the retained review iPhone 17 and Duo, including source switching,
folder/category menus and both kinds of layout. Check the retained iPad's unchanged sidebar.
Record native screenshots for owner inspection without publishing live gallery data into this
repository. Keep all three review devices, avoid device erasure and restore normal launch environments.
Record any test-fixture side effects separately from simulator preservation.
Phase 17 acceptance gates are unchanged.

## Results

Implementation commits:

- `6c284c70fddc3b8199fdaa64104bf990859b08e7` — shared Home section information on iPhone.
- `d66f39b7e635c0a605c0cb9fe6abeabd6f0d2cb7` — adaptive Library source switch, native source menus and regressions.

The sidebar owns its own `columnVisibility` state. An initial live rotation check exposed that
keeping this state above the phone/sidebar branch retained `.detailOnly` after returning to
landscape. Moving the state into the actual sidebar host gives each new sidebar an initially
expanded native split view. The existing hide/show control remains available while that host
is present. This does not claim to fix the separately recorded intermittent header displacement.

### Builds and focused tests

Evidence root: `.build/phone-layout-review/` (ignored local build/test output).

| Check | Result | Evidence |
|---|---|---|
| Generic simulator FeatureTests build-for-testing | Pass; no compiler/analyzer warnings or errors | `build.log`, `build.xcresult` |
| Generic simulator UITests build-for-testing | Pass; no compiler/analyzer warnings or errors | `ui-build.log`, `ui-build.xcresult` |
| LibraryNavigationTests on iPhone 17 | 7 test declarations passed, including the five-argument device/shape matrix | `library-tests.log`, `library-tests.xcresult` |
| iPhone native titles/grid and source navigation | 2/2 UI tests passed | `iphone-ui.log`, `iphone-ui.xcresult` |
| iPad native titles/grid and sidebar navigation | 2/2 UI tests passed | `ipad-ui.log`, `ipad-ui.xcresult` |
| Final normal app build after sidebar state ownership fix | Pass; no compiler/analyzer warnings or errors | `final-build.log`, `final-build.xcresult` |
| Pinned SwiftLint strict checks | Zero violations across changed Swift sources/tests | `lint.log`, `lint-final.log` |
| Whitespace diff check | Pass | `git diff --check` |

The UI cases are `GalleryLayoutUITests/testNativeTitlesAndGridAtEveryTextSize` and
`LibraryPresentationUITests/testCategoryNavigationReturnsAndSwitchesSources`. They cover cold
entry at Large, AX1, AX3 and AX5 on both devices. The phone branch switches Favorites → Downloads,
selects a folder and returns to the remembered Favorites grid; iPad uses the original sidebar path.
The inherited test plan permits retries, but these executions passed on their first iteration;
no retry is credited as a pass. Xcode emitted its infrastructure SDK-record/debugger-version
messages; these are distinct from product compiler diagnostics.

The automated runs precede the final extraction of sidebar-owned visibility state. That final
change has a clean normal build, strict lint, and the native rotation/pose checks below; this
record does not present the earlier UI runs as a rerun of the exact final source tree.

### Native runtime checks on the final app

| Duo posture | Portrait | Landscape |
|---|---|---|
| Closed | Phone source picker | Phone source picker |
| Partially open | Phone source picker | Expanded native sidebar |
| Fully open | Phone source picker | Expanded native sidebar |

All six combinations were observed in the running app. Partially open landscape → portrait →
landscape also restores the expanded sidebar. Reducer tests separately prove preservation of
the selected download folder through layout changes, and of remembered Favorites navigation/query
when entering the phone layout.

Live Large → AX1 → AX3 → AX5 → Large changes on iPhone and iPad retain native Favorites titles
and Search. iPhone retains the source picker; iPad retains the sidebar and has no phone picker.
Snapshots/screenshots and result records are in `live-type/`. Both devices return to their original
Large setting. This is a scoped title/search/layout check, not a full accessibility audit.

Normal iPhone Home inspection confirms the richer Frontpage cover metadata, Toplists fields and
Other cards with description, divider and footnote. Live Home requests also exposed an Unknown
Error/loading state for some network content; this layout verification does not claim complete
live-service health. Live gallery screenshots remain ignored and are not published in this record.

### Delivery and evidence boundaries

The final normal app was installed and launched on the existing review iPhone 17, iPhone Duo and
iPad. No review simulator was erased, created or deleted. `final-delivery.json` records successful
installation/launch on all three; `post-check-delivery.json` records normal launch after live
text-size checks. Launch environments contain no automation/capture overrides. Device Hub's main
view is restored with all three review devices available.

The UI fixture runs used the retained review devices. Their existing automation harness changes
some persisted display preferences and replaces authentication cookies with session-only fixture
cookies; therefore this record does **not** claim byte-for-byte preservation of device app data or
of prior login state. Normal relaunches showed the logged-out Favorites state. The harness used a
temporary downloads root; it did not erase the review devices. Future fixture runs should use an
isolated task simulator when preserving review-device preferences or credentials is required.

The screenshot below is from the passing phone UI case, using neutral bundled gallery fixtures.
It shows the final phone source-picker design; the later state-ownership correction affects the
sidebar branch only. The normal app left for review uses live services, not these fixtures.

Historical screenshot: Phone Library with the native glass source picker (image removed from repository history)

Phase 17 acceptance gates remain unchanged. Owner visual acceptance is still pending.



## Symbol-only source picker — D133

On 2026-10-24 the owner clarified that both text and symbols must remain defined, while only
symbols appear visually. `79655f31db0a3ff8854c50f168e75fcc2b0e497c` adds `.labelStyle(.iconOnly)` to the native
segmented Picker. Both localized Labels remain intact: Downloads with `arrow.down.circle`,
Favorites with `heart`. No source-selection, device/posture or placement behavior changes.

The generic simulator build passes with no compiler warnings/errors (`icon-picker-build.log`
and `icon-picker-build.xcresult` under the existing evidence root); strict pinned SwiftLint and
`git diff --check` pass. A normal iPhone launch and native screenshot verify the two symbols and
the smaller control width. Both retained phones were installed/launched successfully, recorded
in `icon-picker-delivery.json`. No fixture launches, cookie replacement, or test-state seeding
were used for this follow-up; the iPad app was not reinstalled because its sidebar is unaffected.

The device automation client could not establish daemon ownership. Native UI interaction plus
a direct simulator screenshot supplied the visual check without resetting shared services.
Localized accessibility names remain supplied by the original Labels; this follow-up does not
claim an independent VoiceOver announcement test. No automated behavior suite was rerun for this
presentation-only modifier. Earlier test results retain their documented source boundaries.

Historical screenshot: Symbol-only phone Library source picker (image removed from repository history)
