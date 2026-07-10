---
phase: 01-isolated-dependency-modernization
plan: 08
subsystem: ui
tags: [colorfulx, colorful, swiftpm, gradient, homefeature, metal, dependency-migration, gap-closure]

# Dependency graph
requires:
  - phase: 01-isolated-dependency-modernization (plan 01-07)
    provides: DEP-07 Colorful 1.1.1 pin + documented ColorfulView deprecation blocker
provides:
  - Colorful removed; Home gallery-card gradient migrated to ColorfulX 6.1.0 (Metal)
  - DEP-07 deprecation blocker resolved via option (a); HomeFeature builds warning-free
  - Acknowledgements credit ColorfulX with the corrected Lakr233/ColorfulX link (all locales)
  - 01-COLORFUL-UAT.md refreshed for ColorfulX; deferred ColorfulView-deprecation item marked resolved
affects: [gsd-verify-work, HomeFeature, SettingFeature acknowledgements]

# Tech tracking
tech-stack:
  added:
    - ColorfulX 6.1.0 (Lakr233/ColorfulX, exact pin)
    - "transitive: MSDisplayLink 2.1.0, SpringInterpolation 1.4.0, ColorVector 1.0.5"
  removed:
    - Colorful 1.1.1 (Lakr233/Colorful)
  patterns: [exact-pin supply-chain hardening for the successor package; adopt upstream-recommended replacement rather than suppressing a deprecation]

key-files:
  created:
    - .planning/phases/01-isolated-dependency-modernization/01-08-PLAN.md
    - .planning/phases/01-isolated-dependency-modernization/01-08-SUMMARY.md
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings
    - .planning/phases/01-isolated-dependency-modernization/01-COLORFUL-UAT.md
    - .planning/phases/01-isolated-dependency-modernization/deferred-items.md

key-decisions:
  - "Migrated the gallery gradient to ColorfulX 6.1.0 (upstream-recommended Metal successor), removing Colorful entirely — closes the 01-07 ColorfulView deprecation blocker via option (a)."
  - "Mapped Colorful's `animated: Bool` onto ColorfulX's `speed` binding: `speed: animated ? animationSpeed : 0` (0 freezes), so only the focused dark-mode card animates — behavior parity."
  - "Kept the migration inline in GalleryCardCell (no wrapper view) per the user's decision; init signature, both call sites, and the HomeReducer/LibraryClient color flow are untouched."
  - "Corrected the stale acknowledgement link (Co2333/Colorful → Lakr233/ColorfulX) and display text (Colorful → ColorfulX) across all six locales, honoring the AGENTS.md non-translated-key rule."

patterns-established:
  - "When upstream deprecates a whole package pointing at a named successor, adopt the successor and delete the old package rather than suppressing the warning; map the old API's flags onto the successor's parameters (here animated→speed)."

requirements-completed: [DEP-07]

coverage:
  - id: D1
    description: "Colorful removed and ColorfulX 6.1.0 adopted with a verified exact pin in both Package.resolved files (blocker option a)."
    requirement: "DEP-07"
    verification:
      - kind: integration
        ref: "xcodebuild AppPackage-Package build (id ADE09605-...) — BUILD SUCCEEDED [24.285s], 0 warnings/errors"
        status: pass
      - kind: other
        ref: "Package.resolved colorfulx revision bdf19698a9fdd3d2cd3ade4a9434d443b4313b36 == tag 6.1.0 commit; no unrelated pins moved (only ColorfulX + its transitive deps added, Colorful removed)"
        status: pass
    human_judgment: false
  - id: D2
    description: "GalleryCardCell renders the animated gradient + gray fallback through ColorfulX with no deprecation warning; only the focused dark-mode card animates; identity reset preserved."
    requirement: "DEP-07"
    verification:
      - kind: integration
        ref: "clean build — no 'ColorfulView is deprecated' / 'hurts CPU' warning; HomeFeature compiles; SwiftLint plugin ran clean"
        status: pass
    human_judgment: true
    rationale: "Subjective animated-gradient visual parity (Metal look, animationSpeed/bias tuning, dark-mode animation vs light-mode static) cannot be proven by automated tests (D-18/D-19); reserved for user UAT in 01-COLORFUL-UAT.md."
  - id: D3
    description: "Full AppPackage test suite passes after the migration."
    requirement: "DEP-07"
    verification:
      - kind: integration
        ref: "xcodebuild AppPackage-Package test (id ADE09605-...) — TEST SUCCEEDED [43.374s]; 431 tests / 88 suites / 11 targets, 0 failures"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-07-10
