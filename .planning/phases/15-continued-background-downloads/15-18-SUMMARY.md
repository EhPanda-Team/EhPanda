---
phase: 15-continued-background-downloads
plan: 18
subsystem: downloads
tags: [swift, concurrency, download-coordinator, queue-convergence, testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Deferred session reconciliation and a production-faithful single-session spy from plan 15-17"
provides:
  - "A named active-ownership convergence invariant covering every coordinator exit"
  - "Failure-path convergence for gallery deletion, user-folder deletion, and pause commits"
  - "A deterministic parameterized regression over both removal entry points and both error shapes"
affects: [continued-background-downloads, download-coordinator, queue-scheduling, session-lifecycle]

tech-stack:
  added: []
  patterns:
    - "A path that clears active ownership releases any scheduling block, notifies, and converges before returning"
    - "Filesystem failures are injected through FileManager while retaining the production store and path guard"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "Pause error exits converge unconditionally, including expiration-owned pauses, because scheduling does not start a continued-processing session and the failed gallery must not be stranded."
  - "Interrupted-download normalization is exempt from scheduling only when no active task exists and the caller deliberately requested notification without scheduling."
  - "Removal regressions assert that scheduling moved without pinning which still-queued gallery the scheduler selected."

patterns-established:
  - "Function-scoped defers remain idempotent safety nets, while catch branches explicitly release their block before convergence."
  - "A regression over an invariant is parameterized by exit path and error shape instead of duplicating branch-specific cases."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "Every active-ownership clearing exit notifies observers and reaches queue convergence before returning."
    requirement: SC1
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift#testAFailedRemovalStillConvergesTheQueue"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "ownership invariant and convergence source scans"
        status: pass
    human_judgment: false
  - id: D2
    description: "Failed gallery and user-folder removals retain queued records while scheduling, observer delivery, and the continued session remain live."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false
  - id: D3
    description: "A physical iOS 26 device keeps queue progress and the system progress card moving after a real filesystem deletion failure."
    requirement: SC1
    verification: []
    human_judgment: true
    rationale: "The Simulator cannot grant continued-processing execution or render its system progress card; the existing phase device procedure remains the backstop."

duration: 16min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 18: Active-Ownership Convergence Summary

**Every ownership-clearing exit now releases its scheduling block, notifies observers, and converges the download queue, with four deterministic removal-failure regressions**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-29T02:23:41Z
- **Completed:** 2026-07-29T02:39:35Z
- **Tasks:** 2
- **Files modified:** 10 Swift files

## Accomplishments

- Stated `ACTIVE-OWNERSHIP CONVERGENCE` once beside the coordinator ownership fields and recorded the disposition of all fifteen enumerated sites.
- Closed the gallery deletion, user-folder deletion, and pause-commit error exits without changing failure values, dequeuing failed work, or starting a new continued-processing session.
- Added a parameterized suite that covers gallery and user-folder removals across typed application and untyped foundation errors through the real storage call chain.
- Confirmed the regression's value by removing the Task 1 convergence calls locally: all four arguments failed their scheduling and post-failure observer expectations.

## Task Commits

Each task was committed atomically:

1. **Task 1: State the ownership-convergence invariant and satisfy every enumerated exit** - `bea9eef8` (fix)
2. **Task 2: Encode the invariant across ownership-clearing removal failures** - `0ea7c42e` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Defines the invariant, its failure mechanism, and forbidden and accepted interleavings.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` - Releases the active gallery's block and converges from both gallery-removal error exits.
- `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift` - Releases every contained gallery and converges from both user-folder-removal error exits.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` - Converges both pause-commit error exits and records the unconditional expiration decision.
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` - Documents reconciliation as the non-scheduling convergence disposition.
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` - Documents why no-task normalization may deliberately omit scheduling.
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` - Marks ownership installation as a test-only seam outside the clearing invariant.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Injects a behavior-preserving file manager into queued coordinator fixtures.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - Adds the deterministic named-removal failure double.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift` - Covers four failure exits with one five-part invariant.

## Decisions Made

- Pause commit errors converge even during expiration. The surrounding expiration exits already converge, the failed gallery is the work most at risk of being stranded, and scheduling alone does not violate the foreground-only session-start rule.
- `normalizeInterruptedDownloads` does not need to schedule when it clears a stale id with no active task. No task cleanup loses ownership, notification is unconditional, and its caller owns the explicit scheduling choice.
- The regression asserts only that the recorder is non-empty. In the observed runs the scheduler selected the retained `failed-first` gallery for all four arguments, but that ordering is deliberately not part of the contract.

## Reachability Finding

`writeInitialPauseRecord` and `writeSettledPauseRecord` retain throwing signatures, so the two `commitPause` catch shapes are structurally reachable through their declarations. Their current bodies contain no throwing operation. The invariant is enforced on those exits anyway so a future throwing store operation cannot silently reintroduce the ownership gap.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected the parameter type's access level**
- **Found during:** Task 2 targeted compilation
- **Issue:** Swift rejected an internal parameterized test whose argument type was declared private.
- **Fix:** Kept the case descriptor module-internal, matching the test method's visibility without widening any production API.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift`
- **Verification:** The targeted suite compiled and all four arguments passed.
- **Committed in:** `0ea7c42e`

**2. [Rule 1 - Bug] Released the test spy's live session on thrown assertions**
- **Found during:** Task 2 pre-fix sensitivity check
- **Issue:** The intentionally failing pre-fix run could leave the client spy's event stream alive while an awaited observer assertion threw, delaying test-run cleanup.
- **Fix:** Added a deferred spy expiration so every success and failure exit releases the test-only session after assertions.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift`
- **Verification:** The restored targeted suite completed cleanly with four passing arguments.
- **Committed in:** `0ea7c42e`

**3. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers reset completed phases from 14 to 13, wrote an 81 percent frontmatter value beside 189 of 190 completed plans, retained the plan 17 activity text, and labeled both new decisions with an unknown phase.
- **Fix:** Restored 14 completed phases, 99 percent progress, plan 18 activity and next-step text, and Phase 15 decision labels while preserving the handler-recorded metric and session timestamp.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap count, decisions, and session record now agree on plan 18 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 3 auto-fixed (1 blocking issue, 2 bugs)
**Impact on plan:** Test fixes made compilation and teardown deterministic, and the metadata repair kept planning state internally consistent; production scope was unchanged.

## Issues Encountered

- The expected-red pre-fix sensitivity run reported all four parameter combinations failing the missing observer emission after the convergence calls were removed. The production files were restored before verification and remained identical to Task 1's commit.
- The available iPhone Air simulator used iOS 26.5. No overlapping `xcodebuild` process was started.

## Verification

- Targeted `DownloadOwnershipConvergenceTests`: four parameterized arguments passed.
- Full `DownloadsFeatureTests`: 304 tests in 60 suites passed with three expected known issues and no unexpected failures.
- Clean `EhPanda` app-scheme build passed with SwiftLint build plugins and zero SwiftLint violations.
- Static acceptance scans found one invariant statement in the manager, seven client files referencing it, all required notification and scheduling counts, explicit block release before failure convergence, and unchanged dequeue counts.
- Prohibition scans found no timing poll in the new suite, no concurrency or SwiftLint escape hatch in touched files, and no legacy background-execution tier.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-02 and verification gap 2 are closed in production source and automated coverage.
- Phase 15 can proceed to plan 15-19, followed by re-verification and the existing physical-device progress-card checks.

## Self-Check: PASSED

- All ten modified Swift files and this summary exist.
- Task commits `bea9eef8` and `0ea7c42e` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
