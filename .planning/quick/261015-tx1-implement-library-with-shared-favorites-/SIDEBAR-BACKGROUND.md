# Library sidebar background follow-up

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner D67 requests top-edge continuity first, with an opaque sidebar as the fallback.
Implemented in `82da111f79` on `agent/app-design`.

## Scope and selected implementation

`AppPackage/Sources/AppFeature/View/Library/LibraryView.swift` adds two native modifiers to the
sidebar List: hide its default scroll background and supply `Color(uiColor: .systemBackground)`
through the background modifier. The opaque semantic color adapts to system appearance.

The default background overload extends decoration across safe-area edges; foreground layout
continues to respect its safe area. Native selection, compact navigation, `.inlineLarge`, searchable
and the soft top scroll edge remain intact. `TabBarView` was inspected but is unchanged.
No geometry arithmetic, fixed inset, appearance proxy, global window lookup or device branch is added.
Deployment stays iOS 27.0; launch-screen and supported-orientation settings need no change.

## Native probes and rationale

Apple's [background modifier](https://developer.apple.com/documentation/swiftui/view/background(_:ignoressafeareaedges:))
extends decoration across selected safe-area edges. A regular-material background with top-edge
extension did not reach the status-bar region in this TabView hierarchy. Moving the complete
NavigationSplitView into the safe area would also move its foreground and was not selected.
This observation does not assert that every possible hierarchy prevents top extension.

The [navigation container background](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigation)
is a per-column API; [navigationSplitView background](https://developer.apple.com/documentation/swiftui/containerbackgroundplacement/navigationsplitview)
controls the shared backing/divider. The local 27.1 SDK marks tabView placement unavailable on iOS.
The per-column `.background` ShapeStyle probe matched light appearance but retained a gray sidebar
in dark appearance. Explicit systemBackground fixed the color, but that container variant also
changed native column layout: cold title/search positions moved down 44 points and a splitter
appeared. It was rejected. Do not infer geometry neutrality merely from the API's background name.

The selected background-only decoration produces the opaque color in both appearances and matches
the same-toolchain baseline's entire accessible UI outline exactly at cold entry.

## Verification — 2026-10-16

Xcode 27.1.0, dedicated iPadOS 27.0 simulator at 1210 × 834 points, landscape-right:

| Check | Result |
|---|---|
| Same-SDK baseline vs final cold UI | Exact text diff is empty, including tabs, titles, search and row bounds |
| Library / Favorites titles | Both y=108 pt, unchanged from the rebuilt baseline |
| Search | y=160 pt, unchanged from the rebuilt baseline |
| Light continuity | At x=400 px, y=16/60/96/150/200/300/700/1100 all RGB 255/255/255 |
| Dark continuity | At the same points, all RGB 0/0/0 |
| Live appearance change | Light → dark → light verified |
| Sidebar control | Native hide → show succeeds; selected detail remains |
| Scroll and category | Scroll to Downloads, open its empty state; native top edge and controls remain |
| Compact navigation | iPhone: Favorites → Library → Favorites 0 → Library succeeds; native back/search retained |
| Build | `decoration-build.xcresult`: success, zero warnings/errors |
| Strict SwiftLint | `decoration-lint.log`: zero violations in the changed file |
| Independent source review | No actionable defect; final native geometry evidence supersedes the earlier container assumption |

The initial live screenshot had title y=88, so it was not used as a geometry control. The original
source was rebuilt with the same current SDK, relaunched on the same device and captured as
`baseline-current`; its y=108 title matches the final decoration. The original source's gray sidebar
is still visible in that controlled baseline. Actual logs and AX outlines are under
`.build/library/sidebar-background/`. Intermediate failed probes are retained locally.

The compact simulator reported a boot-status migration warning but reached Booted and completed
real navigation. It was returned to Shutdown. The iPad remains running Library/Favorites in light
appearance for owner review, with normal logged-out account state and no offline fixtures.
The proposal preview remains stopped under D65; D66 permits Device Hub for this review.

This focused follow-up did not repeat the full Library test suite, rotation/window resizing, AX-size
matrix, RTL or physical-device coverage. Earlier broader validation remains attributed to its own
source revision. No behavior-mirroring unit test was added for this background-only change.

## Screenshots

These are unedited native captures with source paths and SHA-256 hashes in `screenshots/manifest.json`.

- Controlled baseline (image removed from repository history)
- Opaque light appearance (image removed from repository history)
- Opaque dark appearance (image removed from repository history)
- Compact Library (image removed from repository history)
