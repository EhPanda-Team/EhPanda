---
phase: 04-concurrency-framework-migration
plan: 14
subsystem: tca-migration
tags: [tca, package-traits, deprecations, swiftui, reducer-composition]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Combine-free typed async request layer
provides:
  - TCA 1.25.3 version floor with both 2.0 deprecation traits enabled
  - Positive-control proof that Xcode applies the traits
  - Zero TCA deprecation warnings across the app build and package test build
  - Modern projected presentation scopes and current Store/Scope signatures
affects: [tca, app-feature, swiftui-presentations, reducer-composition]

tech-stack:
  added: []
  patterns:
    - Projected @Presents scope key paths
    - Unlabeled modern Store.scope state argument
    - Unlabeled modern Scope state and child arguments

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-14-SUMMARY.md
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/HomeFeature
    - AppPackage/Sources/SearchFeature
    - AppPackage/Sources/DetailFeature
    - AppPackage/Sources/DownloadsFeature
    - AppPackage/Sources/SettingFeature

key-decisions:
  - "The owner authorized expanding the D-11 surface from 24 expected sites to all 66 compiler-reported sites across 29 files."
  - "All migrations use the compiler-prescribed TCA 1.26 forms without relocating presentation modifiers or changing reducer behavior."

requirements-completed: [CONC-02]

coverage:
  - id: D1
    description: "Both TCA 2.0 deprecation traits are enabled and proven active"
    requirement: CONC-02
    verification:
      - kind: build
        ref: "Clean AppFeature reconnaissance build with PopularView.swift:36 positive control"
        status: pass
      - kind: other
        ref: "Manifest trait and version-floor grep gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 66 trait-gated deprecations are migrated with presentation and reducer behavior preserved"
    requirement: CONC-02
    verification:
      - kind: build
        ref: "AppFeature generic iOS Simulator build with zero deprecation warnings"
        status: pass
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite"
        status: pass
      - kind: lint
        ref: "SwiftLint over all 29 modified Swift files"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 14: TCA 2.0 Deprecation Migration Summary

**Both TCA 2.0 deprecation traits are pinned and active, and all 66 surfaced deprecations are migrated with zero warnings and a green full test suite.**

## Performance

- **Duration:** 20 min active execution, including the D-11 checkpoint
- **Completed:** 2026-07-13
- **Tasks:** 3
- **Files:** 30

## Accomplishments

- Raised the TCA floor to 1.25.3 and enabled both required 2.0 deprecation traits.
- Proved trait activation through the `PopularView.swift:36` positive-control warning in a clean build.
- Migrated 45 projected presentation scopes, 11 renamed `Store.scope` calls, and 10 modern `Scope` initializers.
- Preserved every sheet, cover, alert, dialog, and toast on its existing presentation anchor.
- Reached zero TCA deprecation warnings in both the app build and the full package test build.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `86c8ed78` | Enable the two TCA deprecation traits and record the positive-control inventory |
| 2 | `9980b69d` | Migrate the seven planned primary projected-scope files |
| 3 | `fe34416a` | Migrate the remaining authorized view and reducer deprecations |

The intermediate D-11 checkpoint record was committed as `824677b0` before the owner authorized the expanded scope.

## Deviations from Plan

### [Owner-approved scope expansion] Migrated the authoritative 66-site compiler inventory

- **Found during:** Task 1 clean reconnaissance build
- **Issue:** The plan expected approximately 24 warnings in one projected-destination pattern across 11 files. The traits produced 66 unique sites across three patterns and 29 files, including reducer composition.
- **Checkpoint:** Execution stopped before fixes as D-11 required, and the categorized inventory was surfaced to the owner.
- **Decision:** The owner explicitly authorized extending Plan 04-14 to all 66 sites.
- **Resolution:** Migrated all 45 projected presentation scopes, 11 renamed Store scopes, and 10 Scope initializers using the compiler-prescribed APIs.
- **Impact:** The additional edits are argument-syntax migrations only. No state, action, reducer logic, presentation anchor, or UI semantics changed.

**Total deviations:** 1 owner-approved scope expansion. **Impact:** CONC-02 now covers the complete authoritative compiler surface rather than the stale pre-sized subset.

## Trait Activation and Resolution

- `AppPackage/Package.swift` uses `from: "1.25.3"` with `ComposableArchitecture2Deprecations` and `ComposableArchitecture2DeprecationOverloads` on separate lines.
- `swift package resolve` and the app build regenerated package resolution state; both lockfiles remained byte-identical and continue to pin the canonical dependency at 1.26.0 (`e2fa1df6cd9eec6fa6314aa20513e47da576f24e`).
- The first incremental recon emitted zero warnings because the affected sources were not rebuilt.
- After clearing only this project's DerivedData and re-resolving, the clean recon emitted the expected positive control at `PopularView.swift:36`.

## Build Timing

- Pre-trait warm build: **54.54 seconds wall clock** (`xcodebuild` reported 39.800 seconds).
- Clean positive-control recon: **103.17 seconds wall clock** (`xcodebuild` reported 75.836 seconds); this followed a DerivedData deletion and is not directly comparable.
- Post-migration warm build: **42.93 seconds wall clock** (`xcodebuild` reported 40.100 seconds).
- The comparable warm runs show no compile-time regression from keeping both required traits enabled.

## Validation Results

- Manifest version-floor and two-trait grep gate — **passed**.
- SwiftPM resolution — **passed**; TCA remains at 1.26.0.
- Positive control at `PopularView.swift:36` before fixes — **passed**.
- SwiftLint over all 29 modified Swift files — **passed**, 0 violations.
- Deprecated destination-scope grep — **passed**, zero source matches.
- AppFeature generic iOS Simulator build — **passed** (`BUILD SUCCEEDED`), zero TCA deprecation warnings.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`), zero TCA deprecation warnings.

## Accessibility Impact

System sheets, full-screen covers, alerts, confirmation dialogs, and toasts remain attached to the same views. The migration changes only TCA scope arguments, so native focus trapping, reading order, labels, touch targets, motion, and visual layout are unchanged.

## Issues Encountered

- An incremental recon initially emitted no warnings because Xcode reused compiled sources. The plan's positive-control rule correctly required a project-specific DerivedData clean and rebuild, which exposed the authoritative inventory.
- The expanded inventory included modern `Scope` initializers that conflict with the old labeled signature but not with the project's child-reducer shorthand lint rule; passing reducer initializers as the new unlabeled third argument satisfies both TCA and SwiftLint.

## Next Phase Readiness

- CONC-01 and CONC-02 are complete.
- Phase 4 implementation is complete and ready for phase-level verifier, code-review, hook, drift, and tracking gates.
- Real-device presentation behavior remains covered by the phase UAT workflow referenced in `04-VALIDATION.md`.

## Self-Check: PASSED

- Both traits remain pinned.
- The positive control is recorded before fixes.
- All 66 compiler-reported sites are migrated.
- App and package builds contain zero TCA deprecation warnings.
- Full tests and SwiftLint pass.
