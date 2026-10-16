---
type: retrospective-summary
recorded: 2026-10-15
historical_duo_implementation_commits: 21
library_implementation_commits: 5
decision_records: 68
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
| `7015d62cd3` | Seed reader pager from measured container | D03 |
| `8fb2374536` | Route host Detail and Setting by both size classes | D01–D02 |
| `e89e896634` | Local size-class layout and native search suggestion placement | D01 |
| `e8736e940c` | Horizontal safe areas for prose | D04 |
| `0b0061bfe1` | Scoped native toolbar probes and persistent reader indicator | D06, D24, D45 |
| `628b8b7152` | Split Home, six rankings, opposite-side lists/details, native tab compression | D15–D17, D21 |
| `97b2dbfc7f` | Independent pane navigation preserves left title during right scroll | D18 |
| `3a6b817a99` | Owner-selected soft crease B | D19 |
| `fd75e0746a` | Landscape-only Home splitting; initial toolbar policy later corrected | D20, D22 |
| `a765486959` | Configurable automatic reader orientation and all-device landscape dual-page menu | D25–D27 |
| `5c72028f68` | Preview lifetime follows the complete slider touch | D29 |
| `22423a3296` | Cover-display orientation driver and actual page-pixel assertions | D44–D45 |
| `0a42b7fbb4` | Owner-selected 50% sun in wide NewDawn sheet | D28 |
| `9a5595c8ed` | Restore side tabs and retain full host for pushed pages | D22 |
| `d58ef18476` | Whole-Home refresh in side toolbar | D23 |
| `81f3b5cb58` | Right-half reader controls and no duplicate Duo landscape Close | D30 |
| `d25bd91135` | Fully open Duo/iPad landscape panes and movable half controls | D31–D34 |
| `b47eeac6ed` | Opposite move button, animation, iPad Close above slider | D35–D37 |
| `412285ee9a` | Plain iPad divider; crease only on Duo | D38 |
| `d7820e618e` | Top-boundary divider treatment and narrower iPad Toplists cells | D39–D40 |
| `c274f0eac7` | Final 2 pt iPad divider | D41 |

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

`197b643b74` aligns 17 files with Phase 17's explicit/public-import requirements and synchronizes
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
`720cd47b8d`. The Library/per-list design record was carried forward as `956beb3da2`; earlier Duo
implementation and rewritten SHA references come directly from the new base. See
[Workspace rebuild](WORKSPACE-REBUILD.md) for preservation and cleanup evidence.


## Library implementation and current evidence

| Commit | Responsibility |
|---|---|
| `e60ea41788` | Shared Library navigation, source routing and independently persisted row/grid scopes |
| `7948058ad2` | Native layout menu, aligned grid and offline native tracer |
| `8efc2074eb` | Downloads row/grid management with stable per-gallery confirmation ownership |
| `51102939a5` | Native category links, surviving scroll anchor, visible-row restoration and pagination |
| `030027e44c` | Current UI regression suites and exact-identity validation runner |

Current evidence: 959 FeatureTests identities (949 pass and 10 named existing expected diagnostics),
6/6 UI tests on each of iPhone, iPad and Duo, zero build warnings/errors, strict lint clean in 53
changed Swift files. Native checks include live text sizes, iPad window resizing with query/status,
selected VoiceOver actions and Duo folds/rotation with a retained query/status sheet. All dedicated
devices were restored and normal launch checked. See the [quick summary](../261015-tx1-implement-library-with-shared-favorites-/261015-tx1-SUMMARY.md)
and [validation limits and screenshots](../261015-tx1-implement-library-with-shared-favorites-/VALIDATION.md).

This completes the selected Library implementation, not Phase 17 or a whole-app accessibility audit.
The historical proposal preview was subsequently stopped under D65; its saved artifacts remain.

## Sidebar background follow-up — 2026-10-16

D67 is implemented in `0e9cffb810`: opaque adaptive Library sidebar background, preserving the
same-toolchain baseline title/search geometry. Native extension and container probes, light/dark
and compact screenshots, build/lint results and exact scope limits are recorded in
`../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-BACKGROUND.md`.
The iPad app stays open for owner review; the previous proposal preview is stopped under D65.

## Native sidebar scroll-edge follow-up — 2026-10-16

D68 supersedes D67 after the owner's upward-scroll capture exposed the remaining blur boundary.
`f179b90c99` extends Library's completed native NavigationSplitView through the top container safe
area and removes the opaque List fallback. Actual scrolled light/dark captures establish continuity
behind the status bar, while native titles/search retain safe clearance. Focused build/lint checks,
iPad live rotation, standard/AX1/AX3/AX5 cold/live entry on iPad and iPhone, and Duo folds/orientation
are recorded in [the current report](../261015-tx1-implement-library-with-shared-favorites-/SIDEBAR-SCROLL-EDGE.md).
The report distinguishes the early AX5 navigation sample from its settled successful check and
does not claim the broader suites or iPad window resizing were repeated. The iPad remains running
for owner review; the compact iPhone and Duo are shut down.
