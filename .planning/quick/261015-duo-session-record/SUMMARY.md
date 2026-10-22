---
type: retrospective-summary
recorded: 2026-10-15
historical_duo_implementation_commits: 21
library_implementation_commits: 36
decision_records: 127
---

# Delivery and commit ledger

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

Current title policy: D119 retires the simplified-title setting and transformation from lists and
Home. Earlier D80/D100 entries below remain historical; existing line limits/layouts are retained.

This session extends measured/window-based routing with Duo Home panes, native opposite-side
presentations, independent title behavior, persistent reader controls and configurable orientation
automation. Later owner choices initially extend landscape panes to fully open Duo and eligible
iPad, with distinct separators and movable reader controls. D91 restores iPad Home to one pane;
the independent iPad reader controls remain active. The app-wide Library follow-up combines
Favorites/Downloads around management, with the owner-selected shared category navigation and
separate groups. Quick task `261015-tx1` implements independently remembered row/grid choices and
a regular grid. D120 retains the current Search design and closes the earlier A/B choice; old
prototypes remain comparison material.

The first four commits were inherited from the supplied handoff; the remaining seventeen were
created during this session. Implementation references below point to the replayed commits. MIGRATION.md retains the explicit
old→new mapping. Historical test results belong to original source trees, not these integrated trees.

| Commit | Responsibility | Decisions |
|---|---|---|
| `7cf9ff16ef` | Seed reader pager from measured container | D03 |
| `605b4e4749` | Route host Detail and Setting by both size classes | D01–D02 |
| `e03456839a` | Local size-class layout and native search suggestion placement | D01 |
| `1c79f36368` | Horizontal safe areas for prose | D04 |
| `4191a6bb09` | Scoped native toolbar probes and persistent reader indicator | D06, D24, D45 |
| `8c332e2a21` | Split Home, six rankings, opposite-side lists/details, native tab compression | D15–D17, D21 |
| `7319a710b4` | Independent pane navigation preserves left title during right scroll | D18 |
| `2d298eeba6` | Owner-selected soft crease B | D19 |
| `5365df2f7d` | Landscape-only Home splitting; initial toolbar policy later corrected | D20, D22 |
| `c1a0139b1c` | Configurable automatic reader orientation and all-device landscape dual-page menu | D25–D27 |
| `f0f2b435f2` | Preview lifetime follows the complete slider touch | D29 |
| `67f5829629` | Cover-display orientation driver and actual page-pixel assertions | D44–D45 |
| `30ef583d21` | Owner-selected 50% sun in wide NewDawn sheet | D28 |
| `0b72a1db9d` | Restore side tabs and retain full host for pushed pages | D22 |
| `49b70a328e` | Whole-Home refresh in side toolbar | D23 |
| `f23bf58d1c` | Right-half reader controls and no duplicate Duo landscape Close | D30 |
| `5ab03faff3` | Fully open Duo/iPad landscape panes and movable half controls | D31–D34 |
| `24ede29e5f` | Opposite move button, animation, iPad Close above slider | D35–D37 |
| `1eb8bdcdfe` | Plain iPad divider; crease only on Duo | D38 |
| `52e2547c11` | Top-boundary divider treatment and narrower iPad Toplists cells | D39–D40 |
| `37461f3980` | Final 2 pt iPad divider | D41 |

## Final implementation boundaries

- Ordinary navigation still follows window size classes. Home's special opposite-side presentation
  policy applies to eligible split Home and its nested lists/details; there is no all-tab sheet rewrite.
- Split Home is landscape-only, root-only, and preserves a full navigation host for pushed pages.
  D91 restores iPad Home to a single pane; Duo cover remains single-pane. The iPad reader still
  supports movable half-width controls independently of Home.
- Physical placement accounts for asymmetric safe areas and stays physical left/right in RTL.
  A native presentation owner handles the nested sheet composition that failed in the SwiftUI experiment.
- Reader auto-orientation is a persistent, default-enabled capability policy for iPad/Duo, including
  first entry. Ordinary iPhones gain the manual landscape control, not automatic direction changes.
