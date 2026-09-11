---
phase: 16-dynamic-type-accessibility
plan: 15
subsystem: accessibility
tags: [contrast, wcag, category-badge, color-resolved, composited, button, isSelected, voice-control, colorset, increase-contrast, sha256, d-26, d-27, d-22]

# Dependency graph
requires:
  - phase: 16-13
    provides: "`16-CONTRAST-AUDIT.md` — the 84-variant table, the 19-row HC re-authoring proposal, the 80-variant excluded-cell table, and the owner's decisions `CATEGORYCELL=A HC=A`"
  - phase: 16-14
    provides: "`Color+Contrast.swift` (`contrastingForeground(in:)`, `contrastingForeground(on:)`, `Color.Resolved.composited(over:opacity:)`) and `CategoryColorsetInvariantTests` with the standard-44 / HC-40 pins"
provides:
  - "`CategoryLabel` text is black or white from the resolved background's luminance via `color.contrastingForeground(in: environment)` (`@Environment(\\.self)`); no background byte, inset, font, radius or `lineLimit` changed"
  - "`CategoryCell` is a `Button` (`.plain`) labelled by the visible category name, with `.accessibilityAddTraits(isFiltered ? [] : .isSelected)`; excluded-state text chosen against `resolve(in:).composited(over: secondarySystemGroupedBackground, opacity: 0.3)`; haptic kept in the action; colour flip animates with the wash"
  - "HC=A: the 19 `lower` `contrast: high` entries rewritten to the audit's proposed sRGB values in each file's own encoding (values-only diff); 0/40 HC variants now below their standard sibling"
  - "`CategoryColorsetInvariantTests.highContrastPin` re-derived to `84accf722ad6601f41e6cf8d069344f5c066f58df42bfdbf21b780dbcc539407`; `standardPin` `f940492a…5363` byte-identical and passing"
  - "`16-CONTRAST-AUDIT.md § 16-15 result`: rendered flip counts, HC outcome, composite numbers, AX trait read, evidence paths; D-25 list unchanged"
affects: [16-16, 16-19, 16-23, 16-24, 16-25, 16-26, any future edit of App/Assets.xcassets/Category/Colors]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 7440
  tasks: 3
  commits: 3
  plan_head_before: 0b0926d9e9243bd73bbdbc83629d2ad9ebd8233d

tech-stack:
  added: []
  patterns:
    - "A view that draws an asset-catalog colour captures `@Environment(\\.self)` and asks the `AppTools` helper for the text colour; it never computes luminance itself"
    - "A translucent state is judged against its composite: resolve the drawn colour and the backdrop in the same environment, blend through `composited(over:opacity:)`, choose against the result"
    - "State that a control conveys by colour or opacity travels to assistive technology as a trait (`.isSelected`), never as a label"
    - "Asset-catalog edits are values-only and scoped to entries carrying the appearance key being re-authored; the invariant pins prove the rest untouched"

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift
    - App/Assets.xcassets/Category/Colors/E-Hentai/{Asian Porn,Cosplay,Doujinshi,Game CG,Image Set,Misc}.colorset/Contents.json
    - App/Assets.xcassets/Category/Colors/ExHentai/{Asian Porn,Cosplay,Doujinshi,Image Set,Manga,Misc,Non-H}.colorset/Contents.json
    - .planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md

key-decisions:
  - "Composite backdrop = `secondarySystemGroupedBackground`, identified empirically: the Filters section card sampled `#FFFFFF` / `#2C2C2E` / `#FFFFFF` / `#363638` in the audit's captures (that colour's elevated-level values) while the sheet behind it sampled the `systemGroupedBackground` grays."
  - "The excluded-tile blend is the 16-14 helper's linear `composited(over:opacity:)`, as the plan and the decision text require; the renderer blends in gamma space, and a scratch check over all 80 filter variants × {linear, gamma} × {elevated card, base-level card} found 0 disagreements in the chosen text, so the helper stays the single source and the doc comment records why the choice is insensitive."
  - "One `excludedOpacity` constant feeds both the drawn wash and the composite, so the two cannot drift."
  - "No catalog key was added (CATEGORYCELL=A prefers the trait alone); `Localizable.xcstrings` untouched."
  - "The worst-best-of pin stays `ExHentai / Game CG / light 4.62`: the worst variant is a standard one, and the HC rewrite only raised HC values (worst HC now E-Hentai / Game CG / dark+HC 5.91)."

