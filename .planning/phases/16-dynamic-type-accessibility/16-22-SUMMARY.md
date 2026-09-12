---
phase: 16-dynamic-type-accessibility
plan: 22
subsystem: accessibility
tags: [differentiate-without-color, sf-symbols, os-log-level, laboratory, contrast-measurement, d-20, d-25, d-28]

# Dependency graph
requires:
  - phase: 16-13
    provides: "The audit-first verdicts (`16-CONTRAST-AUDIT.md § Differentiate Without Color`): Activity-log level `fail`, Laboratory on/off `fail`, the § D-28 pixel method and the D-25 candidate table this plan fills in"
  - phase: 16-17
    provides: "`.accessibilityLabel(log.level.title)` on the level glyph and the Laboratory `Toggle` representation that lets the new state glyph stay hidden"
  - phase: 16-21
    provides: "Environment notes: iPhone 17e `67377A20…`, held taps for toggles, coordinate-only navigation near destructive controls, the install-over protocol"
provides:
  - "`OSLogEntryLog.Level.symbol` — a top-level `private extension` in `SettingFeature` (`AppActivityLogsView.swift`) mapping debug / info / notice / error / fault / undefined (+ `@unknown default`) to `ant` / `info.circle.fill` / `bell.fill` / `exclamationmark.triangle.fill` / `xmark.octagon.fill` / `questionmark.circle.fill`; `AppActivityLogRow` draws `log.level.symbol` at the unchanged `.caption2` size, colour and label"
  - "`LaboratoryCell` state glyph — `checkmark.circle.fill` / `circle` leading the title at the cell's `.title2` size, `.accessibilityHidden(true)`, doc-commented; cell height unchanged"
  - "`16-CONTRAST-AUDIT.md § 16-22 result (DWC)`: eight glyph rows at 3:1 across light / dark / light+IC / dark+IC (four rendered, four source-derived and labelled), grayscale note, row-height evidence, the D-28 row `log-glyph-error` handed to 16-23, D-25 rows `#32 Activity Logs` and `#36 Laboratory` recorded as built"
