# iPad Home title follows native tab placement — D118

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Date: 2026-10-22

## Owner direction and official API research

Hide the Home title on iPad whenever tabs float at the top. The owner explicitly directs checking
for an official API before attempting a custom implementation. The local trial was paused for
that investigation; the final implementation uses public SwiftUI APIs only.

The Xcode 27.1 SDK SwiftUI interface and UIKit navigation/tab headers, Apple API documentation,
and the 2024 tab/toolbar sessions were inspected. No public single setting was found that
specifically hides a navigation title automatically when floating top tabs are present.
That is a bounded research conclusion, not proof that every possible API was exhausted.

| API | Supported purpose | Use here |
|---|---|---|
| [`EnvironmentValues.tabBarPlacement`](https://developer.apple.com/documentation/swiftui/environmentvalues/tabbarplacement) | Reports the actual placement within a TabView; undefined placement is nil. | Read locally in HomePrimaryNavigationView. |
| [`TabBarPlacement.topBar`](https://developer.apple.com/documentation/swiftui/tabbarplacement/topbar) | Identifies tabs positioned in the top bar. | Combine with the existing window-local iPad device classification. |
| [`toolbar(removing:)`](https://developer.apple.com/documentation/swiftui/view/toolbar(removing:)) and [`ToolbarDefaultItemKind.title`](https://developer.apple.com/documentation/swiftui/toolbardefaultitemkind) | Remove the system-provided title item. | Remove `.title` only while that condition is true; pass nil otherwise. |
| [`ToolbarTitleDisplayMode.inline`](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/inline) | Uses the inline navigation title presentation. | Pair with removal while hiding; restore the designed `.inlineLarge` mode otherwise. |

[`automatic`](https://developer.apple.com/documentation/swiftui/toolbartitledisplaymode/automatic)
selects title display mode; it does not document this floating-tab visibility rule.
[`ToolbarRole`](https://developer.apple.com/documentation/swiftui/toolbarrole) affects toolbar
organization rather than supplying the requested rule. Apple's
[tab experience session](https://developer.apple.com/videos/play/wwdc2024/10147/) describes shared
top-bar space; the [toolbar session](https://developer.apple.com/videos/play/wwdc2024/10148/)
illustrates removing the default title, not a tab-dependent automatic policy.

## Native implementation and observed behavior

The original `.inlineLarge` plus title removal trial still displayed Home on the iOS 27.0 iPad
runtime. Pairing `.inline` with `.toolbar(removing: .title)` hides it. This runtime observation is
why both modifiers change together; it is not a claim about all OS releases.

The localized `.navigationTitle` remains set, preserving navigation semantics and the Home back
label. The condition applies to the Home root, leaving pushed destinations and their own title
modes intact. Reload remains in its native toolbar. The modifiers retain one view identity.

The existing window-local device observation restricts the new behavior to iPad, as requested.
Actual `tabBarPlacement` drives visibility; neither orientation nor a guessed width threshold
stands in for tab position. Nil, bottom and sidebar placements keep the normal title policy.
No custom title view, empty navigation title, hidden entire navigation bar, UIKit hierarchy
inspection, negative padding or additional safe-area handling is introduced.

## Native visual evidence

- Full iPad with top tabs: title hidden, Reload retained (image removed from repository history).
- The same running app resized into a narrow window: bottom tabs and Home title restored (image removed from repository history).
- Earlier source before the title/metadata follow-up (image removed from repository history).

These use neutral local artwork, not the account's galleries. The full-window image also verifies
D117's closer Pages/Category grouping. The narrow capture demonstrates a live placement transition,
not a separately cold-launched compact configuration.

## Verification and delivery

Implementation: `a516a4adfe88fa5fcdd67db798e6918840f0aedc` (title and existing UI assertion update), following
`34afba01d8219fd36e649cdb2e393c650ace25b4` (D117 metadata spacing).

Strict SwiftLint passes on all three changed Swift files. Native Build and Build for Testing
succeed with zero errors, compiler warnings or analyzer warnings. The single-pass native gate
passes exactly two selected UI tests, with no failures, skips, expected failures or repetitions:

1. iPad Home cold entry and portrait/landscape rotation at standard, AX1, AX3 and AX5; native
   title absent and Reload hittable in the full-width top-tab configurations. Standard size also
   checks Frontpage push, its full-width navigation bar and the Home back action.
2. Landscape centered slideshow width and exposed neighbors, portrait width/height preservation,
   selected-gallery preservation through rotations, and forward/backward swipe selection.

All 924 recorded native source hashes match the committed tree. The updated assertion searches
the navigation bars directly because removing the title changes the bar's accessibility identifier;
it also positively checks Reload, avoiding a missing-parent assertion that passes vacuously.
The fixture UI-test screenshots verify navigation/layout, not successful remote image loading.
Separate neutral local-artwork captures above verify loaded-cover appearance and live resizing.
No new iPhone/Duo, sidebar-placement or live Dynamic Type sweep is claimed; those paths retain the
existing title policy. No screenshot baseline is promoted.

Build logs retain existing Xcode provisioning-profile and IDE metadata messages. Structured build
diagnostics report zero warnings/errors, and no LLVM profile-writer error is recorded. Nothing is
suppressed or retried. The test driver preserves the native gate's checks while selecting only this
task's simulator and enabling the existing iPad test flag in the generated run-local test config.

The review iPad is installed in place and launched normally, without fixture arguments or
SIMCTL_CHILD flags, preserving account/data/settings and Reduce Motion. The automation session
is closed and both task-created test iPads are removed. Device Hub is not operated.
Raw evidence is retained in `.build/library/slideshow-metadata-spacing/` and
`.build/library/home-title-spacing-ui/`. Historical screenshot baselines and Phase 17 owner gates
are unchanged.
