---
type: retrospective-summary
recorded: 2026-10-15
historical_duo_implementation_commits: 21
library_implementation_commits: 5
decision_records: 64
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
The historical proposal preview remains running at `http://127.0.0.1:55920/index.html`.
