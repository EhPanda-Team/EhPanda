# Library long-press: custom tab bar feasibility — 2026-10-24

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Current owner resolution — D136

The owner rejects a custom tab bar: “不接受客製化 tab bar”. Keep the system TabView/tab bar.
The research below is retained as history, not an implementation recommendation or pending
approval request. The earlier long-press sheet request remains unsupported by the identified
native per-tab APIs; do not pursue a custom bar to implement it.

## Historical research scope and conclusion

The owner explicitly chose to research a custom tab bar after the native-tab long-press
limitation was reported (D135). This authorizes investigation, not replacing the shipping bar.
The owner also requested a screenshot of the closed title menu before deciding D134's title-mode
exception. Neither the smaller title nor a custom bar has been approved for production.

A custom SwiftUI bar can implement the requested long press and present a native sheet.
Public APIs also expose the preferred vertical edge on Duo. The distinction is that these
building blocks do not provide native tab-bar behavior as a package. Ordinary phone layout is
straightforward; full Duo parity adds placement, shared-toolbar-space and interaction work.
The viable architecture should preserve TabView and existing stores, replacing only its visible
controls if a later prototype is accepted. A standalone UITabBar is not a shortcut to native
Duo adaptation. No production code or simulator state was changed for this research follow-up.

## Public API basis

| Need | Public API / evidence | Boundary |
|---|---|---|
| Recognize a long press on an app-owned control | SwiftUI `onLongPressGesture` / `LongPressGesture`; the iOS 27 overload also supports input kinds | The control must belong to the app; this does not add a callback to a native Tab item. Tap and hold recognition must be exclusive so releasing a hold cannot also activate/reselect a tab. |
| Native half-height source sheet | `.sheet` and `PresentationDetent.medium` | Medium is approximately half-height and is inactive at compact height. Use native larger presentation when needed rather than promise exact half-height in every pose. |
| Glass appearance | `glassEffect`, `GlassEffectContainer`, native glass button styles | These render material and interaction effects; they do not supply tab selection, scrubbing or compression behavior. |
| Reserve space for app-owned bars | `safeAreaBar` has vertical- and horizontal-edge overloads | It adjusts safe area and affected scroll-edge effects. It does not manage the shared Duo toolbar/tab region for an arbitrary custom bar. |
| Follow Duo's physical bar side | `EnvironmentValues.toolbarVerticalEdge` | Available from 27.1. It returns the system's preferred edge even when the vertical bar is hidden; nil means no vertical bar in that context. It reports an edge, not a per-tab frame or reserved region for custom controls. |
| Preserve tab content/navigation | Keep the existing TabView selection and hide its visible bar with native toolbar visibility | The exact combined layout with an app-owned bar still needs a native prototype. Do not replace all tab content with a switching if/switch that rebuilds its navigation stacks. |

The app targets 27.0. The vertical-edge read therefore needs an availability boundary; older
ordinary phones use the horizontal layout. Avoid introducing an orientation/device-name test
as a substitute for the system edge. Existing Library sidebar eligibility remains separate from
bar placement: those are different decisions.

Sources checked against the installed Xcode 27.1 SDK and Apple documentation:

- [Long-press gesture](https://developer.apple.com/documentation/swiftui/view/onlongpressgesture(minimumduration:maximumdistance:inputkinds:perform:onpressingchanged:))
- [Medium detent](https://developer.apple.com/documentation/swiftui/presentationdetent/medium)
- [Custom safe-area bar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:))
- [Preferred vertical bar edge](https://developer.apple.com/documentation/swiftui/environmentvalues/toolbarverticaledge)
- [Toolbar visibility](https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:))
- [Custom Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Apple: Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/)

The installed iPhone Duo guidance corroborates that standalone bars do not gain container-owned
vertical behavior. Its mention of an unidentified bar-region API is not treated as an available
API. `toolbarVerticalEdge` is verified, but supplies only the side, not the missing dimensions or
compression decisions.

## Implementation choices

| Candidate | Feasibility | Tradeoff |
|---|---|---|
| Retain TabView, hide its visible tab bar, add app-owned glass controls | Preferred basis for an isolated prototype. Long press has a real app-owned source; existing app reducers and navigation stacks can remain. | Must design selection feedback, accessibility, keyboard/pointer behavior, scrubbing and label reveal. Duo's shared toolbar region needs measurement and overlap/overflow testing. |
| Custom bar only on ordinary iPhone; keep native iPad/Duo bars | Smallest practical rollout scope. | Long-press switching would be inconsistent between device types. This scope change is not approved. |
| Replace native SwiftUI tabs with a standalone UITabBar | Does not solve the requirement cleanly. | It remains horizontal outside its native controller and lacks a public per-item long-press hook/frame. Replacing the controller alone also does not create that hook. |
| Put navigation controls into a native bottom toolbar | Possible separate experiment, not yet validated. | Native containers can move toolbar controls to the side, but they remain toolbar actions, not tabs. Long-press forwarding, selected semantics, grouping and competition with page actions require runtime proof. |

Recommendation: if proceeding, prototype the first candidate in isolation, preserving native
page/navigation containers and the existing app state. Do not promise a pixel-identical native tab
bar or change the current Duo/iPad behavior before comparing a real prototype across poses.

## Existing behavior that must survive

Code inspection found reusable selection logic in `TabBarReducer` and `AppReducer`:

- Route taps through `setTabBarItemType`; assigning selection directly would bypass Setting's
  existing inline/sheet decision and the current-tab reselection behavior.
- Reselecting Home/Library/Search can clear a navigation path or refresh its root. A long press
  must not accidentally dispatch this tap action as well.
- Use the existing Library selection and remembered source filters, rather than a second source
  value owned by the custom bar. Present the new source sheet from a stable app presentation root.
- Keep localized text and symbols defined, expose selected state and a discoverable accessibility
  action for the source sheet, and test Dynamic Type without capping it.
- Maintain top soft scroll-edge policy on the new sheet independently of the underlying page.

A native feasibility prototype would need to verify: tap versus hold, cancelled hold, source choice
and dismissal, already-selected-tab behavior, settings-sheet routing, keyboard appearance, sheet
presentation while another destination is active, and navigation/query preservation. For layout,
cover ordinary phone portrait/landscape, Duo both outer-display orientations and open portrait/
landscape, the opposite physical edge, fold transitions, split windows, and iPad floating tabs.
Also check standard and AX1/AX3/AX5, Reduce Motion and Reduce Transparency.

These are proposed validation gates, not completed tests. This follow-up is a documentation/SDK/
source review; it does not claim a working custom tab bar, measured native parity, or a new build.

## Closed title-menu screenshot

Exported unchanged from the earlier passing iPhone Library UI test in
`.build/phone-layout-review/title-menu-inline-ui.xcresult`. The screenshot uses neutral bundled
gallery fixtures. The OS return-to-probe link is a test-launch artifact. The native Favorites title
is smaller and leading with a disclosure arrow; it is not necessarily centered.

Historical screenshot: Library title menu closed (image removed from repository history)

D136 rejects custom-tab implementation. D134 remains under native title-layout review, including
the owner's question about a simultaneous Library large title and smaller source menu. D133
remains the production source-switch design.
