---
phase: 08-architecture-hygiene-client-seams
plan: 02
subsystem: networking
tags: [gallery-host, url-construction, dependency-seam, parity]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: D-03 gallery-host parameterization contract and the retained pure URL namespace
provides:
  - Host-taking helpers for every host-derived Defaults.URL endpoint
  - Explicit GalleryHost parameters on all host-dependent URLUtil builders
  - Transitional defaults that preserve every existing URLUtil call site
affects: [08-03, 08-04, 08-05, 08-06, 08-07, NetworkingFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit value threading, transitional default parameters, pure URL construction]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-02-SUMMARY.md
  modified:
    - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
    - AppPackage/Sources/AppModels/Utilities/URLUtil.swift

key-decisions:
  - "Host-derived Defaults.URL helpers accept GalleryHost explicitly while the existing global properties remain available during caller migration."
  - "URLUtil uses AppUtil.galleryHost only as a transitional default; every host-dependent builder body constructs from its GalleryHost argument."

patterns-established:
  - "Host-derived endpoints centralize their path components in Defaults.URL.<endpoint>(host:) helpers."
  - "Pure URL builders receive GalleryHost as their leading argument and do not read Defaults.URL.host."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: Every host-derived Defaults.URL endpoint has a GalleryHost-taking helper alongside the still-live transitional global properties.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D2
    description: All thirteen host-dependent URLUtil builders accept GalleryHost and preserve default-host request URL behavior.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
      - kind: other
        ref: "rg -c 'Defaults\\.URL\\.host' AppPackage/Sources/AppModels/Utilities/URLUtil.swift (zero matches)"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 02: Host-Taking URL Construction Summary

**Gallery endpoint helpers and all host-dependent URL builders now accept `GalleryHost` explicitly while transitional defaults keep existing callers and request URLs unchanged.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-14T07:45:55Z
- **Completed:** 2026-07-14T07:51:20Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `GalleryHost`-taking helpers for `api`, `myTags`, `uConfig`, `galleryPopups`, `galleryTorrents`, `popular`, `watched`, `favorites`, and `toplist` without removing current global properties.
- Parameterized all thirteen host-dependent `URLUtil` builders with a leading, transitional `GalleryHost` default.
- Eliminated every `Defaults.URL.host` read from `URLUtil` while preserving the six host-independent builders unchanged.
- Kept all 77 `NetworkingFeatureTests` passing, locking default-host request URLs and parsing behavior.

## Task Commits

1. **Task 1: Add host-taking helper functions to Defaults.URL (globals kept)** - `6082995e` (refactor)
2. **Task 2: Parameterize URLUtil builders with host: GalleryHost (transitional default)** - `4d6c7ba8` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift` - Adds nine host-taking endpoint helpers alongside the transitional globals.
- `AppPackage/Sources/AppModels/Utilities/URLUtil.swift` - Threads `GalleryHost` into every builder that previously resolved a host-derived global URL.
- `.planning/phases/08-architecture-hygiene-client-seams/08-02-SUMMARY.md` - Records implementation and parity evidence.

## Decisions Made

- Kept the existing `Defaults.URL` global properties for untouched callers while making the new helper functions require an explicit host.
- Limited `AppUtil.galleryHost` to compile-preserving default arguments; builder bodies now depend only on their `host` argument.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted verification to the available package scheme and simulator**

- **Found during:** Task 1 verification
- **Issue:** The repository-root invocation selected the app project, which has no `AppPackage-Package` scheme, and the planned `iPhone 16` simulator is not installed.
- **Fix:** Ran the package scheme from `AppPackage` and used the installed `iPhone Air` simulator on iOS 26.5 for both build and test verification.
- **Files modified:** None
- **Verification:** The package build succeeded and all 77 `NetworkingFeatureTests` passed.
- **Committed in:** No source change required.

**2. [Rule 1 - State consistency] Reconciled stale progress fields after state updates**

- **Found during:** Plan close-out
- **Issue:** The state commands advanced the plan and recorded the new metric but persisted an incorrect percentage and left the prose activity, next-plan, progress, and completed-plan fields stale.
- **Fix:** Aligned STATE frontmatter and prose to 64/76 plans (84%), recorded Plan 08-02 as the latest activity, and pointed continuity to Plan 08-03.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE frontmatter and Current Position agree with the 64 summaries and 76 plans on disk.
- **Committed in:** Plan metadata commit.

---

**Total deviations:** 2 auto-fixed (1 blocking verification-environment issue, 1 state-consistency bug).
**Impact on plan:** Production scope stayed unchanged; verification remained equivalent and close-out metadata now reflects the repository accurately.

## Issues Encountered

- The first sandboxed staging attempt could not create `.git/index.lock`; approved git operations then created both task commits with normal hooks enabled.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 08-03 through 08-06 can now pass `GalleryHost` explicitly through request and feature callers.
- Plan 08-07 can remove the transitional default after all callers migrate.
- No blockers remain.

## Self-Check: PASSED

- `Defaults+Runtime.swift` contains all nine required `GalleryHost`-taking helpers and retains the current host-derived global properties.
- `URLUtil.swift` contains thirteen `host: GalleryHost = AppUtil.galleryHost` parameters and zero `Defaults.URL.host` references.
- The six host-independent builders remain unchanged.
- The package build succeeds with SwiftLint plugins enabled.
- `NetworkingFeatureTests` passes all 77 tests across nine suites.
- Task commits `6082995e` and `4d6c7ba8` exist in git history.
- `git diff --check` passes for both task commits.
- STATE frontmatter and prose both report 64/76 plans (84%) and Plan 08-03 as next.
- Modified source contains no newly introduced TODO, FIXME, placeholder, or incomplete data-source stub.
- The changed files introduce no new network endpoint, authentication path, file-access pattern, or schema boundary.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
