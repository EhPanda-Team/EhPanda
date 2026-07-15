---
phase: 09-correctness-structured-error-handling
plan: 11
subsystem: error-handling
tags: [swift, optional-try, structured-error-handling, swiftlint]

# Dependency graph
requires:
  - phase: 09-correctness-structured-error-handling
    provides: Reviewed optional-failure classification and adjacent-comment convention from Plans 05 through 10
provides:
  - Documented JSONValue type probes and final view/markdown optional fallbacks
  - Complete 128-expression residual optional-try audit across AppPackage sources
  - Green full package suite and SwiftLint plugin phase gate
affects: [phase-11-optional-try-lint, error-handling, lint-capstone]

# Tech tracking
tech-stack:
  added: []
  patterns: [documented type probe, presentation fallback, phase-wide residual audit]

key-files:
  created:
    - .planning/phases/09-correctness-structured-error-handling/09-11-SUMMARY.md
  modified:
    - AppPackage/Sources/AppModels/Persistence/JSONValue.swift
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift
    - AppPackage/Sources/AppComponents/PreviewImageView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/MarkdownExt/MarkdownUtil.swift
    - AppPackage/Sources/DetailFeature/Components/LinkedText.swift

key-decisions:
  - "Keep JSONValue's six sequential decode attempts as type probes because decoding failure is the intended fall-through control flow."
  - "Keep the five view and markdown failures internal because each has an existing behavior-preserving text, metadata, validation, or no-analysis fallback."
  - "Treat 128 actual optional-try expressions across 34 source files as the audited residual; the BrowsingCountry? Optional type is not an optional-try expression."

patterns-established:
  - "Every surviving optional-try expression has an adjacent comment naming why failure may degrade to a default."
  - "Phase-wide source audits distinguish the try? operator from Optional type spellings before counting residuals."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: "JSONValue type probes and final view/markdown optional fallbacks retain behavior with explicit just-cause documentation."
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:AppModelsTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every residual optional-try expression is documented and the complete package passes with SwiftLintPlugin active."
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 11: Optional Failure Sweep Phase Gate Summary

**All 128 surviving optional-try expressions now carry adjacent just-cause documentation, while JSONValue type probing and every view/markdown fallback retain behavior parity under a green full-suite and SwiftLint gate.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-15T08:49:00Z
- **Completed:** 2026-07-15T08:56:42Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Documented all six sequential JSONValue decode probes without replacing their deliberate fall-through control flow.
- Classified the final five view and markdown sites as optional styling, metadata, Live Text, URL-validation, or link-detection fallbacks without changing rendered behavior.
- Audited 128 actual optional-try expressions across 34 source files; every expression has an adjacent just-cause comment.
- Confirmed Phase 09 added no SwiftLint suppression, left `optional_try` commented, and passed the complete package suite with SwiftLintPlugin active.

## Task Commits

Each task was committed atomically:

