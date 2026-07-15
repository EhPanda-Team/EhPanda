---
phase: 09-correctness-structured-error-handling
plan: 09
subsystem: parser
tags: [swift, parser-feature, optional-try, typed-throws, error-handling]

requires:
  - phase: 09-08
    provides: AppTools optional-failure classification and adjacent just-cause convention
provides:
  - Semantic classification and adjacent just-cause documentation for all 42 surviving ParserFeature optional-try expressions
  - Typed AppError mapping for the MPV JSON whole-parse failure
  - Verified parser fixture parity across list, detail, image, profile, shared, and torrent parsing
affects: [09-10, 09-11, structured-error-handling, optional-try]

tech-stack:
  added: []
  patterns:
    - Optional parser sub-fields retain their established nil, empty, row-skip, or candidate-rejection fallback
    - Genuine whole-parse decoding failures map untyped framework errors to AppError.parseFailed

key-files:
  created: []
  modified:
    - AppPackage/Sources/ParserFeature/Parser+List.swift
    - AppPackage/Sources/ParserFeature/Parser+Detail.swift
    - AppPackage/Sources/ParserFeature/Parser+Shared.swift
    - AppPackage/Sources/ParserFeature/Parser+Profile.swift
    - AppPackage/Sources/ParserFeature/Parser+Image.swift
    - AppPackage/Sources/ParserFeature/Parser+Torrent.swift

key-decisions:
  - "Keep 42 genuine ParserFeature try? expressions as documented per-field, per-row, or per-candidate degradations so malformed optional HTML does not replace the parser's established result classification."
  - "Convert MPV JSON deserialization to a typed AppError boundary because invalid JSON fails the whole parse and already maps to parseFailed."
  - "Treat Parser+Profile.swift's BrowsingCountry? match as an Optional-type substring, not an optional-try expression."

patterns-established:
  - "Every surviving ParserFeature optional-try expression has an immediately adjacent comment naming its exact behavior-preserving fallback."
  - "Untyped Foundation decoding errors are caught at the framework boundary and rethrown without response data as AppError.parseFailed."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: All 25 Parser+List optional-try expressions retain documented list, row, field, and candidate fallback behavior.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "ParserFeatureTests on iPhone Air iOS 26.5"
        status: pass
    human_judgment: false
  - id: D2
    description: The remaining ParserFeature sites are classified as 17 documented survivors, one typed whole-parse conversion, and one raw-survey Optional-type false positive.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "ParserFeatureTests on iPhone Air iOS 26.5"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 09: ParserFeature Optional Failure Sweep Summary

**ParserFeature now distinguishes 42 intentional HTML-degradation survivors from one typed MPV JSON whole-parse failure while all 31 parser fixture tests remain unchanged.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-15T08:27:00Z
- **Completed:** 2026-07-15T08:36:53Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Classified and documented all 25 `Parser+List.swift` optional-try expressions without changing list, row-skip, missing-field, or title-candidate behavior.
- Classified the remaining parser survey as 17 documented optional degradations, one MPV JSON whole-parse conversion, and one `BrowsingCountry?` Optional-type false positive.
- Mapped MPV JSON framework failures to `.parseFailed` through a typed `AppError` boundary without exposing response content.
- Passed all 31 tests in 10 ParserFeature test suites on iPhone Air iOS 26.5 after the complete sweep.

## Task Commits

Each task was committed atomically:

1. **Task 1: Parser+List.swift survivor sweep** - `83f274ef` (refactor)
2. **Task 2: Remaining ParserFeature sweep** - `ccffb320` (refactor)

## Files Created/Modified

- `AppPackage/Sources/ParserFeature/Parser+List.swift` - Documents 25 intentional display-mode, list, row, field, and candidate degradations.
- `AppPackage/Sources/ParserFeature/Parser+Detail.swift` - Documents detail-candidate, preview-config, and optional archive-link fallbacks.
- `AppPackage/Sources/ParserFeature/Parser+Shared.swift` - Documents optional regex, script-date, and text-rating fallbacks.
- `AppPackage/Sources/ParserFeature/Parser+Profile.swift` - Records that the raw survey match is an Optional type rather than an optional-try expression.
- `AppPackage/Sources/ParserFeature/Parser+Image.swift` - Converts MPV JSON deserialization to typed `.parseFailed` propagation.
- `AppPackage/Sources/ParserFeature/Parser+Torrent.swift` - Documents malformed torrent-date row skipping.

## Decisions Made

- Kept 42 genuine optional-try expressions because each preserves an established per-field, per-row, or per-candidate fallback. None silently converts a successful whole parse into an unreported failure.
- Kept the detail-candidate probes optional so a malformed candidate continues into the existing copyright, expunged, response-error, or generic parse-failure classification instead of bypassing that precedence.
- Converted MPV JSON deserialization because invalid JSON is a genuine whole-parse failure. The nested framework catch maps the untyped Foundation error to payload-free `.parseFailed`, while the outer typed boundary guarantees only `AppError` escapes.
- Classified the apparent `Parser+Profile.swift` site as a raw-text survey false positive: `BrowsingCountry?` is an Optional type declaration and contains no `try?` expression.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the ParserFeature optional-try inventory**

- **Found during:** Task 2 (remaining ParserFeature sweep)
- **Issue:** The 44 raw text matches included `BrowsingCountry?` in `Parser+Profile.swift`, so the plan's 19-site second task represented 18 executable `try?` expressions plus one Optional-type substring.
- **Fix:** Classified the false positive explicitly and used a lexical boundary check to verify 43 genuine original expressions: 42 documented survivors and one converted whole-parse failure.
- **Files modified:** `AppPackage/Sources/ParserFeature/Parser+Profile.swift`
- **Verification:** Boundary-aware source scan plus successful ParserFeatureTests.
- **Committed in:** `ccffb320`

**2. [Rule 1 - Bug] Reconciled generated planning progress**

- **Found during:** Final state update
- **Issue:** The state updater advanced to Plan 09-10 but wrote 54% into frontmatter and retained Plan 09-08 activity and 88/91 prose progress.
- **Fix:** Reconciled both state representations to 89/91 plans (98%), completed Plan 09-09, and next Plan 09-10.
- **Files modified:** `.planning/STATE.md`
- **Verification:** Compared the nine Phase 09 summaries and the 91-plan milestone total against both state representations.
- **Committed in:** Final metadata commit

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** The complete raw survey remains accounted for, source documentation distinguishes Swift syntax from a substring match, and planning metadata matches completed work. Runtime parser behavior is unchanged.

## Issues Encountered

- The plan's package test command required the `AppPackage` working directory and an explicit installed simulator destination. Verification used iPhone Air iOS 26.5.
- The first typed-throws build showed that untyped `JSONSerialization` errors cannot escape directly from `do throws(AppError)`. A nested catch now performs the required error mapping at the Foundation boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ParserFeature contributes 42 owner-reviewable, adjacent-commented survivors to the Phase 11 optional-try lint ratchet.
- Parser fixture behavior is verified and ready for the remaining Phase 09 module sweeps; there are no blockers.

## Self-Check: PASSED

- Task commits `83f274ef` and `ccffb320` exist.
- All 31 ParserFeature tests in 10 suites passed on iPhone Air iOS 26.5.
- All 42 surviving executable `try?` expressions have immediately adjacent just-cause comments.
- The one genuine whole-parse decoding failure uses `do throws(AppError)` and maps to payload-free `.parseFailed`.
- No new SwiftLint suppression, dependency, stub, or threat surface was introduced.
- All six scoped source files and this summary exist.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
