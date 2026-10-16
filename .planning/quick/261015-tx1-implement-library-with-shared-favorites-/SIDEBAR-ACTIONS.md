# Library sidebar navigation and section actions

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

**Later owner decision:** D76 supersedes D69's hidden-toggle/fixed-open policy. Native hide/show
is restored, initially expanded; section ordering, disclosure and actions remain. See
[HEADER-STABILITY.md](HEADER-STABILITY.md) for the retained issue and final validation.

Implemented owner decisions D69–D73 in `21473abc07` on `agent/app-design` (2026-10-16).

## Owner decisions and implementation

| Decision | Result |
|---|---|
| D69: Hide the sidebar toggle and keep the sidebar expanded | NavigationSplitView uses constant all-column visibility and balanced style; the sidebar removes the native sidebarToggle item. Native compact navigation still uses push/back. |
| D70: Remove duplicate Manage Folders from Downloads toolbar | The Filters menu retains only its folder filter picker; GalleryLayoutPicker remains. The folder-manager presentation route remains available through Library. |
| D71: Downloads above Favorites; both sections expandable | Downloads is first. Section(isExpanded:) binds to separate LibraryFeature state properties, initially true, retaining each state across source changes and view adaptation. Selection is independent of expansion. |
| D72: Detail-equivalent Create Default Folder action | Appears only when no folders exist, matching Detail. Uses its existing default name and symbol, with the six-locale label promoted to Resources for both callers. |
| D73: Use section action APIs | Both Manage Folders and Create Default Folder live in .sectionActions on Downloads. No custom header buttons or disclosure controls. |

