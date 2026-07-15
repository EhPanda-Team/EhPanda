---
phase: 09-correctness-structured-error-handling
plan: 01
subsystem: error-handling
tags: [swift, localized-error, structured-context, swift-testing]

requires:
  - phase: 08-deglobalization-privacy-and-test-foundation
    provides: Explicit request ownership and privacy-safe logging boundaries
provides:
  - Sendable typed diagnostic context and surfaced ErrorInfo payloads
  - Localized AppError recovery suggestions and LocalizedError conformance
  - All-case AppError parity and AnyHashableBox ergonomics tests
affects: [09-02, 09-03, 09-04, error-presentation, error-routing]

tech-stack:
  added: []
  patterns: [companion error payload, safe context whitelist, identity-excluded equality, localized recovery]

key-files:
  created:
    - AppPackage/Sources/AppModels/Support/AppError+Context.swift
    - AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift
    - AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift
  modified:
    - AppPackage/Sources/AppModels/Support/AppError.swift
    - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppComponents/ActivityView.swift
    - AppPackage/Sources/DetailFeature/Components/LinkedText.swift
    - AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift
    - AppPackage/Sources/SettingFeature/Components/WebView.swift

key-decisions:
  - "Keep AppError's 12-case enum unchanged and carry per-incident diagnostics in ErrorInfo."
  - "Offer recovery suggestions for networking, authentication, IP restriction, quota, and not-found errors."
  - "Use Self.Context in SwiftUI representables so the public diagnostic Context type cannot shadow protocol context."

patterns-established:
  - "Structured errors: ErrorInfo combines an unchanged AppError with an optional safe Context dictionary."
  - "Context security: keys are a fixed five-member whitelist and URL values are path-only."
  - "Presentation identity: ErrorInfo excludes its fresh UUID from equality and hashing."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: "AnyHashableBox, Context, ContextKey, and ErrorInfo provide a Sendable structured-error payload."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift"
        status: pass
    human_judgment: false
  - id: D2
    description: "AppError supplies localized recovery suggestions through LocalizedError without changing existing cases."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift#localizedErrorUsesTheExistingDescriptionAndSolution"
        status: pass
    human_judgment: false
  - id: D3
    description: "All 12 AppError cases retain their retryability, localized descriptions, and alert text."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift#existingErrorBehaviorRemainsStable"
        status: pass
    human_judgment: false

duration: 19min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 01: Structured Error Foundation Summary

**Typed, privacy-safe error context and localized recovery guidance now layer onto the unchanged 12-case AppError enum.**

## Performance

- **Duration:** 19 min
- **Started:** 2026-07-15T05:22:37Z
- **Completed:** 2026-07-15T05:41:40Z
- **Tasks:** 3
- **Files modified:** 9

## Accomplishments

- Added `AnyHashableBox`, the five-key safe `Context` vocabulary, and identity-independent `ErrorInfo` payloads.
- Added five fully localized recovery suggestions and bridged existing descriptions through `LocalizedError`.
- Locked all 12 existing AppError cases to their retryability, description, and alert-text behavior with passing tests.

## Task Commits

Each task was committed atomically, including required TDD gates:

1. **Task 1: Structured context types** — `2b31ca8d` (test RED), `5e8839ab` (feat GREEN)
2. **Task 2: Recovery suggestions and LocalizedError** — `85ff52e8` (test RED), `02f5caef` (feat GREEN)
3. **Task 3: Wave-0 parity tests** — `c4f20e6b` (test)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Support/AppError+Context.swift` — Sendable erasure, safe keys, context, and payload.
- `AppPackage/Sources/AppModels/Support/AppError.swift` — Additive recovery and LocalizedError extensions.
- `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` — Five suggestions in all six locales.
- `AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift` — 12-case parity and recovery round-trip coverage.
- `AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift` — equality, hashing, display, literals, and ErrorInfo tests.
- Four SwiftUI representable files — unambiguous `Self.Context` protocol signatures.

## Decisions Made

- Kept `AppError` byte-stable in shape; `ErrorInfo` owns per-incident context so existing pattern matching remains valid.
- Limited context labels to action, reason, URL path, status code, and gallery ID to prevent secret-bearing diagnostics.
- Provided solutions only where users can take a concrete action: reconnect, reauthenticate, wait, or verify an address.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Qualified SwiftUI representable context types**

- **Found during:** Task 2 verification
- **Issue:** The required public `Context` alias shadowed SwiftUI's representable `Context` shorthand in four modules.
- **Fix:** Changed seven existing representable method signatures to `Self.Context`, preserving behavior and API intent.
- **Files modified:** `ActivityView.swift`, `LinkedText.swift`, `LiveTextView.swift`, `WebView.swift`
- **Verification:** AppModels tests built the complete app dependency graph and all 59 AppModels tests passed.
- **Committed in:** `02f5caef`

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Required compatibility fix only; no user-visible behavior or architecture changed.

## Issues Encountered

- The plan's package-only scheme command had no supported run destination in this workspace. Verification used the app's FeatureTests plan on the installed iPhone Air simulator instead.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Error presentation and reducer routing plans can now carry `ErrorInfo` without changing AppError cases.
- The fixed context whitelist and all-case parity table are ready to guard downstream failure-surface work.

## Self-Check: PASSED

- All three created files exist.
- All five task/TDD commits exist in history.
- AppModels build succeeded and 59 tests in 9 suites passed.
- AppError remains 12 cases; AppError symbol mapping is unchanged; all solution keys contain six locales.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
