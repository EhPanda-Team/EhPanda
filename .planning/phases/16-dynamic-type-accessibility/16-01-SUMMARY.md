---
phase: 16-dynamic-type-accessibility
plan: 01
subsystem: infra
tags: [swiftlint, custom-rules, dynamic-type, accessibility, lint, build-plugin]

# Dependency graph
requires:
  - phase: 05-device-metrics-native-geometry
    provides: "The GeometryReader ban this rule now enforces mechanically"
  - phase: 10-ui-polish
    provides: "D-02 'reflow, never cap' — the Dynamic Type foundation these rules lock in"
  - phase: 11-infra-refactor-lint-capstone
    provides: "The custom_rules battery, the doccomment spelling-trap comment, the negative-control probe pattern (11-EXCEPTIONS §1.2), and the `// reason:` + `swiftlint:disable:next` escape-hatch protocol"
provides:
  - "Build-time enforcement of 'reflow, never cap': `.dynamicTypeSize(...)` as a modifier is now an error diagnostic in every module"
  - "Build-time enforcement of the Phase 5 GeometryReader ban"
  - "Build-time enforcement of scalable fonts: a numeric-literal `.system(size:)` is now an error"
  - "Build-time enforcement of D-30: accessibility label/value/hint/input-label string literals are now an error"
  - "A proven negative-control probe table for all four rules against the 0.65.0 artifact binary"
affects: [16-02, 16-12, 16-13, round-2 accessibility plans, every future SwiftUI change in the tree]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Regex custom rules that ban a *modifier* form while leaving the *property/environment* form legal (trailing `\\(` in the pattern)"
    - "Regex custom rules that ban a *literal* argument while leaving a symbolic one legal (`[0-9]` digit class; `\"` after the open paren)"
    - "A custom rule that deliberately does NOT exclude the `string` match kind because the string literal itself is the violation"

key-files:
  created: []
  modified:
    - ".swiftlint.yml"

key-decisions:
  - "Four rules land now at zero violations; `no_minimum_scale_factor` is deferred to plan 16-12 because it flags five live sites the owner removes by hand in round 1 and the build-tool plugin runs at error severity (D-14, D-16, D-23)."
  - "`accessibility_hardcoded_string` excludes only `comment` and `doccomment` — `string` is deliberately NOT excluded, with an inline YAML comment stating why, because the violation IS the string literal (D-30)."
  - "The `doccomment`-not-`doc_comment` spelling-trap comment is copied verbatim onto all four new rules, matching the three existing occurrences."

patterns-established:
  - "Modifier-vs-property discrimination: `\\.dynamicTypeSize\\s*\\(` fires on the cap but stays silent on `@Environment(\\.dynamicTypeSize)` and `dynamicTypeSize.isAccessibilitySize` (D-17)"
  - "Literal-vs-symbol discrimination: `\\.system\\(\\s*size:\\s*[0-9]` fires on `.system(size: 16)` but stays silent on an `@ScaledMetric`-fed `.system(size: someMetric)` (D-18)"
  - "Negative-control probe before commit: every new custom rule is proven to fire on a positive AND proven silent on the near-miss form, in a throwaway file outside the repo, deleted after the run (11-EXCEPTIONS §1.2)"

requirements-completed: []  # This plan's frontmatter lists A11Y-01 and A11Y-02, but both are
# PHASE-wide requirements carried by all 26 plans: A11Y-01 closes on the owner-signed sweep and the
# five minimumScaleFactor removals, A11Y-02 on the VoiceOver walkthrough and the Nutrition Label
# recommendation. Neither is satisfied by plan 01. See Deviations #3.

