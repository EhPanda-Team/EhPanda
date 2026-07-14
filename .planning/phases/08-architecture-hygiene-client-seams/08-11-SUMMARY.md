---
phase: 08-architecture-hygiene-client-seams
plan: 11
subsystem: testing
tags: [swift-testing, cookie-client, http-cookies, login-parity]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: final CookieClient signatures and host-exact testing store behavior from plans 08-05 and 08-06
provides:
  - Dedicated lint-covered CookieClientTests package target
  - Deterministic login-parity matrix across hosts, igneous states, and expiry
  - Header parsing, host-exact synchronization, backfill, and automation-import coverage
affects: [cookie-client, app-tools, login-gated-views, quality]
tech-stack:
  added: []
  patterns:
    - In-memory CookieClient.testing stores for host and synchronization behavior
    - UUID-scoped Foundation cookie stores for live HTTP response parsing
key-files:
  created:
    - AppPackage/Tests/CookieClientTests/.swiftlint.yml
    - AppPackage/Tests/CookieClientTests/CookieClientTests.swift
  modified:
    - AppPackage/Package.swift
key-decisions:
  - "Use synthetic credential fixtures and clear every live cookie store after each test."
  - "Query skip-server cookies at their /s/ path so Foundation's path matching is exercised rather than bypassed."
patterns-established:
  - "CookieClient login-gating changes must preserve the dedicated didLogin matrix before view migration."
requirements-completed: [QUAL-02, HYG-01]
coverage:
  - id: D1
    description: "A dedicated CookieClientTests target is registered in Package.swift and covered by the repository SwiftLint configuration."
    requirement: QUAL-02
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "SwiftLint --strict --no-cache AppPackage/Tests/CookieClientTests/CookieClientTests.swift"
        status: pass
    human_judgment: false
  - id: D2
    description: "CookieClient.didLogin preserves eh/ex credential, igneous, and expiry behavior for the upcoming login-gated view migration."
    requirement: HYG-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/CookieClientTests/CookieClientTests.swift#CookieClientTests"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:CookieClientTests -test-iterations 3"
        status: pass
    human_judgment: false
  - id: D3
    description: "Credential and skip-server headers, host-exact sync, two-way backfill, and automation import are deterministic and isolated."
    requirement: QUAL-02
    verification:
      - kind: unit
        ref: "AppPackage/Tests/CookieClientTests/CookieClientTests.swift"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:CookieClientTests"
        status: pass
    human_judgment: false
metrics:
  duration: 8 min
  completed: 2026-07-14
status: complete
---

# Phase 8 Plan 11: CookieClient Behavior Matrix Summary

CookieClient now has a dedicated deterministic suite locking login parity, live Set-Cookie parsing, host-exact synchronization, credential backfill, and automation import behavior.

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-14T10:01:07Z
- **Completed:** 2026-07-14T10:09:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added a dedicated `CookieClientTests` package target with inherited project SwiftLint coverage.
- Locked `didLogin` behavior for eh-only credentials, valid ex credentials, mystery or missing igneous, empty storage, and expired cookies.
- Verified credential and skip-server response parsing with isolated Foundation cookie stores.
- Proved ex-to-sibling synchronization preserves the source host, credential backfill works in both directions, and automation imports populate exactly the intended hosts.

## Task Commits

1. **Task 1: Wire the CookieClientTests target** - `4b8e1138`
2. **Task 2: Write the D-10 CookieClient behavior matrix** - `ecb5ee08`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Package.swift` - registers the `CookieClientTests` module and test target dependencies.
- `AppPackage/Tests/CookieClientTests/.swiftlint.yml` - inherits the root SwiftLint configuration.
- `AppPackage/Tests/CookieClientTests/CookieClientTests.swift` - exercises login parity and the selected cookie-seam behaviors.

## Decisions Made

- Synthetic fixture credentials are used throughout, and live cookie stores are cleared with `defer` so no credential-shaped test data survives a case.
- The host and igneous matrix uses `CookieClient.testing()`; only expiry and response parsing use the live client with a per-test Foundation store.
- Skip-server assertions query `/s/`, matching the production cookie path and Foundation's normal URL path filtering.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added the test source foundation while wiring the target**
- **Found during:** Task 1 build verification
- **Issue:** SwiftPM rejects a declared test target whose directory contains only `.swiftlint.yml` and no Swift source.
- **Fix:** Added the test file with its initial `Testing` import in Task 1, then completed it in Task 2.
- **Files modified:** `AppPackage/Tests/CookieClientTests/CookieClientTests.swift`
- **Verification:** Package build succeeds and the target is discoverable by `-only-testing:CookieClientTests`.
- **Committed in:** `4b8e1138`

**2. [Rule 3 - Blocking] Used UUID-scoped Foundation cookie stores for live tests**
- **Found during:** Task 2 targeted test verification
- **Issue:** A directly initialized `HTTPCookieStorage()` discards inserted cookies on the installed Foundation runtime, so live response-parsing assertions cannot observe production writes.
- **Fix:** Used `sharedCookieStorage(forGroupContainerIdentifier:)` with a unique identifier per test and cleared every store after use. This remains isolated per test and never accesses `.shared`.
- **Files modified:** `AppPackage/Tests/CookieClientTests/CookieClientTests.swift`
- **Verification:** The targeted suite passes three consecutive iterations with parallel Swift Testing execution.
- **Committed in:** `ecb5ee08`

**3. [Rule 1 - Bug] Queried the skip-server cookie at its production path**
- **Found during:** Task 2 targeted test verification
- **Issue:** Foundation correctly hid a `/s/` cookie from a root-path URL, making the initial assertion query invalid.
- **Fix:** Query both hosts at `/s/` and assert the cookie value and path there.
- **Files modified:** `AppPackage/Tests/CookieClientTests/CookieClientTests.swift`
- **Verification:** The skip-server case and complete targeted suite pass.
- **Committed in:** `ecb5ee08`

**4. [Rule 1 - Bug] Reconciled stale progress fields after state queries**
- **Found during:** Plan metadata self-check
- **Issue:** The state updater reported 96% but left stale percentage, next-plan, progress-bar, and completed-count values in `STATE.md`.
- **Fix:** Reconciled the human-readable and frontmatter fields to plan 12 and 73 of 76 completed plans after all required state queries ran.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter and the current-position block agree with the 11 summaries present for phase 8.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 4 auto-fixed (2 bugs, 2 blocking issues)
**Impact on plan:** The fixes make the target buildable and the live-store assertions faithful to Foundation path/storage semantics without expanding production scope.

## Issues Encountered

- The plan's iPhone 16 simulator was unavailable, so verification used the installed iPhone Air simulator running iOS 26.5.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Login-gating parity is locked for the planned `CookieUtil` deletion and the 12 view-site migrations in plan 08-12.
- No blockers remain.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Both task commits are present in git history.
- The package target, inherited SwiftLint file, and behavior suite exist.
- Package build, three repeated targeted test runs, direct SwiftLint, static no-padding checks, and diff checks pass.
