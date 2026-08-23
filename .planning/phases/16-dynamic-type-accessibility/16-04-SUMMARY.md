---
phase: 16-dynamic-type-accessibility
plan: 04
subsystem: planning
tags: [dynamic-type, accessibility, sweep, iphone, group-a, D-03, D-04, D-13]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    plan: 03
    provides: "`16-SWEEP.md § Infrastructure` — IPHONE_UDID, BUNDLE_ID, login state, recorded baselines, the sim-use tooling map and the A1/A6 pre-flight confirmations"
provides:
  - "All 78 `iPhone — Group A` matrix rows (#1–#13 × portrait/landscape × XXL/AX3/AX5) judged and non-`pending`"
  - "Twelve numbered § Findings entries with written descriptions, covering title truncation, right-edge clipping, overlap, a blanked search field, a lost navigation title, a squeezed cover, a truncated destructive-confirmation message and the thumbnail-layout grid"
  - "Both Group-A D-13 rows observed (hero-carousel title truncation; Favorites trailing-glyph clip — the latter does NOT reproduce)"
  - "Nine D-04 checklist rows dispositioned, including all five `GalleryDetailCell` sites and both paired `minimumScaleFactor` shrinks"
  - "Corrected `§ Tooling` rotation row plus two newly documented sweep mechanics (landscape screenshot orientation, home-indicator app-switch hazard)"
affects: [16-05, 16-06, 16-07, 16-08, 16-09, 16-10, 16-11, 16-12]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Every cell is judged from the rendered screenshot, never from the accessibility outline — a truncated `Text` reports its full label, so only the image can see an ellipsis"
    - "Long screens capture mid-scroll frames as well as top and bottom, so content between the two ends is evidenced rather than inferred"
    - "Each simulator cell asserts the frontmost bundle and the orientation tag before capturing, and aborts rather than screenshotting the wrong window"

key-files:
  created: []
  modified:
    - ".planning/phases/16-dynamic-type-accessibility/16-SWEEP.md"

key-decisions:
  - "A value that already truncates at the default size but shows strictly fewer characters as the type grows is recorded as a finding under D-03 (less information at a larger size), with the pre-existing truncation stated explicitly in the description — the hero-carousel title is the worked example."
  - "A cell is `pass` when no clipped, ellipsised or overlapping value was seen in the rows actually walked; the description says so rather than claiming the screen can never truncate. Landscape at XXL passes on every list host for exactly this reason."
  - "The pre-registered Favorites trailing-glyph clip does not reproduce; it is recorded as observed-and-not-reproducing rather than quietly dropped, and the adjacent value loss it was probably standing in for is filed as finding #6."
  - "The delete-confirmation popover's missing Cancel button is explicitly excluded from finding #11: it is absent at every size, so it is a design choice and not a Dynamic Type regression."
  - "`sim-use gesture rotate-cw` does not rotate the device — it dispatches an on-screen two-finger rotate. The § Tooling row was corrected in place so plans 16-05 … 16-09 do not repeat the mistake."

patterns-established:
  - "Sweep session hygiene: terminate other apps on the simulator before walking, because a foreign app stealing the foreground silently redirects taps and screenshots"

requirements-completed: []  # A11Y-01 is phase-wide; it closes on the owner-signed sweep (16-12).

coverage:
  - id: D1
    description: "All 78 iPhone Group A matrix rows are non-`pending` with a one-line reason on every row"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "for n in 1..13: `grep -E '^\\| *$n \\| .*iPhone' 16-SWEEP.md | grep -c '| pending |'` → 0 for every n; 78 Group-A rows present"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every `finding:#N` in the Group A rows resolves to a numbered § Findings entry with a written description and status `open`"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "matrix references #1–#11; § Findings defines #1–#12; no dangling reference"
        status: pass
    human_judgment: false
  - id: D3
    description: "Verdicts are judged from rendered screenshots against D-03 / D-04, not from the accessibility outline"
    requirement: A11Y-01
    human_judgment: true
    rationale: "Whether a given layout 'provides less information' is the owner's rule applied by eye; the evidence is the capture set under the evidence root and the owner re-judges it in plan 16-12."
  - id: D4
    description: "Both Group-A D-13 rows carry an iPhone `Observed` note; nine D-04 rows dispositioned"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "D-13 gained an `Observed (iPhone, round 1)` column; hero-carousel and Favorites rows both filled. D-04: GalleryRankingCell:39, GalleryCardCell:73, GalleryDetailCell:107/:152/:163/:155/:166, GalleryHistoryCell:32, DownloadBadgeLabel:19, GalleryThumbnailCell:99, CategoryView:31 all non-pending"
        status: pass
    human_judgment: false
  - id: D5
    description: "No image entered the repository and no absolute home path entered the doc"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`git status --porcelain | grep -Ei '\\.(png|jpe?g|heic|gif)$' | wc -l` → 0 before both commits; the absolute-home-prefix scan of `16-SWEEP.md` counts 0 matches"
        status: pass
    human_judgment: false
  - id: D6
    description: "The sweep simulator is restored to its recorded baseline and read back"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "`content_size` → medium, `appearance` → dark, `increase_contrast` → disabled, `sim-use ui` header 420x912 (no orientation tag); List Display Mode returned to Detail"
        status: pass
    human_judgment: false

