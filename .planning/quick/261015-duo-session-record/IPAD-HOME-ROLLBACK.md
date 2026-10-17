# iPad Home single-pane restoration — D91

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

## Owner decision

Withdraw the iPad Home two-column changes. Restore one vertically scrolling Home with the
original section order and ordinary list navigation. Remove the iPad divider, six-row ranking
variant and split-specific opposite-side presentation. iPhone Duo Home and reading controls are
outside this rollback.

This supersedes D31–D32’s iPad Home extension and D38–D41’s iPad Home divider/ranking
refinements. Reader choices D33–D37 remain active. Historical decisions and verification retain
their original commit attribution.

## Scoped implementation plan

- `HomeView.swift`: remove iPad tab-placement/width gating and its divider.
- `HomeReducer.swift` and `HomeReducer+Body.swift`: remove iPad split state/action; make Home's
  split eligibility Duo-only without changing shared reader/device capabilities.
- `HomeSectionsView.swift` and `HomeView+Sections.swift`: remove the iPad-only ranking width;
  ordinary Home resumes its regular-width ranking grid. Center the native carousel target
  explicitly so rotation retains its selected gallery.
- `HomeDuoPresentationTests.swift`: revise iPad routing/resize expectations, retaining Duo cases.
- `LandscapePaneUITests.swift`: keep opposite-side Home assertions Duo-only; verify iPad single
  pane, native title, normal Frontpage push/back and rotation at standard/AX1/AX3/AX5.
- `AccessibilityAuditUITests.swift`: cache each carousel button’s geometry in the existing
  measurement helper, preserving eligibility, centering/selection checks and the 15-second budget.

## Verification

Implementation commit: `ee11c8e800474bddfb5cb1054870ccb9ae9c242f`.

| Evidence | Result | Scope |
|---|---|---|
| `ipad-home-rollback-feature-01` | 44 passed, 0 failed/skipped/expected failures | All HomeFeature tests, including iPad gallery delegation, all five list routes, resize/navigation retention and Duo opposite-side presentation |
| `ipad-home-rollback-ui-03` | 1 passed, 1 failed | Single-pane/title/rotation/text-size and Frontpage push/back pass; Home audit reaches its unchanged 15-second rotation budget at 17.94 seconds |
| `ipad-home-rollback-ui-04` | 1 failed | The unchanged readiness budget passes after caching frames; selected-gallery equality reveals a real carousel selection change on rotation |
| `ipad-home-rollback-ui-05` | 1 passed, 0 failed/skipped/expected failures | Final-source Home accessibility audit and portrait–landscape–portrait carousel selection/centering/readiness checks |
| `ipad-home-rollback-support/final-lint.log` | 8 Swift files, 0 violations | Final strict lint for all changed production/test files |

Evidence is retained under `.build/library/`. The selected native runner explicitly receives
`EHPANDA_IPAD_UI_TESTS=1`; repetition/retry policies are removed by the existing single-pass helper.
The isolated test iPad is distinct from the original review iPad. No Device Hub is used.
The initial `ipad-home-rollback-ui-01` generic two-architecture preparation was cancelled before
any tests ran. `ipad-home-rollback-ui-02` compiles successfully but the native gate refuses its
ambiguous generated run selection: the prior generic manifest and current arm64 manifest coexist.
The obsolete generic manifest is archived with its hash outside Build/Products, preserving it
without letting a stale architecture/source tree enter the final selection. Later runs target the
actual iPad with `ONLY_ACTIVE_ARCH=YES`; every selected case is executed once per named run.

The feature and final UI builds report zero compiler/analyzer warnings and zero errors.
Reducer and feature-test hashes remain identical to the passing feature run. Relative to that
run, source differences are the native carousel center anchor and the two UI-test refinements
(window-aspect waiting and cached frame reads). Relative to UI-03, only the carousel anchor and
audit helper differ. UI-05 hashes match the committed Swift sources exactly. The earlier
four-size layout result is not represented as a rerun on the final center-anchor source.
Existing root titles and soft top-edge modifiers are retained. The scroll-host inventory now records iPad Home as a single ScrollView.

The rollback removes the iPad Home two-column switch and its related state/action rather than
leaving a disabled layout variant. It also removes the iPad-only ranking-width parameter. Shared
`WindowDevice.supportsLandscapePanes` stays unchanged because the reader still uses it.

## Verification finding: screen-readiness measurement

The first actual native run preserves its failure. The rotation itself completes at t=91.76 and
carousel existence is confirmed by t=93.38; the helper then repeatedly queries button geometry
and labels until the timer reaches 17.94 seconds. Its `min` comparator re-reads the same remote
`frame` values, including more reads for the final centering check. This measures repeated driver
queries as well as readiness.

The revised helper reads each button frame once into a labeled tuple, applies the same visible /
non-empty-label eligibility, compares cached geometry and returns the same XCUIElement. It keeps
the exact centering tolerance, selected-label equality and 15-second limit. The passing four-size
layout test does not use this helper; UI-04 and UI-05 recheck only the affected audit.
There is no app performance workaround, threshold increase or expected-failure conversion.

## Verification finding: carousel resize anchor

UI-04 retains a real selected-gallery equality failure after the driver-query optimization.
Rotation settles within the original readiness budget and centers a card, but that card differs
from the pre-rotation selection. The horizontal carousel was tracking a target ID without an
explicit anchor even though its design centers that target. The final fix specifies
`scrollPosition(id:anchor:)` with `.center`, keeping native scroll ownership, existing gallery IDs,
view-aligned snapping and geometry observation. No timer, manual resize scroll or lowered assertion
is introduced. UI-05 passes the original assertions in both rotation directions.

## Tooling diagnostics

UI-02 contains non-fatal LLVM `default.profraw` write diagnostics. Cached macro executables contain
LLVM profile runtime symbols. Later preparation provides an explicit temporary `LLVM_PROFILE_FILE`
pattern rather than discarding stderr or disabling profiling. UI-03’s incremental build reports
zero compiler/analyzer warnings/errors and no LLVM profile write diagnostic; UI-05 reports the
same clean result. Original logs remain
retained; this is not a claim about every future cold macro build.

## Limits and cleanup

UI-05 restores the test iPad to Large and its original shutdown state; the task-created device is
then deleted. The original review iPad is updated in place and launched on Home with existing
account/data retained. The dedicated feature-test iPhone is left at its original Large/shutdown
state. Device lifecycle and final launch evidence remain in the local run/support directories.
The optional sim-use preflight reports an incompatible installed CLI version; no upgrade or
UI-driving fallback is attempted. Native XCTest results remain the verification basis.

The four-size fixture screenshots
remain in the native result bundle; they show placeholder covers and do not prove image loading.
Duo preservation is covered by the feature tests; native UI checks in this rollback target iPad.
These focused checks do not claim physical-device VoiceOver coverage, successful remote image
loading from hermetic fixtures, resolution of the Library native-menu/header issues, or Phase 17
completion. No capture baseline is promoted.
