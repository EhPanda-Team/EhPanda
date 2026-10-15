---
type: retrospective-summary
recorded: 2026-10-15
implementation_commits: 21
owner_decisions: 54
---

# Delivery and commit ledger

> **Image evidence availability:** Image files were removed from this repository history at the owner's request. Screenshot descriptions, filenames and earlier visual checks below are historical records, not currently available image evidence. Written findings, measurements and source artifacts remain; visual review requires fresh captures.

This session extends measured/window-based routing with Duo Home panes, native opposite-side
presentations, independent title behavior, persistent reader controls and configurable orientation
automation. Later owner choices extend landscape panes to fully open Duo and eligible iPad,
with distinct separators and movable reader controls. Favorites/Search/Downloads remain proposals.

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
Raw live-content screenshots, simulator logs and build products remain local. Migration must preserve
the useful ignored evidence and the existing preview before removing the old checkout.