# Metrics
duration: 2h 45m
completed: 2026-08-24
status: complete
---

# Phase 16 Plan 04: iPhone Group A Dynamic Type Sweep Summary

**All 78 iPhone Group A cells are judged: twelve distinct defects, and the failure is concentrated almost entirely in portrait at AX3 and above — list rows overflow the screen's right edge and lose their language, page count and date outright, pushed screens lose their navigation title completely, the pull-to-reveal filter field renders as a blank capsule, and the Home hero carousel both truncates its title and lets the neighbouring card's artwork sit on top of it. Landscape at XXL passes on every screen walked.**

## Performance

- **Duration:** ~2 h 45 m for 78 cells across 13 surfaces, both orientations, three sizes.
- **Evidence:** 267 full-scale PNGs under `$HOME/Library/Caches/ehpanda-phase16/sweep/`, none in the repo.
- **Commits:** `814fa06e` (rows 1–7), `07a2eb0e` (rows 8–13).

## Findings opened

Each is described in full in `16-SWEEP.md § Findings`; the evidence paths below are all relative to `$HOME/Library/Caches/ehpanda-phase16/sweep/`.

| # | One-liner | Evidence (evidence-root relative) |
|---|---|---|
| 1 | Home hero-carousel title loses text as the size grows — four lines at the default size, one truncated word at AX5 portrait (D-13 case). | `iphone-portrait-{XXL,AX3,AX5}-2-top.png`, `iphone-landscape-{AX3,AX5}-2-top.png`, baseline `../preflight/baseline-medium.png` |
| 2 | At AX5 portrait the hero card's title and rating are overlapped by the neighbouring card's artwork, and its own cover is cut off at the screen's left edge. | `iphone-portrait-AX5-2-top.png` |
| 3 | The Toplists ranking cell truncates both its title and its uploader line from AX3 up, in both orientations. | `iphone-portrait-{AX3,AX5}-2-bottom.png`, `iphone-landscape-AX5-2-mid3.png`, `iphone-landscape-AX5-2-mid6.png` |
| 4 | On the pushed lists the filter field renders as an empty capsule at AX3 and AX5 portrait — magnifying glass and placeholder both absent. | `iphone-portrait-{AX3,AX5}-{3,4,5,6,7,10}-top.png`; contrast with `iphone-portrait-XXL-6-top.png` |
| 5 | The gallery list row's title is line-capped, so a title that reads to its last word at the default size loses its tail from XXL up. | `iphone-portrait-baseline-3-top.png` vs `iphone-portrait-XXL-3-top.png`; `iphone-landscape-XXL-5-top.png` vs `iphone-landscape-AX3-5-top.png` |
| 6 | From AX3 up in portrait the list row overflows the screen's right edge: language, page count and date are cut mid-glyph, and at AX5 the page-count number is gone entirely. | `iphone-portrait-{AX3,AX5}-3-top.png`, `iphone-portrait-AX3-11-top.png`, `iphone-portrait-AX5-11-top.png` |
| 7 | Pushed screens' navigation large title is ellipsised at AX3 and not rendered at all at AX5, in portrait. | `iphone-portrait-AX3-7-top.png`, `iphone-portrait-AX5-{3,4,6,7,10}-top.png` |
| 8 | At AX5 portrait the row's cover thumbnail is squeezed to a narrow sliver and pushed past the screen's left edge. | `iphone-portrait-AX5-{3,4,5,6}-top.png` |
| 9 | The uploader is ellipsised from XXL up whenever a language value shares its line (the D-04 `:107` site). | `iphone-portrait-XXL-5-top.png` |
| 10 | The Search root's Recently Seen strip clips its cells at both screen edges and, at AX5, overlaps the section heading and the neighbouring cells. | `iphone-portrait-{XXL,AX3,AX5}-9-top.png`, `iphone-landscape-{XXL,AX3,AX5}-9-top.png` |
| 11 | The download delete confirmation's message is cut off mid-sentence at AX5 portrait, with the tail hidden behind the confirm button and unreachable. | `iphone-portrait-AX5-11-deletedialog.png` vs `iphone-portrait-XXL-11-deletedialog.png` |
| 12 | In Thumbnail display mode the grid cell abbreviates its category badge into ambiguity, ellipsises its title and page count, and runs its right column off the screen. | `iphone-portrait-AX5-thumbnaillayout.png` |

## D-13 observations

