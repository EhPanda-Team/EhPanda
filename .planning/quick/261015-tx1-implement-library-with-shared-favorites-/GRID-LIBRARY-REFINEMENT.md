# Grid metadata and Library actions follow-up

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Implemented D82–D84 in `8b2f03519b968c1ec09157a4d92cbfd5f3f750ac` on `agent/app-design`.
D85 remains an investigated presentation question.

## Owner request and scoped plan — 2026-10-16

- D82: Remove horizontal padding from the information below every grid cover, preserving vertical
  spacing and the D81 cover geometry/title policy.
- D83: Hide ratings in Library grids (Favorites and Downloads), while retaining them in other grids
  and leaving row presentation unchanged. Pass an explicit, default-enabled grid rating policy.
- D84: Replace the visible Downloads grid Actions menu with a native context menu on the card.
  Retain the shared row action predicates, accessibility actions and stable per-gallery dialog anchor.
- D85: Investigate whether Details/Pages could use a right-side floating inspector without taking
  list width. This is a question about presentation, not approval of a replacement navigation design.

Implement the first three items, then check mixed-title alignment, rating scope, long-press Pages,
move, local reading and cancellation/confirmed deletion. Use isolated fixture simulators and retain
neutral screenshots. Update the review iPad in place. Record exact source/test evidence below.

## Inspector API findings

Current Downloads Pages is a native sheet; Details uses the existing gallery navigation. No SwiftUI
`.inspector` modifier is currently applied. Xcode 27.1's SwiftUI public interface exposes inspector
presentation and column-width preferences, with no switch to force a floating right-edge overlay.

Apple documents context-dependent presentation: a regular-width trailing column, compact sheet,
and automatic overlay in some iPad split-screen conditions. Width preferences do not force overlay.
A native popover can float without resizing the list, but is anchored to a source rather than
promising a right-edge slide. An app-owned trailing overlay can guarantee that motion/placement,
but needs its own focus, dismissal, resizing and Reduce Motion behavior. No size-class overrides,
private inspection or custom panel are introduced by this follow-up.

- [Inspector API](https://developer.apple.com/documentation/swiftui/view/inspector(ispresented:content:))
- [Apple inspector presentation overview](https://developer.apple.com/videos/play/wwdc2023/10161/)

The presentation choice remains open; existing Pages and Details behavior is preserved.

## Implementation details

The shared cell keeps vertical padding while allowing the title and metadata to use the full cover
width. `showsGridRating` defaults to true in GalleryList; Favorites passes false, and Downloads
passes false to its direct cell. The policy affects grid only and does not change stored ratings,
row cells or gallery detail. Other callers retain the default.

Downloads removes the Actions Menu and its extra stack. The card itself owns the native context
menu, named accessibility actions and row-store confirmation binding. Context menus share the row's
Detail, Pages, Move to Folder, update, pause/resume and delete builders/predicates. Folder moves use
the existing native submenu; accessibility Move retains its existing confirmation destination
chooser. The source card remains identifiable and anchors the delete popover after the menu closes.

## Corrected test measurement

The first `grid-refinement-ipad-01` run passed the non-Library rating and Downloads management tests,
but a new geometry assertion expected a short Text accessibility frame to fill its parent's width.
XCTest reports the intrinsic text extent: its trailing edge was 412.5 pt while the card ended at
541.5 pt. The test now measures the leading title edge, bounds its trailing extent, and checks the
standard-size trailing language against the card's trailing edge. The independent row-height
assertions and all four text-size checks remain. No production change was needed for this failure.

## Final verification and review state

Xcode 27.1, iOS/iPadOS 27.0 simulators. Both selections enumerate each identity and run it once,
without retries or skips; all tracked source hashes match the implementation revision above.

| Evidence under `.build/library/` | Result |
|---|---|
| `grid-refinement-ipad-02` | 3/3 UI tests: Favorites geometry/rating absence at standard, AX1, AX3 and AX5; Frontpage retains ratings; Downloads row and grid management. |
| `grid-refinement-iphone-01` | 2/2 UI tests: native Favorites/grid bounds at the same four text sizes; Downloads row and grid management in landscape. |

Both Downloads checks open Pages from row and long-press grid, move a gallery using the native
submenu, open/read local pages, cancel deletion, confirm deletion of only that gallery, and relaunch
to verify the remaining gallery. Screenshots show the native context menu and source-card delete
popover. Explicit Actions buttons and Library grid rating elements are absent.

Both builds report zero compiler/analyzer warnings and errors. Strict SwiftLint has zero violations
in all six changed Swift files. Review confirms explicit default-on rating input, no row rating
change, no new persistence/reducer behavior, and per-gallery confirmation ownership on the stable
card. No full model, all-screen, live-resize, VoiceOver rotor or physical-device suite was repeated.
This does not close Phase 17 or the owner-deferred native header issue.

[Fifteen original fixture screenshots](screenshots/grid-refinement-manifest.json) are retained with
source paths and SHA256 hashes, unedited. The Frontpage screenshot checks ratings using the existing
list fixture; its placeholder covers are not evidence of completed cover loading.

- iPad Favorites (image removed from repository history)
- iPad Downloads (image removed from repository history)
- iPad context menu (image removed from repository history)
- iPad anchored confirmation (image removed from repository history)
- iPhone Favorites (image removed from repository history)
- iPhone context menu (image removed from repository history)

The normal review iPad is updated in place, preserving account/data, and open at Library Favorites.
Its local-only screenshot confirms no horizontal metadata inset and no ratings. The disposable
fixture iPad was deleted after export; the dedicated iPhone returned to Shutdown. The existing
proposal preview remains available. Details and Pages retain their existing presentation; a forced
right-edge floating panel has not been selected or implemented.

## Subsequent trial — D86

The owner subsequently authorized a working trial. [D86](FLOATING-PANEL-PROTOTYPE.md) adds the
native iOS 27 trailing form-sheet alternative, which was missing from D85's option list. The
SwiftUI inspector-style finding above is historical; D87 later measured the actual native overlay.
D88 rejects both presentation trials and restores the pre-trial behavior, while retaining D82–D84
grid refinements. See [rollback record](PRESENTATION-TRIAL-ROLLBACK.md).
