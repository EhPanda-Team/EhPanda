---
phase: 16
slug: dynamic-type-accessibility
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-23
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Seeded from `16-RESEARCH.md` § Validation Architecture. Task IDs are filled in by
> `/gsd-validate-phase` once plans exist.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (package tests, ~178 files / ~1020 `@Test`); XCTest/XCUITest (`EhPandaUITests`, 13 tests, non-default `UITests` plan) |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` (default, package tests via the app scheme); `UITests.xctestplan` (non-default, UI tests); the `AppPackage-Package` scheme runs every package test target |
| **Quick run command** | `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` — the build runs the SwiftLint plugin, so this *is* the lint gate |
| **Full suite command** | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=<spare sim UDID>'`, then `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,id=<spare sim UDID>'` |
| **Estimated runtime** | ~60 s (package suite) + a few minutes for the UI-test plan; the lint build is a few minutes from clean |

**Standing execution constraints.** Run **one** `xcodebuild test` invocation at a time —
overlapping runs, or `pkill`-ing one mid-launch, wedges `testmanagerd`. `xcodebuild` buffers
stdout until exit, so silence is not a hang. Bare `swift build` does not work for this package;
everything goes through `xcodebuild`.

**Simulator discipline (D-09).** The owner's logged-in simulator is phase infrastructure: it is
driven for the round-1 sweep and never erased, reset, uninstalled, or used as a UI-test
destination. UI tests and the accessibility audit run on a *spare* simulator (`<spare sim UDID>`
above), always addressed by UDID — `booted` is ambiguous with two booted simulators.

---

## Sampling Rate

- **After every task commit:** quick run command (lint gate) plus the touched package test
  target via the `AppPackage-Package` scheme (`-only-testing:<Target>`)
- **After every plan wave:** full `AppPackage-Package` test action; the `UITests` plan whenever
  `EhPandaUITests/` or view accessibility semantics changed
- **Before `/gsd-verify-work`:** both suites green, all four D-16 lint rules (plus the D-30
  guard) at zero violations, the owner-signed sweep table complete (no `pending` / `re-verify`
  rows), all five D-13 items dispositioned, the manual VoiceOver / Voice Control walkthrough
  recorded, and the D-25 re-sweep rows added and passed
- **Max feedback latency:** ~60 s for the package suite; the lint build is the slow gate and is
  run per commit, not per edit

---

## Per-Task Verification Map

