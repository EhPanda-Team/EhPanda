---
phase: 15-continued-background-downloads
plan: 14
subsystem: background-processing
tags: [swift, swift-concurrency, download-coordinator, synchronization, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Session-identified expiration handling and the shared schedulable-work authority from plans 15-09 through 15-13"
provides:
  - "Per-gallery queue-intent generations that invalidate stale expiration-owned pauses"
  - "Post-abandonment observer, scheduler, and continued-session convergence"
  - "An explicitly releasable blocking-runner fixture with fixture-owned teardown"
affects: [continued-background-downloads, expiration-reentrancy, download-coordinator, test-fixtures]

tech-stack:
  added: []
  patterns:
    - "Expiration work presents both session ownership and a per-gallery intent generation before post-suspension writes"
    - "Superseded mutations leave their blocking scope before entering observer and scheduler convergence"
    - "Blocking async fixtures park on Mutex-protected checked continuations and expose idempotent synchronous teardown"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "Queue-intent generation is distinct from active-task generation and advances only when a user action writes fresh queue intent."
  - "A superseded expiration pause converges only after its scheduling block is lifted, completing the queue-mobilizing user action that superseded it."
  - "The blocking fixture releases on cancellation by default, while an explicit opt-out preserves a deterministic interleave window for follow-up regressions."

patterns-established:
  - "Reentrant expiration ownership: session id plus gallery intent generation guards every write after a real suspension."
  - "Fixture lifecycle ownership: one cleanUp call releases parked work before removing its temporary directory."

requirements-completed: [SC2, SC3]

coverage:
  - id: D1
    description: "Expiration-owned pauses abandon post-suspension writes when the live session or gallery queue-intent generation has moved."
    requirement: SC3
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "static intent-writer, ownership-construction, and public pause-signature acceptance checks"
        status: pass
    human_judgment: false
  - id: D2
    description: "A superseded expiration pause notifies observers, schedules queued work, and reconciles the continued session after its scheduling block is removed."
    requirement: SC2
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false
  - id: D3
    description: "The blocking coordinator fixture parks on a test-owned token, releases on cancellation by default, and tears down parked work and its directory through one idempotent call."
    requirement: SC3
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "fixture teardown-count, polling-removal, and file-length acceptance checks"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 14: Expiration Reentrancy and Blocking-Fixture Lifecycle Summary

**Expiration pauses now reject stale queue writes by session and user-intent generation, while deterministic blocking fixtures own their release and teardown**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-28T16:46:52Z
- **Completed:** 2026-07-28T16:57:51Z
- **Tasks:** 2
- **Files modified:** 7 Swift files

## Accomplishments

- Added a per-gallery queue-intent generation and advanced it before every resume, retry, page retry, and enqueue intent write.
- Bound expiration-owned pauses to both their session and captured intent generation, abandoning stale writes and completing observer, scheduler, and session convergence after the block is lifted.
- Replaced the blocking fixture's cancellation-polling runner with a `Mutex`-protected checked-continuation control whose idempotent cleanup releases work before removing its directory.

## Task Commits

Each task was committed atomically:

1. **Task 1: Queue-intent generations and an expiration pause that cannot outlive its justification** - `403458c4` (fix)
2. **Task 2: A blocking fixture that parks on a test-owned token instead of leaking** - `a02e4182` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Stores and advances total per-gallery queue-intent generations.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` - Guards expiration pause commits and converges a superseding user action after leaving the blocked scope.
- `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` - Advances intent generations before retry and page-retry writes.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` - Advances intent generations before enqueue writes.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Captures per-gallery expiration ownership immediately before pausing.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Provides the explicit blocking-runner rendezvous and fixture-owned cleanup.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Uses the unified cleanup path in all ten blocking-fixture cases.

## Decisions Made

- Kept queue-intent generation independent from active-task generation: the former names the latest user-authored intent, while the latter names scheduled execution.
- Kept the public `pause(gid:)` signature and user-pause semantics unchanged; ownership checks are inert unless the expiration handler supplies an ownership value.
- Treated superseded expiration convergence as deferred completion of the queue-mobilizing user action, not as a new background-originated session start.
- Used one checked continuation with all rendezvous state protected by `Mutex`; cancellation records an observable signal and releases by default, while tests may deliberately hold the park open.

## Accepted residual

- **Guarded points:** Expiration ownership is checked after the indexed-record read and again after the awaited cancellation of the active download task, before the corresponding destructive or settled writes.
- **Unguarded point:** The first write helper still has one queue-store hop between clearing in-memory intent and removing persisted queue state. A user action that interleaves inside that single hop remains last-writer-wins.
- **Why accepted:** Closing this adjacent actor hop requires transactional semantics across persisted storage or a separate atomic bulk transition. The current residual leaves the queue and card in one consistent paused state, loses or duplicates no completed work, and a second user tap recovers. This is a documented deferral, not an atomicity claim; the unbounded task-cancellation suspension that produced the reported defect is guarded.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted verification to the installed non-interactive Xcode environment**
- **Found during:** Task 1 verification
- **Issue:** The plan's named iPhone 17 simulator is not installed, and sandboxed Xcode cannot access Simulator and package-cache services.
- **Fix:** Used the installed iPhone Air simulator by id, the repository CI's established `-skipMacroValidation -skipPackagePluginValidation` flags, and approved Xcode execution. The project, scheme, test plan, filter, and SwiftLint plugins were unchanged.
- **Files modified:** None
- **Verification:** The complete `DownloadsFeatureTests` run and clean app-scheme build exited 0.
- **Committed in:** Not applicable (verification-command adaptation only)

**2. [Rule 3 - Blocking] Made the idempotent release continuation type explicit**
- **Found during:** Task 2 verification
- **Issue:** Swift could not infer the contextual type of the `nil` returned when the blocking control had already been released.
- **Fix:** Declared the closure result as `CheckedContinuation<Void, Never>?`, preserving the intended idempotent state transition without suppression or unsafe concurrency annotations.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`
- **Verification:** The test target compiled and the complete `DownloadsFeatureTests` run passed.
- **Committed in:** `a02e4182`

**3. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers advanced the plan but rewrote the frontmatter to 13 completed phases and 81 percent, left the current-position prose on plan 13, and labeled the new decisions with an unknown phase.
- **Fix:** Restored the authoritative 14 completed phases and 99 percent, advanced the prose to plan 14 completion, refreshed the activity description, and labeled the decisions as Phase 15.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap counts, and session record now agree on plan 14 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking)
**Impact on plan:** The adjustments were necessary to compile, verify, and record the specified design accurately; none changed product behavior or scope.

## Issues Encountered

- The first sandboxed Xcode test invocation could not access Simulator and package-cache services; the required command was rerun with approved Xcode permissions.

## Verification

- Full `DownloadsFeatureTests`: 301 tests across 58 suites passed, including the existing expiration parity, pause reconciliation, scheduling, and background-execution invariant coverage; three pre-existing known issues remained recorded by the suite.
- Clean `EhPanda` app-scheme build: passed with SwiftLint build plugins and zero violations.
- Intent generation gates: all four user intent writers advance the gallery generation, expiration constructs ownership, and the public pause signature remains unchanged.
- Fixture gates: all ten blocking-fixture cases defer through `cleanUp()`, the runner contains no cancellation polling loop, and both touched test files remain below the 1,000-line limit.

## Known Stubs

None.

## Threat Flags

None - the plan changes actor-local mutation ownership and test-fixture lifecycle only; it adds no network endpoint, authentication path, file-access trust boundary, or schema surface beyond the threat model.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-15 can use `BlockingRunnerControl` start and cancellation rendezvous to stage the expiration/user-action interleave without polling.
- The physical-device card-cancel/resume behavior remains the planned backstop; plan 15-15 owns the deterministic regression coverage.
- The owner-pending background-execution accessor disposition remains assigned to plan 15-16 and was intentionally untouched.

## Self-Check: PASSED

- All seven modified Swift files and this summary exist.
- Task commits `403458c4` and `a02e4182` exist.
- The accepted residual is recorded and the summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