patterns-established:
  - "Verify a composite choice at its boundary: compute the verdict for every variant under every plausible blend and backdrop before trusting one; record the margin (light washes L ≥ 0.53, dark washes L ≤ 0.16 vs the 0.1791 crossover)."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Adaptive badge text at both white-on-category sites (`CategoryLabel`, `CategoryCell`) through the AppTools helper; no background, layout or lineLimit change"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "source greps on CategoryView.swift: foregroundStyle(.white)=0, onTapGesture=0, contrastingForeground=5, isSelected=2, lineLimit(1)=1 (unchanged), swiftlint:disable=0; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "rendered pixels on 67377A20…: Detail header Doujinshi black on #FC4F4F 6.37 / white on #9B0202 8.74 / black on #FC7272 7.79 / white on #9B0101 8.76; 40 Filters tiles all ≥ 4.69:1"
        status: pass
    human_judgment: true
    rationale: "Round 2 is owner-reviewed (D-20/D-33): the visible flip of 47 badges to black text is judged from the badge-review captures, not from the numbers alone"
  - id: D2
    description: "`CategoryCell` is a real selectable control: `Button` + visible-name label + `.isSelected` when included, haptic kept"
    requirement: "A11Y-02"
    verification:
      - kind: automated_ui
        ref: "sim-use raw AX tree on the Filters sheet: ten AXButton elements labelled with the category names; included traits ['Button','Selected'], Misc after exclusion ['Button']; tapping the Button toggled the tile and the trait both ways"
        status: pass
    human_judgment: false
  - id: D3
    description: "HC=A: 19 `contrast: high` entries re-authored values-only; standard pin unchanged, HC pin re-derived; 84/84 ≥ 4.5, 47 flips, 0/40 HC lower"
    requirement: "A11Y-02"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift#CategoryColorsetInvariantTests (8 tests: RED run failed only highContrastVariantsArePinned with digest 84accf72…9407; GREEN 8/8)"
        status: pass
      - kind: other
        ref: "`git diff -U0 -- App/Assets.xcassets | grep '^[-+]' | grep -v '^[-+][-+]' | grep -vc '\"red\"\\|\"green\"\\|\"blue\"'` = 0; 13 files / 56 value lines; full FeatureTests plan 1055 tests / 184 suites / 22 targets, 0 failed"
        status: pass
    human_judgment: false
  - id: D4
    description: "Owner review evidence + audit `### 16-15 result` + D-25 list current"
    requirement: "A11Y-02"
    verification:
      - kind: manual_procedural
        ref: "20 captures under $HOME/Library/Caches/ehpanda-phase16/round2/badge-review/ (light/dark × IC off/on × frontpage, frontpage-scrolled, detail-header, filters, filters-excluded); absolute-home-path grep on 16-CONTRAST-AUDIT.md = 0; no image in git status"
        status: pass
    human_judgment: true
    rationale: "The owner judges the visible result from the captures relayed in chat (D-20, D-33)"

# Metrics
duration: 35min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 15: Adaptive category badge text, selectable `CategoryCell`, HC re-authoring Summary

**Both white-on-category sites now pick black or white from the resolved background through the 16-14 helper (47 of 84 badges flip to black, every pair ≥ 4.58:1 by construction and ≥ 4.69:1 on the rendered E-Hentai set), the Filters grid cells became `Button`s carrying `.isSelected`, and the 19 Increase Contrast variants that read worse than standard were rewritten under HC=A with only the HC-40 digest re-pinned — the 44 standard backgrounds are provably byte-identical.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-11T12:52:35Z
- **Completed:** 2026-09-11T13:27:36Z
- **Tasks:** 3
- **Files modified:** 16 (1 source, 1 test, 13 colorsets, 1 planning doc)

## Accomplishments