- The final production layouts use shared measured geometry. Arrangement feasibility does not mean
  the app switched to a 27.1-only arrangement implementation; deployment remains compatible with 27.0.
- The divider, controls and proposal prototypes do not change the download manifest authority.

## Documentation recovery

The missing record is supplied as CONTEXT, DISCUSSION-LOG, SUMMARY, VERIFICATION and LEARNINGS,
with historical evidence reports and the final screenshot proposal. Original reports are retained
as historical snapshots with their obsolete statements clearly subordinate to the final decision log.
This is not a claim that all historical tests were rerun during documentation recovery.

Tracked neutral screenshots make the approved visual choices and pending proposal review durable.
Raw live-content screenshots, simulator logs and build products remain local. Migration preserved
the useful ignored evidence and existing preview, then removed the old checkout and branch.

## Phase 17 integration follow-up

`2ce594b178` aligns 17 files with Phase 17's explicit/public-import requirements and synchronizes
one Reduce Motion source-inventory test with the approved Home extraction and slider animation.
No production behavior was added in this follow-up. Fresh build/lint/test evidence, D55's simulator
isolation authorization and exact migration state are in [Migration](MIGRATION.md).

## App-wide design follow-up

D56–D58 expand the discussion beyond Duo and propose merging Favorites/Downloads into Library.
[Library direction](LIBRARY-DIRECTION.md) distinguishes the owner's rationale from the assistant's
engineering choices and the D64-selected shared navigation with separate groups. The earlier
A/B screenshots are comparison material, not an approved merged-Library design.

D59–D61 replace the global detail/thumbnail direction with independent row/grid choices for six
named lists. Grid is the proposal's regular aligned grid, replacing waterfall. This is an accepted
design clarification, now implemented with rendering, independent persistence and versioned migration.
Engineering defaults and validation are recorded in quick task `261015-tx1`.

## Workspace rebuild

D62 rebuilds this session on `agent/app-design` from the latest `feature/gsd-phase-17` base
`e6efecb69f`. The Library/per-list design record was carried forward as `3c3a12ad36`; earlier Duo
implementation and rewritten SHA references come directly from the new base. See
[Workspace rebuild](WORKSPACE-REBUILD.md) for preservation and cleanup evidence.

## Library implementation and current evidence

| Commit | Responsibility |
|---|---|
| `e43ab6bd06` | Shared Library navigation, source routing and independently persisted row/grid scopes |
| `2b361c1046` | Native layout menu, aligned grid and offline native tracer |
| `f9058a06eb` | Downloads row/grid management with stable per-gallery confirmation ownership |
| `5536aec8ea` | Native category links, surviving scroll anchor, visible-row restoration and pagination |
| `56f906c766` | Current UI regression suites and exact-identity validation runner |

Current evidence: 959 FeatureTests identities (949 pass and 10 named existing expected diagnostics),
6/6 UI tests on each of iPhone, iPad and Duo, zero build warnings/errors, strict lint clean in 53
changed Swift files. Native checks include live text sizes, iPad window resizing with query/status,
selected VoiceOver actions and Duo folds/rotation with a retained query/status sheet. All dedicated
devices were restored and normal launch checked. See the [quick summary](../261015-tx1-implement-library-with-shared-favorites-/261015-tx1-SUMMARY.md)
and [validation limits and screenshots](../261015-tx1-implement-library-with-shared-favorites-/VALIDATION.md).

This completes the selected Library implementation, not Phase 17 or a whole-app accessibility audit.
The historical proposal preview was subsequently stopped under D65; its saved artifacts remain.

## Sidebar background follow-up — 2026-10-16

D67 is implemented in `82da111f79`: opaque adaptive Library sidebar background, preserving the
same-toolchain baseline title/search geometry. Native extension and container probes, light/dark
and compact screenshots, build/lint results and exact scope limits are recorded in
`../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-BACKGROUND.md`.
The iPad app stays open for owner review; the previous proposal preview is stopped under D65.

## Native sidebar scroll-edge follow-up — 2026-10-16