Task IDs are TBD until plans are written; the rows below are the behavior contract each plan
task must map onto. Round 1 (A11Y-01) is owner-implemented, so its rows are verification work
the agent performs, not implementation tasks.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | A11Y-01 | — | `minimumScaleFactor` count is 0 and the `no_minimum_scale_factor` rule is error-level | lint (build) | quick run command; standalone cross-check `swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` | ❌ W0 (`.swiftlint.yml` rule) | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | `.dynamicTypeSize(` as a view modifier is an error; `@Environment(\.dynamicTypeSize)` and property reads stay legal (negative-control probe) | lint (build) | same as above | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | `GeometryReader` is an error (count stays 0) | lint (build) | same as above | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | Numeric-literal `.system(size:)` is an error; `@ScaledMetric`-fed forms stay legal (negative-control probe) | lint (build) | same as above | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | T-16 data protection | Every screen readable and operable at XXL / AX3 / AX5 × iPhone + iPad × portrait + landscape, judged by D-03 ("less information" = degraded); scroll-to-bottom on every screen | **manual (agent sweep, owner-signed)** | sweep per `16-RESEARCH.md` § Round-1 verification mechanics; evidence = `16-SWEEP.md` verdict table (text only) | ❌ W0 (verdict-table skeleton) | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | Each of the five D-13 AX5 edge cases closes as `fixed` or `accepted (reason recorded)` | manual | named rows in `16-SWEEP.md` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | `.large` parity after every owner fix — no visible change at the default size (D-15) | manual | before/after screenshots at `large` in the scratchpad, judged in chat (D-33) | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-01 | — | The ~30 `lineLimit(1)` sites re-judged under D-04 (no secondary-text exemption) | manual (checklist) | `16-RESEARCH.md` § D-04 re-judgement checklist, each row dispositioned in `16-SWEEP.md` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | No accessibility label / hint / value / input label is a hardcoded string literal (D-30 guard) | lint (build) | quick run command (`accessibility_hardcoded_string`) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Luminance helper: crossover at L ≈ 0.179, best-of black/white ≥ 4.58:1 for any colour, worst real variant 4.62:1 | unit | `cd AppPackage && xcodebuild test -scheme AppPackage-Package … -only-testing:AppToolsTests` (`ColorContrastTests.swift`) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | 84/84 category variants ≥ 4.5:1 with best-of text; colorset JSON bytes unchanged (hash pin; parser handles hex / float / plain-integer components) | unit (repo walk) | `… -only-testing:<target>` (`CategoryColorsetInvariantTests.swift`) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | `CategoryLabel` and the Filters `CategoryCell` render black-or-white text by resolved background luminance; no other white-on-category site remains | unit + manual | source scan + contrast test; light/dark/Increase Contrast screenshots in chat | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Missing labels, undersized hit regions, trait and contrast failures are caught on every fixture-reachable screen | UI (XCUITest) | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,id=<spare sim UDID>'` (`AccessibilityAuditUITests.swift`) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Every icon-only control and custom tappable carries a label; decorative images hidden; state as traits (`ExcludeToggle`, `CategoryCell` included) | UI audit + manual | audit above + VoiceOver walkthrough | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Every interactive element appears under Voice Control "Show numbers" / "Show names" with an input label matching its visible text (English) | **manual (device)** | walkthrough checklist from `$HOME/.claude/skills/swift-accessibility-skill/resources/qa-checklist.md` on `Owner-iPhone-Test` | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | VoiceOver reading order and post-navigation focus are sensible on every common-task screen | **manual (device)** | same walkthrough | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Each in-scope meaningful-motion site reads `accessibilityReduceMotion` and degrades to dissolve / nothing; crossfades and `.numericText()` stay ungated | source scan + manual | Swift Testing scan over the listed sites (pattern: `DownloadSourceInventoryTests`) + Accessibility Inspector "Reduce Motion" simulation | ❌ W0 (optional scan) | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Non-category colours meet 4.5:1 text / 3:1 non-text in light, dark and Increase Contrast | manual sim | `xcrun simctl ui <UDID> appearance dark`, `… increase_contrast enabled`; Accessibility Inspector contrast calculator | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | No state is colour-only: activity-log level dots gain a glyph/text; filter selection and laboratory toggles carry non-colour cues | manual (grayscale) | Settings → Accessibility → Display → Color Filters → Grayscale on a device; screenshot review in chat | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Screens touched by a visible round-2 addition re-pass XXL / AX3 / AX5 (D-25 targeted re-sweep) | manual | rows appended to `16-SWEEP.md` | — | ⬜ pending |
| TBD | TBD | TBD | A11Y-02 | — | Nutrition Label recommendation names each of the 6 claimed categories with its evidence, plus Dark Interface and the two N/A categories | doc | `16-NUTRITION-LABEL.md` present with one section per category | ❌ phase close | ⬜ pending |
| TBD | TBD | TBD | — | — | Existing package suite stays green (no regression from label / motion / colour changes) | regression | full `AppPackage-Package` test action | ✅ exists | ⬜ pending |
| TBD | TBD | TBD | — | — | Existing 13 UI tests stay green | regression | `UITests` plan | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Sequencing constraint the map depends on.** The SwiftLint plugin runs at error severity on
every build, so the `no_minimum_scale_factor` rule can only be committed once the owner's five
removals have landed (or in the same commit); landing it earlier breaks everyone's build. The
other three D-16 rules and the D-30 guard flag zero sites today and can land immediately.

**Why the lint rows carry negative-control probes.** A custom regex rule with a mis-spelled
`match_kinds` or an over-broad pattern either silently matches nothing or blocks the owner's own
reflow code (`@Environment(\.dynamicTypeSize)`, `@ScaledMetric`-fed `.system(size:)`). Each rule is
proven with one positive and one negative sample against the SwiftLint 0.65.0 binary before it is
committed, per the `11-EXCEPTIONS.md` §1.2 pattern.

---

## Wave 0 Requirements

- [ ] `.swiftlint.yml` — five custom rules (four D-16 + the D-30 `accessibility_hardcoded_string`
      guard); `no_minimum_scale_factor` sequenced after the owner's removals
