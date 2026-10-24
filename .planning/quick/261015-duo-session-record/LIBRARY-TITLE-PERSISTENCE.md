# Library title persistence investigation — D142

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

2026-10-24. The owner asks to prevent the title, subtitle and arrow from disappearing after
scrolling in D141's prototype. This is an isolated native rendering and interaction experiment.
Production still uses D133; a different title mode has not been accepted for production.

## Result and tradeoff

The native `.title` placement with `.toolbarTitleDisplayMode(.inline)`, `.toolbarRole(.browser)`
and `.toolbarMinimizationBehavior(.never, for: .navigationBar)` retains the main-title Menu,
app-drawn circular chevron and native source subtitle after scrolling. The Menu label keeps the
same `.title2.bold()` styling as D140/D141. No scroll-offset tracking, view-hierarchy introspection,
custom navigation bar, custom tab bar or dynamic-type branch is introduced.

This is **not an `.inlineLarge` fix**: it changes title mode to `.inline` and the custom Menu slot
from `.largeTitle` to `.title`. On iPad, the native title/subtitle move upward alongside the floating
tabs instead of occupying the large-title region below them. The search field still follows native
scroll behavior. The prototype source remains available; the historical images have been removed; accepting that title-mode/layout tradeoff
and integration into the actual Library remain pending.

[Twenty new screenshots](evidence/library-title-matrix/persistent/index.html) compare 10 initial/
scrolled pairs. The gallery links back to D141's unmodified baseline. The historical run produced full-size captures and 200-point header crops. Those images are no
longer included; the linked page now retains configuration metadata only.

Historical screenshot: Persistent-title screenshot gallery (image removed from repository history)

## Native API investigation

First, the D141 source was changed by adding only the native `.never` minimization policy. The
original `.inlineLarge` title/subtitle/Menu still disappear on iPhone after a real scroll gesture.
The toolbar's trailing control remains. The [failed trial source](evidence/library-title-matrix/persistent/probe/NeverOnlyProbe.swift)
and scrolled capture (image removed from repository history)
are retained, so minimization support is not mistaken for a large-title pinning API.

The installed Xcode 27.1 SDK exposes `toolbarMinimizationBehavior`, whereas an older bundled
skill reference uses `toolbarMinimizeBehavior`. The compiling experiment uses the SDK spelling.
Official references consulted:

- [Toolbar minimization](https://developer.apple.com/documentation/swiftui/view/toolbarminimizationbehavior(_:for:))
  controls navigation-bar minimization. It did not prevent this particular large-title slot from
  scrolling away in the measured trial.
- [Title placement](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/title)
  supplies the inline title and takes precedence over `navigationTitle`.
- [Browser role](https://developer.apple.com/documentation/swiftui/toolbarrole/browser)
  provides leading-aligned titles on iPad.

The tested [persistent prototype](evidence/library-title-matrix/persistent/probe/CustomArrowProbe.swift)
changes only the native title composition/policy; source selection remains a native Menu/Picker.

## Verification

| Configuration | Runtime | Initial and scrolled result |
|---|---|---|
| iPhone 17, portrait and landscape-left | 27.0 | Main-title Menu and subtitle visible; same frames |
| Duo closed, portrait and landscape-left | 27.1 | Main-title Menu and subtitle visible; same frames |
| Duo half at 90°, portrait and landscape-left | 27.1 | Main-title Menu and subtitle visible; same frames |
| Duo open at 180°, portrait and landscape-left | 27.1 | Main-title Menu and subtitle visible; same frames |
| iPad Pro 11-inch, portrait and landscape-left | 27.0 | Main-title Menu and subtitle visible; same frames |

- The title regions of all 20 captures were visually inspected. Actual gestures advance the list; every initial/scrolled
  pair exposes identical Menu and subtitle accessibility frames. Retained
  [frame comparison](evidence/library-title-matrix/persistent/observations/title-frames.json) and
  UI observations support that narrower claim.
- On scrolled iPhone landscape, tapping the title opens the native Menu. Selecting Downloads
  changes the native subtitle without returning the list to its initial position. Retained
  [observation](evidence/library-title-matrix/persistent/observations/menu-switched.txt) and
  capture (image removed from repository history).
- Both probe sources pass strict project SwiftLint with zero violations. The final probe compile
  emits no diagnostics. No production build/test or production source change is claimed.
- Standard Dynamic Type and light appearance only. AX1/AX3/AX5, live size changes, dark appearance,
  pushed navigation, search focus/query and real Library sidebar integration require validation
  before production acceptance. This experiment does not waive the repository's title policy.
- Fresh simulator accessibility initially needed a scoped bridge restart and app-accessibility
  preference reapplied. Reinstalling the probe intentionally terminated its old process; its
  process baseline was reset. No unexplained app crash was observed.
- The Duo automatic screenshot route returned black buffers despite a valid UI tree. Those
  images were rejected. Final Duo captures explicitly use the enumerated cover display 1 or
  inner display 3 through `simctl io screenshot`, with non-black and orientation checks.
  Rotation is applied after the app owns the intended display. The captured geometry, rather
  than physical-pose naming alone, determines portrait/landscape labels.
- Browser checks confirm 10 pairs by default and 6 Duo pairs when filtered. Gallery JavaScript,
  all 60 image references and the retained baseline link pass checks.
- The three task-only simulators were removed after capture. Existing review simulators and app
  data were untouched. Device Hub was not controlled. The localhost comparison page stays open.

Working scripts and command logs remain in `/tmp/ehpanda-title-arrow-persistent/`. The retained
page is served from the same gallery root as D141 at `/persistent/index.html`.
