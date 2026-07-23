---
phase: 13-deep-link-hardening
plan: 01
subsystem: deep-link-routing
tags: [swift, foundation-url, swift-testing, input-validation]

requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Pure helper namespace convention in AppTools
  - phase: 11-infra-refactor-lint-capstone
    provides: Error-level SwiftLint rules and parallel Swift Testing conventions
provides:
  - Pure GalleryURLParser with exact host matching and optional failure
  - Normalized gallery route facts for gallery, single-page, and comment links
  - AppToolsTests target registered in the default unit test plan
affects: [13-03-urlclient-migration, deep-link-routing, comments-links, reading-links]

tech-stack:
  added: []
  patterns: [pure parser namespace, closed host allowlist, parameterized Swift Testing fixtures]

key-files:
  created:
    - AppPackage/Sources/AppTools/GalleryURLParser.swift
    - AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift
    - AppPackage/Tests/AppToolsTests/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan

key-decisions:
  - "GalleryURLParser.Route carries normalized url, gid, pageIndex, commentID, and isGalleryImageURL as the complete call-site migration contract."
  - "Recognized hosts are derived from Defaults.URL.ehentai/exhentai and their computed www variants, then matched exactly and case-insensitively."
  - "Single-page routes require the existing gid-page token shape; a non-decimal page suffix preserves the gid with a nil pageIndex."

patterns-established:
  - "Deep-link parsing is a pure AppTools namespace with no dependency-key ceremony."
  - "External URL host validation uses a closed exact-match set rather than absolute-string scanning."

requirements-completed: [SC-1, SC-3]

coverage:
  - id: D1
    description: "GalleryURLParser safely normalizes and parses supported gallery links while rejecting spoofed or malformed input."
    requirement: SC-1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift#parsesGalleryRoute and rejectsInvalidGalleryRoute"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "The new AppToolsTests target executes in the default FeatureTests plan with exhaustive parser and MPV coverage."
    requirement: SC-3
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:AppToolsTests -skipMacroValidation"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false

duration: 12 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 01: Gallery URL Parser Summary

**Exact-host URLComponents parsing with normalized app-scheme routes, nil-on-failure validation, and a 21-case Swift Testing matrix**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-23T01:47:09Z
- **Completed:** 2026-07-23T01:59:09Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Replaced spoofable absolute-string recognition with an exact, case-insensitive allowlist derived from the existing E-Hentai and ExHentai URL anchors.
- Added a single optional parser contract for `/g/`, `/s/`, and `#c` route facts, including internal `ehpanda`-to-`https` normalization and decimal gallery-ID validation.
- Registered a lint-covered AppToolsTests module in the default test plan and proved 21 accepted, rejected, and MPV cases; the full unit plan remains green.

## Task Commits

Each task was committed atomically; the TDD task has separate RED and GREEN commits:

1. **Task 1 RED: Add failing parser behavior test and test infrastructure** - `0c076035` (test)
2. **Task 1 GREEN: Implement the hardened parser** - `6264cc12` (feat)
3. **Task 2: Expand the exhaustive parser matrix** - `69603bc6` (test)

## Files Created/Modified

- `AppPackage/Sources/AppTools/GalleryURLParser.swift` - Pure URL-to-route parser and normalized Route value.
- `AppPackage/Tests/AppToolsTests/GalleryURLParserTests.swift` - Parameterized accepted, rejected, and MPV behavior matrix.
- `AppPackage/Tests/AppToolsTests/.swiftlint.yml` - Inherits the repository SwiftLint configuration for the new module.
- `AppPackage/Package.swift` - Declares the AppToolsTests module and its sole AppTools dependency.
- `AppPackage/Tests/FeatureTests.xctestplan` - Includes AppToolsTests in the default unit plan.

## Decisions Made

- The final `Route` migration contract is `url`, `gid`, `pageIndex`, `commentID`, and `isGalleryImageURL`; the URL is always the normalized HTTPS value for app-scheme input.
- `/s/` tokens with a hyphen and a non-decimal suffix remain valid single-page routes with `pageIndex == nil`, preserving the former integer-conversion behavior while still requiring a decimal gid.
- AppToolsTests links only AppTools. It does not redundantly link AppTools' transitive dependencies, following the package's test-target isolation convention.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered AppToolsTests during the TDD RED step**
- **Found during:** Task 1 RED
- **Issue:** The new target could not execute through the EhPanda scheme until the default test plan knew about it, but target registration was listed under Task 2.
- **Fix:** Added the test-plan entry with the RED test infrastructure so the failing test ran for the intended behavioral reason, then expanded the matrix in Task 2.
- **Files modified:** `AppPackage/Tests/FeatureTests.xctestplan`
- **Verification:** The RED run reached `GalleryURLParserTests.parsesGalleryURL` and failed because parsing returned nil; GREEN and final targeted runs succeeded.
- **Committed in:** `0c076035`

**2. [Rule 3 - Blocking] Used the repository-standard Xcode macro trust flag**
- **Found during:** Task 1 RED verification
- **Issue:** Local Xcode macro approvals rejected three already-pinned package macros before compilation.
- **Fix:** Re-ran build and test commands with the same `-skipMacroValidation` flag used by repository CI and prior phase verification.
- **Files modified:** None
- **Verification:** Required build, targeted AppToolsTests, and full default-plan tests all succeeded.
- **Committed in:** Not applicable; environment-only adjustment

---

**Total deviations:** 2 auto-fixed blocking issues. **Impact on plan:** Execution ordering and local verification flags changed; shipped code and scope did not.

## Issues Encountered

- The first GREEN compile exposed an ambiguous Optional `flatMap` result and the expanded parameterized tests needed private visibility for private fixture types. Both were corrected directly and verified by the next test run.
- The requirements updater found no `SC-1` or `SC-3` entries in the milestone requirements registry, consistent with Phase 13's spec-less success-criteria note; the plan's requirement identifiers remain recorded verbatim in this summary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 13-03 can migrate call sites against the finalized five-field Route contract without reproducing URL normalization or empty-string failure handling.
- No blockers remain for Plan 13-02 or the rest of Phase 13.

## Self-Check: PASSED

- All three created files exist.
- Commits `0c076035`, `6264cc12`, and `69603bc6` are present in git history.
- Task acceptance criteria, targeted AppToolsTests, the EhPanda build, and the full default unit plan all passed.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
