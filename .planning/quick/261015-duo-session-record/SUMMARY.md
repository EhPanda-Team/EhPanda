---
type: retrospective-summary
recorded: 2026-10-15
implementation_commits: 21
decision_records: 55
---

# Delivery and commit ledger

This session extends measured/window-based routing with Duo Home panes, native opposite-side
presentations, independent title behavior, persistent reader controls and configurable orientation
automation. Later owner choices extend landscape panes to fully open Duo and eligible iPad,
with distinct separators and movable reader controls. Favorites/Search/Downloads remain proposals.

The first four commits were inherited from the supplied handoff; the remaining seventeen were
created during this session. Implementation references below point to the replayed commits. MIGRATION.md retains the explicit
old→new mapping. Historical test results belong to original source trees, not these integrated trees.

| Commit | Responsibility | Decisions |
|---|---|---|
| `c4e9347f1` | Seed reader pager from measured container | D03 |
| `69f23462e` | Route host Detail and Setting by both size classes | D01–D02 |
| `ff58682f9` | Local size-class layout and native search suggestion placement | D01 |
| `7fb7fd1a6` | Horizontal safe areas for prose | D04 |
| `b564f590a` | Scoped native toolbar probes and persistent reader indicator | D06, D24, D45 |
| `fbfc01d1f` | Split Home, six rankings, opposite-side lists/details, native tab compression | D15–D17, D21 |
| `c005393aa` | Independent pane navigation preserves left title during right scroll | D18 |
| `2a2aef98a` | Owner-selected soft crease B | D19 |
| `506d15d14` | Landscape-only Home splitting; initial toolbar policy later corrected | D20, D22 |
| `d7d1de88c` | Configurable automatic reader orientation and all-device landscape dual-page menu | D25–D27 |
| `334a9876d` | Preview lifetime follows the complete slider touch | D29 |
| `c8a4294f9` | Cover-display orientation driver and actual page-pixel assertions | D44–D45 |
| `19a557ec5` | Owner-selected 50% sun in wide NewDawn sheet | D28 |
| `1bc342889` | Restore side tabs and retain full host for pushed pages | D22 |
| `b22b0cd54` | Whole-Home refresh in side toolbar | D23 |
| `2224ba1d9` | Right-half reader controls and no duplicate Duo landscape Close | D30 |
| `7527c96bb` | Fully open Duo/iPad landscape panes and movable half controls | D31–D34 |
| `52c668497` | Opposite move button, animation, iPad Close above slider | D35–D37 |
| `5859cf619` | Plain iPad divider; crease only on Duo | D38 |
| `8ca48f567` | Top-boundary divider treatment and narrower iPad Toplists cells | D39–D40 |
| `79a59892e` | Final 2 pt iPad divider | D41 |

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

`0af542eab` aligns 17 files with Phase 17's explicit/public-import requirements and synchronizes
one Reduce Motion source-inventory test with the approved Home extraction and slider animation.
No production behavior was added in this follow-up. Fresh build/lint/test evidence, D55's simulator
isolation authorization and exact migration state are in [Migration](MIGRATION.md).
