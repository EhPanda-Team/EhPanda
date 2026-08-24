---
phase: 16-dynamic-type-accessibility
plan: 07
subsystem: accessibility-testing
tags: [dynamic-type, accessibility, ipad, simulator, sim-use, D-03, D-04, D-13]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    plan: 06
    provides: "The completed iPhone matrix, numbered findings, simulator infrastructure, and evidence-only sweep protocol"
provides:
  - "All 78 iPad Group A matrix cells (#1–#13 × portrait/landscape × XXL/AX3/AX5) non-`pending`"
  - "First-class iPad evidence extending Findings #1, #3, #4, #5, #6, and #10"
  - "New iPad-only Finding #32 for category-badge and timestamp overlap"
  - "iPad D-13 observations for the hero-carousel title and login-blocked Favorites glyph case"
affects: [16-08, 16-09, 16-10, dynamic-type-sweep, accessibility-remediation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "iPad Dynamic Type walks judge regular-width layouts independently at six orientation/size cells and reuse numbered findings only for the same defect"
    - "Login-gated simulator rows remain explicitly blocked when no owner session exists; credentials are never manufactured or entered"

key-files:
  created:
    - ".planning/phases/16-dynamic-type-accessibility/16-07-SUMMARY.md"
  modified:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"

key-decisions:
  - "Watched, Favorites, and FolderManager remain `blocked: no iPad session` because `IPAD_LOGIN=none`; no credential seam was used."
  - "Shared iPhone/iPad defects retain Findings #1, #3, #4, #5, #6, and #10, while the iPad-only badge/timestamp collision is Finding #32."
  - "The sweep-created eight-page download is preserved in its Default folder because downloads are user-owned after creation."

requirements-completed: [A11Y-01]

coverage:
  - id: D1
    description: "All 78 iPad Group A Dynamic Type cells are explicitly judged or plan-authorized as login-blocked"
    requirement: A11Y-01
    verification:
      - kind: manual_procedural
        ref: "sim-use six-cell observe/scroll/judge walk plus per-screen pending-count scan for #1–#13"
        status: pass
    human_judgment: true
    rationale: "Dynamic Type clipping and overlap verdicts require visual judgment of the rendered iPad layouts."
  - id: D2
    description: "Every iPad finding reference resolves to a numbered Findings entry with iPad cells recorded"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "16-SWEEP.md findings-reference review and `git diff --check`"
        status: pass
    human_judgment: false
  - id: D3
    description: "The dedicated iPad simulator is restored without clearing its data or deleting downloads"
    requirement: A11Y-01
    verification:
      - kind: automated_ui
        ref: "Final sim-use/CoreSimulator readback: portrait, content size `large`, light appearance, Increase Contrast disabled"
        status: pass
    human_judgment: false
  - id: D4
    description: "Screenshot evidence remains outside the repository and generated documentation contains no absolute home path"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Repository image-status count 0; absolute-home-prefix count in 16-SWEEP.md 0"
        status: pass
    human_judgment: false

# Metrics
duration: 1h 21m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 07: iPad Group A Dynamic Type Sweep Summary

**The iPad Group A matrix is complete across 78 cells, exposing a new regular-width metadata overlap and extending six cross-device findings while preserving the simulator, evidence, and download state.**

## Performance

- **Duration:** approximately 1 h 21 m.
- **Started:** 2026-08-24T08:04:05Z.
- **Completed:** 2026-08-24T09:25:01Z.
- **Tasks:** 2.
- **Files modified:** 2.
- **Coverage:** 78 matrix cells: 36 pass / 24 finding / 18 login-blocked.
- **Evidence root:** `$HOME/Library/Caches/ehpanda-phase16/sweep/`; no evidence image entered the repository.

## Accomplishments

- Walked screens #1–#13 on the dedicated iPad in portrait and landscape at XXL, AX3, and AX5, including top and bottom observations for every reachable surface.
- Extended six existing findings with iPad-specific cells and opened Finding #32 for a regular-width category/timestamp collision.
- Updated both Group A D-13 cases with iPad evidence or an explicit login blocker.
- Restored and read back the iPad baseline as portrait, `large`, light appearance, and Increase Contrast disabled.

## Task Commits

1. **Task 1: iPad × Group A surfaces #1–#7** — `05ef57d1` (docs)
2. **Task 2: iPad × Group A surfaces #8–#13 and restore** — `21cf601c` (docs)

## Findings Opened or Extended

Full descriptions live in `16-SWEEP.md § Findings`. Evidence paths below are relative to `$HOME/Library/Caches/ehpanda-phase16/sweep/`.

| # | Change | One-liner | Representative evidence |
|---|---|---|---|
| 1 | Extended | The fixed-height hero carousel loses its title tail in every iPad cell, including landscape XXL. | `ipad-portrait-ax5-2-top.png`, `ipad-landscape-xxl-2-top.png` |
| 3 | Extended | Toplists fixed ranking cells lose title and then uploader text from AX3 on the iPad. | `ipad-portrait-ax5-7-top.png`, `ipad-landscape-ax3-7-top.png` |
| 4 | Extended | Filter/search capsules non-monotonically lose all contents on iPad list and Search-results surfaces. | `ipad-portrait-ax3-3-top.png`, `ipad-landscape-ax5-10-top.png` |
| 5 | Extended | A long Frontpage list title loses its tail at iPad portrait AX5 while landscape preserves it. | `ipad-portrait-ax5-3-top.png`, `ipad-landscape-ax5-3-top.png` |
| 6 | Extended | The Download Inspector timestamp loses its time at iPad AX5 in both orientations. | `ipad-portrait-ax5-12-top.png`, `ipad-landscape-ax5-12-top.png` |
| 10 | Extended | Search's fixed-height Recently Seen cards clip titles and overflow their contents from AX3 on iPad. | `ipad-portrait-ax5-9-top.png`, `ipad-landscape-ax3-9-top.png` |
| 32 | Opened | A long category badge paints over the timestamp at iPad portrait AX3/AX5. | `ipad-portrait-ax3-3-top.png`, `ipad-portrait-ax5-3-top.png` |

## D-13 iPad Observations

| Case | Result |
|---|---|
| Hero-carousel title truncation (#2) | Reproduced in all six iPad cells; even landscape XXL loses the title tail. Recorded under Finding #1. |
| Favorites trailing-glyph clip (#8) | `blocked: no iPad session` because `IPAD_LOGIN=none`; the document makes no inferred iPad glyph verdict. |

## Blocked Rows

| Surface | Cells | Reason |
|---|---:|---|
| #5 Home › Watched | 6 | Login-gated and the declared infrastructure value is `IPAD_LOGIN=none`; no credentials were entered. |
| #8 Favorites root | 6 | Login-gated and the declared infrastructure value is `IPAD_LOGIN=none`; no credentials were entered. |
| #13 Move-to-folder / FolderManager | 6 | Login-gated and the declared infrastructure value is `IPAD_LOGIN=none`; no credentials were entered. |

These are the only blocked Group A iPad rows; every other cell has a pass or numbered-finding verdict.

## Download and Simulator Preservation

- The Downloads route initially had no suitable sample, so the sweep created the small eight-page download `[R-MK] Snivy (Pokemon)` in the Default folder.
- The new download and every pre-existing user-owned download folder were preserved; nothing was deleted, erased, uninstalled, or cleared.
- The Inspector sheet was dismissed normally after the final AX5 capture.
- Final readback returned `large`, `light`, and `disabled`; sim-use reported the app at `834×1210` in portrait.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — all 78 Group A iPad rows, shared/new Findings entries, and D-13 observations.
- `.planning/phases/16-dynamic-type-accessibility/16-07-SUMMARY.md` — execution evidence, blockers, preservation record, and commit traceability.

## Decisions Made

- Reused existing finding numbers only when the rendered defect matched the existing description; opened #32 for the iPad-only collision.
- Recorded login-gated rows as blocked exactly as authorized instead of entering credentials.
- Preserved the sweep-created download as required by the repository's user-owned-download invariant.

## Deviations from Plan

None — the plan was executed as written.

## Issues Encountered

- The sandbox initially denied the simulator daemon/CoreSimulator connection during the final readback. Retrying the same approved simulator operations with simulator access restored the connection; the app remained present and no crash banner or process disappearance occurred.

## Known Stubs

None. This plan changed documentation only.

## Self-Check: PASSED

- `16-SWEEP.md` exists and contains six non-`pending` iPad rows for every screen #1–#13.
- Findings #1, #3, #4, #5, #6, #10, and #32 contain the iPad cells referenced by the matrix.
- Task commits `05ef57d1` and `21cf601c` exist in git history.
- No image is staged or untracked in the repository, and no generated document touched by this plan contains an absolute home path.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-08-24*
