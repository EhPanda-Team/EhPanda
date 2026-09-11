---
phase: 16-dynamic-type-accessibility
plan: 13
subsystem: ui
tags: [accessibility, wcag, contrast, increase-contrast, differentiate-without-color, colorsets, voiceover, audit]

# Dependency graph
requires:
  - phase: 16-dynamic-type-accessibility
    provides: "16-12 round-1 sign-off (the settled UI round 2 measures against); 16-RESEARCH § Contrast and § DWC tables; 16-CONTEXT D-20 / D-22 / D-26 … D-28 / D-31"
provides:
  - "`16-CONTRAST-AUDIT.md`: 84 category variants re-measured from live colorset JSON (RESEARCH totals reproduced), 40 Increase Contrast comparisons + 19-row re-authoring proposal, 28 non-category sites × 4 rendered/source-derived ratios with 14 proposed fixes, DWC verdicts over the RESEARCH table + all 80 filter variants"
  - "Owner decisions recorded verbatim: `STARS=B CATEGORYCELL=A HC=A D28=ok CONTEXTMENU=not-exposed`, one downstream-plan bullet per slot"
  - "Research Open Question 2 answered: SwiftUI `.contextMenu` items are not surfaced as VoiceOver custom actions on iOS 26.5 (simulator accessibility-tree read; provenance recorded)"
  - "D-25 re-sweep candidate list: Activity Logs and Laboratory (16-22) included; every colour-only change excluded per D-24"