- [ ] `.planning/phases/16-dynamic-type-accessibility/16-SWEEP.md` — verdict-table skeleton:
      the re-derived ~42-surface inventory × 12 cells (iPhone/iPad × portrait/landscape ×
      XXL/AX3/AX5), plus the 5 named D-13 rows and the D-04 `lineLimit(1)` checklist rows;
      status vocabulary `pending | pass | finding:#N | re-verify | accepted`
- [ ] `AppPackage/Tests/AppToolsTests/ColorContrastTests.swift` — luminance / contrast helper tests
- [ ] `AppPackage/Tests/<target>/CategoryColorsetInvariantTests.swift` — 84/84 ≥ 4.5:1 with
      best-of text + colorset SHA-256 pin (parser handles the three component encodings)
- [ ] `EhPandaUITests/AccessibilityAuditUITests.swift` — `performAccessibilityAudit()` per
      fixture-reachable screen, deep-link entry via the existing `UITestConstants`; registered in
      `UITests.xctestplan`
- [ ] Catalog keys (`accessibility.*`) in each touched module's `.xcstrings`, all six locales
      filled, numeric arguments labeled per `CLAUDE.md`
- [ ] (optional) hermetic fixtures for Favorites / Archives / Torrents so the automated audit
      reaches them credential-free
- [ ] Framework install: none — Swift Testing, XCTest and both test plans already exist

---

## Manual-Only Verifications

VoiceOver and Voice Control do not exist in the Simulator, the D-03 verdict ("less information")
is a visual judgment, and the Nutrition Label bar requires every common user task to work — so a
human pass is required by the bar itself, not a coverage gap.

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Readability / operability at XXL / AX3 / AX5, both devices, both orientations | A11Y-01 | Truncation is a rendered outcome; the AX snapshot still reports the full label, so the screenshot is the verdict basis | Per cell: `xcrun simctl ui <UDID> content_size <token>` (`extra-extra-extra-large` / `accessibility-extra-large` / `accessibility-extra-extra-extra-large`), `agent-device orientation …`, open the screen, **scroll to the bottom**, screenshot to the scratchpad, record the row in `16-SWEEP.md`; restore `content_size large` afterwards |
| `.large` parity after each owner fix | A11Y-01 | Parity is a visual comparison against the pre-fix appearance | Before/after at `large`, sent in chat (D-33); owner judges |
| Owner-signed UAT (criterion 5) | A11Y-01 | The gate carried over from Phase 10 is the owner's signature, not the agent's | Owner reviews the completed `16-SWEEP.md` and the chat evidence, signs the table |
| VoiceOver announcement, reading order, focus after navigation | A11Y-02 | No VoiceOver in the Simulator; order and focus are experiential | `Owner-iPhone-Test`: Settings → Accessibility → VoiceOver; walk every common-task screen with the skill's `qa-checklist.md` |
| Voice Control "Show numbers" / "Show names" actuation | A11Y-02 | No Voice Control in the Simulator | Same device: Settings → Accessibility → Voice Control; say "Show names", confirm every control is listed and its name matches the visible text; actuate by name |
| Reduce Motion outcome (dissolve / none on gated sites) | A11Y-02 | The replacement is a rendered effect | Accessibility Inspector → Settings → Reduce Motion, or device Settings; exercise each gated site |
| Contrast under dark + Increase Contrast | A11Y-02 | Colour resolution depends on the live trait environment | `xcrun simctl ui <UDID> appearance dark`, `… increase_contrast enabled`; Accessibility Inspector contrast calculator on badge text and non-category colours |
| Differentiate Without Color | A11Y-02 | The cue has to survive a grayscale render | Device Color Filters → Grayscale; confirm every colour-coded state still reads |

**Evidence rules (D-32 / D-33):** screenshots live only under the session scratchpad and are
sent to the owner in chat; the committed artifacts are text-only verdict tables with written
descriptions. No image file is ever added to the repository, even of a content-free screen.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s for the package suite
- [ ] Owner-signed `16-SWEEP.md` with every row non-pending and all five D-13 rows dispositioned
- [ ] Device walkthrough (VoiceOver + Voice Control) recorded
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
