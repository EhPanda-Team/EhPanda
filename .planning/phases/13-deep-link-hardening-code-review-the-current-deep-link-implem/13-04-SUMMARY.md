---
phase: 13-deep-link-hardening
plan: 04
subsystem: deep-link-policy
tags: [swift, composable-architecture, swift-testing, urlcomponents, share-extension]

requires:
  - phase: 13-deep-link-hardening
    plan: 02
    provides: Sanitized unsupported-link error context
  - phase: 13-deep-link-hardening
    plan: 03
    provides: Direct GalleryURLParser consumption at the presentation boundary
provides:
  - Source-aware explicit-open and clipboard failure policy
  - Structural ShareExtension scheme rewriting that preserves every non-scheme URL component
  - Reducer regressions for explicit failures, clipboard silence, clipboard routing, and gallery fetch failures
affects: [13-05-routing-coordination, app-presentation, share-extension]

tech-stack:
  added: []
  patterns: [source pre-validation, sanitized explicit errors, URLComponents mutation, exhaustive TestStore policy tests]

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift
    - ShareExtension/ShareViewController.swift

key-decisions:
  - "Clipboard discovery proves route support before entering the explicit-open handler, preserving silence for unsolicited URLs."
  - "Unsupported explicit input uses Context.unsupportedLink(url:) directly so no raw access-bearing URL enters ErrorInfo."
  - "ShareExtension rewrites only URLComponents.scheme and completes the extension request when conversion cannot produce a URL."

patterns-established:
  - "Entry sources enforce their own failure policy before converging on the shared successful routing path."
  - "Cross-process URL hand-offs mutate structured URL components rather than serialized URL text."

requirements-completed: [SC-3, SC-1]

coverage:
  - id: D1
    description: "Explicit unsupported opens surface a sanitized persistent error while unsupported clipboard URLs remain silent and recognized clipboard URLs still route."
    requirement: SC-3
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation -only-testing:AppFeatureTests"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "ShareExtension changes only the URL scheme, preserving host, path, query, and fragment even when the query embeds another scheme string."
    requirement: SC-1
    verification:
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "URLComponents preservation probe plus structural source check for URLComponents and absence of replacingOccurrences"
        status: pass
      - kind: other
        ref: "SwiftLint 0.62.2 lint --strict --config .swiftlint.yml AppPackage/Sources AppPackage/Tests ShareExtension"
        status: pass
    human_judgment: false

duration: 12 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 04: Entry-Source Policy and ShareExtension URL Rewrite Summary

**Explicit unsupported opens now produce sanitized persistent errors, clipboard noise stays silent, and shared URLs cross into the app through a component-scoped scheme rewrite**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-23T02:34:00Z
- **Completed:** 2026-07-23T02:46:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Split deep-link failure behavior at the entry source: explicit unsupported input sets the existing persistent error toast, while unsupported clipboard input only persists its change count.
- Added TestStore regressions for explicit failure, clipboard silence, recognized clipboard forwarding, and unchanged gallery-fetch failure mapping.
- Replaced ShareExtension's serialized string replacement with `URLComponents.scheme` mutation while preserving failure completion and the existing app hand-off.
- Verified the targeted feature tests, full default unit plan, embedded-extension build, strict lint, and a URL containing an embedded scheme string in its query.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing entry-source policy regressions** - `9a48c74e` (test)
2. **Task 1 GREEN: Enforce deep-link entry-source policy** - `402012bd` (feat)
3. **Task 2: Rewrite the shared URL scheme structurally** - `c9412c44` (fix)

## Files Created/Modified

- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` - Pre-validates clipboard URLs and maps unsupported explicit opens to a sanitized `unsupportedDeepLink` toast without starting a fetch.
- `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` - Proves the negative and positive clipboard legs, explicit-open failure behavior, and unchanged gallery-fetch failure behavior.
- `ShareExtension/ShareViewController.swift` - Mutates only the structured URL scheme and completes the extension request on type or conversion failure.

## Decisions Made

- Kept clipboard discovery free of failure UI by validating its URL before it enters `handleDeepLink`; successful URLs continue through the same handler as explicit opens.
- Built the explicit failure context with the established sanitized unsupported-link builder, preventing raw URL credentials or sensitive path/query values from entering the toast payload.
- Kept the ShareExtension self-contained and used a local `URLComponents` mutation instead of adding an AppPackage dependency for the existing extension helper.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Allowed Xcode and Swift verification tools to use their required system caches**

- **Found during:** Task 1 RED verification and the structural URL preservation probe
- **Issue:** The filesystem sandbox denied CoreSimulator, DerivedData, and Swift compiler-cache writes needed by the planned verification commands.
- **Fix:** Re-ran verification with the required filesystem access and the repository-established `-skipMacroValidation` flag; no product code or test expectations were changed to accommodate the environment.
- **Files modified:** None
- **Commit:** Not applicable

## Issues Encountered

- The initial RED run failed only at the two intended policy gaps: explicit unsupported input had no toast, and unsupported clipboard input still forwarded to routing. The recognized clipboard leg and existing gallery-fetch failure mapping already passed.

## Known Stubs

None. The scan found only established optional-state resets, nil checks, and test expectations; no placeholder data or disconnected UI path was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Entry-source behavior is now explicit and regression-covered, so Plan 13-05 can harden routing coordination without conflating unsupported-input policy.
- The existing 1000ms routing delay, 500ms fetch-failure effect, gallery presentation flow, download navigation, and launch-automation fallback remain unchanged for their owning plans.

## Self-Check: PASSED

- Confirmed `9a48c74e`, `402012bd`, and `c9412c44` exist in git history in RED-to-GREEN task order.
- Confirmed all three modified files exist and the ShareExtension contains `URLComponents` with no `replacingOccurrences` call.
- Confirmed targeted AppFeature tests, the full default unit plan, the embedded-extension build, strict repository-owned source/test/extension lint, and the structured URL preservation probe pass.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