D68 supersedes D67 after the owner's upward-scroll capture exposed the remaining blur boundary.
`e257ee2050` extends Library's completed native NavigationSplitView through the top container safe
area and removes the opaque List fallback. Actual scrolled light/dark captures establish continuity
behind the status bar, while native titles/search retain safe clearance. Focused build/lint checks,
iPad live rotation, standard/AX1/AX3/AX5 cold/live entry on iPad and iPhone, and Duo folds/orientation
are recorded in [the current report](../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-SCROLL-EDGE.md).
The report distinguishes the early AX5 navigation sample from its settled successful check and
does not claim the broader suites or iPad window resizing were repeated. The iPad remains running
for owner review; the compact iPhone and Duo are shut down.

## Library sidebar actions — 2026-10-16

`21473abc07` delivers D69–D73: native fixed expanded columns with the toggle removed, Downloads-first
expandable sections, native sectionActions for management and default-folder creation, and removal
of the duplicate Downloads toolbar manager. The create operation owns its refresh through completion
and reports retryable failure. Nine focused tests pass; native iPad/iPhone/Duo and four text-size
checks are detailed in [SIDEBAR-ACTIONS.md](../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-ACTIONS.md).
The iPad is left open on Library / Downloads; the other dedicated devices are shut down.

## Header stability — owner-deferred; native toggle restored

D74 adds the owner's Library header displacement report and sidebar close/reopen observation.
The native tab/split interaction reproduces independently. D75 retains the native sidebar and
defers the unresolved defect; the fixed-pane prototype is not adopted. D76 restores the working
native toggle, initially expanded, superseding D69's fixed-open requirement. See the quick task's [investigation](../261015-tx1-implement-library-with-shared-favorites-/HEADER-STABILITY.md).

D76 implementation: `25848cc4dc` — restore native sidebar visibility control. Current validation
and the owner-deferred header issue are recorded in the linked investigation. This commit does
not replace native navigation or claim a framework layout fix.

## Folder-only Downloads navigation