coverage:
  - id: D1
    description: "`no_dynamic_type_size_modifier` bans the Dynamic Type cap modifier tree-wide while leaving `@Environment(\\.dynamicTypeSize)` reads legal"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "swiftlint lint --no-cache --config .swiftlint.yml <probe> — positives at probe lines 9,10 fire; negatives at lines 4,17,18 silent"
        status: pass
      - kind: integration
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator' — BUILD SUCCEEDED, 0 error:"
        status: pass
    human_judgment: false
  - id: D2
    description: "`no_geometry_reader` bans GeometryReader tree-wide (Phase 5 constraint, now mechanical)"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "probe line 11 fires `no_geometry_reader`; full-tree strict lint reports 0 violations in 555 files"
        status: pass
    human_judgment: false
  - id: D3
    description: "`no_fixed_system_font_size` bans numeric-literal `.system(size:)` while leaving `@ScaledMetric`-fed sizes legal"
    requirement: A11Y-01
    verification:
      - kind: other
        ref: "probe lines 12,13 fire; negatives at lines 19 (`.system(size: reloadSymbolSize)`) and 20 (`.system(.body)`) silent"
        status: pass
    human_judgment: false
  - id: D4
    description: "`accessibility_hardcoded_string` (D-30) bans string literals in accessibilityLabel/Value/Hint/InputLabels"
    requirement: A11Y-02
    verification:
      - kind: other
        ref: "probe lines 14,15,16 fire; negatives at lines 21-24 (`.someKey`, `title`, `[String(localized:)]`, `[.keyA, .keyB]`) silent"
        status: pass
    human_judgment: false
  - id: D5
    description: "Rules enforced by the SwiftLintBuildToolPlugin on the app scheme AND on the test targets (the app-scheme build does not lint `Tests/`)"
    requirement: A11Y-01
    verification:
      - kind: integration
        ref: "xcodebuild build-for-testing -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=88B217DA-…' — TEST BUILD SUCCEEDED, 0 error:"
        status: pass
    human_judgment: false

# Metrics
duration: 18min
completed: 2026-08-23
status: complete
---

# Phase 16 Plan 01: Dynamic Type and Accessibility Lint Rules Summary

**Four error-level SwiftLint custom rules now enforce "reflow, never cap" and "accessibility strings come from the catalog" on every build, each proven to fire on the banned form and proven silent on its legal near-miss.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-23T13:47:00Z
- **Completed:** 2026-08-23T14:05:00Z
- **Tasks:** 2 of 2
- **Files modified:** 1 (`.swiftlint.yml`, +55 lines)

## Accomplishments

- Landed `accessibility_hardcoded_string`, `no_dynamic_type_size_modifier`, `no_fixed_system_font_size` and `no_geometry_reader` in the root `.swiftlint.yml`, each in alphabetical position (not appended), each `severity: error`, each carrying the `doccomment` spelling-trap comment.
- Proved every rule with a negative control before commit: 8 positives fired, each by exactly the intended rule; 9 near-miss negatives stayed silent. No stderr configuration warning, so no rule was silently discarded.
- Confirmed the whole tree is at zero: `swiftlint lint --strict --no-cache` over `AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests` reported `Found 0 violations, 0 serious in 555 files` and exited 0.
- Proved the rules under the build-tool plugin on both halves of the gate: `xcodebuild build -scheme EhPanda` (`** BUILD SUCCEEDED ** [135.499 sec]`) and `xcodebuild build-for-testing -scheme EhPanda -testPlan FeatureTests` (`** TEST BUILD SUCCEEDED ** [67.827 sec]`), zero `error:` diagnostics in either log.
- Kept `no_minimum_scale_factor` out (`grep -c` prints `0`) — it flags the five live D-14 sites the owner removes by hand in round 1, so it is sequenced into plan 16-12.

## Probe Table (negative control, SwiftLint 0.65.0 artifact binary, live config)

### Positives — all 8 fired, each by exactly the intended rule

| # | Probe line | Construct | Rule that fired |
|---|---|---|---|
| 1 | 9 | `.dynamicTypeSize(.large)` | `no_dynamic_type_size_modifier` |
| 2 | 10 | `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` | `no_dynamic_type_size_modifier` |
| 3 | 11 | `GeometryReader { _ in EmptyView() }` | `no_geometry_reader` |
| 4 | 12 | `.font(.system(size: 16))` | `no_fixed_system_font_size` |
| 5 | 13 | `.font(.system(size:16.5, weight: .bold))` | `no_fixed_system_font_size` |
| 6 | 14 | `.accessibilityLabel("Hardcoded")` | `accessibility_hardcoded_string` |
| 7 | 15 | `.accessibilityInputLabels(["Hard", "Coded"])` | `accessibility_hardcoded_string` |
| 8 | 16 | `.accessibilityHint("x")` | `accessibility_hardcoded_string` |

### Negatives — all 9 silent for all four rules

