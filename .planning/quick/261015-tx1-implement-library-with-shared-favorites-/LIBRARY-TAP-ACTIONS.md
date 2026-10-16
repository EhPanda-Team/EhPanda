# Library gallery tap actions — D89

## Owner decision

Library gallery entries use single tap to open Detail and double tap to start reading. Apply the
same interaction to Favorites and Downloads in both row and grid layouts. Keep the existing
Detail push/sheet rules and reader presentation; D88's rejected sheet/inspector trials remain reverted.

## Implementation plan

1. Preserve native Button semantics and arbitrate tap counts with SwiftUI's exclusive gesture
   composition, giving double tap priority. The single-tap route must not fire during double tap.
2. Keep a localized Read context-menu item and accessibility action so reading does not require
   a timed gesture. Default accessible/button activation opens Detail. Preserve Downloads' context
   menus, swipe actions and stable destructive-confirmation anchors.
3. Add direct Favorites reading. Prefer a local manifest; otherwise fetch the remote gallery's
   actual preview configuration/language and seed its URLs before presenting the reader. Show
   loading/failure feedback, ignore stale completion after another navigation choice and preserve
   resume/dismiss/background progress persistence. Downloads reuses its existing reader route.
4. Verify row/grid single tap, double tap without hidden Detail, context-menu reading and existing
   download management on dedicated simulators. Test routing, local source selection, failures,
   stale completion and reader dismissal. Build/lint must be clean.

## API and accessibility basis

- [Apple: exclusive gestures](https://developer.apple.com/documentation/swiftui/gesture/exclusively(before:))
  documents first-gesture precedence and only one successful result. Native recognition owns the
  double-tap interval; no custom timer or delayed navigation workaround is introduced.
- [Apple: gestures](https://developer.apple.com/documentation/swiftui/gestures) recommends native
  Buttons for button semantics. Existing Buttons remain the primary controls; Downloads rows
  become Buttons rather than label-only tap handlers.
- The SwiftUI and accessibility skills guide implementation and review. VoiceOver default
  activation remains Detail; its Read action provides the secondary operation without requiring
  a physical double tap to bypass VoiceOver's own activation gesture.

## Implementation and verification

Implementation commit: `c484eb3a0aa4dde4eed037e071b74d5f6c153b20`.

The shared gallery interaction uses native Buttons with an exclusive double-/single-tap gesture.
Only Favorites opts into reading in the shared GalleryList; other list sources keep their existing
activation behavior. Downloads row/grid reuse the existing detail and local-reader actions.
Favorites owns a direct reader destination and the app's background flush includes that destination.
The existing six-locale Read label is exposed from the shared resources catalog.

`library-taps-features-06` passes all 50 selected feature tests with zero build warnings/errors.
Coverage includes all Favorites tests, app scene-phase tests, Downloads detail routing, lifecycle,
actions and analytics. Four new Favorites tests cover detail-only activation, failure feedback,
stale completion and local reading/dismissal; one app test checks durable progress on background.
Strict SwiftLint is clean across 13 changed Swift files. Initial preparation errors were corrected
at their source (shared localization visibility and explicit module imports); test dependencies for
date and launch automation are deterministic. No warning or issue is suppressed.


## Native interaction finding

The first iPad run passed Downloads management and both Downloads tap routes, but Favorites row
double tap reopened Detail instead of reading. The native recording retained at
`library-taps-ipad-01/selected-tests.xcresult` shows the Detail sheet. Favorites alone still used
List's automatic row button activation; the shared Library interaction now uses an explicit
borderless button style and rectangular hit region before exclusive recognition. This adjustment
is limited to lists that supply the secondary Read action. Native verification passes after
this change; the failed run is retained rather than counted as a pass.

## Final native validation and evidence boundaries

Evidence is retained locally under `.build/library/`:

| Run | Result | Scope |
|---|---|---|
| `library-taps-features-06` | 50 passed, 0 failed/skipped | Favorites, app background progress, Downloads routing/lifecycle/actions/analytics |
| `library-taps-ipad-02` | 3 passed, no diagnostics | Favorites and Downloads row/grid single tap, double tap, return, Read menu; existing Downloads management |
| `library-taps-iphone-01` | 2 passed, no diagnostics | Both sources and layouts using compact Detail navigation, direct reading and Read menu |
| `library-taps-lint.log` | 13 Swift files, 0 violations | Strict lint on implementation, package and tests |

Both final native runs' recorded source hashes match the implementation commit. The feature run
preceded only the borderless-style/hit-region correction in `GalleryReadInteraction.swift`; all
reducer, dependency and feature-test files match the final source. The affected gesture behavior
is covered by the subsequent native tests. Both final builds report zero compiler/analyzer
warnings and zero errors. Native tests confirm reader dismissal returns directly to the list,
without a Detail view underneath, and preserve management actions.

The original review iPad was updated in place and launched at Library Favorites with its existing
account/data. No fixture or login override was supplied to that launch. The disposable test iPad
was removed; the dedicated test iPhone's content size and original Shutdown state were restored.

Default Button activation remains Detail; a localized Read accessibility action and native menu
provide an alternative to timed double tapping. Physical VoiceOver and keyboard activation were
not exercised. Remote-image success is not claimed by the hermetic navigation fixtures, whose
remote image responses are deliberately unavailable. The deferred native sidebar header issue
and Phase 17 gates remain unchanged; D88's rejected presentation trials remain reverted.