affects: [16-15, 16-16, 16-19, 16-22, 16-23, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the one file this plan changed (16-CONTRAST-AUDIT.md, 64 886 bytes)
actuals:
  tokens: 16222
  tasks: 3
  # MEASURED: git rev-list --count 8d462178..HEAD at SUMMARY write. The range also contains plan 16-14's three
  # commits (bd34e60c, d81f0301, f652b1e7) because 16-14 executed between this plan's Task 1 and Task 3 on the same
  # sequential tree; this plan's own commits are 5e71ea53 (Task 1) and e25d5b53 (Task 3).
  commits: 5
  plan_head_before: 8d462178823f617b81ac08104e05bd0747eb04d6

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Audit-first colour work: every colour decision is backed by a measured number in a committed text artifact before any build task runs (D-20)"
    - "Rendered-pixel measurement: dominant foreground/background colours sampled from full-scale `simctl io screenshot` captures per appearance × Increase Contrast cell; source-derived rows are labelled as such"
    - "Grayscale DWC check: `sips --matchTo 'Generic Gray Profile.icc'` desaturation re-sampled at the same pixel boxes, cross-checked against relative-luminance state ratios"

key-files:
  created:
    - .planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md
  modified: []

key-decisions:
  - "STARS=B: light-mode rating stars darken to a ≥ 3:1 colour in plan 16-23 (audit recommends `#A38100`, fallback `#A16A00` if the rendered Home-card ratio drops below 3.00); dark keeps `.yellow`; 16-19 labels the star group with a VoiceOver label + value"
  - "CATEGORYCELL=A: Filters `CategoryCell` keeps opacity 0.3 for excluded; 16-15 adds adaptive text resolved against the composited colour, `Button` semantics and `.isSelected`; the DWC claim carries the measured caveat (Misc 3.34 light / 1.65 dark; dark minimum 1.25 across 80 variants)"
  - "HC=A: 16-15 re-authors the 19 `lower` Increase Contrast colorset entries to the audit's proposed values and re-pins only the HC-40 hash; the standard-44 pin never changes — D-26's '84 byte-identical' narrows to '44 standard byte-identical + 40 HC re-pinned'"
  - "D28=ok: 16-23 applies every proposed non-category fix (read-glyph, comment-link, comment-date, offline-notice, swipe-move, swipe-pages, swipe-update, newdawn; swipe-delete and swipe-pause kept as platform conventions); 16-22 adds the DWC carriers (level glyphs, Laboratory state glyph, comment-link underline); secondary-meta unchanged"
  - "CONTEXTMENU=not-exposed: 16-16 / 16-19 add explicit `accessibilityAction`s for context-menu items; recorded as a simulator accessibility-tree read (agent-device, iPhone 17e `67377A20…`, iOS 26.5), not a VoiceOver rotor pass on the physical device"

patterns-established:
  - "Decision slots are filled with the owner's resume line verbatim plus one bullet per slot naming the plan that builds against it"
  - "D-25 re-sweep membership is decided per screen with a stated D-24 reason (new glyph/shape or size change → included; colour only → excluded)"

requirements-completed: []  # A11Y-02 completes only when round 2 finishes (plan 16-26); this plan is its audit-first half.

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "84 category variants re-measured from the live colorset JSON; totals 84 / 45 white failures / 0 best-of failures / worst 4.62 ExHentai Game CG light / 47 flips / crossover 0.17913 reproduce RESEARCH"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "grep -c '^## ' 16-CONTRAST-AUDIT.md == 5; grep -c '4.62' >= 1; grep -c '0.1791' >= 1 (Task 1 verify)"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/FeatureTests CategoryColorsetInvariantTests (plan 16-14) — same totals asserted independently, 1055 tests green"
        status: pass
    human_judgment: false
  - id: D2
    description: "40 Increase Contrast variants compared with standard siblings (19/40 lower) and a 19-row re-authoring proposal recorded"
    requirement: "A11Y-02"
    verification: []
    human_judgment: true
    rationale: "The proposal is a set of candidate colour values for the owner; whether adopting them is right was the owner's HC decision (HC=A), not a test outcome"
  - id: D3
    description: "28 non-category sites measured in light / dark / light+IC / dark+IC with thresholds, verdicts and 14 proposed fixes"
    requirement: "A11Y-02"
    verification: []
    human_judgment: true
    rationale: "Ratios were sampled from rendered simulator pixels this session; three rows are source-derived (offline notice, swipe Update, NewDawn) and the fixes are visible changes the owner authorised (D28=ok) — plan 16-23 re-measures after applying them"
  - id: D4
    description: "Differentiate Without Color audited over the RESEARCH table with a grayscale check plus all 80 filter variants; fails: activity-log level dots, Laboratory on/off; weak: CategoryCell excluded; weak pass: comment links"
    requirement: "A11Y-02"
    verification: []
    human_judgment: true
    rationale: "Whether a state 'still reads' in grayscale is a judgment supported by the luminance ratios; the carriers are built and re-measured in plan 16-22"
  - id: D5
    description: "Owner decisions recorded verbatim with downstream bullets and the D-25 re-sweep candidate list; Open Question 2 answered with provenance"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "grep -c 'STARS=\\|CATEGORYCELL=\\|HC=\\|D28=\\|CONTEXTMENU=' 16-CONTRAST-AUDIT.md == 10; grep -c 'D-25 re-sweep candidates' == 1; no absolute home path in the file; git log -1 --format=%s == 'docs(16): record round-2 colour decisions' (Task 3 verify)"
        status: pass
    human_judgment: false

# Metrics
duration: two sessions (Task 1 committed 2026-09-11T09:25Z; Task 3 continuation 2026-09-11T12:44Z – 12:47Z)
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 13: Round-2 Contrast and Colour Audit Summary

**Measured every category, Increase Contrast, non-category and Differentiate-Without-Color colour from live colorsets and rendered pixels, then recorded the owner's five colour decisions (`STARS=B CATEGORYCELL=A HC=A D28=ok CONTEXTMENU=not-exposed`) that plans 16-15 / 16-16 / 16-19 / 16-22 / 16-23 build against.**

## Performance

- **Duration:** two sessions — Task 1 (measurement, prior executor) committed 2026-09-11T09:25:53Z; Task 2 decision checkpoint resolved by the owner ≈ 10:20Z (CONTEXTMENU by the orchestrator ≈ 10:35Z); Task 3 continuation 2026-09-11T12:44Z – 12:47Z
- **Started:** 2026-09-11 (Task 1 session; measurement on the iPhone 17e simulator)
- **Completed:** 2026-09-11T12:47Z
- **Tasks:** 3 (2 auto + 1 decision checkpoint)
- **Files modified:** 1 (`16-CONTRAST-AUDIT.md`, created in Task 1, decisions filled in Task 3)

## Accomplishments

- **Category variants (D-26) reproduced from the live JSON:** 84 variants / 45 white-text failures / 0 best-of failures / worst best-of 4.62:1 (ExHentai Game CG light) / 47 flips to black / crossover L = 0.17913 (ratio 4.583). Every total equals RESEARCH; no deviation to explain. Three component encodings normalised (156 hex, 90 float, 6 decimal).
- **Increase Contrast (D-27):** 19/40 HC variants give less badge contrast than their standard sibling on best-of (40/40 lower on the current white text). A hue-preserving re-authoring proposal for the 19 `lower` entries is tabulated (one, E-Hentai Cosplay light+HC, could not keep its hue because a channel clipped). The D-26 "84 byte-identical" vs D-27 "re-authored" conflict was surfaced with the numbers, never resolved silently.
- **Non-category colours (D-28):** 28 sites × 4 ratios (light / dark / light+IC / dark+IC) from rendered pixels on iPhone 17e `67377A20…` (iOS 26.5); three rows are source-derived and labelled (offline notice, swipe Update, NewDawn). **Failing sites:** rating stars in list cells (1.51 light) and on the Home card (1.23 light; 1.97 / 2.21 on the cover gradient), Read button glyph (1.81 dark, 1.12 dark+IC), category badge white text (3.30 light, 2.70 light+IC — resolved by D-26, not D-28), activity-log `.error` dot (2.31 light), comment link runs (3.26 light), comment preview date (3.13 light), `.secondary` metadata (4.00 light and light+IC), `CategoryCell` excluded label (1.48 light, 1.30 light+IC), offline notice (2.31 light), swipe Delete (3.57 / 3.43 / 2.94), Pause (3.51 dark, 2.13 dark+IC), Move (2.16 / 1.86 / 1.65), Pages (1.68 light, 2.21 light+IC), Update (2.31 / 2.23 / 2.02), NewDawn greeting over the top stop (2.16 light). 14 fixes proposed, each marked `Layout moves? No`.
- **Differentiate Without Color (D-20):** grayscale-desaturated captures re-sampled and cross-checked against luminance state ratios. **Fails:** activity-log level dots (two near-identical gray discs, state ratio 1.6) and Laboratory on/off (state ratios 1.01–1.25). **Weak:** `CategoryCell` excluded (Misc 3.34 light / 1.65 dark; over 80 filter variants dark minimum 1.25, 20/20 below 3.0). **Weak pass:** comment links (colour-only, G183 met on 3:1 link-vs-text). All other RESEARCH rows pass.
- **Decisions recorded** (`## Decisions`): the resume line verbatim, delivery route and date, one downstream bullet per slot, the CONTEXTMENU provenance paragraph, and the `D-25 re-sweep candidates` table (included: Activity Logs, Laboratory — both 16-22; excluded with reasons: list cells, Home card, Detail header, Filters sheet, HC badges, Comments underline, every D-28 site, NewDawn).

## Task Commits

1. **Task 1: Measure — category variants, HC comparison + proposal, non-category colours, DWC** — `5e71ea53` (docs) — prior executor
2. **Task 2: Owner decisions checkpoint** — no commit; resolved by the owner's resume line (see below)
3. **Task 3: Record the decisions and the Open Question 2 answer** — `e25d5b53` (docs)

**Plan metadata:** see the final `docs(16-13)` commit recorded in the completion report.

## Owner decision line (verbatim)

```
STARS=B CATEGORYCELL=A HC=A D28=ok CONTEXTMENU=not-exposed
```

Delivered 2026-09-11 through the orchestrator's structured checkpoint questions, option labels selected verbatim. `STARS=B`, `CATEGORYCELL=A`, `HC=A`, `D28=ok` are the owner's own selections (≈ 10:20Z); `D28=ok` applies every proposed fix, `secondary-meta` proposed no change and stays unchanged, no site vetoed.

**CONTEXTMENU provenance note.** `CONTEXTMENU=not-exposed` was not the plan's VoiceOver rotor check on `Owner-iPhone-Test`. The owner asked the orchestrator to verify Open Question 2 with agent-device instead; the orchestrator read the private-AX custom actions on the iPhone 17e simulator `67377A20…` (iOS 26.5, `agent-device snapshot --actions`, ≈ 10:35Z). The Downloads row (`.contextMenu` = Detail, Pages, Move, [Update], [Pause], Delete; `.swipeActions` = Pages, Move | Delete) exposed exactly the swipe-action set `["Pages", "Move", "Delete"]`; the context menu's distinguishing `Detail` item was absent. The reader page (`.contextMenu` only) could not be read by that backend and is not corroborating evidence. Conclusion: SwiftUI `.contextMenu` items are not surfaced as VoiceOver custom actions on iOS 26.5 (swipe actions are), so plans 16-16 / 16-19 add explicit `accessibilityAction`s. This is a simulator accessibility-tree read, not a rotor pass on the physical device; plan 16-25's manual walkthrough confirms it. No screenshot enters the repository.

## Files Created/Modified

- `.planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md` — 517 lines, five `##` sections: Category variants (84 rows + totals + rendered cross-check), Increase Contrast variants (40 comparisons + 19-row proposal), Non-category colours (28 rows + 14-row findings/fixes table), Differentiate Without Color (RESEARCH rows + 80 filter variants), Decisions (five slots + `D-25 re-sweep candidates`).

## Decisions Made

Recorded in `16-CONTRAST-AUDIT.md § Decisions` and mirrored in the frontmatter `key-decisions`. One audit-level recommendation was added while recording STARS=B, as the resume instructions required: among the three measured light-mode star candidates the audit recommends `#A38100` (3.69:1 on white, 3.01:1 on the Home card — the smallest departure from `.yellow` that clears 3:1 on both measured light backgrounds) with `#A16A00` as the deterministic fallback if 16-23's rendered Home-card ratio falls below 3.00. It is a recommendation for 16-23 to measure, not a code change.

## Deviations from Plan

All deviations occurred in Task 1 and were pre-authorised and written into the audit's introduction by the prior executor; they are listed here for the record. Task 3 executed exactly as written.

1. **[Rule 3 - Blocking] Sweep simulators no longer exist.** The `16-SWEEP.md § Infrastructure` UDIDs (`IPHONE_UDID` `ADE09605…`, `IPAD_UDID`, `SPARE_UDID`) and the plan's `88B217DA…` are gone from `xcrun simctl list devices`. All pixel measurements were taken on the available iOS 26.5 iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`. `16-SWEEP.md § Infrastructure` was deliberately not edited (this plan's `files_modified` is the audit only); a later plan re-derives the sweep infrastructure. Consequence: the plan's `xcrun simctl ui "$IPHONE_UDID" appearance` verify line cannot resolve; baselines `appearance=light`, `increase_contrast=disabled`, `content_size=large` were read on `67377A20…`, restored and read back identical.
2. **[Rule 3 - Blocking] No session on the measurement simulator (D-09).** The offline notice, the Downloads *Update* swipe action and `NewDawnView` need a session or a fixture; their ratios are computed from declared colours and marked `source-derived` in the table.
3. **[Rule 3 - Blocking] Downloads row required a download.** One public gallery (112 pages) was downloaded into a newly created default folder, and a second folder `Second` created so the *Move* action renders. It completed before it could be paused; nothing was deleted.
4. **[Rule 3 - Blocking] `simctl io screenshot` has no `--scale` flag in this Xcode.** Captures are full-scale 1170 × 2532; 57 captures + 48 grayscale copies live only under `$HOME/Library/Caches/ehpanda-phase16/round2/contrast/`. No image enters the repository (D-32).
5. **[Rule 3 - Blocking] Reduce Transparency not measurable via `simctl`** (no `ui` switch exists); Bold Text also not measured. The Liquid Glass toast was measured over a plain page only.
6. **[Documented method] Audit assembled by a scratchpad generator** (stdlib-Python colorset walker, PNG sampler, table emitter); no script was committed.

