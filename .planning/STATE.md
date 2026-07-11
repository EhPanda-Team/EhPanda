---
gsd_state_version: 1.0
milestone: v3.0.0
milestone_name: milestone
current_phase: 2
current_phase_name: spike-gated
status: executing
stopped_at: Completed 01-09 (DeprecatedAPI inlined as LegacyCFReadStream; DEP-06 override)
last_updated: "2026-07-11T01:53:20.717Z"
last_activity: 2026-07-10
last_activity_desc: Phase 01 complete, transitioned to Phase 2
progress:
  total_phases: 11
  completed_phases: 1
  total_plans: 9
  completed_plans: 9
  percent: 9
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-09)

**Core value:** The load-bearing paths — fetch, parse, read, download galleries — keep working; every task is a foundation change held to behavior/appearance parity.
**Current focus:** Phase 01 — Isolated Dependency Modernization

## Current Position

Phase: 2 — Native Masonry Grid Swap (spike-gated)
Plan: Not started
Status: Ready to execute
Last activity: 2026-07-10 — Phase 01 complete, transitioned to Phase 2

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 9
- Average duration: — min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 9 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01 P01 | 8min | 2 tasks | 8 files |
| Phase 01 P02 | 8min | 2 tasks | 8 files |
| Phase 01 P03 | 14min | 3 tasks | 150 files |
| Phase 01 P04 | 5min | 3 tasks | 7 files |
| Phase 01 P05 | 7min | 3 tasks | 10 files |
| Phase 01 P06 | 12min | 3 tasks | 2 files |
| Phase 01 P07 | 20min | 3 tasks | 5 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: Combine→async/await (Phase 4) stays in this milestone, sequenced after the isolated dep removals.
- Roadmap: WaterfallGrid→Layout (Phase 2) and SwiftUIPager→TabView (Phase 3) are spike-first — validate feasibility before committing.
- Roadmap: Fold cookies→Keychain + networking/cookie/image tests + `.private.filterValue` fix into their open seams (Phases 8–9); defer Parser/Download refactors.
- Roadmap: LINT-01 split — mechanical rules sweep last (Phase 11); refactor-gated rules land with their refactors (`optional_try`→Phase 9; binding/lifecycle/unchecked-subscript→Phases 5–7).
- [Phase ?]: 01-01: Dropped invalid -testPlan FeatureTests from AppPackage-Package commands (plan bound to EhPanda scheme; package scheme runs all test targets)
- [Phase ?]: 01-01: Wave 0 parity fixtures lock current SwiftyOpenCC (default/HK/TW + full color) and UIImageColors RGBA output before DEP-01/DEP-02 swaps
- [Phase ?]: 01-02: Wave 0 markdown fixtures target current CommonMarkExt.MarkdownUtil; MarkdownExtTests name reserves MarkdownExt (D-09) with no app-owned Markdown module
- [Phase ?]: 01-02: DF semantics locked via pure request transforms + DFRequest header assembly, resume() never called (no live networking, D-13); real-world DF stays manual
- [Phase ?]: 01-02: Wave 0 complete (DEP-01/02/03/06 baselines locked); nyquist_compliant true
- [Phase ?]: 01-03: Replaced external ddddxxx/SwiftyOpenCC with an app-owned local SwiftyOpenCC module backed by an internal copencc C++14 target; Wave 0 parity fixtures pass verbatim.
- [Phase ?]: DEP-02: vendored a clean-room local UIImageColors module (getColors preserved verbatim); external jathu/UIImageColors removed.
- [Phase ?]: DEP-03: markdown parsing migrated to Apple swift-markdown 0.8.0 behind MarkdownExt; SwiftCommonMark/CommonMarkExt removed; parity fixtures unchanged (D-07/D-08/D-09)
- [Phase ?]: DEP-06 resolved as document-skip: DeprecatedAPI deliberately retained (D-12); no warning-free replacement preserves host-control + arbitrary-Host + original-domain-trust, so removal would weaken D-14.
- [Phase ?]: DEP-07: Colorful updated to official Lakr233/Colorful.git exact 1.1.1; ColorfulView deprecation documented as user-decision blocker (not suppressed).
- [Phase 01]: 01-08: Migrated gallery gradient Colorful → ColorfulX 6.1.0 (Metal), closing the DEP-07 ColorfulView deprecation blocker via option (a); animated→speed mapping, warning-free build, full suite green (431 tests).
- [Phase 01]: 01-09: Inlined the external DeprecatedAPI package into a local internal LegacyCFReadStream module (isolates deprecated CFReadStreamCreateForHTTPRequest), silenced via -suppress-warnings scoped to that one target; overrides DEP-06 D-12 (document-skip) per explicit user request; DF behavior byte-identical (S1–S7 green), warning-free build, full suite green.
- [Phase 02]: DEP-04 column derivation decided: the masonry `Layout` computes `N = max(2, floor((w + 15) / (185 + 15)))` from its own proposed width; all cells share one identical flexible width (`cellWidth = (w − 15·(N−1)) / N`, spacing fixed 15). Exact 2/4/5 count parity dropped by owner — the bar is a stable, content-independent count that tiles any width. Known deviations at m=185: iPad mini portrait 4→3, 13" landscape 5→6, Split View bands become container-coherent. Details in 02-CONTEXT.md.
- [Phase 01]: verify-work found & fixed a ColorfulX behavior regression (gap G-01-1): the Colorful→ColorfulX swap was API-faithful but NOT behavior-faithful (ColorfulX always paints a full-bleed opaque gradient; speed:0 ≠ Colorful's near-invisible animated:false). Fix in GalleryCardCell: gate `ColorfulView` on `animated` (focused dark card only), skip light-mode color calc, and seed-then-bloom the gradient via ColorfulX `transitionSpeed`. User-verified live; 01-VERIFICATION.md re-verified status **passed 5/5**. Lesson: a library swap needs behavior parity, not just API parity.

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- Phase 8 (QUAL-02): NetworkingFeature tests couple to Phase 4's async migration but land in the hygiene phase (where CookieClient/ImageClient are reworked) — verify NetworkingFeature parity tests are written against the migrated async layer, not deferred silently.
- Phases 2 & 3 carry genuine parity risk (spike-gated); a failed spike must surface before committing implementation.

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| *(none)* | | | |

## Session Continuity

Last session: 2026-07-11
Stopped at: Phase 01 complete — verify-work fixed gradient regression G-01-1, 4 UAT items pass, verification passed 5/5; ready to plan Phase 2
Resume file: None
