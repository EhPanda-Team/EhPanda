# Library title menu and tab long-press investigation — 2026-10-24

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Current native-only direction

D136 rejects custom tab bars. D137 clarifies that Library and the source-menu subtitle must
occupy one navigation-title region. A native `.largeSubtitle` Menu with `.inlineLarge` now renders
that composition; see [screenshot and verification limits](LIBRARY-SUBTITLE-MENU.md). The earlier
separate-position alternatives misunderstood this requirement and are superseded. The original
inline title-menu experiment below remains historical; its `.inline` requirement belongs to
`toolbarTitleMenu`, not to the native subtitle-menu route.

## Owner requests and pending choices

D134 requests replacing the phone Library source picker with a navigation title menu.
D135 additionally requests a half-height source-switch sheet opened directly by a long press
on the Library tab. These are two entry points to the same Downloads/Favorites selection.
The established iPad/Duo sidebar routing is not being redesigned.

The native title-menu prototype is functional, but it changes the phone root title from
`.inlineLarge` to `.inline`. The repository navigation policy explicitly preserves the former.
The owner requested the closed-menu screenshot before deciding that exception and explicitly
authorized research into a custom tab bar. That research is recorded in
[CUSTOM-TAB-BAR-FEASIBILITY.md](CUSTOM-TAB-BAR-FEASIBILITY.md), together with the requested closed
screenshot. Authorization to research does not approve shipping a custom bar or the title change.

## Native API evidence

Apple documents [toolbarTitleMenu](https://developer.apple.com/documentation/swiftui/view/toolbartitlemenu(content:))
and [ToolbarTitleMenu](https://developer.apple.com/documentation/swiftui/toolbartitlemenu) for actions opened by tapping
the navigation title. A minimal SwiftUI probe on an isolated iPhone 17 / iOS 27.0 simulator
compared the modifier, an explicit toolbar title-menu item, and `.inline` display mode.
Both `.inlineLarge` variants displayed the large title without a menu affordance. `.inline`
displayed the native disclosure control. The real app reproduced this distinction.
This is measured behavior for that runtime, not a claim about every future OS version.

The working app prototype supplies a localized Label-based Picker through a content slot in
FavoritesView and DownloadsView. Only the phone Library branch supplies the menu and requests
`.inline`; the sidebar branches retain `.inlineLarge`. The floating safe-area picker is removed.
The native system chooses the title's placement alongside the existing toolbar items: in the
Favorites screenshot below it is leading, rather than necessarily centered.

Historical screenshot: Native Library title menu proposal (image removed from repository history)

Apple's [Tab contextMenu documentation](https://developer.apple.com/documentation/swiftui/tabcontent/contextmenu(menuitems:))
limits that modifier to the tab's sidebar representation. The installed 27.1 SwiftUI TabContent
interface and UIKit UITab/UITabBarItem/UITabBarController headers did not expose a direct
per-tab long-press callback for the bottom or vertical native tab bar. A gesture on arbitrary
private subviews, guessed tab hit regions, or a replacement tab bar has not been introduced.
A custom bar would need separate design approval and would not automatically inherit Duo's
native tab scrubbing, labels, placement, and compression behavior. A half-height sheet itself
is supported; the unresolved part is the requested native-tab gesture entry point.

## Verification and disposition

Evidence root: `.build/phone-layout-review/` (ignored local artifacts).

- `title-menu-build.log` / `.xcresult`: original `.inlineLarge` attempt compiled, but the
  native iPhone title was not actionable. This is not counted as functional success.
- `title-menu-inline-build.log` / `.xcresult`: the `.inline` prototype's build-for-testing
  passed without compiler warnings/errors (50.813 seconds).
- `title-menu-inline-ui.log` / `.xcresult`: the focused category/source switching test passed
  once, with one test and zero failures (34.967 seconds). It opens the Favorites title menu,
  switches to Downloads, selects Inbox, returns through the Downloads title menu, and verifies
  the remembered Favorites Grid layout and absence of phone sidebar/floating picker.
- The generated local `LibraryTitleMenu-single-shot.xctestrun` omits the repetition policy;
  the repository test plan is unchanged. An earlier invocation with `-test-iterations 1` was
  rejected by xcodebuild before testing and supplies no test evidence.
- The isolated fixture simulator contains no owner account data. Review-device cookies and
  app data were not seeded by this task. No iPad or accessibility-size regression pass is
  claimed for the pending title-mode exception.
- `title-menu-prototype.patch` preserves the four-file functional prototype against
  `41efc36215` for the owner's choice. Production Swift and test changes are restored to the
  approved baseline while that choice is pending. The large-title baseline app is rebuilt
  for the two review phones so the unsuccessful large-title attempt does not remove their
  usable source switch.

The baseline restoration build passed without compiler warnings/errors (56.207 seconds;
`title-menu-baseline-restore.log` / `.xcresult`). Both review phones were installed and launched
normally, with no automation environment; `title-menu-baseline-delivery.json` records success.
The task-owned simulator was shut down and deleted. The three retained review devices remain.
Source/test files match the approved baseline; this delivery contains documentation only.

No long-press sheet is implemented. D133 remains the shipped source-switch design until the
owner accepts a replacement. Phase 17 acceptance gates remain unchanged.
