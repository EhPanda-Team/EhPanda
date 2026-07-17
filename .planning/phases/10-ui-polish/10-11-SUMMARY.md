---
phase: 10-ui-polish
plan: 11
subsystem: ui
tags: [swiftui, dynamic-type, scaledmetric, viewthatfits, accessibility, reflow]

requires:
  - phase: 10-ui-polish (plan 10)
    provides: the broke-at-AX5 verdict table (B1–B10) + the out-of-inventory actionIconFont finding — this plan's work order
provides:
  - Every broke-at-AX5 site reflowed (D-02): dropped line limits / fixedSize for wrap; @ScaledMetric-scaled fixed heights and action-icon font
  - Zero unresolved broke verdicts; default (.large) parity preserved by construction
affects: [10-12, D-03 owner gate]

tech-stack:
  added: []
  patterns:
    - "@ScaledMetric(relativeTo: <row's dominant text style>) to scale a fixed frame(height:) that wraps growing text — literal == scaled value at .large, so default parity is exact and the frame grows with Dynamic Type"
    - "Drop lineLimit(1)/fixedSize() to let a short label wrap instead of truncate — a no-op at default where the content is single-line"

key-files:
  created:
    - .planning/phases/10-ui-polish/10-11-SUMMARY.md
  modified:
    - AppPackage/Sources/SystemNotification/ToastMessageView.swift
    - AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/DetailFeature/DetailView+CommentCells.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift

key-decisions:
  - "Fixed frame(height:) wrapping scaling text -> @ScaledMetric(relativeTo: nearest style), not minHeight: literal == scaled at .large gives exact default parity while the frame tracks Dynamic Type growth"
  - "lineLimit(1)/fixedSize on short single-line labels -> dropped: wrap is the reflow, and it is a no-op at default because the content already fits one line"
  - "B2's minimumScaleFactor(0.75) removed with its lineLimit(1) (inert once the label wraps): reduces the D-02-flagged shrink count from 8 to 7 (still <= 8)"
  - "B7/B8 are subsumed by the B6 fix: the DescriptionSection row now grows vertically, so the single-line value/rating labels are no longer clipped; their lineLimit(1) is kept (short numeric/label, horizontal truncation acceptable)"
  - "Device screenshot verification (AX5 readability + default-size parity) is batched to the owner-signed D-03 gate in 10-12 — same precedent as 10-10; Detail/Archives/Comments screens need live e-hentai login/data unavailable in a clean simulator"

patterns-established:
  - "Pattern: @ScaledMetric-driven frame(height:) is the parity-exact way to relax a text-bearing fixed height — extends 10-10's @ScaledMetric-for-fonts to fixed frames"

requirements-completed: [CRIT-05]

coverage:
  - id: D1
    description: "Every broke-at-AX5 verdict (B1–B10) reflowed within D-02 (no cap, no shrink, no GeometryReader); no redesign, no default-size change"
    requirement: CRIT-05
    verification:
      - kind: automated_ui
        ref: "grep dynamicTypeSize (AppPackage/Sources App) == 0; minimumScaleFactor (AppPackage/Sources App ShareExtension) == 7 (<=8, one removed); GeometryReader == 0"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme EhPanda (iPhone Air sim) => BUILD SUCCEEDED, 0 warnings; SwiftLint 0 violations on the 9 touched files"
        status: pass
    human_judgment: true
    rationale: "Default-size pixel-parity and AX5 readability are visual claims. @ScaledMetric fixes are parity-exact by construction (literal == scaled at .large); dropped-limit fixes are no-ops at default for single-line content. The owner-signed D-03 simulator pass (XXL/AX3/AX5) in 10-12 confirms on device."
  - id: D2
    description: "Final verdict table: zero unresolved broke verdicts; each B-site carries its reflow fix; no escalations"
    requirement: CRIT-05
    verification:
      - kind: manual_procedural
        ref: "reflow verdict table in this SUMMARY (## Final Reflow Verdict Table)"
        status: pass
    human_judgment: true
    rationale: "The static reflow is complete and build/lint-gated; the authoritative device confirmation is the D-03 owner gate in 10-12."

