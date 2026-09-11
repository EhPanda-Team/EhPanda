---
phase: 16-dynamic-type-accessibility
plan: 14
subsystem: accessibility
tags: [contrast, wcag, color-resolved, relative-luminance, colorset, sha256, invariant-test, swift-testing, d-26, d-27]

# Dependency graph
requires:
  - phase: 16-12
    provides: Round 2 unblocked under D-23; the five D-16 lint rules live at error severity (the new files had to pass them)
  - phase: 16-13
    provides: "`16-CONTRAST-AUDIT.md § Category variants` — the live-JSON totals this plan's invariant test reproduces (84 variants, worst best-of 4.62 ExHentai / Game CG / light, 47 flips, crossover L 0.17913)"
provides:
  - "`AppTools/Extensions/Color+Contrast.swift`: `Color.Resolved.relativeLuminance` (linear fields), `Color.Resolved.composited(over:opacity:)` (linear source-over), `Color.contrastRatio(_:_:)`, and the better-of rule `Color.contrastingForeground(forRelativeLuminance:)` / `contrastingForeground(on:)` / `contrastingForeground(in:)` with the crossover `0.1791` and strict `>` (structural floor 4.58:1)"
  - "`ColorContrastTests` (8 functions / 17 cases): black/white, the Double-level tie and one ulp above, the resolved neighbours 0.1790 / 0.1792, the worst real variant (4.62 / 4.55 → black), symmetry, compositing at 0.3 / 1 / 0, static-vs-instance agreement"
  - "`CategoryColorsetInvariantTests` (8 functions / 13 cases): the 22-colorset / 84-variant repository walk, three-encoding normaliser, 84/84 ≥ 4.5 best-of, worst 4.62 ± 0.01 named, 47 black flips, and two SHA-256 pins — 44 standard variants `f940492a…5363`, 40 `contrast: high` variants `e81b0604…0937`"
affects: [16-15, 16-23, accessibility-round-2, any future edit of App/Assets.xcassets/Category/Colors]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 6918
  tasks: 2
  commits: 2
  plan_head_before: 5e71ea539d8055aa1a7fcbd05be1193a81fd29e8

tech-stack:
  added: []
  patterns:
    - "Contrast maths lives on `Color.Resolved`'s linear fields in `AppTools`; views resolve through `EnvironmentValues` and ask the helper, never compute luminance themselves"
    - "A colour rule whose boundary is a property of a scalar is exposed on that scalar (`forRelativeLuminance:`) so the boundary is exactly testable; the colour-taking overloads route through it"
    - "Repository-walk invariant with equality pins (counts, named worst case, two SHA-256 digests over a canonical serialization) and a known-member guard; the mutation check is part of the evidence"

key-files:
  created:
    - AppPackage/Sources/AppTools/Extensions/Color+Contrast.swift
    - AppPackage/Tests/AppToolsTests/ColorContrastTests.swift
    - AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift
  modified: []

key-decisions:
  - "Orchestrator-selected option A for the Float/Double conflict: the better-of rule is exposed on a `Double` (`contrastingForeground(forRelativeLuminance:)`) and `contrastingForeground(on:)` delegates to it; the tie is pinned there (0.1791 → white, `0.1791.nextUp` → black) because `Color.Resolved` stores `Float` channels and `Float(0.1791)` rounds up by 6.8e-9, so the exact crossover is unrepresentable through a resolved colour."
  - "`contrastRatio` uses `max`/`min` rather than the plan's `(hi, lo)` ternary tuple: the ternary's `: (…)` line trips the `labeled_tuple_elements` regex and `a`/`b` fail `identifier_name`; public signature unchanged."
  - "The invariant suite lives in `AppToolsTests` (plan's recorded deviation from the PATTERNS target note), routing every luminance and every text-colour choice through the `AppTools` helper so a helper regression fails against the audited table too."
  - "Canonical pin serialization: `<host>/<category>/<appearance>:<r>,<g>,<b>` with six-decimal normalised channels, sorted, `\\n`-joined, SHA-256 — standard (light / dark, 44 lines) and `contrast: high` (`light+HC` / `dark+HC`, 40 lines) hashed separately so D-27 re-authoring re-pins only the HC digest."

