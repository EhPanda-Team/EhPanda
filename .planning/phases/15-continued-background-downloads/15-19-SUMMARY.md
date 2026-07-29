---
phase: 15-continued-background-downloads
plan: 19
subsystem: security
tags: [swift, oslog, privacy, download-client, invariant-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Neutral system progress-card identity and the completed download coordinator from plans 15-01 through 15-18"
provides:
  - "DownloadClient logs with titles removed, identifiers hash-masked, and gallery-derived diagnostics private"
  - "A non-vacuous invariant suite that rejects public identity fields and deleted operational identity logs"
  - "A recorded 46-statement logging baseline and audited exclusions outside the gallery-aware client boundary"
affects: [continued-background-downloads, download-client, unified-logging, diagnostics, security-review]

tech-stack:
  added: []
  patterns:
    - "Operational facts remain public while values derived from the user's library are private"
    - "Gallery identifiers use private hash masking so diagnostic correlation survives without disclosure"
    - "Source-scanning invariants prove both a privacy prohibition and the continued presence of operational signals"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift

key-decisions:
  - "Gallery titles are removed from completion and enqueue logs rather than merely privatized because neither operational message needs content names."
  - "Gallery identifiers remain present with private hash masking so one download can still be correlated across enqueue, pause, resume, failure, and completion."
  - "Raw errors, localized descriptions, and rejected-response snippets are uniformly private inside DownloadClient because paths, URLs, and remote bodies can carry gallery identity."
  - "The invariant is scoped to DownloadClient; two BackgroundProcessingClient fields remain public after confirming that no gallery-derived value is in scope."

patterns-established:
  - "A logging privacy sweep preserves message severity, call sites, counts, modes, attempts, and page indices while reclassifying only identity-bearing payloads."
  - "A source invariant refuses an empty scan, requires a known member, assembles banned tokens dynamically, and checks positive operational evidence."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "DownloadClient emits no gallery title, unmasked gallery identifier, raw error description, or response-body prefix as a public unified-log field."
    requirement: SC1
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testNoDownloadLogPublishesGalleryIdentity"
        status: pass
      - kind: other
        ref: "module-wide interpolation and logger-count acceptance scans"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false
  - id: D2
    description: "Eight identity-bearing operational logs remain present and correlate galleries through private hash masking."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift#testDownloadIdentityLogsStayHashMasked"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests -parallel-testing-enabled NO"
        status: pass
    human_judgment: false
  - id: D3
    description: "A physical iOS 26 sysdiagnose collected after downloads contains no gallery title or unmasked identifier from DownloadClient."
    requirement: SC1
    verification: []
    human_judgment: true
    rationale: "Simulator tests and source scans prove field classification, but only the existing physical-device procedure can inspect a real collected log archive."

duration: 28min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 19: Download Log Privacy Summary

**Gallery identity is removed or hash-masked across all 46 DownloadClient log statements, with a permanent two-sided source invariant preventing disclosure or silent log deletion**

## Performance

- **Duration:** 28 min
- **Started:** 2026-07-29T02:44:04Z
- **Completed:** 2026-07-29T03:12:12Z
- **Tasks:** 3
- **Files modified:** 18 Swift files

## Accomplishments

- Removed gallery titles from completion and enqueue messages, then hash-masked all eight remaining gallery-identifier fields across execution, public API, and scheduling logs.
- Reclassified 35 raw-error or localized-description fields and the rejected-response body prefix as explicitly private while preserving public operational context.
- Added a permanent, non-vacuous invariant suite that rejects all four banned public interpolation shapes and also rejects deleting the masked operational logs.
- Preserved the recorded 46-statement logging baseline exactly and confirmed the 21-row continued-processing API coverage matrix remains complete.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove gallery titles and mask identifiers in the three cited files** - `073c2ce4` (fix)
2. **Task 2: Reclassify the module's remaining error, description, and response-body disclosures** - `d1924834` (fix)
3. **Task 3: Add a permanent scan that fails if the disclosure returns** - `45370eec` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` - Scans every DownloadClient Swift source, refuses a vacuous scan, rejects banned public fields, and requires masked identity logs and their operational messages.
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` - Removes the completion title and masks completion, failure, and partial-failure identifiers.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` - Removes the enqueue title, masks enqueue and delete identifiers, and privatizes operation errors.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` - Masks expiration, pause, and resume identifiers and privatizes scheduling errors.
- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift` - Privatizes read errors and the remote response-body prefix.
- `AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift` - Keeps retry operation and attempt fields public while privatizing localized errors.
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` - Privatizes store errors that can contain title-bearing folder paths.
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` - Privatizes path-guard and folder-operation errors.
- `AppPackage/Sources/DownloadClient/DownloadBackgroundTaskStore.swift`, `DownloadClient+BackgroundDownloads.swift`, `DownloadClient+Cache.swift`, `DownloadClient+ExecutionSupport.swift`, `DownloadClient+Folders.swift`, `DownloadClient+PageDownload.swift`, `DownloadClient+Persistence.swift`, `DownloadClient+RetryHelpers.swift`, `DownloadClient.swift`, and `DownloadQueueStore.swift` - Privatize their remaining raw diagnostic error values.

## Decisions Made

- Completion and enqueue omit titles entirely. Even a private title would expose content identity during an attached debugging session, while page count and a masked identifier already provide the required operational signal.
- All eight gallery identifiers use `.private(mask: .hash)`, giving operators a stable correlation token without writing the identifier itself into collected diagnostics.
- The module applies one uniform privacy rule to raw errors and localized descriptions. Filesystem paths embed gallery titles, and networking or persistence errors can carry gallery-specific URLs or paths, so per-site exceptions would be fragile.
- The rejected-response snippet remains available but private because it is valuable rejection evidence and can contain the remote gallery title.

## Audited Exclusions

The invariant deliberately stops at `AppPackage/Sources/DownloadClient`. The two public fields in `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` remain unchanged:

- The registration failure's task identifier contains a bundle identifier plus a newly minted UUID, not gallery identity.
- The submission failure contains a system scheduler error produced before any gallery value is in scope.

Applying a gallery-identity rule outside the gallery-aware client boundary would require exceptions without increasing protection.

## Logging Baseline

Task 2 began from 36 publicly classified interpolations in DownloadClient. It privatized 28 fields after Task 1 had already privatized eight error or description fields. The final module has 44 explicit private classifications, including eight hash-masked identifiers, while these statement counts remain unchanged:

| File | Logger calls |
|---|---:|
| `DownloadClient+Execution.swift` | 5 |
| `DownloadClient+PublicAPI.swift` | 5 |
| `DownloadClient+Scheduling.swift` | 5 |
| `DownloadClient+Folders.swift` | 4 |
| `DownloadStore.swift` | 4 |
| `DownloadClient+ContinuedSession.swift` | 3 |
| `DownloadClient+Networking.swift` | 3 |
| `DownloadBackgroundTaskStore.swift` | 2 |
| `DownloadClient+BackgroundDownloads.swift` | 2 |
| `DownloadClient+ResponseValidation.swift` | 2 |
| `DownloadClient+RetryHelpers.swift` | 2 |
| `DownloadClient.swift` | 2 |
| `DownloadStore+Operations.swift` | 2 |
| `DownloadClient+Cache.swift` | 1 |
| `DownloadClient+ExecutionSupport.swift` | 1 |
| `DownloadClient+PageDownload.swift` | 1 |
| `DownloadClient+Persistence.swift` | 1 |
| `DownloadQueueStore.swift` | 1 |
| **Total** | **46** |

## Deliberate-Break Verification

- Temporarily changing the enqueue identifier back to public made `testNoDownloadLogPublishesGalleryIdentity` name `DownloadClient+PublicAPI.swift` as an offender; the positive test also observed only seven hash-masked fields.
- Temporarily deleting the completion log made `testDownloadIdentityLogsStayHashMasked` observe seven masked fields and report the missing `Download completed` operational message.
- Both source changes were restored before Task 3 verification and never committed.

## Coverage Matrix Validation

`.planning/phases/15-continued-background-downloads/COVERAGE.md` remains unchanged. All 21 capability rows have a decision, every opt-out has a reason, and this round added no continued-processing capability: it changed only log classification and its enforcement.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restricted the scan helper to its private result type**
- **Found during:** Task 3 targeted compilation
- **Issue:** Swift rejected `scannedFiles()` because its result exposed the suite's private `ScannedFile` type beyond the method's access level.
- **Fix:** Declared `scannedFiles()` private, preserving the helper's intended suite-only scope.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift`
- **Verification:** The targeted invariant suite compiled and both tests passed.
- **Committed in:** `45370eec`

**2. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers computed the frontmatter percentage from completed phases while displaying plan completion elsewhere, retained plan 18 activity text and next steps, and labeled each new decision with an unknown phase.
- **Fix:** Restored 100 percent plan progress, plan 19 activity and re-verification guidance, and explicit Phase 15 decision labels while preserving the handler-recorded metric and session timestamp.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap plan count, decisions, and session record now agree on plan 19 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed (1 blocking issue, 1 metadata bug)
**Impact on plan:** The access correction was required for compilation, and the metadata repair kept planning state internally consistent; neither changed production behavior or test scope.

## Issues Encountered

- A default parallel full-suite run reproduced the pre-existing `DownloadDeleteConvergenceTests.testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving()` observer-timeout flake at line 54, with helper evidence stating that it timed out waiting for the vanished-record deletion observer emission. Plan 15-17 already records this scheduler-sensitive parallel failure. The mandated serialized rerun passed all 306 tests in 61 suites with only three known issues.
- The first deliberate-break run wedged while finalizing its result bundle after correctly reporting the privacy failures. The invocation was terminated, the source was restored, and all subsequent targeted and full verification ran serially.
- The requirements updater found no `SC1` or `SC2` entries, as expected: Phase 15 maps no requirement IDs and uses ROADMAP success-criterion labels as its scope contract.

## Verification

- Targeted `DownloadLogPrivacyInvariantTests`: two tests in one suite passed.
- Full serialized `DownloadsFeatureTests`: 306 tests in 61 suites passed with three expected known issues and no unexpected failures.
- Clean `EhPanda` app-scheme build passed in 100.766 seconds with SwiftLint build plugins and zero SwiftLint violations.
- Module scans report zero public raw-error, localized-description, title, or gallery-identifier interpolations; 44 explicit private classifications; eight hash-masked identifiers; and exactly 46 logger calls.
- The new suite contains both required test cases, six non-vacuity requirements, two compile-time path references, and no SwiftLint or concurrency escape hatch.
- `git diff --check` passed, and no generated or runtime file remains untracked.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-03 and verification gap 3 are closed in source and automated coverage.
- Phase 15's code plans are complete. Re-verification and the existing physical-device sysdiagnose and progress-card procedures remain the final owner checks.

## Self-Check: PASSED

- All 18 modified Swift files and this summary exist.
- Task commits `073c2ce4`, `d1924834`, and `45370eec` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
