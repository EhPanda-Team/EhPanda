---
phase: 08-architecture-hygiene-client-seams
plan: 17
subsystem: testing
tags: [tca, dependencies, userdefaults, clipboard, deep-link, swift-testing]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: "08-16 sequenced this plan after it so the xcodebuild test runs never overlap"
provides:
  - "UserDefaultsClient exposes clipboardChangeCount as an injected @Sendable read endpoint (getValue), matching setValue's shape"
  - "AppRouteReducer.detectClipboardURL reads through the injected endpoint, not UserDefaults.standard"
  - "AppRouteReducerTests proving one override controls both the read and the write"
affects: [architecture-hygiene, client-seams, userdefaults, deep-link-handling]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Model every client read as a concrete Sendable stored endpoint, not a generic instance method that reaches the process-global"

key-files:
  created:
    - AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift
  modified:
    - AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift

key-decisions:
  - "Model the clipboardChangeCount read as a stored @Sendable (AppUserDefaults) -> Int? endpoint and delete the generic getValue<T:Codable>(_:) instance method, so overrides control reads exactly as they control writes."
  - "noop returns nil (deterministic); unimplemented reports an issue exactly like setValue; UserDefaults.standard is touched only inside live's endpoint closures."

patterns-established:
  - "Read substitutability regression: seed a conflicting value into the process-global, override the injected read to a different value, and assert the reducer honors the override — proving the process-global is never consulted."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: "UserDefaultsClient models clipboardChangeCount as an injected @Sendable read endpoint (getValue) with live/noop/unimplemented values; the generic getValue<T> instance method is gone and UserDefaults.standard is read only inside live."
    requirement: "HYG-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift#injectedReadSuppressesWriteDespiteConflictingProcessGlobal"
        status: pass
      - kind: automated_ui
        ref: "xcodebuild build -scheme EhPanda (SwiftLint-as-error, clean)"
        status: pass
    human_judgment: false
  - id: D2
    description: "detectClipboardURL routes both the read and the write through the injected UserDefaultsClient — one override controls both."
    requirement: "HYG-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift#injectedReadMismatchWritesThroughInjectedSetValue"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift#injectedReadSuppressesWriteDespiteConflictingProcessGlobal"
        status: pass
    human_judgment: false

# Metrics
duration: 20min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 17: UserDefaultsClient Read Substitutability Summary

**Converted the clipboardChangeCount read into an injected @Sendable UserDefaultsClient endpoint so a single override controls both the read and the write in `detectClipboardURL`, with a reducer test that fails if the read ever bypasses the injected value.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-14T12:36:00Z
- **Completed:** 2026-07-14T12:56:03Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments
- Closed GAP-03 (HYG-01): the last non-substitutable UserDefaults read now routes through an injected endpoint. Overrides, `.noop`, and `.unimplemented` control reads exactly as they already controlled writes.
- Replaced the generic `getValue<T: Codable>(_:)` instance method (which always read `UserDefaults.standard`) with a stored `getValue: @Sendable (AppUserDefaults) -> Int?` endpoint mirroring `setValue`'s shape; `UserDefaults.standard` is now touched only inside `live`'s endpoint closures.
- `AppRouteReducer.detectClipboardURL` reads through the injected endpoint (the call site `userDefaultsClient.getValue(.clipboardChangeCount)` is unchanged text but now resolves to the substitutable property).
- Added `AppRouteReducerTests` — two deterministic tests proving one override controls the read (short-circuit despite a conflicting process-global) and the write (injected `setValue` records the new count).

## Task Commits

Each task was committed atomically:

1. **Task 1: Model the clipboardChangeCount read as a @Sendable endpoint and route detectClipboardURL through it** - `d5914268` (feat)
2. **Task 2: Add a reducer test proving an override controls both the read and the write** - `12628235` (test)

_Note: this is a gap-closure regression test — the fix (Task 1) landed first, then Task 2's test guards it. The RED gate was proven by temporarily reverting the reducer read to `UserDefaults.standard` and observing `injectedReadSuppressesWriteDespiteConflictingProcessGlobal` fail; it passes against the injected endpoint._

## Files Created/Modified
- `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift` - Added the stored `getValue` read endpoint (`@Sendable (AppUserDefaults) -> Int?`); wired `live`/`noop`/`unimplemented`; removed the generic instance method.
- `AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift` - New Swift Testing suite with the read/write both-way substitutability regression, seeding and restoring the process-global per-test with no `.serialized` trait.

## Decisions Made
- Modeled the read as a concrete `Int?`-returning endpoint keyed by `AppUserDefaults` (parallel to `setValue`'s `(Any, AppUserDefaults)` signature) rather than a generic — the sole consumer reads an `Int` change count, so a concrete, `Sendable` endpoint is sufficient and removes the generic-method process-global bypass.
- `noop` returns `nil` (deterministic default) and `unimplemented` reports an unimplemented issue exactly like `setValue`, keeping the two endpoints symmetric.

## Deviations from Plan
None - plan executed exactly as written. The reducer call site required no textual edit because the new stored `getValue` property is invoked with the same syntax as the removed instance method; `AppRouteReducer.swift` therefore has no diff while still routing through the injected endpoint (verified by the RED-gate revert).

## Issues Encountered
- The plan's verify command referenced `-scheme AppPackage-Package` against `EhPanda.xcodeproj`, but that aggregate package scheme is only auto-generated when xcodebuild targets the package directory. Resolved by running `xcodebuild test -scheme AppPackage-Package` from `AppPackage/` (the per-target `AppFeature` scheme is not configured for the test action). `-only-testing:AppFeatureTests` is the correct focused filter.
- `UserDefaultsClient` / `ClipboardClient` memberwise initializers are internal (public structs, internal init). Used `@testable import` for both in the test, matching the existing `AppReducerScenePhaseTests` idiom.

## Next Phase Readiness
- The UserDefaults seam is fully substitutable; no code path outside the injected value reads `UserDefaults.standard` for `clipboardChangeCount`.
- Full AppPackage suite is green (31.8s); the EhPanda app target builds clean under SwiftLint-as-error.

## Self-Check: PASSED

- FOUND: AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift
- FOUND: AppPackage/Tests/AppFeatureTests/AppRouteReducerTests.swift
- FOUND: .planning/phases/08-architecture-hygiene-client-seams/08-17-SUMMARY.md
- FOUND commit: d5914268 (Task 1)
- FOUND commit: 12628235 (Task 2)
- Confirmed no generic `getValue<T>` instance method survives in AppPackage/Sources.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