patterns-established:
  - "Test the boundary at the layer that owns it: a strict-inequality rule on a scalar is pinned on the scalar with `nextUp`, and the Float-backed path is pinned at ±1e-4 neighbours, never at the unrepresentable tie."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Contrast helper in AppTools: linear-field luminance, linear compositing, contrast ratio, better-of foreground rule (Double / Resolved / environment overloads)"
    requirement: "A11Y-02"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppToolsTests/ColorContrastTests.swift#ColorContrastTests (8 tests / 17 cases)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Category colorset invariant: 22 files / 84 variants parsed with all three encodings, 84/84 ≥ 4.5:1 best-of, worst 4.62 named, 47 flips, standard-44 and HC-40 SHA-256 pins with a recorded mutation check"
    requirement: "A11Y-02"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift#CategoryColorsetInvariantTests (8 tests / 13 cases)"
        status: pass
      - kind: other
        ref: "Mutation check: E-Hentai Manga light red 0.910→0.911 → standardVariantsArePinned fails (digest 7e8a0833…55ed), highContrastVariantsArePinned passes; reverted, `git status --porcelain` shows no colorset"
        status: pass
    human_judgment: false

# Metrics
duration: 43min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 14: Color contrast helper + colorset invariant tests Summary

**WCAG contrast maths on `Color.Resolved`'s linear channels with the better-of black/white rule (crossover L = 0.1791, floor 4.58:1) in `AppTools`, unit-pinned at the tie and the worst real variant, plus a repository-walk test that proves all 84 category variants pass AA and pins the 44 standard backgrounds and the 40 Increase Contrast backgrounds under separate SHA-256 digests.**

## Performance

- **Duration:** 43 min
- **Started:** 2026-09-11T09:28:09Z
- **Completed:** 2026-09-11T10:11:31Z
- **Tasks:** 2 (both `tdd="true"`)
- **Files modified:** 3 created, 0 modified

## Accomplishments

- `Color+Contrast.swift`: `relativeLuminance` reads `linearRed/Green/Blue` (no second decode), `composited(over:opacity:)` blends per linear channel and returns an opaque `.sRGBLinear` colour, `contrastRatio(_:_:)` is order-independent, and the better-of rule is one `Double` comparison (`> 0.1791` → black, else white) that the `Color.Resolved` and `EnvironmentValues` overloads route through. Every member carries a doc comment stating the why (linear fields, crossover derivation √0.0525 − 0.05, why linear compositing, why better-of beats "white unless it fails").
- `ColorContrastTests`: black/white (21:1, symmetric), crossover gray ties at 4.583 against both, worst variant ExHentai Game CG light 4.62 vs black / 4.55 vs white → black, tie exactly at 0.1791 → white and one ulp above → black, resolved neighbours 0.1790 → white / 0.1792 → black, black/white backgrounds, static-vs-instance agreement over five colours, compositing at 0.3 (0.75373) / 1 / 0.
- `CategoryColorsetInvariantTests`: walks `App/Assets.xcassets/Category/Colors/{E-Hentai,ExHentai}`, requires 22 files / 84 variants / 44 standard / 40 HC and two named members, normalises `"0x11"` / `"0.910"` / `"163"` (six fixtures), asserts `srgb` on every entry, proves 84/84 ≥ 4.5 with the variant name in each failure message, pins the worst best-of to `ExHentai / Game CG / light` at 4.62 ± 0.01, counts exactly 47 black choices through `Color.contrastingForeground(on:)`, and checks the two digests — with the actual digest printed in the failure message so a deliberate re-pin is one copy away.

## Helper API

```swift
extension Color.Resolved {
    public var relativeLuminance: Double
    public func composited(over backdrop: Color.Resolved, opacity: Double) -> Color.Resolved
}
extension Color {
    public static func contrastRatio(_ lhs: Color.Resolved, _ rhs: Color.Resolved) -> Double
    public static func contrastingForeground(forRelativeLuminance luminance: Double) -> Color
    public static func contrastingForeground(on background: Color.Resolved) -> Color
    public func contrastingForeground(in environment: EnvironmentValues) -> Color
}
```

## TDD evidence

All runs on the iOS 26.5 iPhone 17e simulator `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, one `xcodebuild` at a time. `gsd_run check tdd-red-evidence` parses node TAP output only and cannot classify `xcodebuild` output, so the records below are kept as manual evidence (JSON copies in the session scratchpad).

**Task 1 RED** — `xcodebuild test … -only-testing:AppToolsTests/ColorContrastTests` → exit 65, `Testing cancelled because the build failed`; 11 compile errors, all `has no member` for `relativeLuminance`, `composited`, `contrastRatio`, `contrastingForeground` (static and instance); no other error.

**Task 1 GREEN (first, blocked)** — helper written per plan → exit 65: 5/7 functions passed; `readsTheLinearChannels(crossover gray)` failed with `|L − 0.1791| = 6.818771325356465e-09 < 1e-9` false, and `choosesTheMoreContrastingForeground(crossover tie)` returned black. Checkpoint raised; orchestrator selected option A (see Deviations).

**Task 1 GREEN (final)** — `✔ Test run with 8 tests in 1 suite passed after 0.015 seconds` (17 cases: `readsTheLinearChannels` 3, `resolvesTheTieToWhite` 2, `choosesTheMoreContrastingForeground` 5, `compositesInLinearSpace` 3, four single-case tests); `** TEST SUCCEEDED ** [33.222 sec]`. Lint build `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'` → `** BUILD SUCCEEDED ** [52.240 sec]`, 0 `Violation:` lines.

