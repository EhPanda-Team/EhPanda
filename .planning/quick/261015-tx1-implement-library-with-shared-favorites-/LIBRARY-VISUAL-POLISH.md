# Library visual follow-up — D90

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decision and scope

- Row titles must use leading text alignment, including wrapped lines inside native Buttons.
- Detail's preview strip and the full Previews page need the same neutral image background as
  other covers.
- Grid context menus must omit Detail and Read. Downloads retains its management actions and
  its lifted preview wraps the whole grid cell in a container with an opaque background.

This supersedes only D89's grid-menu Read affordance. Single-tap Detail, double-tap reading,
row menus and the accessible Read action remain. Favorites' grid had no other menu action, so
its empty menu is removed. No new Favorites management action or presentation redesign is added.

## Implementation and review plan

1. Explicitly set multiline leading alignment on the shared row title, at the text source.
2. Share a Detail-owned `PreviewThumbnail` tile across the strip and full-page grid. Retain the
   existing 8:11 preview-slot aspect, fitted artwork, neutral light/dark background and 5 pt rounded
   clip. Keep image loading in `PreviewImageView`; reader slider thumbnails are outside this change.
3. Use native `contextMenu(menuItems:preview:)` on Downloads grid cards. Render the same cell at
   its measured width in a 12 pt inset, opaque system-background container with 24 pt corners.
   The ordinary grid remains transparent. Keep confirmation anchored to the stable gallery item.
4. Adjust the existing tap/menu tests for the owner-approved menu change. Verify native Library
   interaction/management and existing Detail/Previews accessibility audits; inspect retained
   screenshots, run strict lint and update the original review iPad without replacing its data.

SwiftUI specialist guidance is used for planning, implementation and review. Apple's native
[context menu preview API](https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:preview:))
owns presentation. The shared row title uses
[multilineTextAlignment](https://developer.apple.com/documentation/swiftui/view/multilinetextalignment(_:)).

## Verification

Implementation commit: `2f5706b0cfa24a5e880cdc301b3a457b153632b8`.

All runs use Xcode 27.1 and iOS/iPadOS 27.0 build 24A434. Evidence is retained under
`.build/library/`; each run records source hashes, exact test identities and result bundles.

| Run | Result | Scope |
|---|---|---|
| `library-polish-ipad-01` | 5 passed, 0 failed/skipped | Detail and Previews accessibility audits; Downloads management; Favorites/Downloads single- and double-tap routes in row/grid |
| `library-polish-iphone-01` | 1 passed, 1 failed | Previews audit passes; landscape Downloads management stops at the grid Pages action |
| `library-polish-iphone-02` | 1 failed | Controlled repeat reproduces the same Pages failure on unchanged sources |
| `library-polish-iphone-03` | 2 passed, 0 failed/skipped | Favorites/Downloads single- and double-tap routes in row/grid |
| `library-polish-lint.log` | 7 files, 0 violations | Strict SwiftLint for all changed Swift source/tests |

Builds report zero compiler/analyzer warnings and zero errors. The iPhone management failure is
not skipped, converted into an expected failure, retried until green, or concealed by the separate
passing selections. The new grid assertions verify that Detail/Read are absent. iPad management
covers Pages, moving a gallery, reading, cancel/confirm deletion and durable deletion after relaunch.

### Remaining native menu defect

On iPhone Air landscape (912 × 420 points), the three-item native menu sits at y=20. Its Pages
button spans y=30…72. Both XCUITest and direct native-driver activation at the semantic center
(x≈335, y=51) leave the menu visible. A diagnostic tap within the same button at (300,65) opens
Download Status. Moving the gallery is not required to reproduce this. No presentation error is
logged; public UIKit hit-testing reaches the expected menu cell at both points.

The independent native [reproducer](NATIVE-MENU-HIT-TEST.md) reproduces the failure without EhPanda
models, gestures, downloads, custom cover rendering or reducers. A version without ScrollView
passes. Removing the custom soft-edge policy or clearing its inherited style does **not** fix it;
the initial scroll-edge hypothesis was disproved. The confirmed boundary is native scrolling plus
context-menu presentation, not a proven implementation detail inside UIKit.

This remains unresolved. No coordinate-shift, delayed tap, private-API patch, menu padding item,
changed menu ordering or scrolling-policy exception is added to production/tests. The original
failing test and recording remain available. A supported framework fix or separately reviewed
presentation change is needed before claiming all-device management verification.

### Visual evidence and limits

Five unedited iPad screenshots and their SHA-256/attachment provenance are recorded in
`screenshots/library-polish-manifest.json`. The menu preview shows the entire cell inside its
opaque container; normal cards remain transparent. Row screenshots cover both Library sources.
Detail/Previews screenshots verify background tiles and placeholder geometry. Their hermetic
remote image responses deliberately do not load, so they do not establish successful remote
artwork letterboxing. The explicit leading text modifier is reviewed at the shared title source;
the retained short-title fixtures do not exercise wrapped multi-line title alignment.

The original review iPad is updated in place and open on Library Favorites with its existing
account/data. No fixture or login override is used for that launch. All four native runs’ source hashes match this implementation commit, including the new preview
tile. The dedicated iPhone returned to its original Large/Shutdown baseline; the disposable iPad
and standalone probe app were removed. The native-driver session is closed and its test-owned
download fixtures were removed. The existing browser preview was not changed.

No Phase 17 completion, physical VoiceOver verification, exhaustive Dynamic Type sweep or
resolution of the deferred sidebar header issue is implied. D88's rejected sheet/inspector trials
remain reverted.

### Screenshots

- Downloads native menu preview (image removed from repository history)
- Downloads row (image removed from repository history) and Favorites row (image removed from repository history)
- Detail preview strip (image removed from repository history) and Previews grid (image removed from repository history)
- iPhone landscape menu at the failing geometry (image removed from repository history)
