---
type: retrospective-summary
recorded: 2026-10-15
historical_duo_implementation_commits: 21
library_implementation_commits: 13
decision_records: 85
---

# Delivery and commit ledger

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

This session extends measured/window-based routing with Duo Home panes, native opposite-side
presentations, independent title behavior, persistent reader controls and configurable orientation
automation. Later owner choices extend landscape panes to fully open Duo and eligible iPad,
with distinct separators and movable reader controls. The app-wide Library follow-up combines
Favorites/Downloads around management, with the owner-selected shared category navigation and
separate groups. Quick task `261015-tx1` implements independently remembered row/grid choices and
a regular grid. Search A/B remains unresolved; old prototypes remain comparison material.

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
  iPad additionally needs top tabs and at least 640 pt content width. Duo cover remains single-pane.
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
