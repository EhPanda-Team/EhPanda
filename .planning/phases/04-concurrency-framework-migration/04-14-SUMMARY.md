---
phase: 04-concurrency-framework-migration
plan: 14
subsystem: tca-migration
tags: [tca, package-traits, deprecations, checkpoint]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Combine-free typed async request layer
provides:
  - TCA 1.25.3 version floor with both 2.0 deprecation traits enabled
  - Positive-control proof that Xcode applies the traits after a clean DerivedData rebuild
  - Categorized D-11 reconnaissance inventory for an owner scope decision
affects: [tca, app-feature, swiftui-presentations]

tech-stack:
  added: []
  patterns:
    - Package traits as a compile-time migration inventory

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-14-SUMMARY.md
  modified:
    - AppPackage/Package.swift

key-decisions:
  - "Execution stopped at D-11 before view or reducer fixes because the clean recon surfaced 66 unique warnings across three patterns, not the planned approximately 24 warnings in one pattern."

requirements-completed: []

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

duration: 9min
completed: 2026-07-13
status: blocked
---

# Phase 04 Plan 14: TCA Deprecation Reconnaissance Checkpoint

**Both deprecation traits are active, but the authoritative clean build found 66 unique warning sites across three migration patterns, triggering the plan's mandatory D-11 stop condition before any fixes.**

## Checkpoint Status

- **Status:** Blocked pending owner scope decision
- **Stopped after:** Task 1 reconnaissance
- **View changes:** None
- **Reducer changes:** None
- **Task 1 commit:** `86c8ed78`

## Trait Activation

- `AppPackage/Package.swift` now uses the `1.25.3` floor and enables both required traits.
- `swift package resolve` regenerated the package lock state; both resolved files remained byte-identical and continue to pin the canonical dependency at `1.26.0` (`e2fa1df6cd9eec6fa6314aa20513e47da576f24e`).
- The first incremental recon emitted zero warnings because the affected sources were not rebuilt.
- After deleting only this project's DerivedData and re-resolving, the clean recon emitted the expected positive control at `PopularView.swift:36`, proving the traits are active.

## D-11 Reconnaissance Inventory

The clean log contains 132 warning lines because each of 66 sites was compiled for two simulator architectures. Deduplicated by file, line, and message:

| Category | Unique sites | Scope |
|----------|-------------:|-------|
| Enum destination scope migration | 45 | 23 view files; 28 sites in the 11 planned files and 17 in 12 additional files |
| Renamed `Store.scope(state:action:)` calls | 11 | 6 files, including app tab, home, search, settings, and detail routing |
| Deprecated `Scope(state:action:child:)` initializers | 10 | `AppReducer.swift` reducer composition |
| **Total** | **66** | **29 files** |

Additional files outside the planned edit surface include app tab routing, quick search, filters, settings screens, home history/top lists, several detail subfeatures, and a downloads subview. The reducer initializer warnings also violate the plan's expectation that no reducer file would need modification.

The categorized scratch inventory is at `/tmp/ehpanda-phase04-plan14-recon-unique.txt`; the complete clean build log is at `/tmp/ehpanda-phase04-plan14-recon-clean.log`.

## Build Timing

- Pre-trait baseline incremental build: **54.54 seconds wall clock** (`xcodebuild` reported 39.800 seconds).
- Clean positive-control recon: **103.17 seconds wall clock** (`xcodebuild` reported 75.836 seconds).
- These numbers are not a fair trait-cost comparison because the positive-control run intentionally followed a DerivedData deletion. A post-migration build must be measured under comparable cache conditions after the scope decision.

## Validation Results

- Manifest version floor and two-trait grep gate — **passed**.
- SwiftPM resolution — **passed**; dependency remains at 1.26.0.
- AppFeature clean reconnaissance build — **passed**.
- Positive control at `PopularView.swift:36` — **passed**.
- D-11 inventory-size and pattern check — **halted as designed**: 66 unique sites across three patterns exceeds the planned surface.

## Accessibility Impact

None. No SwiftUI modifier or presentation code was changed before the checkpoint.

## Owner Decision Required

Choose whether to expand Plan 04-14 to migrate all 66 warnings across 29 files, or revise the trait/scope requirement. No warning fixes have been applied, so the inventory remains an exact compiler-generated migration checklist.