duration: 18min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 11: Dynamic Type Reflow — Broke-at-AX5 Remediation Summary

**Every broke-at-AX5 site from the 10-10 audit (B1–B10) plus the out-of-inventory actionIconFont is reflowed within D-02 — dropped line limits / fixedSize for wrap, @ScaledMetric-scaled fixed heights and action-icon font — with exact default (.large) parity and zero prohibition-grep regressions.**

## Performance

- **Duration:** 18 min
- **Tasks:** 2 (Task 1 = reflow code; Task 2 = static re-verification, device pass deferred to D-03)
- **Files modified:** 9

## Accomplishments

- Reflowed all 10 broke-at-AX5 sites (B1–B10) and the out-of-inventory `actionIconFont` finding.
- Two reflow strategies, both no-ops at default:
  - **Drop the constraint** (B1–B5, and B7/B8 via B6): remove `lineLimit(1)` / `fixedSize()` so short labels wrap instead of truncate at AX sizes.
  - **@ScaledMetric-scaled fixed metric** (B6, B9, B10, actionIconFont): replace a literal `frame(height:)` / fixed font size with `@ScaledMetric(relativeTo:)` — the value equals the literal at `.large` (exact parity) and grows with Dynamic Type.
- Reduced the D-02-flagged shrink count from 8 to 7 by removing B2's now-inert `minimumScaleFactor(0.75)`.
- All three prohibition greps hold: `dynamicTypeSize` 0, `minimumScaleFactor` 7 (<= 8), `GeometryReader` 0.
- Build clean (BUILD SUCCEEDED, 0 warnings, iPhone Air sim); SwiftLint 0 violations on all 9 touched files.
- No escalations: every site reflowed without redesign or any default-size change.

## Task Commits

1. **Task 1: Reflow every broke-at-AX5 site** — `58f4a88f` (fix, 9 files)
2. **Task 2: Re-verify (static) at AX5 + default parity** — no code commit; verification-only. Device screenshot pass batched to the D-03 owner gate (10-12).

## Final Reflow Verdict Table

Every B-site is now `fine` after the listed reflow. The reflow column records exactly what changed; the parity column states why it is a no-op at default (.large).

| # | Site | Reflow applied | Default (.large) parity |
|---|------|----------------|-------------------------|
| B1 | `SystemNotification/ToastMessageView.swift:67` | dropped `.lineLimit(1)` on the toast title+subtitle VStack; HUD grows to fit | single-line toast text unchanged at default |
| B2 | `SettingFeature/Components/LaboratorySettingView.swift:70,74` | dropped `.lineLimit(1)` and the now-inert `.minimumScaleFactor(0.75)`; title2 label wraps | short setting labels fit one line at default; shrink was never engaged at default |
| B3 | `SettingFeature/EhSetting/EhSettingView+Sections3.swift:151,153` | dropped `.lineLimit(1)` + `.fixedSize()`; language label wraps within its 25% column | language names fit the 25% column on one line at default |
| B4 | `HomeFeature/HomeView+Sections.swift:456` | dropped `.lineLimit(1)`; Misc-card title wraps, card grows vertically | short card titles are single-line at default |
| B5 | `SearchFeature/SearchRootView+Keywords.swift:113` | dropped `.lineLimit(1)`; keyword/suggestion row title wraps | short keywords are single-line at default |
| B6 | `DetailFeature/DetailView+Subviews.swift:70` | `.frame(height: 60)` -> `@ScaledMetric(relativeTo: .title3) rowHeight = 60` | 60 == scaled(60) at `.large` (exact) |
| B7 | `DetailFeature/DetailView+Subviews.swift:91` | subsumed by B6 — the row grows so the single-line value is no longer vertically clipped (lineLimit(1) kept: short numeric) | unchanged |
| B8 | `DetailFeature/DetailView+Subviews.swift:105` | subsumed by B6 — row grows; single-line rating title no longer clipped (lineLimit(1) kept) | unchanged |
| B9 | `DetailFeature/Archives/ArchivesView.swift:243` | `.frame(height: 50)` -> `@ScaledMetric(relativeTo: .headline) bannerHeight = 50` | 50 == scaled(50) at `.large` (exact) |
| B10 | `DetailFeature/DetailView+CommentCells.swift:39` | `.frame(width: 300, height: 120)` -> height `@ScaledMetric(relativeTo: .body) cardHeight = 120` (width kept for uniform horizontal-scroll cards) | 120 == scaled(120) at `.large` (exact) |
| — | `DetailFeature/DetailView+HeaderSection.swift:38` (out-of-inventory) | `let actionIconFont = .system(size: 16)` -> `@ScaledMetric(relativeTo: .callout) actionIconFontSize = 16` + computed `actionIconFont`; 4 call sites unchanged | 16 == scaled(16) at `.large`; callout default is 16pt (exact) |

