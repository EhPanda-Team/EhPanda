---
phase: 13-deep-link-hardening
plan: 02
subsystem: deep-link-errors
tags: [swift, localization, urlcomponents, swift-testing, privacy]

requires:
  - phase: 13-deep-link-hardening
    plan: 01
    provides: Pure URLComponents-based gallery-link parser and hardened route facts
  - phase: 09-correctness-structured-error-handling
    provides: AppError, ErrorInfo context, and toast-to-detail error machinery
provides:
  - Dedicated non-retryable AppError.unsupportedDeepLink vocabulary
  - Three unsupported-link strings translated across all six catalog locales
  - Context.unsupportedLink(url:) with a sanitized ContextKey.link diagnostic row
  - Regression coverage for URL sanitization and LocalizedError wiring
affects: [13-04-deep-link-policy-wiring, error-info-view, explicit-deep-link-failures]

tech-stack:
  added: []
  patterns: [URLComponents reconstruction, fixed diagnostic-key whitelist, parameterized Swift Testing privacy fixtures]

key-files:
  created:
    - AppPackage/Tests/AppModelsTests/UnsupportedDeepLinkErrorTests.swift
  modified:
    - AppPackage/Sources/AppModels/Support/AppError.swift
    - AppPackage/Sources/AppModels/Support/AppError+Context.swift
    - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppComponents/AppError+Symbol.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift

key-decisions:
  - "Context.unsupportedLink(url:) stores the sanitized link under ContextKey.link alongside fixed Open link action and unrecognized-gallery reason rows."
  - "The link rendering is reconstructed from URLComponents scheme, host, and first path component; deeper paths become one ellipsis and userinfo, port, query, and fragment are never copied."
  - "AppError.unsupportedDeepLink remains non-retryable and non-fatal to the download account batch because it describes route input, not an account-wide outage."

patterns-established:
  - "User-visible URL diagnostics reconstruct an allowlisted projection instead of redacting a raw absolute string."
  - "Privacy regressions assert forbidden fixture values are absent from every stored context row."

requirements-completed: [SC-3]

coverage:
  - id: D1
    description: "Unsupported deep links have distinct non-retryable localized error and recovery vocabulary."
    requirement: SC-3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/UnsupportedDeepLinkErrorTests.swift#unsupportedDeepLinkIsNonRetryableAndFullyDescribed"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Unsupported-link context identifies the route without retaining access-bearing URL components."
    requirement: SC-3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/UnsupportedDeepLinkErrorTests.swift#unsupportedLinkContextSanitizesAccessBearingComponents"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false

duration: 11 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 02: Unsupported Deep-Link Error Summary

**Six-locale unsupported-link guidance plus URLComponents-based diagnostics that expose only scheme, host, and the first path component**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-23T02:05:10Z
- **Completed:** 2026-07-23T02:16:17Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `AppError.unsupportedDeepLink` as a dedicated non-retryable failure with description, alert text, recovery suggestion, and symbol coverage.
- Authored the short name, explanation, and actionable recovery guidance in English, German, Japanese, Korean, Simplified Chinese, and Traditional Chinese; the recovery names both supported hosts and `/g/`, `/s/`, and comment links.
- Added `Context.unsupportedLink(url:)` and `ContextKey.link`, reconstructing a diagnostic from safe URL components instead of storing or redacting the raw URL.
- Proved that userinfo, ports, queries, fragments, and deeper path tokens never appear in any persisted context row; the full default unit plan remains green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add unsupported deep-link error vocabulary and six-locale localization** - `54822504` (feat)
2. **Task 2: Add sanitized unsupported-link context and regressions** - `be935c7f` (feat)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Support/AppError.swift` - Adds and fully wires the dedicated unsupported-link error case.
- `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` - Adds three translated keys across all six locales.
- `AppPackage/Sources/AppModels/Support/AppError+Context.swift` - Adds `Context.unsupportedLink(url:)` and the sanitized `ContextKey.link` row.
- `AppPackage/Tests/AppModelsTests/UnsupportedDeepLinkErrorTests.swift` - Covers sanitization boundaries and localized error behavior.
- `AppPackage/Sources/AppComponents/AppError+Symbol.swift` - Gives the new error an exhaustive warning symbol mapping.
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` - Classifies the new route-input error as non-fatal to account-wide page batches.

## Decisions Made

- The exact downstream contract for Plan 13-04 is `Context.unsupportedLink(url:)`, with the sanitized value stored under `ContextKey.link`.
- The diagnostic omits ports in addition to the explicitly prohibited userinfo, query, fragment, and deeper path because the locked projection is scheme + host + first path component only.
- A URL that cannot yield both scheme and host falls back to the non-sensitive text `Unsupported link`; the raw URL is never a fallback.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Completed exhaustive downstream AppError switches**
- **Found during:** Task 1 build verification
- **Issue:** Adding the enum case made the existing symbol and download account-fatality switches non-exhaustive.
- **Fix:** Added a warning symbol and classified unsupported deep links as non-fatal to an account-wide download batch.
- **Files modified:** `AppPackage/Sources/AppComponents/AppError+Symbol.swift`, `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift`
- **Verification:** The EhPanda simulator build succeeded.
- **Committed in:** `54822504`

**2. [Rule 1 - Bug] Preserved a literal ellipsis in the sanitized diagnostic**
- **Found during:** Task 2 targeted AppModelsTests
- **Issue:** Asking URLComponents to render the ellipsis path segment percent-encoded it as `%E2%80%A6`, contrary to the required `https://host/g/…` user-facing form.
- **Fix:** URLComponents now renders the safe scheme/host/first-component base, then the code appends the constant `/…` marker outside the encoded URL.
- **Files modified:** `AppPackage/Sources/AppModels/Support/AppError+Context.swift`
- **Verification:** Both parameterized privacy fixtures and all 70 AppModelsTests passed.
- **Committed in:** `be935c7f`

**3. [Rule 3 - Blocking] Replaced the catalog lint probe with a JSON parser check**
- **Found during:** Task 1 verification
- **Issue:** The installed `plutil -lint` rejects JSON string catalogs at the opening brace even when the catalog is valid.
- **Fix:** Validated the catalog with Python's JSON parser, then verified all three key/locale/state invariants directly; Xcode string-symbol generation provided the compile check.
- **Files modified:** None
- **Verification:** JSON parsing, catalog assertions, generated symbols, and the app build all passed.
- **Committed in:** Not applicable; verification-only adjustment

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking issues). **Impact on plan:** Two exhaustive switches joined the Task 1 commit and verification used a catalog-aware parser; the shipped error and privacy contracts remain exactly in scope.

## Issues Encountered

- Sandboxed Xcode initially could not write its package/module caches. Verification was rerun with cache access and succeeded.
- The full default test plan reports the repository's existing expected `Category.private` known issue; it completed successfully with no unexpected failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 13-04 can construct `ErrorInfo(error: .unsupportedDeepLink, context: .unsupportedLink(url: url))` without introducing its own URL redaction logic.
- No blockers remain for deep-link policy wiring.

## Self-Check: PASSED

- All six created or modified implementation/test files exist.
- Commits `54822504` and `be935c7f` are present in git history.
- The catalog has exactly three unsupported-link keys, each translated across all six locales.
- The app build, all 70 AppModelsTests, and the full default unit test plan passed.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