D77 is implemented in `b2d1d602dc`: remove the generic Downloads sidebar link, retaining actual
folder links and native folder actions. The existing category navigation regression now uses a
test-owned Inbox folder and passes on compact iPhone. Build/lint and iPad native folder entry are
verified; [evidence](../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-ACTIONS.md#folder-only-navigation-follow-up--d77)
includes the unedited final screenshot. The iPad remains open for owner review.

## Preview review resumed

D78 reopens the unchanged historical proposal at `http://127.0.0.1:55920/index.html`.
The saved page and all nine screenshots are available, and the in-app browser tab remains open
for review. This supersedes D65's stopped-preview state without changing any design selection.

## Grid appearance and simplified titles

Initial D79–D80 delivery in `7b58987a7d` (corner/ratio/line limit superseded by D81): transparent grid
cards, square covers using the established background, three-line vertically centered titles, aligned row edges, and default-on simplified
titles across all row/grid lists. The setting is in Appearance → Gallery and preserves old settings.
The 97 model tests and four UI tests pass, with zero build warnings/errors or lint violations.
See [implementation and retained evidence](../261015-tx1-implement-library-with-shared-favorites-/GRID-TITLES.md)
for exact scope, corrected failed attempts, eleven native screenshots and review-device state.
The iPad remains open at Library Favorites with its real data; Phase 17 gates are unchanged.

## Grid cover clarification — D81

`428897f452` corrects all four cover corners to rounded, uses the owner's reference cover's original
2117:3000 ratio and reduces grid titles to two lines. Transparent containers, centered short titles,
aligned row edges and default-on simplified titles remain. Two focused UI tests pass across iPad
and iPhone standard/AX1/AX3/AX5, with clean builds/lint and eight original screenshots. The first
visual attempt exposed the nested category clip; final compositing and corner checks resolve it.
See [current evidence](../261015-tx1-implement-library-with-shared-favorites-/GRID-TITLES.md#cover-correction-verification--d81).
The iPad is updated and open for review; the known native header issue and Phase 17 gates are unchanged.

## Grid metadata and context menus — D82–D85

`8b2f03519b` removes horizontal metadata padding from every grid card, hides ratings only in Library
grids, and replaces the Downloads Actions button with the card's native context menu. Stable
per-gallery delete confirmation and accessibility actions remain. Five focused UI tests pass on
iPad/iPhone, including four text sizes, non-Library ratings, folder move, Pages, local reading,
cancel/delete and relaunch. Builds/lint are clean; fifteen original fixture screenshots are retained.

D85 is an API investigation, not a selected redesign: SwiftUI inspector cannot be forced into a
right-edge floating overlay through its public style preferences. Native popover or app-owned
panel remain alternatives; existing Details/Pages presentation is unchanged. See
[implementation and evidence](../261015-tx1-implement-library-with-shared-favorites-/GRID-LIBRARY-REFINEMENT.md).
The updated review iPad is open; Phase 17 and the deferred native header issue are unchanged.

## Native floating Downloads trial — D86

`cb029d6db0` adds the authorized trial of Details/Pages over the right side of a wide Downloads list.
It uses native iOS 27 sheet placement and leaves the grid width unchanged. Narrow entry retains its
prior presentation. Three final UI tests pass with clean build/lint and five original screenshots.
The review iPad was updated for the trial; D88 subsequently rejects and reverts it. See [trial report](../261015-tx1-implement-library-with-shared-favorites-/FLOATING-PANEL-PROTOTYPE.md).

## Actual SwiftUI inspector trial — D87

`658ba665b2` replaces the D86 presentation with real `.inspector`, owned outside Library's native
NavigationSplitView. On the tested iPad it automatically overlays the right side with unchanged
grid-card geometry; on iPhone it becomes a native sheet. The Details close action targets the
presentation state so it still works after nested navigation. All 30 selected feature tests and
three iPad/iPhone UI tests pass with clean build/lint and matching source hashes. Six original
screenshots and the frame record are retained. The review iPad was updated for that trial.
D88 rejects and reverts the trial. See [D87 report](../261015-tx1-implement-library-with-shared-favorites-/NATIVE-INSPECTOR-PROTOTYPE.md).

## Presentation trial rollback — D88

The owner rejects the sheet effect, inspector transparency and inspector-induced recurrence of
background clipping below the status bar. Every non-docs change since D86 is reverted, restoring
`019b598a66` source behavior while preserving the trial docs and screenshots. D82–D84 remain active.
Rollback commit: `b20b6ff8a43d45d8c05d04dcdfb203699201fb9c`.
The implementation-commit count includes this rollback, not an additional delivered feature.
See [rollback record](../261015-tx1-implement-library-with-shared-favorites-/PRESENTATION-TRIAL-ROLLBACK.md).

Rollback validation: 32/32 feature tests and 1/1 iPad UI test pass; zero build/lint diagnostics.
The original review iPad is running the restored implementation with existing data.

## Library single/double tap — D89

`c484eb3a0aa4dde4eed037e071b74d5f6c153b20` makes single tap open Detail and double tap open reading in Library Favorites
and Downloads, in both row and grid. Native exclusive recognition prevents a hidden Detail beneath
the reader; Read remains in context menus and accessibility actions. Favorites prefers local
content and otherwise resolves remote reader metadata, with loading/error feedback and background
progress persistence. Existing presentation routes and D88's rollback remain intact.

Fifty feature tests and five final native iPad/iPhone UI tests pass; builds and strict lint are
clean. The original review iPad was updated in place. See [implementation and evidence boundaries](../261015-tx1-implement-library-with-shared-favorites-/LIBRARY-TAP-ACTIONS.md).

## Library visual follow-up — D90

`2f5706b0cfa24a5e880cdc301b3a457b153632b8` sets leading row-title alignment, adds neutral image tiles to Detail/Previews,
and removes Detail/Read from grid context menus. Downloads' lifted preview wraps its whole card
in an opaque background; ordinary cards remain transparent and accessible Read remains available.

Five iPad native checks pass. The iPhone management test reproduces a first-menu-item center-tap
failure twice; an independent native ScrollView/context-menu app reproduces it too. It remains
open, with no coordinate/timing patch or claim of all-device success. See
[visual/menu evidence](../261015-tx1-implement-library-with-shared-favorites-/LIBRARY-VISUAL-POLISH.md).
The review iPad is updated; the deferred header issue and Phase 17 gates remain unchanged.

## iPad Home rollback — D91

The owner withdraws iPad Home's two-column display and associated behavior. Home restores its
single scrolling section hierarchy, regular ranking layout and ordinary list/gallery routing;
the iPad divider and layout gating are removed. Duo Home and the shared reader capability policy
remain active. See [the scoped rollback and verification](IPAD-HOME-ROLLBACK.md).

Implementation: `ee11c8e800474bddfb5cb1054870ccb9ae9c242f`. Forty-four feature tests, the four-size single-pane UI case and the
final Home audit pass within their documented source boundaries. Rotation preserves the centered
carousel gallery via its native center anchor. Builds and strict lint are clean; the review iPad
is updated and the temporary test device removed. Intermediate failures remain in the report.

## Large-window Home exploration — D92–D94

Three [section-information proposals](../../sketches/001-large-home-information/README.md)
compare balanced, cover-led and grouped metadata presentations for iPad and a future macOS Home.
The framework, section order and destinations remain fixed. Owner review is pending; no app
source, implementation-commit count or Phase 17 gate changes. The brief itself is the reference,
following the owner’s instruction to stop inspecting the Mac App Store.


## Preferred Home refinement — D95–D97

The owner leans toward B and keeps C-style slideshow grouping only for ample available space.
The [B revision](../../sketches/001-large-home-information/README.md) removes the redundant Popular
source label and excludes uploader/date. One metadata set flows normally or groups at extra-wide
width; it is never repeated as a second summary. Other sections retain B, while original A/B/C
remain reviewable. Browser screenshots/geometry cover ordinary and extra-wide layouts, with a
600-wide check. This remains proposal work, not production approval or native validation.


## Slideshow selection — D98

C is now selected for slideshow, with no space-dependent mode switching in this iteration.
The [current B+C preview](../../sketches/001-large-home-information/README.md#selected-c-slideshow--d98)
uses C's compact card and below-title grouping while preserving the removal of Popular,
uploader/date and duplicate information. Other sections retain B. This supersedes D95's
conditional grouping; responsive design is deferred and app code remains unchanged.


## Home implementation and shared titles — D99–D100

`1cc211aee6158251c5ae3533cc59a22e33af1dc2` implements C slideshow with B Frontpage, Toplists and Other for measured
large single-pane Home. Compact/Duo structure and navigation stay intact. Slideshow excludes
Popular, uploader/date and duplicated metadata. Every Home gallery title and cover accessibility
label now follows the same default-on simplified-title setting; disabling it restores full titles.

Fifty feature/model tests pass; three native iPad UI cases pass, followed by a final-source pass
of the expanded title/layout case. Native four-size cold/rotation and live-size captures are
retained for iPad, with additional iPhone cold/live checks. Initial native-title blank frames and
LLVM profile-writer diagnostics are documented rather than suppressed. The original review iPad
has the final app with its data preserved; temporary test resources are restored/removed. See
[implementation and exact evidence boundaries](../261017-pjj-implement-b-home-sections-with-selected-/261017-pjj-SUMMARY.md).
Phase 17 and screenshot baselines are unchanged; this remains an owner-review implementation trial.


## Home corrections and slideshow proposals — D101–D104

`3673f4670652afa91bf54aa043b8ebdac2a81801` restores B Other divider/footnotes, removes Home Toplists uploader
and makes rating stars inherit text foreground throughout the app. Two existing native iPad UI
cases pass, including four-size cold entry/rotation and live title settings. Build/lint pass;
retained tooling diagnostics and evidence boundaries are in the
[follow-up record](../261017-pjj-implement-b-home-sections-with-selected-/FOLLOW-UP-20261022.md).
Review iPad is updated in place with data preserved. [Sketch 002](../../sketches/002-landscape-slideshow/README.md)
provides three landscape slideshow alternatives and portrait comparison; no winner is selected.


## Selected slideshow A and ranking spacing — D105–D106

`6644232f25285fa9724d5e708b8d10f8a5e964a9` applies the selected 720-point card cap in measured wide Home
viewports, preserving portrait and compact/Duo geometry. Toplists information uses an 8-point gap.
Three focused native iPad UI tests pass with clean build/lint, and the review iPad is updated in
place. [Exact verification and screenshots](../261017-pjj-implement-b-home-sections-with-selected-/SLIDESHOW-A.md).
This supersedes D104's pending selection; B/C remain comparison alternatives only.


## Home cell finishes — D107–D109

`13e688a7ad404ea45b6099fb99f478f1f187fa93` makes rich ranking gaps expand through the cell height, uses aspect-fill
for rich slideshow covers, and restores light tag backgrounds/fine outlines with adaptive dark
material and legible dark tag text. Native Home regressions pass; the final foreground-only change
receives a clean build and neutral warm/cool visual checks. The review iPad is updated with its data
preserved. [Verification, screenshots and scope](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).
D107 supersedes D106's fixed gaps. D111 resolves the separate gradient proposal: only tags change
in this pass; retain the existing card-wide brightness and foreground policy. The observed contrast
limitation remains documented. This scope decision requires no additional source change.


## Comment preview background — D110

`b15f385ee83eda5c5fdb7290ae08a1e09a056b0a` fixes content-dependent square/narrow comment preview cards by aligning
background painting with the final card frame. Nine native test identities pass, including sixteen
comment render configurations. Two separate verification repairs address a missing fixture argument
and XCTest result-name normalization. [Cause, commits and before/after evidence](../261022-comment-card-background/SUMMARY.md).
Review iPad updated; full Comments list behavior and Phase 17 owner gates remain unchanged.

## Stacked comment metadata — D112

`2a208fd3e7f02c5aeb380ae5eef7d0f2d09f5c6e` aligns the fallback score/date row to trailing, with the author leading and the
single-line arrangement unchanged. Two existing tests pass across 16 native render configurations;
strict lint/build pass. [Screenshot and verification scope](../261022-comment-card-background/SUMMARY.md).
The review iPad is updated in place.

## Slideshow tag material prototypes — D113

[Sketch 003](../../sketches/003-slideshow-tag-containers/README.md) compares native Liquid Glass and
regular Material in light and two dark palettes. Both variants pass strict lint/native builds;
production source and build were restored after six captures. D114 below resolves the selection.
D113 added review artifacts, not a production implementation commit.

## Selected Liquid Glass slideshow tags — D114

`75a50edd83449783730eab8931b515dd00f51c52` adopts sketch 003 A in both appearances. The final file matches the reviewed
prototype byte-for-byte; strict lint and a fresh native build pass. Existing A captures cover
light, warm dark and cool dark. The review iPad is updated in place and launched normally.
[Selection and verification](../../sketches/003-slideshow-tag-containers/README.md).

## Frontpage aspect-fill — D115

`980ea59d687ce6219fafb0725e9a5f70842eaa80` makes the Home Frontpage cover wall use aspect-fill in both rich and compact layouts.
The existing frame and rounded clip crop excess artwork while preserving its proportions. Strict
lint and a native iPad build pass without warnings/errors; the review iPad is updated and launched
normally. [Verification scope](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

## Toplists aspect-fill — D116

`20f9f8735f18013ae994f4a2b4a919c3256d6243` makes Home Toplists covers use aspect-fill in rich and compact arrangements, retaining
cover dimensions, information and spacing. Strict lint and a clean native build pass; the review
iPad is updated in place and launched normally. No new UI test run or screenshot is claimed.
[Verification scope](../261017-pjj-implement-b-home-sections-with-selected-/HOME-CELL-FINISHES.md).

## Closer slideshow fields and native iPad title policy — D117–D118

`34afba01d8219fd36e649cdb2e393c650ace25b4` reduces the Pages/Category group width cap to 360 points.
`a516a4adfe88fa5fcdd67db798e6918840f0aedc` hides Home's native title only on iPad with actual top-bar tabs,
using public tabBarPlacement/title-removal APIs and inline display mode. The localized navigation
title and Home back label remain; bottom/side/undefined placements retain inlineLarge.

Strict lint and native builds pass with zero compiler/analyzer warnings/errors; exactly two UI
tests pass with no skips/repetitions. They cover four-size cold entry/rotation, Frontpage push/back,
slideshow geometry and selection. Native live-resize evidence also verifies bottom-tab title
restoration. Review iPad updated normally, account/data/settings preserved; task devices removed.
[Research-first owner direction, official references, screenshots and exact scope](../261017-pjj-implement-b-home-sections-with-selected-/HOME-TITLE-TAB-PLACEMENT.md).


## Original gallery titles — D119

`8fcf087616613319652f6e3a0c38d7094d3f30c5` removes the simplification setting and bracket-removal implementation. Row/grid lists
and Home use stored titles directly, preserving line limits, layouts and Japanese-title selection.
Old settings retain unrelated preferences and omit the retired key on their next save. Strict lint,
native builds, 94 model test identities and three focused iPad UI tests pass. The UI checks cover
four text sizes, row/grid/relaunch, Appearance and Home. Review iPad updated in place; the task
test device is removed.
[Retirement, compatibility coverage and delivery evidence](../261015-tx1-implement-library-with-shared-favorites-/REMOVE-SIMPLIFIED-TITLES.md).


## Retain current Search — D120

The owner accepts the current Search design and requests no redesign. Its root shows Quick Search,
Recently Searched and Recently Seen in that order when data exists. Source inspection confirms
saved query shortcuts, up to 20 recent keywords and the 10 most recent gallery-history entries.
Neither earlier A/B proposal is selected. This records a design decision only; implementation
commit counts and the previous verified source remain unchanged.


## Search section order and empty text — D121

`7dea2ee67a3515e2a6abdf0ebd697c5b8200682e` changes the order to Recently Searched → Recently Seen → Quick Search and keeps
empty sections visible with localized secondary text. Populated content and native Search behavior
remain. Pinned lint/catalog checks and a generic Simulator SDK build pass without warnings/errors;
native empty-state/Show All checks pass, the review iPad is updated in place and the task device
is removed. [Verification and scope](../261022-search-section-placeholders/SUMMARY.md).


## Search empty-section spacing — D122

`b19295afa2a69925a7ac0de7e73f0008d7681840` adds a 96-point minimum height to the three empty section content frames.
Secondary text remains leading and vertically centered; populated sections stay unchanged.
Strict lint and the native build pass without warnings/errors. A new native iPad screenshot
confirms the roomier layout. Review iPad updated normally after a bounded retry; the task test
device is removed. [Screenshot and verification limits](../261022-search-section-placeholders/SUMMARY.md).


## Top-aligned Search placeholders — D123

`35957ec4ebd19fba24800dee725fdbc8514a443a` changes the three empty frames to `.topLeading`, retaining the 96-point minimum
height and existing section spacing. [Verification and delivery](../261022-search-section-placeholders/SUMMARY.md).


## Search spacing and history actions — D124–D126

`15c4e9ead3ad10da71974bf7a93f87aa2fc976b4` adds 24-point section gaps, equal keyword-control minimum heights and
native header Remove All actions. Both confirmations anchor correctly. Search removal retains
saved searches; browsing removal follows existing History semantics, explicitly including resume
positions. Sixteen Search tests, clean builds/lint and isolated iPad clear/relaunch checks pass.
[Decisions, confirmed policy, screenshots and delivery](../261022-search-section-placeholders/SEARCH-ACTIONS.md).
Review iPad updated normally, original data preserved; task device removed. Phase 17 unchanged.

Owner confirmation on 2026-10-23 resolves D126's earlier assumption: Recently Seen Remove All
clears all browsing records and their reading positions, matching History. Implementation and
verification evidence remain unchanged.


## Equal spacing around Recently Seen — D127

`105950892dbe7b28e4b2e80ce85a447378f9f5a9` removes keyword-only vertical padding and trailing invisible separator
space. Native iPad measurements confirm equal 24-point inter-section gaps; heading/content gaps
are 8 points and keyword controls retain their 44-point minimum. Clean builds/lint; review iPad
updated normally, capture simulator removed. [Evidence](../261022-search-section-placeholders/EQUAL-SECTION-SPACING.md).
