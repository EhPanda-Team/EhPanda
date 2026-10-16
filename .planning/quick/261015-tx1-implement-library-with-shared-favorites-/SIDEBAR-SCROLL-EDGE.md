# Sidebar scroll-edge continuity

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Owner decision D68 rejects D67's opaque fallback: it matched static colors, but upward scrolling
still exposed a hard boundary between the sidebar's progressive blur and the status bar.
Implemented in `e257ee2050` on `agent/app-design`. This supersedes [D67's implementation](SIDEBAR-BACKGROUND.md).

## Cause and selected change

The native NavigationSplitView hosted inside TabView started below the status-bar region. The
previous live accessibility outline began at y=32 pt, matching the visible cut in the scrolled
capture. Changing the List's background did not extend the navigation/scroll-edge host.

`AppPackage/Sources/AppFeature/View/Library/LibraryView.swift` now applies
`.ignoresSafeArea(.container, edges: .top)` to the completed NavigationSplitView, and removes the
List's `.scrollContentBackground(.hidden)` and opaque `systemBackground` decoration. This lets the
native sidebar material and progressive blur continue behind the status bar. The split view's
native navigation bars still provide clearance for titles and controls.

This deliberately narrow change does not alter TabBarView or RootView, both inspected. Bottom,
side and keyboard safe areas remain unchanged. There is no manual inset calculation, compensating
padding, device branch, custom blur, global window access or title/search fallback. Existing
`.inlineLarge` and both page-owned `.scrollEdgeEffectStyle(.soft, for: .top)` policies remain.
No new page or presentation boundary is added.

Apple documents the selected [safe-area modifier](https://developer.apple.com/documentation/swiftui/view/ignoressafearea(_:edges:))
and [native bar safe-area behavior](https://developer.apple.com/videos/play/tech-talks/111461/?time=415).
The app-resizability pre-edit review treated this as a bounded native-container experiment, with
actual foreground placement as the acceptance gate. Post-edit review found no actionable defect
in the source or resting/light-scrolled/dark-scrolled screenshots. The earlier assumption that
extending the split would necessarily make controls unsafe was not supported by the native result.

## Current validation — 2026-10-16

Built with Xcode 27.1.0. All captures use the normal logged-out account state, with only the Library
routing launch flag and no offline fixtures. Local captures, accessibility outlines, commands and
build results are under `.build/library/sidebar-scroll-edge/`.

| Check | Observed result |
|---|---|
| iPadOS 27.0, landscape, rest | Native sidebar material reaches the window top, including behind time/date |
| iPad, upward sidebar scroll | Rows progressively blur through the top region; the former horizontal cut below the status bar is absent |
| iPad, dark appearance while scrolled | Continuous native material/blur; no separate status-bar color strip |
| iPad sidebar controls and category | Native hide/show and Favorites 0 selection work; detail and search remain accessible |
| iPad live rotation | Landscape-right → portrait-upside-down → landscape-right; native bars remain clear of system UI |
| iPad standard, AX1, AX3, AX5 | Cold entry and live size changes captured independently; native titles/search remain usable |
| Compact iPhone, same four text sizes | Cold/live detail captures and Library/category/back navigation checked; settled AX5 root verified separately |
| Duo iOS 27.1 | Closed → open → half → tall orientation → closed; same app process survives, native columns and top/side/bottom tabs adapt without unsafe overlap |
| Build | `split-top-build.xcresult`: success, zero warnings/errors |
| Strict SwiftLint | `lint.log`: zero violations in LibraryView.swift |
| Source and patch review | Native safe-area scope reviewed; `git diff --check` passes |

Cold iPad title/search origins move from the earlier same-SDK opaque baseline's 108/160 pt to
98/150 pt. After live rotation they settle at 88/140 pt, also observed in the earlier live layout.
These are native bar layout differences, not a pixel-position preservation claim. The acceptance
criterion is safe, usable native placement and continuous scroll effects. No offset was added to
force old coordinates. At AX5, long row labels wrap through native behavior; no font clamp is added.

### Probe failures and limits

- The iPhone size-check script sampled 0.3 seconds after Back at AX5 and asserted before navigation
  finished. The next accessibility read showed Library; a redundant Back attempt was correctly
  rejected because the root was already visible. A settled AX5 screenshot/outline then verified the
  root. This is not reported as an entirely passing automated script or an app failure.
- Dedicated compact/Duo simulator boot checks emitted a data-migration warning but reached Booted
  and completed native interactions. Intentional relaunches reset crash baselines; no app crash was
  observed during these checks.
- This follow-up did not rerun the full FeatureTests/UITests suites, iPad windowed resizing,
  physical-device, full VoiceOver or RTL coverage. Earlier suite evidence remains tied to its own
  code revision. Live iPad rotation and Duo display changes are the resizing evidence for this fix.
- No behavior-mirroring unit test was added for this native container layout change. The meaningful
  regression evidence is actual upward scrolling, control placement and size/device transitions.

## Review state and screenshots

The iPad is left running Library/Favorites, light appearance, standard large text, landscape-right
and Full Screen Apps, with the sidebar scrolled upward for owner review. D66's one-time Device Hub
permission covers this review. The proposal preview remains stopped under D65. The compact iPhone
was returned to large text and Shutdown; Duo was returned to closed hinge/hardware portrait and
Shutdown. No unrelated simulator was operated.

The following are unedited native captures. `screenshots/manifest.json` records source paths and
SHA-256 hashes; D67's earlier screenshots remain as historical evidence.

- Before: blur clipped below the status bar (image removed from repository history)
- After: upward scrolling, light (image removed from repository history)
- After: upward scrolling, dark (image removed from repository history)
- After: native material at rest (image removed from repository history)
- Final running iPad review state (image removed from repository history)
- iPad AX5 cold entry (image removed from repository history)
- Compact iPhone AX5 Library root (image removed from repository history)
- Duo half-open (image removed from repository history)
