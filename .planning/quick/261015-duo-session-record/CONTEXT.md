---
type: retrospective-session-context
recorded: 2026-10-15
session_dates: [2026-10-14, 2026-10-15]
status: implemented-with-app-design-follow-up
original_source_branch: claude/iphone-duo-support-c0b23d
working_branch: agent/app-design
implementation_head: 37461f3980a0a057078b5539c54efea285ebf43e
---

# iPhone Duo and landscape support: complete session record

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

This record recovers the entire session, including the inherited handoff, owner choices,
implementation corrections, validation findings, and unselected proposals. It was written
retrospectively after the owner pointed out that these decisions belonged in GSD docs.
The original implementation commits updated only the scroll-edge inventory; most evidence
was left in ignored `.build`. This is a documentation failure, not evidence that a GSD plan
had been approved or executed. No retrospective PLAN is presented as a prior approval.

## Read this record

- [Decision log](DISCUSSION-LOG.md): all owner decisions and their supersession, with implementation references.
- [Summary](SUMMARY.md): commit ledger and current delivery boundary.
- [Verification](VERIFICATION.md): retained evidence, failures, corrections and remaining gaps.
- [Learnings](LEARNINGS.md): findings grounded in this session.
- [Library direction](LIBRARY-DIRECTION.md): management-focused Library with the selected shared category navigation and separate Favorites/Downloads groups.
- [Wide-screen proposal](proposal/PROPOSAL.md): nine earlier native screenshots, retained for comparison; D120 keeps the current Search design and closes the A/B choice; D121 reorders its sections and adds empty placeholders; D122 reserves a 96-point minimum content height when empty; D123 aligns its text to the top. D124–D126 add section gaps, equal keyword-row height and native Remove All actions ([delivery](../261022-search-section-placeholders/SEARCH-ACTIONS.md)).
- [Large Home proposals](../../sketches/001-large-home-information/README.md): original A/B/C plus current B+C mix for iPad/future macOS; D98 selects C slideshow and defers space-dependent adaptation. No repeated source label or uploader/date; other sections retain B. D99–D100 originally implement this mix and shared simplified titles in [quick task 261017-pjj](../261017-pjj-implement-b-home-sections-with-selected-/261017-pjj-SUMMARY.md), available for owner review.
- [Home corrections and landscape slideshow](../261017-pjj-implement-b-home-sections-with-selected-/FOLLOW-UP-20261022.md): D101–D103 implemented; D105 selects slideshow A from sketch 002 and D106 adds Toplists spacing. [Native A verification](../261017-pjj-implement-b-home-sections-with-selected-/SLIDESHOW-A.md) records implementation and screenshots. [D107–D109 cell finishes](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md) supersede fixed ranking gaps, fill slideshow covers and adapt tag backgrounds.
- [Migration](MIGRATION.md): original integration and rewritten commit mapping.
- [Workspace rebuild](WORKSPACE-REBUILD.md): current branch/worktree after rebuilding from the latest Phase 17 history.

The app-design follow-up also replaces the global detail/thumbnail direction with independent
row/grid choices for Frontpage, Popular, Toplists, Favorites, Search and Downloads. Grid replaces
waterfall with the proposal's regular aligned layout. See D59–D61 and LIBRARY-DIRECTION.md; the
production renderer is implemented by quick task `261015-tx1` and its later owner follow-ups.

The final decisions in DISCUSSION-LOG take precedence over historical evidence reports.
D119 removes the simplified-title setting and transformation throughout Home and row/grid lists;
see [the retirement record](../261015-tx1-implement-library-with-shared-favorites-/REMOVE-SIMPLIFIED-TITLES.md).
Existing line limits, geometry and Japanese-title selection remain.
In particular: D91 restores iPad Home to a single pane and ordinary navigation, removing its
divider and split-only ranking layout. Home splitting remains available on fully open/half-fold
Duo landscape. The move button stays opposite the reader slider; iPad retains its lower Close;
native Duo side tabs remain; and normal simulator launches must clear fixture flags. See
[the iPad Home rollback](IPAD-HOME-ROLLBACK.md).

## Scope and provenance

The user supplied a handoff with four existing commits, then approved and refined Home,
reader, presentation and toolbar behavior through this session. Direct owner messages and
option answers are the authority for product choices. Code and Git establish what was
implemented. Historical verification reports and retained logs establish what was tested;
static screenshots do not establish navigation, network or resize correctness.

Ordinary layout/presentation decisions use the current window's size classes and measured
geometry. Explicit device-capability requirements (automatic reader orientation and Duo/iPad
landscape panes) are separate product policies; they do not reinstate idiom-based width guesses.
Unrelated Phase 17 capture work remains in progress and is not marked complete by this record.

The initial Duo delivery did not include a push, PR, baseline promotion or implementation of
the wide-screen/Library proposals. Later owner decisions authorize the Library implementation;
its evidence is recorded separately. The saved proposal remains comparison material.


Latest investigation: [D110 comment preview shape](../261022-comment-card-background/SUMMARY.md)
reproduces and fixes narrow square backgrounds, with native before/after evidence and final tests.

Latest scope decision: D111 limits this pass to the completed slideshow tag adjustment. Preserve
card-wide gradient brightness/color variation and title/metadata foregrounds; the dimming proposal
is no longer pending. See [the recorded disposition](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

Comment follow-up: D112 aligns stacked comment metadata to trailing while the author stays leading.
[Implementation and native evidence](../261022-comment-card-background/SUMMARY.md).

D113 compares slideshow tag Liquid Glass and Material containers in
[sketch 003](../../sketches/003-slideshow-tag-containers/README.md). D114 selects and implements A
(Liquid Glass) exactly; fresh lint/build pass and the review iPad is updated in place.

D115 extends aspect-fill to Home Frontpage covers in rich and compact layouts. Separate row/grid
cover defaults remain unchanged. [Implementation and verification](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

D116 applies the same aspect-fill policy to Home Toplists covers in rich and compact arrangements.
[Implementation and verification](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

D117 brings slideshow Pages/Category closer. D118 hides Home's native title on iPad only while
actual tabs occupy the top bar, and restores it for other placements. The owner explicitly requests
official API investigation before custom implementation; the result uses public SwiftUI APIs.
[Research, native screenshots, two passing UI regressions and delivery](../261017-pjj-implement-b-home-sections-with-selected-/HOME-TITLE-TAB-PLACEMENT.md).