**Task 2 RED** — suite with empty placeholder pins → exit 65: six tests passed (walk, six encodings, Cosplay luminance, 84/84, worst, 47 flips); the two pin tests failed and printed the digests computed by the test's own serialization:
- standard (44 lines): `f940492af7648bf41e12a5cca24532c8f7451d79875a75b3534a7b9c0f235363`
- `contrast: high` (40 lines): `e81b0604c84754a0260818465051f11fae99fe756b934db2f16929ea83600937`

Both equal the digests an independent Python reproduction of the serialization produced from the live JSON before the Swift suite existed (22 files / 84 variants / 44 + 40, worst 4.619991 ExHentai Game CG light, 47 flips).

**Task 2 mutation check** — with the pins in place, `E-Hentai/Manga.colorset` light `"red" : "0.910"` → `"0.911"`: `✘ standardVariantsArePinned` (actual digest `7e8a0833b33c05c7f3501e2245b2333b3b8395dce89ce139df2690c7255a55ed`), `✔ highContrastVariantsArePinned`, the six other tests unchanged. Reverted with `git checkout -- <that file>`; `git status --porcelain` afterwards listed only `?? .gsd/` and the not-yet-committed test file — no colorset modified.

**Task 2 GREEN** — `-only-testing:AppToolsTests` → `✔ Test run with 19 tests in 3 suites passed` (`CategoryColorsetInvariantTests`, `ColorContrastTests`, `GalleryURLParserTests`); `** TEST SUCCEEDED ** [47.494 sec]`.

**Full `FeatureTests` plan** — `** TEST SUCCEEDED ** [91.547 sec]`; 1055 tests in 184 suites over 22 targets, 0 failed suites (13 pre-existing `withKnownIssue` expectations in the downloads/background-processing targets, unchanged). Lint build → `** BUILD SUCCEEDED ** [55.704 sec]`, 0 `Violation:` lines.

## Task Commits

1. **Task 1: `Color+Contrast.swift` helper with `ColorContrastTests`** — `bd34e60c` (feat)
2. **Task 2: `CategoryColorsetInvariantTests`** — `d81f0301` (test)

Both tasks followed RED → GREEN; the plan explicitly allowed source and test in one commit per task, so each task is one commit (no separate RED commit of a non-compiling test file was made). No REFACTOR commit was needed.

## Files Created/Modified

- `AppPackage/Sources/AppTools/Extensions/Color+Contrast.swift` — the helper (API above), doc-commented WHYs.
- `AppPackage/Tests/AppToolsTests/ColorContrastTests.swift` — parameterised `CustomTestStringConvertible` fixtures per the `GalleryURLParserTests` shape.
- `AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift` — repository walk (helpers copied from `DownloadLogPrivacyInvariantTests`), Codable colorset model, normaliser, contrast and pin tests.

## Decisions Made

See `key-decisions` in the frontmatter. In addition: the plan's `must_haves` truth "at exactly L = 0.1791 the helper resolves to white" and "0.1791 ± 1e-9" are satisfied at the `Double` level (`forRelativeLuminance:` and `Double(Float(0.1791))` respectively) rather than through a `Color.Resolved`; the plan's `provides` list for `Color+Contrast.swift` gains `contrastingForeground(forRelativeLuminance:)`. `16-14-PLAN.md` was not edited, per the orchestrator's instruction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Float storage of `Color.Resolved` vs the plan's tie and 1e-9 fixtures — orchestrator-selected option A**
- **Found during:** Task 1 (GREEN run)
- **Issue:** `Color.Resolved` stores channels as `Float`; `Float(0.1791) = 0.17910000681877136` (+6.8e-9). The plan's "linear 0.1791 gray → luminance 0.1791 ± 1e-9" cannot pass through a resolved colour, and its tie fixture `Color(.sRGBLinear, red: 0.1791, …) → .white` resolves to black under the plan's own strict `>` against a `Double` 0.1791. Execution paused at a `checkpoint:decision`; the orchestrator selected option A.
- **Fix:** Added `public static func contrastingForeground(forRelativeLuminance:) -> Color` (the rule on its natural scalar, doc-commented as the seam where the tie is exactly testable); `contrastingForeground(on:)` delegates to it. Tests: tie pinned at the Double level (0.1791 → white, `0.1791.nextUp` → black); resolved-colour neighbours 0.1790 / 0.1792 kept; the linear-read case compares against `Double(Float(0.1791))` within 1e-9 with a comment that a double decode would give ≈ 0.027, so it still refutes that bug. Every other fixture verbatim.
- **Files modified:** `Color+Contrast.swift`, `ColorContrastTests.swift`
- **Verification:** Task 1 GREEN run 8/8 functions (17 cases), lint build clean.
- **Committed in:** `bd34e60c`