| # | Probe line | Construct | Why it must stay legal | Fired |
|---|---|---|---|---|
| 1 | 4 | `@Environment(\.dynamicTypeSize) private var dynamicTypeSize` | the read form is the prescribed replacement (D-17) | — |
| 2 | 17 | `dynamicTypeSize.isAccessibilitySize` | property read, no `(` (D-17) | — |
| 3 | 18 | `dynamicTypeSize >= .accessibility1` | comparison, no `(` (D-17) | — |
| 4 | 19 | `.font(.system(size: reloadSymbolSize))` | `@ScaledMetric`-fed, scales correctly (D-18) | — |
| 5 | 20 | `.font(.system(.body))` | text style | — |
| 6 | 21 | `.accessibilityLabel(.someKey)` | generated `LocalizedStringResource` (D-30) | — |
| 7 | 22 | `.accessibilityLabel(title)` | symbolic argument | — |
| 8 | 23 | `.accessibilityInputLabels([String(localized: .someKey)])` | the `StringProtocol` overload the catalog requires | — |
| 9 | 24 | `.accessibilityInputLabels([.keyA, .keyB])` | key array | — |

The only other diagnostic the probe produced was a pre-existing `colon` warning on line 13, caused by the deliberately un-spaced `size:16.5` in that positive — an artifact of the probe, not one of the four rules. The probe file was written under the session scratchpad, never inside the repository, and was deleted after the run.

## Deferred Rule

`no_minimum_scale_factor` (regex `\.minimumScaleFactor\s*\(`) is **not** in `.swiftlint.yml`. It flags five live sites today; the plugin runs at error severity, so landing it now would break every module's build. It is sequenced into **plan 16-12**, to be committed with or after the owner's five round-1 removals (D-14, D-16, D-23).

## Task Commits

1. **Task 1: Add the three zero-violation D-16 rules and the D-30 guard** — folded into the Task 2 commit, per the plan's explicit "commit `.swiftlint.yml` alone" instruction and its success criterion "One commit touching only `.swiftlint.yml`".
2. **Task 2: Prove the rules under the build-tool plugin and commit** — `bca50938` (feat)

**Plan metadata:** see the `docs(16-01)` commit that follows this summary.

## Files Created/Modified

- `.swiftlint.yml` — four new `custom_rules` entries: `accessibility_hardcoded_string` (line 49), `no_dynamic_type_size_modifier` (line 182), `no_fixed_system_font_size` (line 197), `no_geometry_reader` (line 211).

## Decisions Made

- **One commit, not two.** Task 1 and Task 2 touch the same single file, and the plan's success criteria demand exactly one commit touching only `.swiftlint.yml`. Task 1's work is fully verified (probe table above, strict full-tree lint) and its result is carried in `bca50938`.
- **Message wording kept in the house voice and each rule names the decision it enforces** — Phase 10 D-02 for the modifier rule, Phase 5 for GeometryReader, Phase 16 D-18 for the font rule, Phase 16 D-30 for the guard — plus the prescribed fix in each message.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's SwiftLint binary glob is one directory level short**
- **Found during:** Task 1
- **Issue:** The plan (and PATTERNS/RESEARCH) give the binary path as `…/swiftlintplugins/*/macos/swiftlint`. The real layout has an extra level: `…/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`. The glob matched nothing, so the probe and the acceptance-criteria lint could not run.
- **Fix:** Resolved with the full path `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`, newest-first (`ls -dt … | head -1`). Confirmed `swiftlint version` prints `0.65.0`, the version the regexes were validated against. Three `EhPanda-*` DerivedData directories exist; all three carry the same artifact bundle.
- **Files modified:** none (command-line only)
- **Verification:** `swiftlint version` → `0.65.0`; baseline lint over the five source roots before the edit → `Found 0 violations, 0 serious in 555 files`.
- **Committed in:** n/a (no file change)

**2. [Rule 1 - Bug] Blank-line spacing after the first YAML insertion**
- **Found during:** Task 1
- **Issue:** The initial insertion put the new rules flush against the preceding `severity: error` and left a doubled blank line after, breaking the one-blank-line-between-rules convention the rest of the block follows.
- **Fix:** Normalised to exactly one blank line before and after each inserted rule; asserted no `\n\n\n` remains in the file.
- **Files modified:** `.swiftlint.yml`
- **Verification:** re-read of lines 45-50, 61-64, 180-184, 220-226; full-tree strict lint still 0 violations.
- **Committed in:** `bca50938`