- `CategoryView.swift`: `CategoryLabel` captures `@Environment(\.self)` and draws `color.contrastingForeground(in: environment)`; `CategoryCell` captures the same, becomes a `Button { toggle + soft haptic } label: { … }` with `.buttonStyle(.plain)` and `.accessibilityAddTraits(isFiltered ? [] : .isSelected)`, and chooses its text against the category colour itself when included or against `resolve(in:).composited(over: Color(.secondarySystemGroupedBackground).resolve(in:), opacity: excludedOpacity)` when excluded; the text colour animates with the same `.animation(.default)` as the wash. Doc comments state the why for: the better-of rule, the full-environment capture, the composite (which backdrop, why linear, why the verdict is insensitive), the inverted `isFiltered` sense, and the single `excludedOpacity` constant. `lineLimit(1)` count before = 1, after = 1.
- Colorsets: 13 `Contents.json` files, 19 `contrast: high` entries, 56 changed value lines (`red` / `green` / `blue` only; one component happened to keep its byte), each written in the entry's own encoding — 16 hex, 2 float (E-Hentai Game CG dark+HC, ExHentai Asian Porn light+HC), 1 decimal (ExHentai Cosplay light+HC). After the rewrite: 84 / 84 ≥ 4.5, 47 black, worst best-of unchanged (ExHentai / Game CG / light 4.62), **0 / 40** HC variants below their standard sibling (was 19 / 40), worst HC best-of E-Hentai / Game CG / dark+HC 5.91.
- `CategoryColorsetInvariantTests`: `highContrastPin` → `84accf722ad6601f41e6cf8d069344f5c066f58df42bfdbf21b780dbcc539407` with a comment naming plan 16-15, the `HC=A` decision and the previous pin `e81b0604c84754a0260818465051f11fae99fe756b934db2f16929ea83600937`; the type doc now says the re-authoring happened. `standardPin` `f940492af7648bf41e12a5cca24532c8f7451d79875a75b3534a7b9c0f235363` untouched. The RED run failed on exactly that one pin and printed the same digest an independent Python reproduction of the serialization produced.
- `16-CONTRAST-AUDIT.md § 16-15 result`: rendered flip counts, the HC outcome, the excluded-cell composite table (per mode: raw Misc, linear composite L → text, rendered tile, rendered ratio), the AX trait read and the evidence paths; the D-25 section records "no exception" for this plan.

## Rendered evidence (owner review — D-20 / D-33)

Captured on the iOS 26.5 iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` with the tree at `b8296146` built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData`, bundle id checked (`plutil` → `app.ehpanda.personal`, equal to the installed bundle) and installed over the existing app. Full-scale PNGs (1170 × 2532), never committed:

| Path (`$HOME/Library/Caches/ehpanda-phase16/round2/badge-review/`) | What it shows |
|---|---|
| `light-std-frontpage.png`, `dark-std-frontpage.png`, `light-ic-frontpage.png`, `dark-ic-frontpage.png` | Top of the Frontpage list: every visible cell is `Misc` — white text in light and dark, black on the gray HC variants (`#9E9E9E`, and the re-authored `#8B969C` in dark+IC) |
| `light-std-frontpage-scrolled.png`, `dark-std-frontpage-scrolled.png`, `light-ic-frontpage-scrolled.png`, `dark-ic-frontpage-scrolled.png` | Scrolled Frontpage list with `Misc`, `Doujinshi`, `Image Set` badges: Doujinshi black on `#FC4F4F` (light) / white on `#9B0202` (dark) / black on `#FC7272` (light+IC) / white on the re-authored `#9B0101` (dark+IC); Image Set white throughout (re-authored `#2956A3` / `#1B4389` under IC) |
| `light-std-detail-header.png`, `dark-std-detail-header.png`, `light-ic-detail-header.png`, `dark-ic-detail-header.png` | Detail header of the Doujinshi gallery: the badge under the uploader — black / white / black / white, ratios 6.37 / 8.74 / 7.79 / 8.76 |
| `light-std-filters.png`, `dark-std-filters.png`, `light-ic-filters.png`, `dark-ic-filters.png` | Filters sheet, all ten tiles included: 7 / 3 / 9 / 7 tiles read black; every tile ≥ 4.69:1 (worst E-Hentai Asian Porn, light) |
| `light-std-filters-excluded.png`, `dark-std-filters-excluded.png`, `light-ic-filters-excluded.png`, `dark-ic-filters-excluded.png` | Filters sheet with `Misc` excluded through the new Button: black on `#D4D4D4` 14.17 / white on `#383A3C` 11.42 / black on `#E2E2E2` 16.21 / white on `#505356` 7.74 — was white 1.48 / 11.42 / 1.30 / 8.78 |

Rendered flips: Filters tiles **26 / 40**, list badges 4 / 12, header 2 / 4 — each matching the audited table row for row; the full 47 / 84 is the invariant test's count. Raw AX traits on the sheet: included `['Button', 'Selected']`, Misc after exclusion `['Button']`. Misc was tapped back to included, so the filter state is as found. Simulator baselines (`light` / `disabled` / `large`) read after boot, restored, read back identical; device shut down.

## Task Commits

1. **Task 1: Adaptive text on `CategoryLabel` and `CategoryCell`; `CategoryCell` becomes a selectable `Button`** — `4a6169f6` (feat)
2. **Task 2: Increase Contrast variants per `HC=A`; HC hash re-pinned** — `b8296146` (feat)
3. **Task 3: Visual review evidence, D-25 tracking** — `c1655cc3` (docs)

## Files Created/Modified