affects: [16-23 (log-glyph-error D-28 row; palette-rendering and comment-link underline still open), 16-24 (Activity Logs / Laboratory now render shapes), 16-26 (D-25 re-sweep of #32 and #36; Nutrition Label DWC evidence)]

# Actuals (#2632) — estimateTokens scale (chars/4 over the realized diff)
actuals:
  tokens: 3565
  tasks: 2
  commits: 2
plan_head_before: 73e7da11bc85923d6f7baf0e829440e8dcad8856

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Presentation-side enum extensions: a glyph mapping for a model enum lives as a `private extension` beside the one view that renders it, so `AppModels` gains no `SFSafeSymbols` dependency"
    - "Absent-state contrast basis: when a state cannot be rendered, resolve its system colour through UIKit trait collections inside the same simulator (`xcrun simctl spawn` on a throwaway tool) and validate the basis against colours that were rendered"

key-files:
  created: []
  modified:
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift
    - .planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md
    - .planning/phases/16-dynamic-type-accessibility/deferred-items.md

key-decisions:
  - "Six distinct level shapes (not the audit's three with a shared `circle.fill`): with a shared shape debug / info / notice would still have differed by colour alone; `.undefined` and `@unknown default` share the question mark so an unknown level is never mistaken for a known one"
  - "The Laboratory glyph leads the title inside the centred content (plan wording: leading), inherits the cell's `.title2` and `contentColor`, and is `.accessibilityHidden(true)` because the 16-17 `Toggle` representation already carries the state"
  - "The failing `.error` glyph colour (`.orange` 2.31:1 on white in light) is handed to 16-23 as D-28 row `log-glyph-error` rather than fixed here: the plan keeps `.foregroundStyle(level.color)` and forbids editing `AppModels`"
  - "Absent levels (debug, info, fault, undefined — no such row in any of the 18 run logs on the simulator) are source-derived from UIKit-resolved iOS 26 system colours, validated byte-for-byte against the rendered gray / orange / indigo / red of the audit, and labelled per row"

patterns-established:
  - "D-25 bookkeeping: a plan that adds a visible glyph records the screen number, the commit and the measured frame in the audit's candidate table, and the re-sweep plan reads it from there"

requirements-completed: [A11Y-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Per-level SF Symbol on the Activity Logs level glyph (view-side `OSLogEntryLog.Level.symbol`, six shapes + `@unknown default`), colour / size / label unchanged; `AppModels` and `Package.swift` untouched"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: `var symbol` view 1 / AppModels 0; `log.level.symbol` 1; `systemSymbol: .circleFill` 0; `awk '/module: .appModels,/,/\\]/' Package.swift | grep -c sfSafeSymbols` 0; `git diff --quiet 73e7da11..HEAD -- AppPackage/Package.swift AppPackage/Sources/AppModels` exit 0; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests -only-testing:SettingFeatureTests on 67377A20… — TEST SUCCEEDED, 60 tests in 13 suites (2 pre-declared known issues at SettingReducerTests.swift:44 and SettingPresentationTests.swift:73)"
        status: pass
      - kind: automated_ui
        ref: "sim-use describe-ui on 67377A20…: `Image 'Error' #exclamationmark.triangle.fill (17,176 11x10)` and `Image 'Notice' #bell.fill (17,130 10x11)`; row timestamps at y 174 / 265 / 355 / 446 / 537 / 627 before and after (`before-large-activity-logs.png` / `after-large-activity-logs.png`)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Laboratory cell on/off glyph (`checkmark.circle.fill` / `circle`), hidden from accessibility, cell height unchanged"
    requirement: "A11Y-02"
    verification:
      - kind: automated_ui
        ref: "sim-use describe-ui: `CheckBox 'Bypass SNI Filtering' (16,169 358x71)` before and after; agent-device `[switch] \"Bypass SNI Filtering\"` (one element, glyph not exposed); `before-large-laboratory.png` / `after-large-laboratory.png`; restored OFF (`after-large-laboratory-restored.png` cell centre `#E5E5EA`)"
        status: pass
      - kind: other
        ref: "grep -c 'accessibilityHidden(true)' LaboratorySettingView.swift = 1; lint build SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every added glyph re-measured at 3:1 in light / dark / light+IC / dark+IC and checked in grayscale; results appended to the audit; the one failing level colour handed to 16-23 as a D-28 row"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "`### 16-22 result (DWC)` table: bell 3.26 / 6.44 / 5.23 / 9.50, triangle 2.31 (FAIL light → `log-glyph-error`) / 9.41 / 4.55 / 10.41, circle 4.50 / 6.07 / 4.35 / 5.50, checkmark 3.39 / 4.79 / 4.33 / 7.33, source-derived ant ≥ 5.09, info ≥ 3.52, octagon ≥ 3.57, question mark 21.00; grayscale copies under round2/dwc/gray/"
        status: pass
    human_judgment: true
    rationale: "Whether the bell / triangle and ring / filled-disc shapes read as distinct states to a sighted user is a visual judgment; the owner reviews the before/after captures listed below (D-33)"
  - id: D4
    description: "D-25 re-sweep candidates carry `#32 Activity Logs` and `#36 Laboratory` as built; simulator baselines restored; no image in the repo"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "grep -c '#32 Activity Logs' 16-CONTRAST-AUDIT.md = 3, '#36 Laboratory' = 3, absolute home paths 0; `xcrun simctl ui` read back appearance light / content_size large / increase_contrast disabled before shutdown; `git status --porcelain | grep -Eic '\\.(png|jpe?g|heic|gif|mov|mp4)$'` = 0 before each commit"
        status: pass
    human_judgment: false

# Metrics
duration: 16min
completed: 2026-09-12
status: complete
---

# Phase 16 Plan 22: Differentiate Without Color remediation Summary

**Every activity-log level now has its own SF Symbol (`ant`, `info.circle.fill`, `bell.fill`, `exclamationmark.triangle.fill`, `xmark.octagon.fill`, `questionmark.circle.fill`) drawn by a view-side `OSLogEntryLog.Level.symbol` at the old dot's size, the Laboratory cell shows a `checkmark.circle.fill` / `circle` state glyph hidden from VoiceOver, both measured at 3:1 in four modes and in grayscale with the row and cell heights unchanged; the `.error` orange's 2.31:1 light-mode failure is handed to 16-23 as D-28 row `log-glyph-error`, and `#32 Activity Logs` / `#36 Laboratory` are recorded as the D-25 re-sweep screens.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-09-11T23:57:58Z
- **Completed:** 2026-09-12T00:14:53Z
- **Tasks:** 2
- **Files modified:** 4 (2 Swift, 2 planning)

## Accomplishments

- Criterion 11 on the Activity Logs list: shape carries the level, colour repeats it, the level title remains the accessibility label. The mapping is a top-level `private extension` beside the row that uses it, doc-commented with the two reasons the plan asked for (shape as the non-colour carrier; view-side because `AppModels` does not depend on `SFSafeSymbols` and a glyph is presentation). `AppModels` and `AppPackage/Package.swift` are byte-identical to `73e7da11`.
- Criterion 11 on the Laboratory cell: the audit's verdict was **fail** (tinted vs gray measured 1.01–1.25 in grayscale), so the on/off glyph was added, leading the title at `.title2`, inheriting `contentColor`, `.accessibilityHidden(true)` with a doc comment explaining that the `Toggle` representation carries the state and the marker stays decorative even if that representation is ever removed. The cell measures 358 × 71 pt before and after.
- After-measurements appended to `16-CONTRAST-AUDIT.md § 16-22 result (DWC)`: 8 glyph rows × 4 modes; every ratio ≥ 3:1 except the error triangle in light (2.31, the audit's `log-dot` colour, unchanged by design here); grayscale check recorded with the desaturated copies' path; D-25 rows updated with the screen numbers, commit and measured frames.

## Symbols per level

| Level | `Level.color` | Symbol | Why |
|---|---|---|---|
| `.debug` | `.indigo` | `ant` | The debugging metaphor; a distinct silhouette from every other level |
| `.info` | `.blue` | `info.circle.fill` | The system's information glyph |
| `.notice` | `.gray` | `bell.fill` | A notice is something to be told about; distinct from the info circle by outline |
| `.error` | `.orange` | `exclamationmark.triangle.fill` | The system's warning glyph (the same family as the toast's error icon) |
| `.fault` | `.red` | `xmark.octagon.fill` | The stop sign; heavier than the warning triangle, as a fault is heavier than an error |
| `.undefined` and `@unknown default` | `.primary` | `questionmark.circle.fill` | An unknown level must not be mistaken for a known one; the two share a glyph as `title` shares its "unknown" wording |

All six names verified present in the vendored SFSafeSymbols set (`static let` grep = 1 each); no substitution was needed.

## Laboratory outcome

Glyph **added** (audit verdict `fail`, not `weak`): `Image(systemSymbol: isOn ? .checkmarkCircleFill : .circle)` leads the `Label` inside an `HStack`, hidden from accessibility. Live tree after: agent-device `@e11 [switch] "Bypass SNI Filtering"` (one element; the glyph is not exposed), sim-use `CheckBox "Bypass SNI Filtering" (16,169 358x71)` — identical frame to the 16-21 build. Toggled ON with `sim-use tap --duration 0.05` for the ON captures and restored to OFF the same way (`after-large-laboratory-restored.png` reads gray-5 `#E5E5EA` at the cell centre).

## Measurement table (from the audit)

| glyph | level/state | L | D | L+IC | D+IC | verdict | basis |
|---|---|---|---|---|---|---|---|
| `ant` | debug `.indigo` | 5.09 | 5.98 | 6.12 | 9.84 | pass | source-derived |
| `info.circle.fill` | info `.blue` | 3.52 | 6.49 | 4.57 | 9.76 | pass | source-derived |
| `bell.fill` | notice `.gray` | 3.26 | 6.44 | 5.23 | 9.50 | pass | rendered |
| `exclamationmark.triangle.fill` | error `.orange` | **2.31** | 9.41 | 4.55 | 10.41 | **FAIL (light)** → D-28 `log-glyph-error`, 16-23 | rendered |
| `xmark.octagon.fill` | fault `.red` | 3.57 | 6.12 | 4.56 | 7.15 | pass | source-derived |
| `questionmark.circle.fill` | undefined `.primary` | 21.00 | 21.00 | 21.00 | 21.00 | pass | source-derived |
| `circle` | Laboratory OFF | 4.50 | 6.07 | 4.35 | 5.50 | pass | rendered |
| `checkmark.circle.fill` | Laboratory ON | 3.39 | 4.79 | 4.33 | 7.33 | pass | rendered |

Threshold 3:1, compared `>=`, no rounding up. Rendered rows: pixel boxes over the glyphs in `<mode>-activity-logs.png` (run 4's `07:28:27` second — three notice rows and one error row on one screen, reached through the Runs picker's More Logs sheet and the search field) and `<mode>-laboratory-{off,on}.png`. Source-derived rows: every run log on the simulator (18 JSONL files) holds `level` 3 and 4 only, so the four other colours were resolved through UIKit trait collections by a throwaway tool spawned inside the same simulator; that tool reproduced the audit's rendered gray / orange / indigo / red bytes exactly, which validates the basis. Every rendered glyph colour equals the dot colour the audit measured for the same level or state.

Grayscale (`sips --matchTo 'Generic Gray Profile.icc'`): bell `#7C7C7C` vs triangle `#9C9C9C` on white (tonal ratio 1.3 — the disc's failure; the shapes carry it); Laboratory ring `#545454` on `#DFDFDF` vs filled disc `#616161` on `#D5D5D5` (tones within the audit's 1.1 state ratio; ring vs disc, 12 % vs 46 % coverage, carries it).

## Evidence for the owner (D-33; never committed, D-32)

`$HOME/Library/Caches/ehpanda-phase16/round2/dwc/` — 23 files:

- Row-height pairs at `content_size large`: `before-large-activity-logs.png` → `after-large-activity-logs.png` (timestamps at y 174 / 265 / 355 / 446 / 537 / 627 pt in both; the disc became the triangle); `before-large-laboratory.png` → `after-large-laboratory.png` (cell 358 × 71 pt in both; the empty circle leads the title); `after-large-laboratory-restored.png`.
- Four-mode sets: `{light-std,dark-std,light-ic,dark-ic}-activity-logs.png`, `…-laboratory-off.png`, `…-laboratory-on.png`.
- `gray/`: desaturated `light-std` and `dark-std` copies of the three screens.

## D-25 updates

`16-CONTRAST-AUDIT.md § D-25 re-sweep candidates`: the two rows now read `#32 Activity Logs (Settings › General › App Activity Logs)` and `#36 Laboratory (Settings › Laboratory)`, marked built by 16-22 (`286ecc15`) with the measured frames, and the "included set" sentence names both by number. The `Comments (LinkColoredText)` row is unchanged: the underline was not part of this plan (see Deviations).

## Task Commits

1. **Task 1: Differentiate Without Color — log-level symbols, Laboratory glyph** — `286ecc15` (feat)
2. **Task 2: Re-measure, record, update the D-25 list** — `a4b67241` (docs)

**Plan metadata:** see the final `docs(16-22)` commit.

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift` — row draws `log.level.symbol`; `private extension OSLogEntryLog.Level { var symbol: SFSymbol }` with doc comment; row comment rewritten for the new carrier.
- `AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift` — `HStack` with the hidden state glyph before the `Label`; body doc comment extended.
- `.planning/phases/16-dynamic-type-accessibility/16-CONTRAST-AUDIT.md` — `### 16-22 result (DWC)` appended; D-25 rows and sentence updated.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — one out-of-scope observation appended (below).

## Decisions Made

See `key-decisions` in the frontmatter. In short: six distinct shapes rather than the audit's three; the glyph leads the title inside the centred content; the failing `.error` colour goes to 16-23 unchanged; absent levels are source-derived from validated UIKit-resolved colours and labelled as such.

## Deviations from Plan

No deviation rule (1–4) fired: no bug, missing functionality or blocker in the code, and no architectural question. The differences below are between the plan's environment / references and HEAD, applied per the orchestrator's pre-authorisations, plus two places where the audit's own text and the plan disagree (surfaced, not resolved here).

1. **Sites at HEAD (env fact 1).** `AppActivityLogRow` sat at lines 274–277 (plan: 205–230) with the 16-17 comment "Colour is the dot's only visible meaning…", rewritten to "The shape carries the level, the colour repeats it, and the level name is what both stand for". `LaboratoryCell` body as described. The audit's Laboratory verdict is `fail`, so the glyph branch of the plan applied.
2. **Simulator (env fact 3).** Every UDID in `16-SWEEP.md § Infrastructure` and the plan's `IPHONE_UDID` are gone; iPhone 17e `67377A20…` was used for the install-over, the captures and `SettingFeatureTests` (the test host, not the app bundle, is what `xcodebuild test` installs; `app.ehpanda.personal` and its downloads were verified present afterwards). `agent-device open … --device "iPhone 17e"` (no `--udid`, per the orchestrator; the only booted 17e). Baselines light / large / disabled as expected, restored and read back.
3. **Absent levels (env fact 4).** No debug / info / fault / undefined row exists in any run on the simulator (all 18 JSONL files: levels 3 and 4 only), so those four rows are source-derived and say so; the basis was validated against the rendered colours rather than taken from Apple's documented (pre-iOS-26) palette. The `Fault` absence the orchestrator anticipated held; `Info` / `Debug` were also absent (the app persists nothing below notice on these runs).
4. **"Before" captures.** The `content_size large` before-shots were taken from the installed 16-21 build *before* the install-over, so the pair compares the two builds on the same simulator and settings.
5. **Table shape.** The audit table carries the plan's eight columns plus a ninth `basis` column, so each row states rendered vs source-derived as the orchestrator asked.
6. **Audit text vs plan (surfaced for 16-23 / the owner).** `§ Decisions › D28 = ok` says 16-22 renders the glyphs in palette mode (`.primary` mark) and adds `.underlineStyle(.single)` on comment links; plan 16-22's action keeps `.foregroundStyle(level.color)` and lists neither `LinkColoredText` nor an underline task. The plan was followed as written; the audit's new section records both as still open, and `deferred-items.md` carries the underline so it is not lost.
7. **`grep -c "### 16-22 result (DWC)"` prints 2**, not 1: the heading plus the D-25 row that points at it. The section exists once.

**Total deviations:** 0 auto-fixed; 7 pre-authorised environment / reference differences recorded.
**Impact on plan:** every plan truth met; `AppModels` and the manifest untouched; no lint suppression; no layout moved at `large`. One D-28 row (`log-glyph-error`) is handed to 16-23 exactly as the plan provides for.

## Issues Encountered

- **Search submission on the simulator.** With the hardware keyboard attached the `.searchable` field showed no software keyboard; the keyword was submitted by typing a newline (`sim-use type $'\n'`), which fired `onSubmit(of: .search)` normally.
- **Runs picker navigation.** The current run (run 9) is 310 Parser errors and two notices 300 rows apart, so run 4 was selected through More Logs and filtered to its `07:28:27` second to put both shapes on one screen; the current run was re-selected afterwards (top row `09:01:43.223 Error` verified).
- **Notice light+IC box** sampled `#FEFEFE` and `#FFFFFF` in equal share; the ratio is reported against the page white (5.23; 5.18 against `#FEFEFE`; both pass) and the tie is noted in the audit.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-05 mitigated (no colorset touched). T-16-14 mitigated (four ratios per glyph, eight glyphs, rendered / source-derived labelled). T-16-21 mitigated (`git diff --quiet 73e7da11..HEAD -- AppPackage/Package.swift AppPackage/Sources/AppModels` exit 0; `appModels` target still lists no `sfSafeSymbols`). T-16-01 mitigated (evidence root only; image check 0 before both commits). T-16-03 mitigated (bundle id checked before the single install-over; nothing uninstalled, erased or reset; downloads `4178996` / `4183242` / `4179873` untouched; settings restored; Laboratory toggle restored to OFF).

## Deferred items appended

- Comment-link `.underlineStyle(.single)` in `LinkColoredText`: attributed to 16-22 by `16-CONTRAST-AUDIT.md § Decisions` and the D-25 table, present in no plan's tasks (16-22's files exclude `LinkColoredText`); needs a home (16-23 or a later plan).

## User Setup Required

None.

## Next Phase Readiness

- Ready for 16-23 (wave 21): apply the D-28 fixes, now including `log-glyph-error` (the `.error` triangle's light-mode orange, 2.31:1); the § Findings `log-dot` proposal (palette rendering with a `.primary` mark, or a light-mode orange ≥ 3:1) applies to the triangle unchanged.
- 16-26 re-walks `#32 Activity Logs` and `#36 Laboratory` at XXL / AX3 / AX5 (D-25); both frames are unchanged at `large`, which is the claim to prove at the accessibility sizes.
- Open for the owner: the two items in deviation 6 (palette rendering; comment-link underline) have no plan; the Nutrition Label DWC claim (16-26) can cite this section for the Activity Logs and Laboratory states.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-12*

## Self-Check: PASSED

SUMMARY present; the four modified files present; commits `286ecc15` and `a4b67241` found in history; 0 absolute home paths in the SUMMARY, the audit and `deferred-items.md`; 0 image files in `git status`.
