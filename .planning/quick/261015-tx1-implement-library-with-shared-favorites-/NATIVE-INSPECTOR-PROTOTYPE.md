# Native Downloads inspector trial — D87

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner request and plan

The owner explicitly asks to try SwiftUI inspector after reviewing the native trailing-sheet
prototype (D86). This is a separate review candidate, not final adoption.

- Replace the UIKit form-sheet presenter with the real `.inspector(isPresented:)` modifier.
- Reuse the existing Details navigation feature and Pages feature, including nested reader and
  Previews navigation. Present through the inspector at every size; let SwiftUI adapt naturally.
- Use optional presentation state as the source of truth, without a second visibility flag,
  forced size classes, custom transitions or controller introspection.
- Measure the list before and during presentation rather than promising floating geometry.
- Verify native dismissal, rotation, management actions and compact presentation with dedicated
  simulators and neutral fixtures; retain original screenshots for owner comparison.
- Preserve the native Library sidebar and the deferred header-displacement issue.

The active candidate remains a prototype pending owner review. See the findings and verification below.

## Integration findings

The first run passed download management but stopped at a geometry assertion: the list's XCTest
accessibility frame remained 1210 points wide, while only the leading cards remained unobscured. Reviewing
the retained native recording also showed inspector title/Close items merging into the Downloads
navigation bar. The inspector was outside the inner NavigationStack but still inside Library's
NavigationSplitView. The next candidate attaches it outside that outer navigation structure;
the regression checks that Downloads retains its own title and records actual card/bar frames.

This follows Apple's documented distinction between inside/outside navigation placement:
[Inspectors in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10161/).

The second run separated both navigation bars. Actual card geometry is unchanged before/after
opening the inspector (205.5-point card width, x=336); the inspector is a 480-point trailing
overlay on this iPad, not a forced reserved column. Native rotation, reading and Previews succeed.
The remaining failure is Details Close after pushing/popping Previews: the nested navigation
dismiss environment does not clear the inspector. Details now receives an explicit close action
from the presentation owner, which sends the existing TCA presentation-dismiss action. Other
GallerySheetView users retain their native environment dismissal by default.

## Measured native presentation

The final candidate attaches `.inspector` outside Library's NavigationSplitView. The content has
its own navigation stack and top scroll-edge policy. `Binding` projects the optional TCA
presentation directly; native dismissal clears it, and Details Close explicitly targets it.
Downloads restores accessibility focus to its originating visible card when the presentation ends.

On the 11-inch review-class iPad at 1210×834 points, the system chooses an overlay:

- Inspector frame: x=730, width=480 points.
- First grid card before and after opening: x=336, width=205.5 points.
- Main Downloads and inspector navigation bars remain distinct.
- Rotation to portrait retains the Pages inspector, which stays within the window.

This is observed automatic inspector behavior, not a forced overlay API or an assertion that every
window size uses the same style. The earlier statement that the inspector necessarily reserves
space on this iPad is corrected by this measurement. Preferred width is a trial value (min 320,
ideal 480, max 600); SwiftUI owns adaptation, material and transitions.

## Verification scope

The iPad UI regression exercises row/grid management, both inspector contents, unchanged card
width/leading position, portrait rotation, local reader return, nested Previews push/pop and final
state-driven dismissal. Original neutral-fixture screenshots and exact source references are
retained with the final verification record. This does not claim a new full Dynamic Type, physical
VoiceOver/keyboard, arbitrary window resizing or Duo fold matrix. The owner-deferred native Library
header displacement remains recorded and is not fixed by this inspector trial.

## Final candidate and verification

Implementation: `658ba665b2fd5976f17878b22d53a6fcd9093aaf`. **Native inspector trial awaiting owner review**.
The earlier trailing-sheet implementation remains at `cb029d6db0` for comparison.

| Evidence under `.build/library/` | Result |
|---|---|
| `native-inspector-ipad-03` | 2/2 UI tests pass: management and adaptive inspector/navigation regression. |
| `native-inspector-iphone-01` | 1/1 UI test passes: Pages and Details use the inspector's native compact sheet and close correctly. |
| `native-inspector-features-01` | 30/30 tests pass across routing, presentation lifecycle, download actions and analytics. |

Every final gate builds without warnings/errors, runs its enumerated selection once without skips
or retries, and has source hashes matching the implementation. Strict SwiftLint finds zero
violations across all 11 changed Swift files; `git diff --check` is clean. Earlier iPad runs 01/02
retain the geometry/toolbar integration and nested dismissal findings above.

The original review iPad was updated in place and EhPanda launched into Library with only the
route environment override. A native screenshot confirms the app is running; no fixture/auth
overrides or account-file resets were used. Bringing a standalone Simulator GUI forward was not
available through Launch Services in this shell, so foreground window activation is not claimed.
The dedicated iPhone returned to its prior Shutdown state. The disposable test iPad is removed
after export. The existing web proposal preview remains untouched.

## Original review captures

[Manifest and SHA256 hashes](screenshots/native-inspector-manifest.json):

- iPad Details inspector (image removed from repository history)
- iPad Pages inspector (image removed from repository history)
- iPad grid before opening (image removed from repository history)
- iPad Pages after portrait rotation (image removed from repository history)
- iPhone Pages sheet (image removed from repository history)
- iPhone Details sheet (image removed from repository history)
- [Native frame measurements](screenshots/native-inspector-geometry.txt)

The six images are original neutral-fixture screenshots, not edited mockups or review-account
captures. The native sidebar/header issue remains deferred under D75/D76. D87 is the currently
installed trial; neither candidate is marked as the final design.
