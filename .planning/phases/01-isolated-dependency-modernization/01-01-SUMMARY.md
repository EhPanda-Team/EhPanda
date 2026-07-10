---
phase: 01-isolated-dependency-modernization
plan: 01
subsystem: testing
tags: [swift-testing, swiftyopencc, uiimagecolors, opencc, parity, wave-0, xcodebuild]

# Dependency graph
requires: []
provides:
  - SwiftyOpenCCTests target locking default/HK/TW ChineseConverter output and the chtConverted app seam
  - UIImageColorsTests target locking deterministic getColors(quality:.lowest) RGBA output
  - FileClient parity fixtures proving OpenCC conversion applies only for .traditionalChinese
  - Confirmed, executable simulator destination and corrected AppPackage-Package test command
affects: [01-03, 01-04, isolated-dependency-modernization]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Wave 0 golden-master parity fixtures freeze current dependency output before a local swap"
    - "Neutral-gray solid image fixtures make UIImageColors output deterministic across device gamut/byte-order"
    - "Explicit ChineseConverter.Options in tests decouple HK/TW parity from machine locale"

key-files:
  created:
    - AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift
    - AppPackage/Tests/SwiftyOpenCCTests/.swiftlint.yml
    - AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift
    - AppPackage/Tests/UIImageColorsTests/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
    - AppPackage/Tests/FileClientTests/FileClientTests.swift
    - .planning/phases/01-isolated-dependency-modernization/01-VALIDATION.md

key-decisions:
  - "Removed the invalid `-testPlan FeatureTests` flag from AppPackage-Package commands; that plan is bound to the app's EhPanda scheme, and the package scheme already runs all test targets."
  - "Locked chtConverted/FileClient conversions on locale-invariant inputs (`简体`→`簡體`, `full color`→`全彩`) and tested HK/TW variance via explicit converter options, so parity holds on any machine locale."
  - "Used neutral-gray solid images for UIImageColors so expected RGBA tuples are stable across sRGB/P3 and channel packing."

patterns-established:
  - "Parity/characterization fixtures: capture current external-dependency output as the baseline for later app-owned modules."
  - "New AppPackage test targets register Module case + .testTarget + parent-linked .swiftlint.yml + xctestplan entry together with real source."

requirements-completed: [DEP-01, DEP-02]