status: complete
---

# Phase 01 Plan 08: Colorful → ColorfulX Migration (DEP-07 blocker closure) Summary

**The Home gallery-card gradient now renders through ColorfulX 6.1.0 (Metal); Colorful is
removed, the `ColorfulView` deprecation warning is gone (not suppressed — the package is
gone), acknowledgements credit ColorfulX, and the full suite is green. This closes the 01-07
DEP-07 blocker via option (a).**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-07-10
- **Tasks:** 4 (landed in 3 code/doc commits + 1 plan commit)
- **Files modified:** 5 modified, 2 created (plan + summary)

## Accomplishments
- Replaced the deprecated `Lakr233/Colorful` (exact 1.1.1) with `Lakr233/ColorfulX` (exact
  `6.1.0`); regenerated both `Package.resolved` files (pin revision
  `bdf19698a9fdd3d2cd3ade4a9434d443b4313b36` == the 6.1.0 tag commit). ColorfulX's own
  transitive deps (MSDisplayLink 2.1.0, SpringInterpolation 1.4.0, ColorVector 1.0.5) are the
  only added pins; no unrelated pins moved.
- Migrated `GalleryCardCell` to ColorfulX's `ColorfulView(color:speed:)`: mapped the former
  `animated: Bool` onto `speed: .constant(animated ? animationSpeed : 0)` (0 freezes the Metal
  animation), so only the focused dark-mode card animates. Preserved the gray fallback, the
  `.id(currentID + animated.description)` identity reset, the init signature, both call sites,
  and the `HomeReducer.rawCardColors`/`cardColors` + `LibraryClient.analyzeImageColors` flow.
  The preview's `ColorfulView.defaultColorList` became `ColorfulPreset.aurora.colors.map { Color($0) }`.
- Documented the deliberate speed↔animated mapping inline (why the design is intentional).
- Confirmed a warning-free build: the two 01-07 deprecation warnings (`GalleryCardCell.swift:45`,
  `:72`) are gone, and SwiftLint ran clean across all modules.
- Updated the acknowledgements: `acknowledgement.colorful` → "ColorfulX" and
  `acknowledgement.colorful_link` → `https://github.com/Lakr233/ColorfulX` (also fixing the
  pre-existing stale `Co2333/Colorful` link), filled into all six supported locales per the
  AGENTS.md non-translated-key rule; `AboutView` symbols unchanged.
- Refreshed `01-COLORFUL-UAT.md` for ColorfulX (Metal continuous animation via `speed`, `speed = 0`
  static fallback, tunable `animationSpeed`/`bias`) and recorded the resolved option-(a) decision;
  marked the deferred ColorfulView-deprecation item resolved.

## Task Commits

1. **Plan doc** - `3177250a` (docs): 01-08-PLAN.md
2. **Tasks 1+2: package swap + view migration** - `673252b6` (feat): landed together to keep the
   commit buildable (removing Colorful breaks `GalleryCardCell` until the view is migrated).
3. **Task 3: acknowledgements** - `280ff274` (chore)
4. **Task 4: UAT + deferred + summary + STATE** - final docs commit (this summary).

