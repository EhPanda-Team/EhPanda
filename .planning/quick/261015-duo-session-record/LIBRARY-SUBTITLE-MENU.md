# Library main title and source-menu subtitle — D137

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner clarification

The owner means **one navigation-title region**: Library as the main title, with a
Favorites/Downloads menu as its subtitle. A separate centered or trailing toolbar menu does not
meet this request. The two D136 layout alternatives are therefore superseded, not selected.
D136's rejection of a custom tab bar remains in force.

## Native API and measured result

SwiftUI provides public `.subtitle` and `.largeSubtitle` toolbar placements, available since
iOS 26. These accept arbitrary view content, including a native Menu. They are separate from
`navigationSubtitle`, whose overloads accept text, and from `toolbarTitleMenu`, which adds a menu
to the title itself. No UIKit hierarchy introspection, replacement navigation bar or custom tab
bar is necessary for this composition.

The Xcode 27.1 SDK interface and Apple's documentation confirm these APIs:

- [subtitle](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/subtitle)
  supplies the inline subtitle slot.
- [largeSubtitle](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/largesubtitle)
  supplies the large-title subtitle slot.
- [navigationSubtitle](https://developer.apple.com/documentation/swiftui/view/navigationsubtitle(_:))
  provides text-only subtitle values.

A standalone native probe on a task-owned iPhone 17 / iOS 27.0 simulator retained
`.navigationTitle("Library")` and `.toolbarTitleDisplayMode(.inlineLarge)`, with a Menu containing
an inline Favorites/Downloads Picker. It used a neutral list and a representative trailing Grid
button. Three cold-entry renders isolated the relevant placement:

| Supplied menu placement | Observed result with `.inlineLarge` |
|---|---|
| `.subtitle` only | Library title remains; the menu is not displayed in this state. |
| `.largeSubtitle` only | Library main title and source-menu subtitle appear in the same native title region. |
| Both placements | The same two-line composition appears; no duplicate subtitle is rendered. |

The system reduces the main title's rendered font size to accommodate the subtitle while keeping
`.inlineLarge`. Thus retaining that display mode does **not** mean preserving the previous
single-line title's exact font size. No title font, navigation-bar height or manual offset was set.
The probe's disclosure glyph is part of its neutral Menu label; it is not the automatic
`toolbarTitleMenu` indicator. Production integration should use the existing localized Labels
and typed symbols.

Historical screenshot: Native title region with Library and source menu (image removed from repository history)

The image above is a top crop of the unaltered native screenshot (image removed from repository history).
This is an isolated API probe, not the full app.

## Verification and delivery boundary

- Compiled with Xcode 27.1's simulator SDK, targeting iOS 27.0; compiler emitted no warnings/errors.
- Verified native cold-entry rendering for the three placement combinations above.
- Menu interaction, source changes, navigation/search state, scrolling, live resizing, accessibility
  sizes, and iPad/Duo behavior were not verified in this isolated rendering probe.
- The standalone source and original screenshots remain locally in
  `/tmp/ehpanda-subtitle-menu-probe/`. The task simulator was shut down and deleted afterward.
- No production Swift or test code was changed. The existing review-device installations and native
  tab bar were untouched. D133 remains the installed source-switch implementation.
- D137 clarifies the requested design and establishes native feasibility; it does not claim that
  D134's production integration or D135's native-tab long-press request is complete.

The earlier conclusion that `toolbarTitleMenu` requires `.inline` on the measured runtime remains
scoped to that API. It does not apply to this separate native subtitle-menu composition.
