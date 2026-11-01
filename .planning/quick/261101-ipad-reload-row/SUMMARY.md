# iPad top tab bar keeps Home's Reload in its row — 2026-11-01

## Owner request

On iPad with the top tab bar, Home's Reload sat on a row of its own below the tabs. Find a native
SwiftUI way to keep it in the tab bar's row, without a custom navigation bar and without relying on
pull-to-refresh alone. Preserve uncommitted work, iPhone, the Duo split and pushed navigation.
After the investigation the owner chose option A (move the sheet presenter), to be committed before
a pure SwiftUI presentation is evaluated.

## Cause

UIKit merges a tab's navigation bar into the iPad top tab bar only while the tab's hosting
controller has the navigation stack as its sole child controller. `HomePaneSheet`, the
`UIViewControllerRepresentable` that owns Duo's opposite-side sheets (`8c332e2a2`), sat in
`HomeView`'s outer `.background`, beside Home's `NavigationStack`, so the bar fell back to its own
row (Reload y=100 instead of y=36 in a 1210 × 834 landscape window).

A single-file SwiftUI probe isolated it on iPadOS 27.2. Each EhPanda factor was added alone to a
native baseline: the HStack shell, `toolbarVerticalCompressionBehavior`, overlays, scroll-edge
styles, a `UIViewRepresentable`, `.primaryAction` and `.toolbarRole(.browser)` were all neutral.
Only a `UIViewControllerRepresentable` beside the stack (as a background or overlay) reproduced the
second row; the same controller inside the stack's root content did not. The probe, its per-variant
logs and screenshots are kept locally in `.capture/home-toolbar-review/` (`FINDINGS.md`).

## Change

- `HomeView.swift` / `HomeNavigationView.swift`: the unchanged `HomePaneSheet` background moves
  from `HomeView`'s shell into `HomePrimaryNavigationView`'s root content, with a comment recording
  why it must not sit beside the stack. Sheets are requested only from the root content, and
  UIKitNavigation's `present(item:)` observes the binding itself.
- `LandscapePaneUITests.assertSingleHomePane`: Reload's centre must lie within the Home tab's
  vertical extent, in both orientations and at Large, AX1, AX3 and AX5.

Pushed Home destinations on iPad now merge too: Back and their trailing items sit in the tab bar's
row and the title is centred below (Frontpage: Back y=32, Date Seek/Filters y=36, title y=97.5;
previously y=96/100/107.5).

## Verification

All runs used a worktree at `HEAD` plus this change only, so the owner's uncommitted work was not
part of the tested tree, on project simulators running iOS 27.2 (24B8117 / 24B91016s for Duo).

| Check | Result |
|---|---|
| Strict SwiftLint, the three changed files | 0 violations |
| App and test builds | 0 warnings, 0 errors |
| `HomeFeatureTests` | 47 passed |
| iPad Pro 11 (M5) `LandscapePaneUITests` | 4 passed on the first attempt, 1 Duo-only skip |
| Same iPad test without the source change | fails: `Reload (1160, 100, 36, 36), tab (434.5, 36, 78.5, 36)` |
| iPhone 18 Pro, Home root before/after | identical: bar y=62, Reload (346, 66), tab bar y=791 |
| iPhone Duo, before/after, driven with `agent-device fold` | identical frames, listed below |

Duo frames (951 × 669 window; identical for the `HEAD` build and the change):

| Step | Result |
|---|---|
| Half-open root | split at x=475.7; one Reload in the side bar (884, 129) |
| Left Frontpage → sheet | right half, x=483.5 w=459.3; nested gallery left, x=8 w=459.3 |
| Right Toplists → sheet | left half, x=8 w=459.3; nested gallery right, x=483.5 w=459.3 |
| Left slideshow gallery | right half, x=483.5 w=459.3 |
| Closing a nested Detail | its list stays presented |
| Frontpage up, fold open → closed → half-open | x=475.5 w=467.3 → 466-pt cover x=8 w=450 → x=483.5 w=459.3 |

`DuoHomeUITests` could not serve as the gate: the UITests plan runs parallel clones, a clone does
not inherit the posed hinge, and every case failed with `did not present home_left_pane`. Running
them unparallelised on the posed device needs the owner's approval under the test-parallelism
policy, so the cases were reproduced by hand instead. `testPortraitUsesOnePaneAndPushesLists`
and `LandscapePaneUITests.testHomeAndNestedSheetsUseOppositeHalves` also need the host pose
driver behind `EHPANDA_DUO_POSE_DIRECTORY`, which is not installed. Stage Manager was not exercised.

## Observed outside this change

On the main working tree, `testWideSlideshowRevealsNeighborsAndPreservesSelectionAcrossRotation`
times out: it expects a 720 pt landscape slideshow card, while the uncommitted slideshow
aspect-ratio work renders 751 pt. It passes on `HEAD`. Left for that work to resolve.

## Commit

`350773d46` fix(home): keep iPad Reload in the tab bar row. Local commit only; not pushed.