**3. [Rule 1 - Bug] `requirements mark-complete` marked the phase's two requirements Complete after plan 1 of 26**
- **Found during:** state updates
- **Issue:** The workflow's `requirements.mark-complete` step takes the plan's `requirements` frontmatter (`[A11Y-01, A11Y-02]`) and checks both off. But A11Y-01 and A11Y-02 are *phase-wide* requirements — A11Y-01 closes on an owner-signed simulator sweep and five `minimumScaleFactor` removals, A11Y-02 on a VoiceOver/Voice Control walkthrough and the Nutrition Label recommendation. Every one of the 26 plans in this phase carries the same two IDs. Checking them off now records a completion that has not happened.
- **Fix:** Reverted `.planning/REQUIREMENTS.md` to `- [ ]` and `Pending` for both IDs. The real completion signal for this phase is the ROADMAP progress row (`roadmap update-plan-progress 16` → 1/26 summaries, status `In Progress`), which was left as written.
- **Files modified:** `.planning/REQUIREMENTS.md` (net zero change vs. HEAD)
- **Verification:** `git diff --stat .planning/REQUIREMENTS.md` → empty.

**4. [Rule 1 - Bug] `state update-progress` rewrote the STATE body bar with a plan-based formula under a phase-based label**
- **Found during:** state updates
- **Issue:** The writer replaced `Progress: [████████░░] 82% (14/17 phases)` with `91%` — 248/274 *plans* — while keeping the `(14/17 phases)` label and leaving frontmatter `percent: 76` and `completed_phases: 13` untouched. Three mutually inconsistent numbers. The same pass also left `Status: Ready to execute` and emitted a literal `[Phase ?]` placeholder on both new decision lines. This is the known gsd-tools under-sync class.
- **Fix:** Hand-corrected the body bar back to the phase-based `82% (14/17 phases)`, set `Status: Executing Phase 16`, replaced `[Phase ?]` with `[Phase 16]` on both decisions, and rewrote `last_activity_desc` / `Last activity` to name what actually landed instead of "execution started".
- **Files modified:** `.planning/STATE.md`
- **Verification:** re-read of the Progress / Status / Decisions lines.

---

**Total deviations:** 4 auto-fixed (1 × Rule 3 blocking, 3 × Rule 1 bug)
**Impact on plan:** None on scope. Deviations 1-2 were mechanical corrections needed to execute the plan as written. No rule was weakened, suppressed, or disabled; no `swiftlint:disable` was added anywhere.

## Issues Encountered

- **Acceptance criterion "`git status --porcelain` shows only `.swiftlint.yml` modified" reads as two extra files.** `.planning/STATE.md` and `.planning/config.json` were already modified when this executor started — the orchestrator writes them when phase execution begins. They were not staged into the task commit (files were staged individually, never `git add .`), and they are carried by the plan-metadata commit instead. No source file other than `.swiftlint.yml` was touched.
- **`-testPlan FeatureTests` is valid here.** The project build notes warn that `-testPlan FeatureTests` is invalid on this machine; that warning applies to the `AppPackage-Package` scheme. The `EhPanda` scheme declares `container:AppPackage/Tests/FeatureTests.xctestplan` as its default test plan, so the plan's command ran unchanged.
- **The `build-for-testing` log carries `appintentsmetadataprocessor … No AppIntents.framework dependency found` warnings.** Pre-existing and unrelated to this plan (out of scope per the scope boundary); zero `error:` lines and zero SwiftLint violations in either build log.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- The four rules are live and self-enforcing: any Dynamic Type cap, any `GeometryReader`, any numeric-literal `.system(size:)`, and any hardcoded accessibility string introduced by the rest of Phase 16 fails the build immediately.
- **Blocker for 16-12:** `no_minimum_scale_factor` cannot land until the owner's five `.minimumScaleFactor` removals are in the tree. Plan 16-12 must add the rule in the same commit as, or after, those removals.
- Round-2 plans that add accessibility labels must route every string through a generated `LocalizedStringResource` key or through the `[String(localized: .key)]` form for `accessibilityInputLabels`; the literal form is now mechanically impossible.

## Self-Check: PASSED

- `.swiftlint.yml` exists and contains all four rule keys at lines 49 / 182 / 197 / 211, in the required file order.
- `grep -c "no_minimum_scale_factor" .swiftlint.yml` → `0`.
- Commit `bca50938` exists on `feature/gsd-phase-16`, subject 48 characters, `git show --stat` lists only `.swiftlint.yml` (1 file changed, 55 insertions, 0 deletions).
- `.planning/phases/16-dynamic-type-accessibility/16-01-SUMMARY.md` exists.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-08-23*