- **Hero-carousel title truncation (#2)** — it ellipsises, which is the pre-registered failing case, and it does so well before AX5: the card's fixed height, not the four-line limit, is what removes the text. Recorded as finding #1, with the AX5 overlap split out as finding #2.
- **Favorites trailing-glyph clip (#8)** — **does not reproduce.** The favourites-index, sort-order and features glyphs keep their size and stay fully drawn at AX5 in both orientations, and the row's trailing symbol is never cut. What is lost is the *number* beside that symbol, which is finding #6.

## Deviations from Plan

**1. [Rule 3 - Blocker] The `§ Tooling` rotation mapping was wrong**
- **Found during:** Task 1, first rotation to landscape.
- **Issue:** `sim-use gesture rotate-cw --angle 90` dispatches an on-screen two-finger rotate; it left the device in portrait and the app interpreted the gesture as content input, navigating into a pushed screen.
- **Fix:** rotation is done with `agent-device orientation …` (the verb the § Protocol names). The `§ Tooling` row was corrected in place, together with two mechanics this plan had to discover: `sim-use screenshot` writes landscape frames in the native portrait framebuffer (straighten with `sips -r 270`), and a page gesture in landscape can land on the home indicator and switch apps.
- **Files modified:** `16-SWEEP.md § Tooling`.
- **Commit:** `814fa06e`.

**2. [Rule 2 - Missing verification basis] A default-size reference capture was needed**
- **Found during:** Task 1, judging list-row titles on Frontpage.
- **Issue:** D-04 asks whether a value "reads in full at `.large`"; nothing in the sweep set showed the same rows at the default size, so the claim could not be evidenced.
- **Fix:** one reference capture at the recorded `medium` baseline (`iphone-portrait-baseline-3-top.png`). This is the recorded restore value, not the `large` reserved for the plan-16-05 D-15 parity captures, so it changes nothing about D-15.
- **Commit:** `814fa06e`.

**3. [Rule 2 - Coverage] The Thumbnail display mode was exercised once**
- **Found during:** Task 2, dispositioning `GalleryThumbnailCell.swift:99`.
- **Issue:** the sweep simulator's List Display Mode is `Detail`, so the thumbnail cell never rendered and its D-04 row could not be judged.
- **Fix:** Display Mode switched to Thumbnail for one AX5 portrait capture and restored to `Detail` immediately afterwards (verified by re-reading the control). Produced finding #12.
- **Commit:** `07a2eb0e`.

**4. [Rule 2 - Evidence] Mid-scroll captures added for long screens**
- **Issue:** top-and-bottom captures alone leave a long screen's middle unjudged, and the Home root's ranking cells live there.
- **Fix:** the walk now also captures a frame every third scroll. Extra evidence only; no protocol change is implied for later plans.

**Total deviations:** 4 auto-fixed (1 blocker, 3 missing-coverage). **Impact:** the verdicts rest on evidence rather than inference, and plans 16-05 … 16-09 inherit a tooling map that matches reality.

## Simulator handling

- Addressed only by `IPHONE_UDID`; `IPAD_UDID` was never touched.
- No erase, no uninstall, no clear-app-state, no `xcodebuild` against the sweep simulator.
- **The sweep created exactly one download**, and it is the only entry under `Downloads/Default/` in the app's data container — a 14-page gallery started at 01:30 on 2026-08-24. Nothing pre-existing was deleted, and the delete confirmation opened for finding #11 was cancelled. Identifying it by folder position rather than by name keeps the gallery's title and id out of this public repository.
- Restored and read back at session end: `content_size` `medium`, `appearance` `dark`, `increase_contrast` `disabled`, portrait, and List Display Mode back to `Detail`.

## Issues Encountered

- Two other apps installed on the simulator repeatedly stole the foreground mid-walk, silently redirecting taps and producing captures of the wrong window. Terminating them (`xcrun simctl terminate`, process only) fixed it, and each cell now asserts `App: EhPanda` plus the expected orientation tag before capturing. One `PROCESS DISAPPEARED` banner was raised by `sim-use`; it was caused by `agent-device open --foreground` relaunching the app, not by an EhPanda crash — no crash report exists for the app in `DiagnosticReports` or the simulator's `CrashReporter` directory, so no cell is recorded as `crash:`.
- The lists on screens #3, #4, #5 and #10 load more content indefinitely, so their "bottom" capture is the eighth scroll rather than a true end of list. Every distinct content type on those screens was reached.

## Next Phase Readiness

Group A is verified on the iPhone. Ready for plan 16-05 (iPhone Group B, screens #14–#27), which also owns the three remaining D-13 cases and the D-15 `.large` baseline captures. The iPad pass over the same screens is plan 16-07.

## Self-Check: PASSED

- `16-SWEEP.md` exists and carries 78 Group-A iPhone rows, 0 `pending`.
- Commits `814fa06e` and `07a2eb0e` present in `git log`.
- The absolute-home-prefix scan of `16-SWEEP.md` counts 0 matches; `git status --porcelain | grep -Ei '\.(png|jpe?g|heic|gif)$' | wc -l` → 0.
- Matrix references findings #1–#11; § Findings defines #1–#12; no dangling reference.
- Simulator baseline read back identical to the recorded values.