- `AppPackage/Sources/AppComponents/CategoryView.swift` — adaptive `CategoryLabel`; `CategoryCell` as `Button` + `.isSelected` + composite-aware text; doc comments.
- `AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift` — `highContrastPin` re-derived; type doc updated.
- `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}/…/Contents.json` — 13 files, 19 HC entries, values only.
- `.planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md` — `### 16-15 result`, D-25 confirmation line.

## Decisions Made

See `key-decisions` in the frontmatter. The plan's proposal table and decision text were checked against each other before Task 2: the 19 rows, the direction and the text side agree, so no checkpoint was needed.

## Deviations from Plan

### Auto-fixed Issues

None — no bug, missing functionality or blocker was found; every lint rule passed on the first build (0 `Violation:` lines), and no `swiftlint:disable` was added.

### Environment deviations (pre-authorised by the orchestrator, recorded as required)

1. **Simulator.** The plan's `88B217DA…` and `16-SWEEP.md § Infrastructure`'s `IPHONE_UDID` do not exist; every `xcodebuild test` (Tasks 1–2) and the Task 3 review ran on the iOS 26.5 iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (booted from Shutdown; baselines `light` / `disabled` / `large`; no session; restored and shut down at the end). Only `app.ehpanda.personal` is installed there and that is what the built `Info.plist` reported.
2. **Screenshots** are full-scale (`xcrun simctl io … screenshot` has no `--scale` in this Xcode).
3. **Owner chat.** The evidence paths and one-line descriptions are in this SUMMARY and in the executor's return for the orchestrator to relay.
4. **`lineLimit(1)` before-count** was 1, not the plan's "2 unless the owner changed it"; kept at 1.
5. **Section card colour** verified empirically from the audit's Filters captures (`#FFFFFF` / `#2C2C2E` / `#FFFFFF` / `#363638` card vs `#F2F2F7` / `#1C1C1E` / `#EBEBF0` / `#242426` sheet) → `secondarySystemGroupedBackground`; doc-commented.
6. **Lint** enforced by the build plugin (`xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` → `** BUILD SUCCEEDED **`, 0 violations).
7. **Scratch scripts** (`p15_hc_rewrite.py`, `p15_hc_verify.py`, `p15_verdicts.py`, `p15_shot4.sh`) lived in the session scratchpad only.

### Other notes (not deviations)

- **Device driver.** `agent-device` refused the review simulator with `DEVICE_IN_USE` (a stale `default` session from the orchestrator's earlier CONTEXTMENU read still holds the device; its runner log ends in `TEST EXECUTE FAILED`). Nothing was closed or killed; `sim-use` — the owner's recorded sweep driver — drove the session instead. Its `--label` taps did not register on the Home hero cards, coordinate taps (`--x/--y`) did on every screen; its `describe-ui --json` raw tree provided the trait evidence.
- **Filter state.** Excluding `Misc` was the only state change made on the device, and it was reverted through the same Button; the downloaded gallery and folders from 16-13 were not touched.
- **Test-run cost.** The first colorset test run after the asset edit took > 10 min (asset catalog recompile pulled a full app rebuild); test-only runs took 36–73 s; the install build into a fresh `DerivedData` under the evidence root took 52 s.

---

**Total deviations:** 0 auto-fixed; 7 pre-authorised environment deviations recorded.
**Impact on plan:** Every acceptance criterion met as written; `CATEGORYCELL=A` and `HC=A` implemented exactly; no standard colour moved (pin byte-identical); no lint rule suppressed.

## Issues Encountered

None beyond the tooling notes above.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-05 mitigated (standard pin passing; values-only diff check printed 0); T-16-03 mitigated (bundle id checked before install-over, nothing uninstalled/erased, baselines restored); T-16-01 mitigated (captures only under the evidence root; image check 0 before every docs commit; no absolute home path in the audit).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 16-16 (next, wave 14) proceeds; the Filters grid is now a set of native `Button`s, so any Voice Control / VoiceOver pass over the Filters sheet finds them labelled under their visible names.
- Plan 16-23 (`STARS=B`, D-28 fixes) can reuse the `CategoryLabel` pattern for the Read-button glyph (`read-glyph`): resolve the accent in `@Environment(\.self)` and ask `Color.contrastingForeground(in:)`.
- Plan 16-26's Nutrition Label recommendation can claim Sufficient Contrast for the category system with the numbers in `§ 16-15 result`, keeping the CATEGORYCELL=A dark-mode luminance-only caveat verbatim.
- `A11Y-02` stays open (shared with the remaining round-2 plans); nothing pushed.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*

## Self-Check: PASSED