**Total deviations:** 5 blocking, auto-handled and recorded in the audit's introduction; 1 method note. **Impact on plan:** none of the measured totals changed; three of 28 non-category rows are source-derived instead of rendered and are labelled so the owner could see which ratios are pixels.

## Issues Encountered

- Task 2 was a `checkpoint:decision`; the executor stopped, the orchestrator presented the numbers, and the owner resolved it. The Open Question 2 method changed from a physical-device rotor check to a simulator accessibility-tree read at the owner's request; recorded with provenance rather than presented as a rotor result.
- The commit count in `actuals` measures the ledger range `8d462178..HEAD`, which includes plan 16-14's three commits because 16-14 ran between this plan's Task 1 and Task 3 on the same sequential tree; the per-plan commits are listed above.

## Known Stubs

None — this plan produced a planning artifact only; no source, asset or test was changed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Wave 12 complete (16-13 + 16-14). Next: plan **16-15** (adaptive `CategoryLabel` / `CategoryCell` text, HC=A re-authoring of the 19 `lower` entries, HC-40 hash re-pin only).
- Every round-2 colour and DWC build task now has an owner decision with numbers to implement against; Open Question 2 is answered.
- A11Y-02 stays open; the phase is not complete. Do not push without the owner.
- Residual caveats for plan 16-26's Nutrition Label recommendation: `.secondary` metadata at 4.00:1 (platform convention, unchanged), swipe Delete/Pause tints kept as platform conventions (fail dark+IC by Apple's pastel IC palette), Home-card dark stars over the cover gradient (content-dependent under STARS=B), and the `CategoryCell` dark-mode luminance-only distinction (CATEGORYCELL=A).

## Self-Check: PASSED

- `16-CONTRAST-AUDIT.md` exists on disk with 5 `##` sections; no absolute home path in the file; no image files staged.
- Commits `5e71ea53` (Task 1) and `e25d5b53` (Task 3) exist on `feature/gsd-phase-16`; `git log -1 --format=%s` after Task 3 = `docs(16): record round-2 colour decisions`.
- Task 3 verify: token-line count 10 (≥ 5), `D-25 re-sweep candidates` count 1.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*
