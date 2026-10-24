# Library main title and source-menu subtitle — D137

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Current follow-up: D139 accepts the system circular arrow beside the Library main title and
requests that appearance with `.inlineLarge`. The remaining obstacle is the display mode, not
the arrow's placement: native title-menu probes on 27.0 and 27.1 show no arrow with `.inlineLarge`.
The manual glyph in D137 is not system-provided. No new production layout has been selected.

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


## System circular menu indicator — D138, 2026-10-24

The owner asks whether the system circular downward chevron from the original title-menu
screenshot can be retained. The original D137 probe added a literal `⌄` in its Menu label; that
was an app-authored glyph, not the native title-menu disclosure indicator.

Apple provides [menuIndicator](https://developer.apple.com/documentation/swiftui/view/menuindicator(_:))
to request indicator visibility. It does not expose a choice of circular title-menu indicator
style or a way to move the title-menu affordance to the subtitle. The documented
[toolbarTitleMenu](https://developer.apple.com/documentation/swiftui/view/toolbartitlemenu(content:))
presents actions from the navigation title. The installed SDK exposes `titleMenuProvider` in
UIKit but no separate subtitle-menu provider.

A fresh standalone probe, compiled against Xcode 27.1 and run on an isolated iPhone 17 / iOS 27.0,
removed all manual arrow text and compared these configurations:

| Configuration | Observed cold-entry rendering |
|---|---|
| Native Menu in `.largeSubtitle`, automatic indicator | No arrow displayed. |
| Same Menu with `.menuIndicator(.visible)` | No arrow displayed. |
| Same Menu with `.menuStyle(.button)`, `.buttonStyle(.borderless)` and visible indicator | No arrow displayed. |
| Native text `navigationSubtitle`, `ToolbarTitleMenu`, `.inline` | The system circular arrow appears beside **Library**, with Favorites underneath as secondary subtitle text. Both are in one title region. |
| Native text `navigationSubtitle`, `ToolbarTitleMenu`, `.inlineLarge` | Library and Favorites render, but no circular title-menu arrow is displayed. |

### System title-menu arrow with a text subtitle

Historical screenshot: Native circular title-menu arrow and subtitle (image removed from repository history)

This preserves the exact **kind** of system title-menu arrow, but changes the root to `.inline`
and places the menu affordance beside the main title. It does not put an independently actionable
menu or arrow beside the Favorites subtitle. In this simple probe the title group is centered;
full-app toolbar composition may affect placement, as in the earlier app screenshot.

### Subtitle Menu with the system indicator requested

Historical screenshot: Subtitle Menu with menuIndicator visible (image removed from repository history)

The requested main-title/menu-subtitle hierarchy can render using `.largeSubtitle`, but the
circular arrow cannot be claimed for that composition based on these results. No public route
that preserves both that exact subtitle interaction and the original circular arrow was found.
This is scoped to the tested runtime and configurations, not a claim about all future SDKs.

Compilation emitted no warnings/errors. These are rendering probes only: no menu interaction,
source switching, accessibility-size, rotation or full-app regression pass is claimed. No
production source or test code changed, and no alternative was selected for the owner. All original
screenshots and source remain in `/tmp/ehpanda-subtitle-indicator-probe/`; the two retained images
are unretouched top crops. The task simulator was removed after capture. The three review devices
and their app data were untouched. Native tabs remain required; D135 remains unimplemented.


## Main-title arrow accepted; inline-large combination requested — D139, 2026-10-24

The owner accepts placing the system arrow beside **Library** rather than beside the source
subtitle. That supersedes the earlier subtitle-arrow placement requirement. The owner asks to
see the main title, subtitle, native arrow and `.inlineLarge` together; it does not authorize
substituting `.inline`, drawing a replacement arrow or replacing the native tab bar.

### Actual `.inlineLarge` rendering

The retained iPhone 17 / iOS 27.0 render below has `navigationTitle("Library")`, a text
`navigationSubtitle`, `.toolbarTitleDisplayMode(.inlineLarge)`, and a `ToolbarTitleMenu` containing
the source Picker. The native menu was supplied; the system arrow did not render.

Historical screenshot: Inline-large native title menu without a rendered arrow (image removed from repository history)

### Targeted iOS 27.1 follow-up

To check whether the earlier result was limited to the runtime or indicator visibility, a new
standalone probe applied `.menuIndicator(.visible)` to the page owning `ToolbarTitleMenu`, rather
than to a subtitle Menu. It also checked the public `.browser` toolbar role. Four native renders
on a task-owned Duo / iOS 27.1 produced:

| Title mode / configuration | Observed system circular arrow |
|---|---|
| `.inlineLarge`, automatic indicator and role | Absent |
| `.inlineLarge`, explicitly visible indicator | Absent |
| `.inlineLarge`, explicitly visible indicator and browser role | Absent |
| `.inline`, automatic indicator and role, same main title/subtitle/menu | Present beside Library |

Historical screenshot: iOS 27.1 inline-large with visible indicator requested (image removed from repository history)

Historical screenshot: iOS 27.1 inline control showing the native arrow (image removed from repository history)

Apple's [inline-large documentation](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/inlinelarge)
describes title sizing/toolbar placement; [menuIndicator](https://developer.apple.com/documentation/swiftui/view/menuindicator(_:))
requests indicator visibility. Neither documents a way to force the native title-menu circular
arrow into this mode. These measurements establish the behavior of the tested combinations,
not an assertion that every possible future OS implementation is incapable of it.

The installed 27.1 runtime supports only Duo: an attempted iPhone 17 simulator creation was
rejected as incompatible and yielded no device. The Duo boot-status stream reported a data
migration failure, but installation, all four app launches and all four captures succeeded.
The captures show the probe itself and the `.inline` positive control. the simulator pose driver reported closed,
portrait; screenshots use display 1 (LCD, 1398 by 2034, reported portrait) and visibly include the
runtime's side status region. They are title-rendering evidence, not a full-app posture-validation
claim. Compiler output was clean; no interaction, accessibility or app regression test was run.
The task-owned Duo was deleted afterward, and the existing review devices were untouched.

Original source and full screenshots are retained in `/tmp/ehpanda-inlinelarge-native-title-probe/`.
No production files changed. D133 remains installed; D139's exact native combination is not claimed
as achieved. The accepted arrow placement is recorded for subsequent implementation choices.