Apple documents [toolbar removal and split visibility](https://developer.apple.com/documentation/swiftui/navigationsplitview)
and [sectionActions](https://developer.apple.com/documentation/swiftui/view/sectionactions(content:)).
The SDK declarations were checked with Xcode 27.1. On iOS the native API renders section actions
as rows after section content; those actions remain visible when the section's contents collapse.
This is native section-action behavior, not ordinary rows left inside the section content builder.

There is no device-identity branch, screen-width threshold, custom split controller, global window lookup,
manual inset, or title/search fallback. D68's top-only safe-area expansion and soft scroll edges stay
intact. Constant visibility is a native preference; the practical no-collapse claim below is based
on the gestures and transitions actually verified, not an undocumented universal gesture guarantee.

## Folder operation ownership

Library first selects Downloads so completion feedback has a visible owner, then asks
DownloadsReducer to create `Defaults.FilePath.defaultDownloadFolder` through DownloadClient.
The reducer remains busy through creation and its authoritative folder fetch, then updates the
folder list and re-enables the control atomically. Failure produces the existing toast style and
an error haptic; the operation can be retried. Success gives the same haptic as Detail.

Review identified and corrected two related races before delivery: a second tap during the
post-create refresh, and an older standalone folder fetch overwriting the new snapshot. Starting
creation cancels the existing standalone fetch; standalone fetch requests are skipped while
creation owns the refresh. The test suspends that refresh and submits both another create request
and another fetch request before allowing completion.

All planned source files were updated: LibraryView, LibraryFeature, AppReducer, DownloadsView,
DownloadsReducer, shared Resources and the Detail caller/catalog. Package.swift adds the existing
local HapticsClient dependency. No new third-party package, module, page or scroll-edge inventory
entry is needed. The download manifest and gallery-folder deletion policies are unchanged.

## Verification

Evidence is local under `.build/library/sidebar-actions/`; selected unedited screenshots and their
SHA-256/source manifest are tracked in `screenshots/`.

| Check | Actual evidence |
|---|---|
| Final focused tests | `final.xcresult`: 4 LibraryNavigationTests and 5 DownloadsReducerRefreshTests pass, including the two new creation tests; zero compiler warnings/errors |
| Strict SwiftLint | `lint-final.log`: zero violations in all eight changed Swift source/test files (Package.swift is package configuration) |
| Independent pre/post review | Native API scope reviewed; both concurrency findings corrected; no remaining actionable source findings |
| iPad native toggle/gestures | Toggle absent; leftward swipes across the sidebar before and after rotation do not hide it |
| iPad section disclosure | Downloads and Favorites collapse/expand independently; right-side selection survives; native section actions remain available |
| iPad folder actions | Creating from Favorites switches to Downloads, creates Default and removes the bootstrap action; Manage Folders opens its Folders sheet; Filters contains only All/Default |
| Final-build compact iPhone | Native Library back navigation works. Create Default Folder from Library opens Downloads and adds Default; no toolbar manager duplicate |
| iPad/iPhone text sizes | Standard, AX1, AX3, AX5 cold entry and live changes captured independently; both size scripts complete and restore large text |
| iPad rotation | Landscape-right → portrait-upside-down → landscape-right retains expanded columns and clear native controls |
| Duo transitions | Closed → open → half → tall orientation → closed retains the same process; screenshots show both columns in expanded layouts and native side/top/bottom bars |
| D68 regression | Scrolled iPad capture still shows continuous native blur behind the status bar |
| Patch and localization | git diff --check passes; existing six translations moved intact to the shared key |

Early compile attempts exposed a required explicit UIKit import for haptic enum cases and an extra
closing parenthesis introduced while addressing review; both were fixed, and final tests compile
cleanly. One simulator pose driver invocation omitted DEVELOPER_DIR and failed before changing device state; the
explicit current Xcode path corrected it. Duo's accessibility outline under-reported expanded
controls and reported uncertain orientation, so screenshots establish its expanded visual result;
no coordinate interactions were attempted against that uncertain outline. No app crash was observed.

This focused follow-up does not claim a rerun of all UI/FeatureTests suites, iPad window resizing,
physical-device, full VoiceOver or RTL testing. Prior broad evidence retains its original revision.
The first iPad bootstrap interaction preceded the final cancellation refinement; final-build
compact iPhone creation and the final focused tests verify the delivered operation.

## Review state and screenshots

The iPad is left open on Library / Downloads in landscape-right, light appearance, large text and
Full Screen Apps, with both sections expanded. Its newly created empty Default folder is retained.
The dedicated compact iPhone also retains the empty Default folder created during validation, was
restored to large text and shut down. Duo is closed/hardware portrait and shut down. The proposal
preview stays stopped. No unrelated simulator was operated.

- Empty folders: native creation action (image removed from repository history)
- Final iPad Library / Downloads (image removed from repository history)
- Both sections collapsed; native actions remain (image removed from repository history)
- Scrolled blur continuity (image removed from repository history)
- iPad portrait columns (image removed from repository history)
- Compact iPhone AX5 Library (image removed from repository history)
- Duo open (image removed from repository history)
- Duo tall layout (image removed from repository history)

## Folder-only navigation follow-up — D77

Owner removes the generic Downloads navigation item because downloads belong to a folder.
`b2d1d602dc` removes that all-downloads link from the Library sidebar. Actual folder links,
Manage Folders, conditional Create Default Folder and the restored native toggle remain.
This is an entry-point change: existing aggregate filtering and internal presentation routes
are not retired. No folder or downloaded content is removed.

The existing category-navigation UI test now creates its own download fixture root and selects
Inbox, then returns to Favorites and checks that its grid choice survives. Cleanup removes only
that test-owned root. The scroll toward Downloads follows its current position above Favorites.

Evidence under `.build/library/folder-entry/`:

- `build-results.json`: build-for-testing succeeds with zero warnings and errors.
- `result.json`, `selected-tests.xcresult`: the one enumerated navigation regression passes on
  the dedicated iPhone Air / iOS 27.0, with zero failures, skips or repetitions.
- Strict no-cache SwiftLint passes both changed Swift files with zero violations; diff check passes.
- `ipad-final-ui.txt` and `ipad-final.png`: the updated iPad / iPadOS 27.0 sidebar contains Default
  and Manage Folders under Downloads, with no generic Downloads row; tapping Default opens its
  Downloads page. Native toggle and both section disclosure controls remain visible.
- Unedited final iPad screenshot (image removed from repository history), with source
  and SHA-256 in the screenshot manifest.

The compact simulator's sim-use preflight could not read its hierarchy after auto-recovery;
no sim-use interaction followed there. The independent native XCTest run above passed. The iPad
preflight and native interactions succeeded. The compact simulator returned to Shutdown; the
normal iPad app remains open on Library / Default in landscape-right for owner review.

This focused row removal does not rerun the full feature/UI matrix or claim to resolve the
owner-deferred header displacement. The broader evidence retains its original revision.
