---
phase: 08-architecture-hygiene-client-seams
plan: 12
subsystem: architecture
tags: [swiftui, dependencies, cookie-client, login-gating]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: CookieClient didLogin behavior matrix from plan 08-11
provides:
  - Injected CookieClient login reads at all 12 former CookieUtil view sites
  - Complete removal of the redundant CookieUtil source type
  - Login-gating behavior backed by the CookieClient matrix and full package suite
affects: [detail, favorites, home, settings, app-tools]
tech-stack:
  added: []
  patterns:
    - View-owned CookieClient dependency reads for render-time login gating
    - Function-local dependency resolution for a cross-file toolbar extension
key-files:
  created: []
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift
    - AppPackage/Sources/DetailFeature/DetailView+Navigation.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/AppTools/CookieUtil.swift
key-decisions:
  - "Resolve CookieClient at each view owner, including a function-local read in the cross-file Detail toolbar extension."
  - "Keep every existing login condition and control modifier unchanged apart from its predicate source."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "All 12 former CookieUtil.didLogin sites read the injected CookieClient at render time."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "12-site cookieClient.didLogin source inventory"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D2
    description: "CookieUtil is deleted and no source reference to the type remains."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "tree-wide AppPackage/Sources CookieUtil absence check"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Download, archive, comment, favorite, rating, tag-vote, and login controls retain their former logged-in and logged-out behavior."
    requirement: HYG-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/CookieClientTests/CookieClientTests.swift#CookieClientTests"
        status: pass
    human_judgment: true
    rationale: "The predicate matrix and unchanged conditions prove code parity; the phase gate still requires an owner device check of visible and disabled control behavior."
duration: 7 min
completed: 2026-07-14
status: complete
---

# Phase 8 Plan 12: Cookie Login View Seam Summary

Cookie login gating now reads the injected `CookieClient` at every view site, with the duplicate `CookieUtil` implementation removed and behavior guarded by the full client matrix.

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-14T10:19:37Z
- **Completed:** 2026-07-14T10:27:22Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Replaced all 12 `CookieUtil.didLogin` reads with view-owned `@Dependency(\.cookieClient)` access while preserving each surrounding condition and modifier.
- Deleted `CookieUtil.swift` without leaving a source reference or compatibility stub.
- Verified the migration with a warning-free package build, strict SwiftLint, the complete package test suite, and the plan 08-11 login behavior matrix.

## Task Commits

1. **Task 1: Migrate the 12 didLogin view sites to CookieClient** - `9e0be526`
2. **Task 2: Delete CookieUtil** - `c430ab8d`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Package.swift` - declares direct CookieClient module dependencies for FavoritesFeature and HomeFeature.
- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift` - injects CookieClient for both favorites login checks.
- `AppPackage/Sources/HomeFeature/Watched/WatchedView.swift` - injects CookieClient for both watched-page login checks.
- `AppPackage/Sources/DetailFeature/DetailView.swift` - resolves download eligibility through CookieClient.
- `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` - resolves the favorite-button gate through CookieClient.
- `AppPackage/Sources/DetailFeature/DetailView+Navigation.swift` - resolves the archive-button gate through a function-local CookieClient dependency.
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift` - resolves rating, tag-vote, and comment controls through CookieClient.
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` - resolves the post-comment toolbar gate through CookieClient.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift` - resolves login versus account controls through CookieClient while retaining the logout dialog anchor.
- `AppPackage/Sources/AppTools/CookieUtil.swift` - deleted after all consumers migrated.

## Decisions Made

- Each independent view owns its injected client, while the Detail toolbar extension resolves its dependency inside `toolbar()` because a private stored property is file-scoped in Swift.
- The migration changes only the predicate source; all layout, conditional branches, disabled expressions, alert/dialog attachment, and actions remain unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Declared direct CookieClient module dependencies for migrated feature targets**
- **Found during:** Task 1 implementation
- **Issue:** FavoritesFeature and HomeFeature did not directly depend on CookieClient, so their new imports could not compile under SwiftPM module boundaries.
- **Fix:** Added `.module(.cookieClient)` to both target dependency lists in `AppPackage/Package.swift`.
- **Files modified:** `AppPackage/Package.swift`
- **Verification:** The complete package build and test suite pass.
- **Committed in:** `9e0be526`

**2. [Rule 1 - Bug] Reconciled stale progress fields after state queries**
- **Found during:** Plan metadata self-check
- **Issue:** The state updater advanced plan and completed-plan fields but later rewrote the percentage from phase completion, leaving the human-readable next-plan and progress values stale.
- **Fix:** Reconciled frontmatter and human-readable state to plan 13, 74 of 76 plans, and 97 percent after all required state queries ran.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current position, next plan, progress bar, and completed-plan count agree with the summaries present on disk.
- **Committed in:** Plan state metadata commit

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue).
**Impact on plan:** The direct target edges are required by the planned dependency injection, and the metadata repair records the verified result accurately; neither changes runtime behavior or broadens feature scope.

## Issues Encountered

- The plan's iPhone 16 simulator was unavailable, so verification used the installed iPhone Air simulator running iOS 26.5.
- CoreSimulator disconnected during the first full-suite attempt; an immediate clean retry completed successfully with no test failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Cookie login state now has one implementation seam, and plan 08-13 can proceed without a remaining `CookieUtil` dependency.
- The phase-level device check for logged-in versus logged-out control visibility and enabled state remains part of final phase verification.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Both task commits are present in git history.
- Exactly 12 migrated view sites read `cookieClient.didLogin`, and `CookieUtil` is absent from the source tree.
- Package build, full package tests, strict SwiftLint, diff checks, direct dependency checks, and security/accessibility parity review pass.