## Decisions Made

- **@ScaledMetric over minHeight for text-bearing fixed heights.** `minHeight: N` risks a small default drift when natural content already differs from `N`; `@ScaledMetric(relativeTo:) = N` is literally `N` at `.large` (exact parity) and scales the frame with the type ramp. This extends 10-10's @ScaledMetric-for-fonts pattern to fixed frames.
- **Dropped constraints only where the content is single-line at default**, so wrap is a genuine no-op at default and only engages at AX sizes.
- **B2 shrink removed, not kept.** Once the label wraps, `minimumScaleFactor(0.75)` is dead (no truncating line limit / bounded height to trigger it). Removing it is the root-cause fix the audit pointed at and drops one D-02-flagged shrink (8 -> 7).
- **B10 width kept fixed (300).** Comment preview cards live in a horizontal scroll and read as uniform-width; only the height fights Dynamic Type, so only the height scales.

## Deviations from Plan

### Method adjustment

**1. [Rule 3 - Scope/method] Task 2 device screenshots deferred to the D-03 owner gate (10-12)**
- **Found during:** Task 2
- **Issue:** Task 2 asks for a sim-use pass (AX5 readability + default-size parity screenshots) on every reflowed screen. Most B-sites are Detail-content screens (Detail DescriptionSection, Archives, Comments) that require live e-hentai login + gallery data unavailable in a clean simulator, and the D-03 gate is explicitly an owner-signed end-of-phase device pass (config `human_verify_mode: end-of-phase`). This is the same constraint 10-10 recorded.
- **Fix:** Delivered the reflow with a by-construction default-parity argument (@ScaledMetric fixes are exact at `.large`; dropped-limit fixes are no-ops for single-line content) plus a full build + SwiftLint gate. The device confirmation (XXL/AX3/AX5, every screen incl. sheets) is handed to the D-03 owner gate in 10-12, with this SUMMARY's verdict table as its input.
- **Files modified:** none beyond Task 1.
- **Verification:** prohibition greps hold; build 0 warnings; lint 0 violations; verdict table complete.

**Total deviations:** 1 (method adjustment, mirroring 10-10). **Impact:** no scope creep; every observed breakage is reflowed within D-02.

## Issues Encountered

- None. The pre-existing `minimumScaleFactor` baseline dropped from 8 to 7 (B2 removal); the remaining 7 are unchanged pre-existing shrinks already flagged to the owner in 10-10.

## User Setup Required

None.

## Next Phase Readiness

- **D-03 gate input ready:** the final reflow verdict table above (zero unresolved broke verdicts) is the owner gate's input for 10-12.
- **Owner device pass outstanding:** confirm B1–B10 readable+operable at AX5 and every reflowed screen unchanged at default (.large). By construction the @ScaledMetric sites are exact-parity at default; the dropped-limit sites should be eyeballed for any long-content wrap at default.
- **Prohibitions hold:** `dynamicTypeSize` 0, `minimumScaleFactor` 7, `GeometryReader` 0.

## Self-Check: PASSED

- FOUND: all 9 modified source files
- FOUND: commit `58f4a88f` (Task 1, 9 files)

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
