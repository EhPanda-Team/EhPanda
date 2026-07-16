---
phase: 09-correctness-structured-error-handling
plan: 12
subsystem: error-handling
tags: [privacy, diagnostics, swift-testing, tca]

requires:
  - phase: 09-04
    provides: ErrorInfo-bearing gallery failure toast routing
provides:
  - Route-aware gallery diagnostic context that retains only a validated numeric gallery ID
  - Token-leak regressions for both /g and /s gallery routes
affects: [error-context, presentation-feature, support-diagnostics]

tech-stack:
  added: []
  patterns: [constrained diagnostic-context factory, test-store boundary privacy assertion]

key-files:
  created:
    - AppPackage/Tests/AppModelsTests/ErrorContextSanitizerTests.swift
  modified:
    - AppPackage/Sources/AppModels/Support/AppError+Context.swift
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift
    - AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift

key-decisions:
  - "Gallery diagnostics retain only a validated decimal gallery ID; tokens, image keys, hosts, queries, and complete paths are never represented in Context."
  - "PresentationFeature obtains gallery-failure context exclusively through Context.galleryFailure(url:action:reason:)."

patterns-established:
  - "Untrusted route input crosses into user-visible diagnostics only through a constrained, route-aware factory."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: Gallery failure diagnostics omit access-bearing tokens for both supported route forms.
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: AppPackage/Tests/AppModelsTests/ErrorContextSanitizerTests.swift
        status: pass
    human_judgment: false
  - id: D2
    description: PresentationFeature surfaces only sanitized gallery context in ErrorInfo-bearing toasts.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift#galleryFailureToastUsesSanitizedContext
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-07-16
status: complete
---

# Phase 09 Plan 12: Privacy-Safe Gallery Diagnostics Summary

**Route-aware diagnostic context now preserves a useful gallery ID without exposing gallery tokens, image keys, paths, hosts, or queries.**

## Performance

- **Duration:** 6 min implementation plus recovery verification
- **Started:** 2026-07-16T17:06:43+09:00
- **Completed:** 2026-07-16T19:47:14+09:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Replaced the raw URL context slot with a constrained gallery-failure context factory.
- Added parameterized privacy regressions for `/g/<gid>/<token>` and `/s/<key>/<gid>-<page>`.
- Proved the reducer's surfaced toast boundary carries the sanitized context for both route forms.

## Task Commits

1. **Task 1 RED: Add failing gallery context sanitizer tests** — `afcf2fe7`
2. **Task 1 GREEN: Sanitize gallery diagnostic context** — `8e41881a`
3. **Task 2 RED: Add failing sanitized toast route tests** — `de5c6bf6`
4. **Task 2 GREEN: Route gallery failures through sanitizer** — `afec2460`

## Files Created/Modified

- `AppPackage/Sources/AppModels/Support/AppError+Context.swift` — route-aware safe context factory and raw URL key removal.
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` — exclusive sanitizer use at the gallery failure boundary.
- `AppPackage/Tests/AppModelsTests/ErrorContextSanitizerTests.swift` — supported and malformed route privacy tests.
- `AppPackage/Tests/AppModelsTests/AnyHashableBoxTests.swift` — safe literal-context coverage.
- `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` — surfaced-toast integration regressions.

## Decisions Made

- Unsupported or malformed routes omit the gallery identifier instead of reflecting attacker-controlled text.
- AppModels performs the small deterministic route parse directly, avoiding a dependency on URLClient.

## Deviations from Plan

None - implementation followed the plan. The interrupted executor omitted only the summary/tracking closeout; recovery reran all focused verification before authoring this summary.

## Issues Encountered

- The executor session ended after task commits but before SUMMARY creation. Recovery inspected all four commits and reran the combined focused test command successfully.

## User Setup Required

None - no external service configuration required.

## Verification

- `AppModelsTests/ErrorContextSanitizerTests`: passed both supported routes and three malformed/unsupported routes.
- `AppModelsTests/AnyHashableBoxTests`: passed.
- `AppFeatureTests/PresentationFeatureTests`: passed four tests, including two parameterized sanitized-toast cases.
- Combined `xcodebuild test` result: **TEST SUCCEEDED**.

## Next Phase Readiness

Plan 09-13 can safely build the persistent accessible error-toast interaction on token-free ErrorInfo context.

## Self-Check: PASSED

- All five created/modified files exist.
- All four task commits exist in branch history.
- Focused AppModels and AppFeature tests pass.
- No absolute home path is recorded in this document.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-16*
