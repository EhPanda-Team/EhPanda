---
phase: 10-ui-polish
plan: 07
subsystem: ui
tags: [swiftui, numeric-text, monospacedDigit, contentTransition, polish-01]

# Dependency graph
requires:
  - phase: 10-06
    provides: "Settled view surface (ZStack conversions) for the same Detail/Reading/Setting files"
provides:
  - "POLISH-01: paired monospacedDigit + contentTransition(.numericText) on every D-05 changing-value Text"
  - "Each treated Text keyed on its changing value via animation(_:value:)"
affects: [ui-polish-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Changing numeric Text → monospacedDigit + contentTransition(.numericText[(value:)]) + animation(.default, value: changingValue)"
    - "numericText(value:) for pure numbers (direction matters); plain numericText() for mixed strings (\"3 / 45\", \"12.3 MB\")"

key-files:
  created:
    - ".planning/phases/10-ui-polish/10-07-SUMMARY.md"
  modified:
    - "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift"
    - "AppPackage/Sources/GalleryListComponents/DownloadBadgeLabel.swift"
    - "AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift"
    - "AppPackage/Sources/SettingFeature/Components/DownloadSettingView.swift"
    - "AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift"
    - "AppPackage/Sources/DetailFeature/DetailView+Subviews.swift"

key-decisions:
  - "Applied the paired treatment inline per site (not via a shared modifier) because the plan's pair-check grep requires both tokens co-located in each of the 6 files; a shared modifier would move the tokens out of the treated files."
  - "Left the animation ungated (.default, not reduceMotion-gated) because .contentTransition(.numericText()) is itself Reduce-Motion-aware — it falls back to an opacity crossfade under Reduce Motion, so the animation scope only enables the (already-adaptive) transition. This matches GeneralSettingView's existing ungated .animation(.default, value:) style and keeps the diff minimal."
  - "Static one-off numbers left untreated per D-04 (see Deliberately-untreated section) — the intended outcome, not a coverage gap."

patterns-established:
  - "Treat a number-bearing Text only when its value visibly changes (D-05); pair both modifiers and key an animation on the changing value."

requirements-completed: [POLISH-01]

coverage:
  - id: D1
    description: "All D-05 changing-value sites carry both monospacedDigit and contentTransition(.numericText), co-located, each with an animation keyed on its changing value"
    requirement: "POLISH-01"
    verification:
      - kind: automated_ui
        ref: "xcodebuild build -scheme EhPanda: BUILD SUCCEEDED, 0 warnings"
        status: pass
      - kind: other
        ref: "swiftlint lint (6 files): 0 violations; pair-check grep: both tokens nonzero in every file"
        status: pass
    human_judgment: false
  - id: D2
    description: "No layout jitter on value change (D-06); reader page indicator ticks as a numeric transition with no horizontal shift"
    requirement: "POLISH-01"
    verification:
      - kind: other
        ref: "monospacedDigit is the structural jitter guarantee (fixed-width digits); live sim-use reader observation deferred to the phase D-03/D-11 owner-signed gate"
        status: pass
    human_judgment: true
    rationale: "Zero-jitter on a live numeric change is inherently visual. monospacedDigit fixes digit advance-width so the width cannot change as digits roll (D-06 guarantee, proven structurally). Driving the reader to a swiped page requires a logged-in session and a loaded gallery; the plan explicitly permits deferring that observation to the D-03/final gate, which is the designated owner-signed mechanism."

# Metrics
duration: 12min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 07: Numeric-Text Treatment (POLISH-01) Summary

**Paired `.monospacedDigit()` + `.contentTransition(.numericText())` (with a value-keyed `.animation`) on every value that visibly changes on screen across the 6 D-05 files — completing the 4 half-treated sites and adding both modifiers to the previously-untreated cache size, gallery-detail description rows, and rating displays.**

## Performance
- **Duration:** ~12 min
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Added the missing `.contentTransition(.numericText())` half at the 4 `monospacedDigit`-only sites (reader current/total, download progress badge, archive GP/credits funds, thread-limit slider value).
- Added BOTH modifiers at the previously-untreated D-05 sites (disk cache size, DescScrollInfo description rows, rating count title, average rating number).
- Keyed each treated Text on its changing value via `.animation(.default, value:)`.
- Build clean (0 warnings, `EhPanda` scheme); SwiftLint clean (0 violations on all 6 files); pair-check grep green (both tokens present in every file).

## Treated sites

| File | Site | Value | numericText variant | animation key |
|------|------|-------|---------------------|---------------|
| ControlPanel.swift | reader title | "current / total" (live, every swipe) | plain (mixed string) | `title` |
| DownloadBadgeLabel.swift | progress text | "n / total" (live download) | plain (mixed string) | `badge.progress.displayCompletedPageCount` |
| ArchivesView.swift | GP funds | galleryPoints (after purchase) | `value:` (pure Int) | `galleryPoints` |
| ArchivesView.swift | credits funds | credits (after purchase) | `value:` (pure Int) | `credits` |
| DownloadSettingView.swift | thread-limit value | downloadThreadLimit (slider drag) | `value:` (pure Int) | `setting.downloadThreadLimit` |
| GeneralSettingView.swift | disk cache size | "12.3 MB" (after clearing cache) | plain (mixed string) | `store.diskImageCacheSize` |
| DetailView+Subviews.swift | DescScrollItem value | favoritedCount / pageCount / sizeCount / language (on refresh) | plain (mixed/varies) | `value` |
| DetailView+Subviews.swift | DescScrollRatingItem title | ratingCount in "N RATINGS" (on refresh) | plain (mixed string) | `title` |
| DetailView+Subviews.swift | DescScrollRatingItem rating | average rating "%.2f" (on refresh/rate) | `value:` (Double) | `rating` |

## Deliberately-untreated static sites (D-04 verifier note — correct, not gaps)
- **DescScrollItem title** (`DetailView+Subviews.swift`) — static uppercase labels ("FAVORITED", "PAGES", "FILE SIZE"); not numbers, no change → neither modifier.
- **ControlPanel slider bound labels** (`Text(range.upperBound, format: .number)`, lower/upper page-range numbers) — these mark the fixed page span, not a live-ticking value; left untreated.
- **RatingView stars** (Detail user-rating on tap, `DetailView+Subviews.swift:143`) — a symbol view, not a numeric Text; the numeric rating it accompanies is treated at the DescScrollRatingItem "%.2f" text.
- No other number-bearing Text in the 6 files visibly mutates on screen; all such static one-off numbers are left untreated per D-04.

## Task Commits
1. **Task 1: Treat the D-05 numeric-text sites** — `3337c5fc` (feat)
2. **Task 2: Build/lint gate + jitter check** — no code (verification only; results above)

**Plan metadata:** committed with this SUMMARY (docs)

## Decisions Made
- **Inline per-site treatment, not a shared modifier.** The plan's pair-check grep requires both `monospacedDigit` and `numericText` tokens co-located in each of the 6 files; a shared modifier would relocate the tokens and fail that contract.
- **Ungated `.animation(.default, value:)`.** `.contentTransition(.numericText())` is Reduce-Motion-aware on its own (opacity-crossfade fallback), so gating the animation on `accessibilityReduceMotion` would be redundant boilerplate across 7 structs; ungated matches the local `.animation(.default, value:)` style already in `GeneralSettingView`.
- **`numericText(value:)` vs plain `numericText()`** per the plan's variant rule: value-variant for pure numbers where count direction matters (GP, credits, thread limit, rating); plain for mixed strings ("3 / 45", "12.3 MB", "N RATINGS").

## Deviations from Plan
None — plan executed as written. (Line numbers were re-grepped before editing per the plan's note; waves 2–6 had shifted them.)

## Issues Encountered
- The plan's verify command referenced `-scheme AppPackage-Package`, which does not exist in this project; built the `EhPanda` app scheme (transitively compiles all touched modules — ReadingFeature, GalleryListComponents, DetailFeature, SettingFeature) instead. The `iPhone 17 Pro` destination is not installed here; used the booted `iPhone 17e` simulator by UDID.
- Live reader jitter observation via sim-use deferred to the phase D-03/D-11 owner-signed gate (plan-permitted); `monospacedDigit` is the structural D-06 jitter guarantee.

## User Setup Required
None.

## Next Phase Readiness
- POLISH-01 delivered: every D-05 changing value is paired-treated; static numbers deliberately untouched and documented.
- No blockers. Remaining phase-10 plans are independent of this change.

## Self-Check: PASSED
- All 6 modified files and `10-07-SUMMARY.md` exist on disk.
- Commit `3337c5fc` present in `git log`.
- Pair-check grep: both `monospacedDigit` and `numericText` tokens nonzero in every one of the 6 files.
- ControlPanel.swift contains `contentTransition(.numericText`; GeneralSettingView.swift contains `monospacedDigit` (must_haves artifacts).

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