1. **Task 1: JSONValue type probes and remaining view/markdown survivors** - `2d646c83` (refactor)
2. **Task 2: Residual audit, full suite, and SwiftLint gate** - `b98d87d0` (chore, verification-only commit)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Persistence/JSONValue.swift` - Documents six ordered scalar/collection type probes.
- `AppPackage/Sources/AppComponents/TagSuggestionView.swift` - Documents literal-text fallback for malformed markdown styling.
- `AppPackage/Sources/AppComponents/PreviewImageView.swift` - Documents path-only cache-key fallback when file metadata is unavailable.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Documents skipping optional Live Text analysis when a local page cannot be read.
- `AppPackage/Sources/MarkdownExt/MarkdownUtil.swift` - Documents invalid-URL fallback when detector construction fails.
- `AppPackage/Sources/DetailFeature/Components/LinkedText.swift` - Documents unlinked-text fallback when link detection is unavailable.

## Residual Optional-Try Audit

The source-aware audit counted the `try?` operator in code, excluding comments and Optional type names. Total: **128 expressions in 34 files**.

| Count | File | Justification category |
|---:|---|---|
| 1 | `AppComponents/PreviewImageView.swift` | Optional cache-invalidation metadata |
| 1 | `AppComponents/TagSuggestionView.swift` | Markdown styling with literal-text fallback |
| 6 | `AppModels/Persistence/JSONValue.swift` | Ordered JSON representation type probes |
| 13 | `AppTools/DataCache.swift` | Cache probes, advisory metadata, and best-effort housekeeping |
| 1 | `AppTools/Defaults.swift` | Optional persisted-value decoding |
| 3 | `AppTools/Extensions.swift` | Optional encoding, decoding, and URL-detection contracts |
| 1 | `DetailFeature/Components/LinkedText.swift` | Optional link-detection enrichment |
| 1 | `DownloadClient/DownloadClient+BackgroundDownloads.swift` | Idempotent staged-file cleanup |
| 1 | `DownloadClient/DownloadClient+Cache.swift` | Best-effort cache eviction |
| 3 | `DownloadClient/DownloadClient+ExecutionSupport.swift` | Cleanup and optional persistence support |
| 3 | `DownloadClient/DownloadClient+Networking.swift` | Rejected-file cleanup and deferred handle closing |
| 1 | `DownloadClient/DownloadClient+PageDownload.swift` | Opportunistic cadence persistence |
| 1 | `DownloadClient/DownloadClient+PersistenceNormalize.swift` | Reusable-manifest probe |
| 1 | `DownloadClient/DownloadClient+PublicAPI.swift` | Optional manifest reuse |
| 4 | `DownloadClient/DownloadClient+ResponseValidation.swift` | Response-content and DOM probes |
| 3 | `DownloadClient/DownloadClient+ResponseValidationHelpers.swift` | Fingerprint, DOM, and file-metadata probes |
| 2 | `DownloadClient/DownloadClient.swift` | Optional remote metadata and local acceleration |
| 2 | `DownloadClient/DownloadStore+Operations.swift` | Corruption validation probes |
| 14 | `DownloadClient/DownloadStore.swift` | Advisory metadata, cleanup, and validation fallbacks |
| 1 | `FileClient/TagTranslation+ChtConverted.swift` | Optional Chinese-conversion fallback |
| 4 | `ImageClient/ImageClient.swift` | Optional cache read, prefetch, cleanup, and population |
| 4 | `LibraryClient/LibraryClient.swift` | Cache miss, size, and housekeeping fallbacks |
| 4 | `LogsClient/LogsClient.swift` | Per-line decode, missing-directory, and close cleanup fallbacks |
| 1 | `MarkdownExt/MarkdownUtil.swift` | URL-validation probe |
| 2 | `NetworkingFeature/Request+Detail.swift` | Optional greeting and funds enrichment |
| 1 | `NetworkingFeature/Request.swift` | Optional HTML repair fallback |
| 13 | `ParserFeature/Parser+Detail.swift` | Per-field and per-candidate detail degradation |
| 25 | `ParserFeature/Parser+List.swift` | Per-row and per-field list degradation |
| 3 | `ParserFeature/Parser+Shared.swift` | Regex, date, and text-rating optional fields |
| 1 | `ParserFeature/Parser+Torrent.swift` | Malformed-row date rejection |
| 1 | `ReadingFeature/ReadingView.swift` | Optional Live Text local-file probe |
| 4 | `SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift` | Best-effort diagnostic read and persistence |
| 1 | `SettingFeature/AppActivityLogs/AppActivityLogsReducer.swift` | Empty historical-log fallback |
| 1 | `SystemNotificationExt/View+Toast.swift` | Cancellation-only toast sleep |

## Decisions Made

- Preserved the sequential JSONValue probe chain: replacing it with repeated `do/catch` blocks would obscure that type mismatches are expected branch selection, not actionable failures.
- Preserved the final five UI/markdown contracts because their callers already define a parity-sensitive fallback and none represents a user-actionable primary failure.
- Counted operators with a source-aware word-boundary scan. This avoids treating `BrowsingCountry?` as `try?`, matching the earlier Parser audit decision.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - State metadata] Reconciled stale progress fields written by the state handlers**

- **Found during:** Plan metadata finalization
- **Issue:** The handlers advanced the phase to verification but left the prose position on Plan 09-10, wrote 62% despite 91/91 completed plans, and labeled new decisions as Phase `?`.
- **Fix:** Reconciled frontmatter, prose position, progress, next action, and the two new decision labels with the completed summary inventory.
- **Files modified:** `.planning/STATE.md`
- **Verification:** Re-read the updated state fields against the 11 Phase 09 summaries and 91/91 milestone plan count.

---

**Total deviations:** 1 auto-fixed (1 Rule 1)
**Impact on plan:** Documentation-only correction; no source behavior or scope changed.

## Issues Encountered

- The plan's package command was initially invoked from the repository root, where the Xcode project does not expose `AppPackage-Package`. Running from `AppPackage/` with the established iPhone Air, iOS 26.5 destination passed.
- Restricted sandbox access could not reach CoreSimulator services. Re-running the same required commands with approved simulator access succeeded.

## Known Stubs

None. No production behavior or dependency endpoint was added.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 09 is ready for verification: the complete package suite and SwiftLintPlugin gate are green.
- Phase 11 can enable `optional_try` against the explicit 128-expression owner-review inventory while preserving the D-03 exception policy.

## Self-Check: PASSED

- All six modified source files exist.
- Task commits `2d646c83` and `b98d87d0` exist in git history.
- All 61 AppModels tests passed with one expected known issue; the complete package suite passed.
- Every actual optional-try expression in `AppPackage/Sources` has an adjacent just-cause comment.
- Phase 09 added zero `// swiftlint:disable` lines in source, and `.swiftlint.yml` still comments out `optional_try`.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