**2. [Rule 3 - Blocking] Lint violations in the plan's suggested `contrastRatio` body**
- **Found during:** Task 1 (first GREEN build)
- **Issue:** `let (hi, lo) = … ? (a.…, b.…) : (b.…, a.…)` fails `labeled_tuple_elements` (the ternary's `: (` reads as a type position to the regex) and `identifier_name` errors on `a`/`b` (warnings on `hi`/`lo`).
- **Fix:** `max`/`min` over the two luminances; parameters `lhs`/`rhs` (external labels stay `_ _`, so the planned signature is unchanged). Pre-authorised by the quality bar ("resolve every lint violation at its root").
- **Files modified:** `Color+Contrast.swift`
- **Verification:** scheme build 0 violations.
- **Committed in:** `bd34e60c`

**3. [Rule 3 - Blocking] Access level and nesting in the invariant suite**
- **Found during:** Task 2 (first RED build)
- **Issue:** helpers in a `private extension` are implicitly `fileprivate` and cannot take or return the suite's `private` nested types; a `CodingKeys` enum inside a nested Codable model tripped the `nesting` rule (two levels deep). A missing `import CustomDump` also surfaced.
- **Fix:** Codable JSON models moved to file scope as `private` types; the five type-bound helpers declared `private static`; `CustomDump` imported in sorted position.
- **Files modified:** `CategoryColorsetInvariantTests.swift`
- **Verification:** RED run compiled and failed only on the two placeholder pins; lint build 0 violations.
- **Committed in:** `d81f0301`

### Environment deviations (pre-authorised by the orchestrator)

- **Simulator:** the plan's `88B217DA-A166-4BAD-820D-DE13B1C4EB54` no longer exists; every `xcodebuild test` ran on the iOS 26.5 iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, which already held plan 16-13's EhPanda build and downloaded gallery — nothing was deleted or erased. The simulator is **left booted**.
- **Test target:** the invariant suite lives in `AppToolsTests` (recorded in the plan's action; the PATTERNS target note said `AppModelsTests`).
- **RED evidence checker:** `gsd_run check tdd-red-evidence` is TAP-only and not applicable to `xcodebuild`; evidence recorded manually above.

---

**Total deviations:** 3 auto-fixed (1 orchestrator-decided numerics conflict, 2 lint/compile root fixes) + 3 pre-authorised environment deviations.
**Impact on plan:** The helper's planned API is a superset (one extra `Double` entry point); every planned truth is met, two of them at the `Double` level instead of through a `Color.Resolved`. No colour moved; no lint rule suppressed.

## Issues Encountered

- `xcodebuild test` after touching an `AppTools` source recompiles every dependent module (~10 min) versus ~35–50 s for a test-only change; runs were backgrounded and polled rather than overlapped.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-05 (background bytes) is mitigated by the standard-44 pin with a recorded mutation check; T-16-15 (gamma-channel maths) by the linear-field helper pinned at the crossover and the worst variant, with the invariant suite routed through it; T-16-03 by running only on `67377A20…`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 16-15 can make `CategoryLabel` / `CategoryCell` adaptive by calling `color.contrastingForeground(in: environment)` (with `@Environment(\.self)`), and for the excluded `CategoryCell` state choose against `resolved.composited(over: sheetBackground, opacity: 0.3)`.
- If the owner chooses HC re-authoring under D-27, only `highContrastPin` in `CategoryColorsetInvariantTests` is re-derived (the failure message prints the new digest); `standardPin` must never change.
- `A11Y-02` stays open (shared with the remaining round-2 plans); nothing pushed.

---
*Phase: 16-dynamic-type-accessibility*
*Completed: 2026-09-11*

## Self-Check: PASSED
