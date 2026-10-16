# Downloads floating-panel prototype — D86

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Authorization and scope

The owner asks to try the D85 alternative. This authorizes a working prototype, not a final design
selection. Downloads Details and Pages open over the trailing side of a wide content area without
resizing the underlying list. Existing narrow-entry navigation/sheets remain. Other tabs, the native
Library sidebar and its deferred header issue are outside scope.

## Implementation and validation plan

- Reuse the existing gallery navigation feature and page inspector, including their operations.
- Gate new entry by available Downloads width (at least 700 points), not device identity.
- Keep an already-open panel's state when resizing; constrain its width to the available area.
- Use native trailing placement, system motion/accessibility behavior and native close controls;
  return focus to the originating card. Leave the background undimmed and interactive.
- Verify unchanged grid geometry, both panel contents, dismissal, nested detail navigation/reader,
  resizing and narrow-entry fallback. Capture original neutral-fixture screenshots.
- Record build/lint/test results and the exact implementation revision; await owner visual review.

## Findings during implementation

The first build used TCA's deprecated labeled `scope(state:action:)`; it was corrected to the
current unlabeled API. The zero-warning gate stopped before tests in that run.

The first native UI run exposed a real composition defect: a NavigationStack inside a SwiftUI
overlay in Library forwarded its toolbar into the enclosing Downloads navigation bar. The panel
body appeared on the right but its Download Status title was absent and its Close button appeared
on the main toolbar. Both selected tests failed at that title assertion.

A contained UIHostingController alone did not fix that native navigation integration: the second
UI run failed at the same title assertion. This variant is discarded.

The final candidate uses an app-owned presentation controller with the existing UIKitNavigation
state binding and a native form sheet. iOS 27's UISheetPresentationController.preferredPlacement
selects the physical right side, and largestUndimmedDetentIdentifier keeps uncovered content
interactive. Native presentation owns corners, elevation, motion, navigation separation and dismissal.
There is no custom overlay transition, controller discovery/introspection, fake size class or toolbar
reimplementation. The gallery and page feature views are unchanged.

This is a native trailing **sheet**, not a forced SwiftUI inspector style. D85's inspector finding
remains correct, but its alternatives were incomplete: the public sheet placement API is suitable
for this trial. The installed Xcode 27.1 UISheetPresentationController header documents leading,
center and trailing placement; [Apple's API page](https://developer.apple.com/documentation/uikit/uisheetpresentationcontroller/preferredplacement)
is the public reference. The native-sheet pattern already used elsewhere in this repository avoids
the nested SwiftUI presentation ownership problem.

The original gallery/page features keep their effects, observations, navigation, confirmation
ownership and reader state. Background reading-progress flush includes the new gallery host.

An already-open panel stays open and fits its available content area when rotating or resizing.
The 700-point threshold only controls new entry; it never destroys an active panel/store.

## Final candidate and verification

Implementation: `cb029d6db0f10c42750041b15a1571ad6abe64ed`. **Prototype awaiting owner visual review**, not a finalized Library
design. Other tabs and Phase 17 remain unchanged.

| Evidence under `.build/library/` | Result |
|---|---|
| `floating-panel-ipad-05` | 2/2 UI tests pass. Row/grid management, panel geometry, Pages rotation, Details, nested reader return and Previews push/pop. |
| `floating-panel-iphone-01` | 1/1 UI test passes. Portrait Pages remains a native sheet; Details remains native navigation, with no floating panel. |

Both final gates compile with zero warnings/errors, enumerate each requested test and execute it
once without retries or skips. Every captured source hash matches the implementation revision.
Strict SwiftLint reports zero violations across all five changed Swift files; `git diff --check`
is clean. The earlier `floating-panel-ipad-04` also passed both tests before the UI test was extended
to cover the nested reader and Previews. Runs 01–03 retain the discarded variants' build/UI failures.

The geometry test compares card width, card leading position and full list width before/after
opening Pages with a one-point tolerance, then checks the list width again for Details. The panel
is on the right. Pages remains open and inside the window after portrait rotation, then closes.
Details opens the existing local reader and returns to the same panel; Previews pushes and pops
inside its gallery stack. The management test moves a gallery, opens Pages from both layouts, reads
local pages, cancels deletion, confirms only the selected gallery's deletion and verifies the
neighbor after relaunch.

The original review iPad was updated in place and launched into Library without fixture/auth
overrides. Its account and files are preserved. The dedicated iPhone returns to its prior Shutdown
state; the disposable screenshot iPad is removed after export. The existing proposal web preview
remains open.

## Review screenshots

[Original screenshot manifest and SHA256 hashes](screenshots/floating-panel-manifest.json):

- Details on the right (image removed from repository history)
- Pages on the right (image removed from repository history)
- Grid before presentation (image removed from repository history)
- Pages retained after portrait rotation (image removed from repository history)
- Narrow native Pages sheet (image removed from repository history)

These are original neutral-fixture captures. They do not contain the review iPad's account content.

## Scope of verification and remaining review

The 700-point entry threshold and preferred 480-point width are trial geometry, pending owner
feedback. The presentation is a system form sheet with native trailing placement; it does not
reserve a list column. Native presentation controls animation and Reduce Motion, dismissal and
accessibility semantics; the originating row is explicitly restored as the accessibility focus
target on dismissal when it still exists. No custom keyboard/VoiceOver controls were introduced.

This run does not claim a new full Dynamic Type matrix, physical-device VoiceOver/focus/keyboard
audit, Reduce Motion comparison, arbitrary live-window resize matrix or Duo folding sweep.
Rotation and the narrow-entry fallback above are the measured adaptive cases. The previously
owner-deferred native sidebar/header displacement is not repaired by this trial.

## Subsequent comparison trial

D87 explicitly requests the actual SwiftUI inspector. That candidate is now installed for review;
this D86 sheet version remains recoverable at its recorded commit. Neither is a final owner choice.
See [native inspector results and original captures](NATIVE-INSPECTOR-PROTOTYPE.md).
