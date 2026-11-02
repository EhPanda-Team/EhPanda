# Home test repairs

Four Home tests failed on `feature/gsd-phase-17` whatever else changed, as the
[copy audit](../261101-copy-audit/SUMMARY.md) recorded on 2026-11-02. Three were stale tests and one was a real app
bug. A fifth test, skipped by default, was stale as well and covers the same behavior, so it was corrected too.

## Causes and changes

| Test | Cause | Change | Commit |
| --- | --- | --- | --- |
| `GalleryCoverLayoutTests.richSlideshowGrowsForMetadataWithoutClipping(.large)` | Stale test. The rich title has a flexible frame, so `sizeThatFits` returned the 2000 points it was offered, while the carousel lays cards out at their ideal height. | Measures through `fixedSize`. The bounds are unchanged. | `0e8bb252f` |
| `AccessibilityAuditUITests.testPopularAudit`, `testHistoryAudit` | Stale tests. Since `20940e628` a destination card reads its title, summary and footnote as one label, so an exact title query finds nothing. | Match the start of the label, as `LandscapePaneUITests` already does. | `4b612749e` |
| `AccessibilityAuditUITests.testHomeRootAudit` | App bug, described below, which hid a stale comparison: the card's label also reads the tags that fit its width, so the same gallery has a longer label in landscape. | App fix, and the test compares the gallery's title identifier. | `a333f617e` |
| `LandscapePaneUITests.testWideSlideshowRevealsNeighborsAndPreservesSelectionAcrossRotation` | Stale test. It expected a 720-point card after `3bdd9865e` capped the card at the 751-point reference. The suite is skipped unless `EHPANDA_IPAD_UI_TESTS=1`, so the failure never showed. | Expects 751 points. | `abbf4d847` |

## The app bug

The first portrait-to-landscape rotation on iPhone left the previous gallery in the center. Rotating back restored the
selected one, and later rotations were correct.

A trace showed the selected id staying at 43 throughout, with no scroll phase. At a new width the lazy stack places the
selected card from its estimates for the unbuilt cards before it, and that first layout missed by more than half a
card, so `.viewAligned` snapped to the neighbor. Removing the center anchor changed nothing, and rotation does not
refetch the shuffled list.

`CardSlideSection` now holds a `ScrollPosition` and repeats the selected id whenever `centeringMargin` changes, the same
approach `AdvancedList` uses on a width change. Geometry still only observes the selection and never chooses a card, and
a drag, a deceleration or a height-only change does not reach this code.

The seed must be a plain `Int`. `ScrollPosition(id:)` with an `Int?` compiles but matches no card, so the carousel opens
on the first slot of the window.

## Verification

All on iOS 27.2 simulators, iPhone Air and iPad Pro 11-inch (M5). No test passed only on a retry.

- `FeatureTests` without `VisualSnapshotTests`: 1,395 tests, 1,385 passed, 10 expected failures, 0 failed.
- `AccessibilityAuditUITests` on iPhone: 28 passed, and the iPad-only case skipped.
- On iPad with `EHPANDA_IPAD_UI_TESTS=1`, `LandscapePaneUITests` and the three Home audits: 7 passed, and the Duo-only
  case skipped.
- Negative control: without the repeated id, `testHomeRootAudit` failed all three attempts, each naming two different
  galleries.
- Swipes on iPhone: 28 swipes crossed the window rebase in both directions (ids 43 to 54 to 37). Each moved one card, in
  order, and every rotation in between kept the selection centered.
- SwiftLint reports no violations.

## Left open

- **VoiceOver rotation offset.** With VoiceOver focus on a carousel card, rotating leaves the card selected but 40
  points off center until the next flick. The card first lands centered, then moves about 0.6 seconds later with a
  momentary `interacting` phase, which is consistent with VoiceOver's own scroll to its focus. With focus elsewhere
  there is no offset. The old code does this in portrait; with this fix it also happens in landscape. It is not
  corrected, because writing the position at `.idle` is what the carousel's design rules out.
- **VoiceOver order, on the old code too.** From the card focused at launch, one flick reaches the next card and the
  second jumps to the Front Page heading. Flicking back from the heading enters at the third card. Both builds took the
  same path in the same walk on iPhone. The cause has not been investigated.
- **Carousel rotation on Duo.** The suites below rotate Duo with Home open, but none of them checks which card stays
  selected, so the rotation fix was not exercised there. The test that checks it runs on iPad and is skipped on Duo.

## Duo run

The owner approved a serial run on 2026-11-02 for the Duo suites below. `Scripts/run-duo-ui-tests.py` passes
`-parallel-testing-enabled NO`, because a simulator clone loses the posed hinge. Test plans, suites and the runner are
unchanged. The host pose driver the runner asks for was not installed, so this run used a scratch driver over the
simulator's command-line tools, which is not committed. An `EhPanda iPhone Duo` simulator on iOS 27.2 (24B91016s) was
created for the run and deleted after it.

| Suite | Pose | Result |
| --- | --- | --- |
| `DuoHomeUITests` | half open (130 degrees) | 8 passed |
| `LandscapePaneUITests` | open | 2 passed, 3 iPad-only cases skipped |
| `DuoReadingPanelUITests` | half open | 2 passed |
| `ReadingOrientationUITests` | half open | 2 passed, 1 ordinary-phone case skipped |
| `ReadingOrientationUITests` | closed, with `--cover-display` | 2 passed, 1 ordinary-phone case skipped |
| `DuoToolbarUITests` | closed, landscape | 1 passed |

Each passed on its first attempt. The first run failed three stale tests, and no app code changed for them.

- `testOtherListsPresentOnTheRight` queried a button labeled exactly `Popular`. Destination cards combine their labels,
  so it now matches the start of the label, as `LandscapePaneUITests` does (`9426dd900`).
- `testPortraitUsesOnePaneAndPushesLists` looked for the old Favorites tab, `heart.circle`. It now uses the Library tab,
  `books.vertical.circle` (`9426dd900`).
- `DuoToolbarUITests` still expected a five-tab bar that collapses, with both list tools visible. It failed all three
  attempts. The bar now has four tabs, and on the closed display in landscape they all fit while the system folds Seek
  to Date and Filters into its More menu. The test is now `testListToolsAndEveryTabStayReachable`, which checks the
  tabs' positions, switches to Library and back, and opens Filters from More (`9426dd900`).

The two list tools therefore take one more tap in that pose. That the folding began with the move to four tabs is
inferred from the test's history, since no build from before that change was run.

Landscape on the closed display has to be set while an app is frontmost, because the Home Screen refuses it. The toolbar
suite's first run was in portrait for that reason, and its later runs were in landscape.