## Files Created/Modified
- `AppPackage/Package.swift` - Colorful dependency + `colorful` helper replaced with ColorfulX / `colorfulX`; `.targetDependency` updated in appFeature + homeFeature; comment updated.
- `AppPackage/Package.resolved` & the xcodeproj workspace mirror - ColorfulX pin + transitive deps; Colorful removed.
- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` - migrated to ColorfulX API; `animationSpeed` constant + doc comment; preview uses a ColorfulPreset.
- `AppPackage/Sources/SettingFeature/Resources/Constant.xcstrings` - ColorfulX credit + corrected link, all locales.
- `01-COLORFUL-UAT.md` - ColorfulX-specific checks + resolved decision.
- `deferred-items.md` - ColorfulView-deprecation item marked resolved.

## Decisions Made
- **Adopt the successor, don't suppress:** the deprecation pointed at ColorfulX, so migrating there (option a) removes the deprecated API entirely — the honest fix over `@available` suppression or a warning workaround.
- **animated → speed:** ColorfulX has no on/off flag; `speed = 0` freezes the Metal animation. Driving `speed` off the existing `animated` predicate reproduces "only the focused dark-mode card animates" with no state changes elsewhere.
- **Inline, not wrapped:** per the user's structure decision, the ColorfulX view stays inline in `GalleryCardCell` — the smallest change faithful to the current design.

## Deviations from Plan
- **Tasks 1 and 2 committed together (build integrity).** The plan lists the package swap and the
  view migration as separate tasks, but a package-only commit would not build (`GalleryCardCell`
  still `import`s the removed Colorful). To honor the clean-build-per-commit gate, both landed in
  `673252b6`. No scope change.
- **Test command corrected.** The plan's Task 4 verify copied `-testPlan FeatureTests` from 01-07,
  but per the 01-01 decision that test plan is bound to the **EhPanda app scheme**, not
  `AppPackage-Package` (which runs all test targets without it). Ran
  `xcodebuild -scheme AppPackage-Package … test` (no `-testPlan`) → TEST SUCCEEDED.
- **Simulator pinned by id.** Two "iPhone Air" simulators exist on this machine, so builds/tests
  used `id=ADE09605-A44E-4F00-BE12-235970217355` (the booted one) instead of the ambiguous
  `name=iPhone Air` written in the plan.

## Issues Encountered
- First test run failed fast with "Scheme AppPackage-Package does not have an associated test plan
  named FeatureTests" — root-caused to the copied `-testPlan` flag (see Deviations) and re-run
  correctly.

## Threat Flags
None. The one trust boundary touched (SwiftPM resolver, T-01-08-01) was mitigated: official
Lakr233/ColorfulX remote, exact `6.1.0` pin, verified `Package.resolved` revision against the tag
commit, both lockfiles updated. ColorfulX is the upstream-recommended, CPU-cheaper Metal successor
(T-01-08-02).

## User Setup Required
None. A user **visual verification** step remains (not setup): follow `01-COLORFUL-UAT.md` during
`$gsd-verify-work` to confirm ColorfulX gradient parity (D-19) — dark-mode animation, light-mode
static fallback, and whether `animationSpeed`/`bias` want tuning.

## Next Phase Readiness
- The DEP-07 deprecation blocker is closed; Phase 01 now builds warning-free for the gallery gradient.
- No remaining ColorfulView deferred item. The unrelated 01-05 acknowledgements pass (SwiftCommonMark → swift-markdown) and the DownloadsFeatureTests warning remain open in `deferred-items.md`.

## Self-Check: PASSED

- Files verified on disk: `01-08-PLAN.md`, `01-08-SUMMARY.md`, `01-COLORFUL-UAT.md`, `deferred-items.md`, `GalleryCardCell.swift`, `Package.swift`, both `Package.resolved`, `Constant.xcstrings`.
- Commits verified in git log: `3177250a` (plan), `673252b6` (feat), `280ff274` (chore).
- Gates: clean warning-free build; full suite TEST SUCCEEDED (431 tests, 0 failures).

---
*Phase: 01-isolated-dependency-modernization*
*Completed: 2026-07-10*
