---
phase: 16-dynamic-type-accessibility
plan: 06
subsystem: planning
tags: [dynamic-type, accessibility, sweep, iphone, settings, sheets, sim-use, D-03, D-04]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    plan: 05
    provides: "The completed iPhone Group A/B rows, findings #1–#23, simulator baseline, and the established evidence-only sweep protocol"
provides:
  - "All 90 iPhone Group C matrix cells (#28–#42 × portrait/landscape × XXL/AX3/AX5) non-`pending`"
  - "A complete 252-cell iPhone half of the Dynamic Type matrix"
  - "Eight new numbered Findings entries (#24–#31) covering account values, activity-log state, EhSetting, Filters, Quick Search, and the error toast"
  - "All Group C D-04 sites dispositioned; one unrelated download-spinner site remains pending with its reachability reason recorded"
affects: [16-07, 16-08, 16-09, 16-10, 16-11, 16-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Simulator-only accessibility sweeps preserve the logged-in app container, keep screenshots outside git, and restore every temporary setting before baseline readback"
    - "A deliberately created Quick Search fixture is removed together with the search-history record it generates"

key-files:
  created:
    - ".planning/phases/16-dynamic-type-accessibility/16-06-SUMMARY.md"
  modified:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"

key-decisions:
  - "The logged-in simulator's native Login form remains blocked rather than forcing logout; preserving phase infrastructure takes precedence over manufacturing that state."
  - "D-13 observations use `open`, not matrix `pending`, after the iPhone evidence is recorded; owner disposition still remains for the later closeout plan."
  - "The download progress-spinner frame remains pending because neither Downloads surface had an active transfer; the missing runtime state is stated instead of inferred from code."

requirements-completed: []

coverage:
  - id: C1
    description: "All 90 Group C iPhone cells and all 252 iPhone matrix cells are non-pending"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`grep -E 'iPhone' 16-SWEEP.md | grep -c '| pending'` -> 0; rows #36–#42 each independently return 0"
        status: pass
    human_judgment: false
  - id: C2
    description: "Every Group C finding reference resolves to a numbered Findings entry"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Findings #24–#31 exist and the dangling-reference scan returns no numbers"
        status: pass
    human_judgment: false
  - id: C3
    description: "The required iPhone Air simulator is restored without destroying its data"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Final readback: content size `medium`, portrait, dark appearance, Increase Contrast disabled, EhPanda Home selected"
        status: pass
    human_judgment: false
  - id: C4
    description: "No image or absolute home path entered the repository"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "Image-status count -> 0; absolute-home-prefix count in 16-SWEEP.md -> 0; `git diff --check` clean"
        status: pass
    human_judgment: false

# Metrics
duration: 2h 20m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 06: iPhone Group C Dynamic Type Sweep Summary

**The iPhone half of the Dynamic Type matrix is complete: all 252 cells are judged, with Group C exposing eight additional failures in dense settings and sheet layouts while preserving the logged-in simulator and restoring its baseline.**

## Performance

- **Duration:** approximately 2 h 20 m across the resumed partial sweep and final seven-surface walk.
- **Coverage:** 90 Group C cells; status tally 57 pass / 27 finding / 6 blocked.
- **Evidence root:** `$HOME/Library/Caches/ehpanda-phase16/sweep/`; no evidence image entered the repository.
- **Task commits:** `19b76636` and `0af1a196`.

## Task Commits

1. **Task 1: iPhone Group C surfaces #28–#35** — `19b76636` (docs)
2. **Task 2: iPhone Group C surfaces #36–#42 and baseline restore** — `0af1a196` (docs)

## Findings Opened

Full descriptions live in `16-SWEEP.md § Findings`. Evidence paths below are relative to `$HOME/Library/Caches/ehpanda-phase16/sweep/`.

| # | Screen | One-liner | Evidence |
|---|---|---|---|
| 24 | #29 Account | Cookie-value fields surrender their credential fragments while their labels wrap; at AX5 portrait each value is only three or four characters plus an ellipsis. | `iphone-portrait-AX5-29-top.png`, `iphone-landscape-AX3-29-top.png` |
| 25 | #32 Activity Logs | The single-line category chip loses the subsystem name from AX3 portrait and at AX5 landscape. | `iphone-portrait-AX3-32-top.png`, `iphone-landscape-AX5-32-top.png` |
| 26 | #32 Activity Logs | The Runs menu stops drawing its selected-run checkmark from AX3 even though the accessibility tree still reports it. | `iphone-portrait-AX3-32-runmenu.png`, `iphone-landscape-AX5-32-runmenu.png` |
| 27 | #38 EhSetting | Excluded Languages headers refuse to wrap and overlap into an unreadable string from XXL portrait and at AX5 landscape. | `iphone-portrait-{XXL,AX3,AX5}-38-*.png`, `iphone-landscape-AX5-38-langheader.png` |
| 28 | #38 EhSetting | At AX5 portrait, consecutive multi-line picker rows paint through their separators and cover one another. | `iphone-portrait-AX5-38-segmented.png` |
| 29 | #39 Filters | Fixed category cells ellipsise two names at XXL and all nine at AX5 in both orientations, making multiple controls indistinguishable. | `iphone-portrait-{XXL,AX3,AX5}-39-top.png`, `iphone-landscape-{XXL,AX3,AX5}-39-top.png` |
| 30 | #40 Quick Search | The saved-word name's one-line cap truncates from XXL portrait in Edit mode and from AX3 in the ordinary row. | `iphone-portrait-ax5-40-top.png`, `iphone-landscape-ax5-40-top.png` |
| 31 | #42 Error toast | The toast title survives, but the one-line unsupported-link subtitle ellipsises in five of six cells. | `iphone-portrait-ax5-42-toast.png`, `iphone-landscape-ax3-42-toast.png` |

## Blocked and Remaining Rows

| Surface / site | Status | Reason |
|---|---|---|
| #30 native Login form, all six iPhone cells | `blocked: no logged-out session` | The form exists only in the logged-out branch. Logging out would violate D-09 and destroy the sweep's preserved authenticated state, so no login submission was attempted. The WKWebView and Cloudflare challenge remained out of scope. |
| `DownloadsFeature/DownloadsView+Subviews.swift:145` progress-spinner slot | `pending` | The spinner exists only during an active transfer. The download folder was empty and no transfer was started merely to manufacture this unrelated state; revisit when a later round has a legitimate active download. |

There are no pending iPhone matrix rows. The single pending D-04 entry is outside Group C's reachable runtime states and is listed explicitly rather than silently passed.

## State Preservation and Restore

- No logout, cache clear, login submission, purchase, download, or profile deletion occurred.
- The Quick Search item `Dynamic Type Sweep Throwaway` was created only for #40, then deleted through its own confirmation. Its generated `language:english` search-history entry was also removed, restoring the original empty list.
- Tags Extension and Show Tags Search Suggestion were temporarily enabled to expose the #42 suggestion rows, then both were switched back off and visually verified.
- The malformed deep link was opened only against `app.ehpanda.personal`; it raised the expected unsupported-link toast and error detail without navigating or modifying account data.
- The required iPhone Air finished at `content_size medium`, portrait, dark appearance, Increase Contrast disabled, on the Home tab. The final `simctl` content-size readback returned `medium`.

## D-04 Disposition

All Group C sites named by the plan are non-pending: EhSetting language headers and fixed controls, Filters category cells, Quick Search saved names, Date Seek picker rows, toast title/subtitle, tag-suggestion title/detail, and toast/state-view minimum heights. Date Seek and the detailed error sheet reflowed completely; tag-suggestion titles and detail lines remained complete at AX5; the toast subtitle became finding #31.

The only D-04 row still pending anywhere in the checklist is the active-transfer spinner noted above.

## Deviations from Plan

None — the resumed plan was executed as written. Unreachable Login cells and the inactive-transfer spinner are explicit evidence-based statuses, not execution deviations.

## Known Stubs

None. This plan changed documentation only.

## Self-Check: PASSED

- `16-SWEEP.md` exists and contains all Group C judgments plus Findings #24–#31.
- Task commits `19b76636` and `0af1a196` exist in git history.
- All iPhone `pending` checks return zero; all Group C finding references resolve.
- No image is staged or untracked in the repository, and no generated document contains an absolute home path.