coverage:
  - id: D1
    description: "DEP-01 conversion parity: default s2t, HK s2hk, TW s2twp idiom, and chtConverted custom `full color`→`全彩`"
    requirement: DEP-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift (4 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "DEP-01 app-boundary parity: FileClient applies OpenCC conversion only for .traditionalChinese, raw otherwise"
    requirement: DEP-01
    verification:
      - kind: integration
        ref: "AppPackage/Tests/FileClientTests/FileClientTests.swift#traditionalChineseAppliesOpenCCConversionAndCustomFullColor, #nonTraditionalChineseLeavesTagValuesUnconverted"
        status: pass
    human_judgment: false
  - id: D3
    description: "DEP-02 color parity: deterministic getColors(quality:.lowest) background + light/dark text fallback RGBA tuples"
    requirement: DEP-02
    verification:
      - kind: unit
        ref: "AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift (2 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Confirmed iPhone Air iOS 26.5 simulator destination recorded with concrete id-based syntax"
    verification:
      - kind: other
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -showdestinations"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 01: Wave 0 Conversion & Color Parity Lock Summary

**Fixture-based Swift Testing targets that freeze current SwiftyOpenCC (default/HK/TW + `full color`) and UIImageColors (`getColors(quality:.lowest)` RGBA) behavior before any DEP-01/DEP-02 dependency swap, plus a confirmed, executable iPhone Air iOS 26.5 simulator destination.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-10T02:11:29Z
- **Completed:** 2026-07-10T02:19:26Z
- **Tasks:** 2
- **Files modified:** 8 (4 created, 4 modified)

## Accomplishments
- Confirmed the exact simulator destination `platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355` (iPhone Air, iOS 26.5) is present via `xcodebuild -showdestinations` and recorded the concrete id-based syntax.
- Added `SwiftyOpenCCTests` locking default (`s2t`), Hong Kong (`s2hk`), and Taiwan idiom (`s2twp`) `ChineseConverter` output plus the `chtConverted` app seam (`full color`→`全彩`).
- Added `UIImageColorsTests` locking deterministic `getColors(quality:.lowest)` background and light/dark text-fallback RGBA tuples.
- Added `FileClient` fixtures proving OpenCC conversion is applied only for `.traditionalChinese` and left raw for every other language.
- Registered both test targets (Module case + `.testTarget` + parent-linked `.swiftlint.yml` + `FeatureTests.xctestplan` entry) and ran all 14 targeted tests green on the confirmed simulator.

## Task Commits

Each task was committed atomically:

1. **Task 1: Record the concrete simulator destination** - `2fbf2c84` (docs)
2. **Task 2: Fixture-lock conversion and color behavior** - `a75f9346` (test)

**Plan metadata:** see final `docs(01-01)` commit.

## Files Created/Modified
- `AppPackage/Tests/SwiftyOpenCCTests/ChineseConverterParityTests.swift` - DEP-01 default/HK/TW + `chtConverted` parity (4 tests)
- `AppPackage/Tests/SwiftyOpenCCTests/.swiftlint.yml` - parent-linked lint config
- `AppPackage/Tests/UIImageColorsTests/UIImageColorsParityTests.swift` - DEP-02 deterministic color parity (2 tests)
- `AppPackage/Tests/UIImageColorsTests/.swiftlint.yml` - parent-linked lint config
- `AppPackage/Package.swift` - two new `Module` cases and `.testTarget` declarations
- `AppPackage/Tests/FeatureTests.xctestplan` - `SwiftyOpenCCTests` and `UIImageColorsTests` entries
- `AppPackage/Tests/FileClientTests/FileClientTests.swift` - 2 traditional-vs-non-traditional conversion fixtures + helpers
- `.planning/phases/01-isolated-dependency-modernization/01-VALIDATION.md` - confirmed destination, corrected commands, Wave 0 status

## Decisions Made
- **Locale-robust conversion fixtures:** `chtConverted` reads `Locale.preferredLanguages`, so HK/TW parity is tested through explicit `ChineseConverter.Options` (deterministic), while the app-seam assertions use locale-invariant inputs (`简体`→`簡體`, `full color`→`全彩`). This locks all four required cases (default/HK/TW/custom) without depending on the runner's locale.
- **Neutral-gray color fixtures:** solid gray images collapse to a single counted color, so the algorithm returns the dominant color as background and falls back to black (light bg) / white (dark bg) accents; grays are symmetric across channel order and identical on the sRGB/P3 neutral axis, making the expected tuples device-stable. Background asserted within ±2 to absorb sub-pixel color-space rounding; fallback endpoints (0 / 255) asserted exactly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected the documented test command (`-testPlan FeatureTests` invalid on AppPackage-Package)**
- **Found during:** Task 2 (running the plan's verify command)
- **Issue:** The plan's/validation's verify command `xcodebuild ... -scheme AppPackage-Package -testPlan FeatureTests ... test` fails with `Scheme "AppPackage-Package" does not have an associated test plan named "FeatureTests"`. The `FeatureTests.xctestplan` is bound to the app's shared `EhPanda` scheme (`EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme`), not the auto-generated SwiftPM `AppPackage-Package` scheme.
- **Fix:** Removed the `-testPlan FeatureTests` flag from every `AppPackage-Package` command in `01-VALIDATION.md`. That scheme already includes all package test targets by default, and `-only-testing:` selects the specific ones. The `.xctestplan` is kept in sync (new targets added) since it still drives the `EhPanda` scheme.
- **Files modified:** `.planning/phases/01-isolated-dependency-modernization/01-VALIDATION.md`
- **Verification:** `xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:SwiftyOpenCCTests -only-testing:UIImageColorsTests -only-testing:FileClientTests` → EXIT 0, 14 tests passed.
- **Committed in:** `a75f9346` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The correction makes the validation contract executable and unblocks every later plan in the phase (all embed the same command shape). No scope creep — no production dependency changed, and the same simulator/target coverage is preserved. Later plans (01-02..01-07) still embed `-testPlan FeatureTests` in their own verify commands and should apply the same correction (drop the flag on `AppPackage-Package`, or run the `EhPanda` scheme).

## Issues Encountered
- Initial verify run failed on the `-testPlan` flag (see Deviation 1). Re-run without the flag passed cleanly. No `testmanagerd` wedge — a single invocation was used and allowed to finish.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DEP-01 and DEP-02 baselines are locked; plans 01-03 (local SwiftyOpenCC) and 01-04 (local UIImageColors) can now be proven against these fixtures.
- No production dependency was swapped in this plan.
- Phase-wide `wave_0_complete` stays `false` in `01-VALIDATION.md`: the remaining Wave 0 references (MarkdownExtTests, TagTranslationFeatureTests, DFRequestSemanticsTests) belong to plan 01-02.
- Note for later executors: apply the same `-testPlan` command correction documented above.

## Self-Check: PASSED

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-10*
