# Selected slideshow A and Toplists spacing — 2026-10-22

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decisions and execution plan

- D105: Select sketch 002 A. Apply the narrower centered slideshow card and reveal neighboring
  galleries in wide single-pane Home; retain the accepted portrait arrangement, card/cover height
  and metadata. No additional or repeated information is introduced.
- D106: Home Toplists information feels too tight; modestly increase spacing without changing
  cover sizes or the existing ranking arrangements.

Use the already measured local Home viewport. For the rich slideshow in a viewport wider than
900 points and wider than tall, cap the current 90%-width card at 720. Keep 90% in portrait and
80% for existing compact/Duo panes. The aspect check also protects portrait on larger iPads;
the proposal's width-only 900 switch was provisional. Retain native centering, scroll identity,
snap behavior, gesture ownership and gradient selection. Set ranking information stack spacing
to 8 points. No navigation, title or scroll-edge changes are required.

Verify with strict lint, native build and existing four-size cold/rotation and title/layout UI
cases. Add a focused native regression for centered widths, adjacent-card visibility, preserved
selection/height through portrait and landscape, and forward/backward swipe selection. Keep
source hashes and screenshots. Update the review iPad in place after checks, then record the
actual implementation SHA and final results here and in the session decision ledger.

## Implementation and verification

Implementation commit: `6644232f25285fa9724d5e708b8d10f8a5e964a9`.

Only three production view files change: Home passes its already measured viewport size to the
carousel; the rich wide card uses the approved cap while its existing centering margin follows
that width; ranking metadata receives an explicit 8-point gap. No new global device query,
geometry observer, scroll command, wrapper or fixed-height restriction is introduced.

Strict lint passes on all four changed Swift files. Build for Testing reports zero compiler and
analyzer warnings/errors. The native single-pass gate passes three tests, with zero failures,
skips, expected failures or runtime warnings:

1. Live simplified/full/simplified title changes, aligned Frontpage rows and all Other destinations
   fitting within the viewport. The lower screenshot confirms the roomier ranking information.
2. Single-pane Home cold entry and rotation at Large, AX1, AX3 and AX5, plus Frontpage push/back.
3. New A regression: 720-point centered landscape card, both neighboring cards exposed by more
   than 100 points, portrait width restored to 90%, unchanged selected gallery and card height,
   centered selection after rotating back, and forward/backward swipes changing/restoring selection.

All 923 native source hashes match the committed tree. The new test passed on its first native
run; the initial lint pass identified two single-line closures in that test, which were fixed
before building. Evidence is retained in `.build/library/slideshow-a-20261022-ui/` (xcresult,
source hashes, build results, diagnostics, exported screenshots and exact test enumeration).
This build records zero LLVM profile-writer diagnostics; earlier run diagnostics remain in their
own records. No warning suppression or test retry was added.

## Screenshots

- Landscape A (image removed from repository history)
- Portrait preserved (image removed from repository history)
- Toplists 8-point spacing (image removed from repository history)

These are native fixture captures. Placeholder covers are intentional test evidence, not proof of
network artwork loading. Existing title/layout screenshot attachment names may still mention C;
the source hash and this record identify the new A width policy. No iPhone/Duo runtime sweep,
13-inch portrait run, live accessibility-size sequence or native resize-mode sweep was added for
this scoped change. Large-iPad portrait preservation follows the measured aspect guard and remains
an implementation guarantee not independently demonstrated on that device in this run.

The existing review iPad was updated in place and launched normally, with no fixture arguments or
SIMCTL_CHILD keys. Account/data were preserved. The task-created test iPad was shut down by the
gate and then deleted; the review iPad remains running. Device Hub and other sessions' devices
were not operated. Phase 17 owner gates, screenshot baselines and unrelated open issues remain.
