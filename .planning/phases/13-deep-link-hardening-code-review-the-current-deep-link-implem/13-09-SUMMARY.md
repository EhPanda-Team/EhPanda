---
phase: 13-deep-link-hardening
plan: 09
subsystem: deep-link-ui-coverage
tags: [swift, xctest, xcuitest, deep-links, accessibility, hermetic-fixtures]

requires:
  - phase: 13-deep-link-hardening
    plan: 08
    provides: Hermetic UI-test fixtures, dedicated retrying plan, and pinned cold/warm URL delivery
provides:
  - Eight-test custom-scheme matrix covering gallery, page, comment, and malformed routes
  - Cold-launch and warm-foreground lifecycle coverage for every scheme route
  - Destination assertions for detail, reader page, linked comment, toast, and error information
  - Stable accessibility containers for nested reader and toast identifiers
affects: [13-10-entry-ui-tests, deep-link-regression-coverage, accessibility]

tech-stack:
  added: []
  patterns: [bounded accessibility waits, lifecycle-paired UI tests, destination-specific assertions]

key-files:
  created:
    - EhPandaUITests/DeepLinkSchemeUITests.swift
  modified:
    - EhPandaUITests/Support/DeepLinkLauncher.swift
    - EhPandaUITests/Support/UITestConstants.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/SystemNotification/ToastMessageView.swift

key-decisions:
  - "Cold delivery terminates the app before XCUIApplication.open(_:); warm delivery proves foreground state before opening and never relaunches afterward."
  - "Reader and toast identifiers belong to explicit accessibility containers so nested destination markers retain distinct identities."
  - "Comment routing is proven by the linked cell being hittable and navigation back revealing detail, because hermetic routing completes the detail-to-comments push before XCUIApplication.open(_:) returns."

patterns-established:
  - "Each scheme route shares one destination assertion across cold and warm lifecycle variants."
  - "Negative route assertions use bounded waitForExistence calls; UI tests contain no arbitrary sleeps."

requirements-completed: [SC-2, SC-3]

coverage:
  - id: D1
    description: "Gallery, single-page, and comment ehpanda:// routes reach their locked destinations in both cold-launch and warm-foreground lifecycles."
    requirement: SC-2
    verification:
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkSchemeUITests.swift: gallery, page, and comment lifecycle pairs"
        status: pass
      - kind: e2e
        ref: "xcodebuild test -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone Air' -retry-tests-on-failure -test-iterations 3 -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Malformed ehpanda:// routes keep the app foregrounded, show the persistent unsupported-link toast, avoid detail presentation, and open ErrorInfoView when tapped in both lifecycles."
    requirement: SC-3
    verification:
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkSchemeUITests.swift: malformed-link lifecycle pair"
        status: pass
      - kind: integration
        ref: "Complete UITests plan: 9 tests, 0 failures, all successful on first iteration"
        status: pass
    human_judgment: false
  - id: D3
    description: "The new scheme matrix preserves the default unit suite, strict lint, and simulator build."
    requirement: SC-2
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "Default FeatureTests plan: 638 tests passed; SwiftLint: 468 files, 0 violations; simulator build succeeded"
        status: pass
    human_judgment: false

duration: 36 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 09: Full-Density Custom-Scheme UI Matrix Summary

**Eight hermetic XCUITests now prove gallery, linked-page, linked-comment, and malformed custom-scheme behavior across both cold-launch and warm-foreground lifecycles.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-07-23T04:20:44Z
- **Completed:** 2026-07-23T04:56:10Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added six lifecycle-paired success-route tests for gallery detail, reader page 2 of 156, and linked comment 6894060.
- Added two lifecycle-paired malformed-route tests that validate the localized unsupported-link toast, prohibit detail presentation, and tap through to `error_info_view`.
- Strengthened cold delivery by explicitly terminating before URL open and kept warm delivery observably foregrounded without a post-open relaunch.
- Passed the complete retry-configured UI plan with 9 tests on their first iterations, the default 638-test FeatureTests plan, a simulator build, and strict lint across 468 Swift files.

## Route Matrix

| Route | Cold launch | Warm foreground | Locked destination |
| --- | --- | --- | --- |
| `/g/` | Pass | Pass | Detail only with fixture marker |
| `/s/` | Pass | Pass | Detail followed by reader at `2 / 156` |
| `#c` | Pass | Pass | Comments pushed over detail and scrolled to comment `6894060` |
| Malformed host | Pass | Pass | Unsupported-link toast followed by ErrorInfoView |

## Task Commits

Each task was committed atomically:

1. **Task 1: Cold and warm success-route matrix** — `90a8ef34` (test)
2. **Task 2: Cold and warm malformed-route matrix** — `272e74d6` (test)

## Files Created/Modified

- `EhPandaUITests/DeepLinkSchemeUITests.swift` — Implements the eight-test route/lifecycle matrix and shared destination assertions.
- `EhPandaUITests/Support/DeepLinkLauncher.swift` — Enforces true cold termination, foreground arrival checks, bounded element lookup, and a deterministic English UI-test locale.
- `EhPandaUITests/Support/UITestConstants.swift` — Adds the malformed URL and unsupported-link text contract.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — Keeps the reader container identifier distinct from its nested page indicator.
- `AppPackage/Sources/SystemNotification/ToastMessageView.swift` — Keeps the combined toast identifier on the tappable text-bearing accessibility element.

## Decisions Made

- Used shared destination assertions so cold and warm variants differ only in lifecycle setup, making contract drift visible.
- Proved page routes do not skip detail by requiring `detail_view` before `reading_view`, then checking the exposed page indicator.
- Proved comment routes retain detail beneath comments by requiring the linked cell to be hittable, navigating back, and requiring `detail_view`.
- Pinned the UI-test language and locale to English because the plan explicitly asserts the English unsupported-link description.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved the reader's nested page-indicator identity**
- **Found during:** Task 1 (Cold and warm success-route matrix)
- **Issue:** The reader's parent accessibility identifier propagated to descendants, erasing `reading_page_indicator` and making the required linked-page assertion ambiguous.
- **Fix:** Made `reading_view` an explicit containing accessibility element before assigning its identifier.
- **Files modified:** `AppPackage/Sources/ReadingFeature/ReadingView.swift`
- **Verification:** Both linked-page lifecycle tests locate the distinct static-text marker and report `2 / 156`.
- **Committed in:** `90a8ef34`

**2. [Rule 1 - Bug] Attached the toast identifier to its combined accessibility element**
- **Found during:** Task 2 (Cold and warm malformed-route matrix)
- **Issue:** Modifier order propagated `toast_message` to the warning icon, so XCUITest resolved an image labeled `Warning` rather than the tappable toast containing the error text.
- **Fix:** Combined the toast's children before assigning the identifier.
- **Files modified:** `AppPackage/Sources/SystemNotification/ToastMessageView.swift`
- **Verification:** Both malformed lifecycle tests read the English unsupported-link description, tap the toast, and reach `error_info_view`.
- **Committed in:** `272e74d6`

---

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both fixes make existing production accessibility contracts observable and correct; route architecture and scope are unchanged.

## Issues Encountered

- Xcode rejected the repository's already-approved package macros when test commands omitted validation bypassing. The established `-skipMacroValidation` build flag from Plan 13-08 restored the intended non-interactive build path; no dependency or source change was required.
- Xcode emitted a non-fatal debugger-version snapshot warning during UI-test launches. It did not affect lifecycle delivery, retry behavior, or results.

## Known Stubs

None. The created and modified files contain no placeholder data, empty render paths, TODOs, or unwired mock inputs.

## User Setup Required

None — the matrix is offline, credential-free, and uses runner-bundled fixtures.

## Next Phase Readiness

- Plan 13-10 can reuse the lifecycle helpers, deterministic locale, route constants, and stable destination markers for alternate entry-path coverage.
- No blockers remain; the explicit UI plan, default unit plan, strict lint, and simulator build are green.

## Self-Check: PASSED

- All five created or modified plan files exist.
- Task commits `90a8ef34` and `272e74d6` exist in repository history.
- Eight exact matrix test names are present; no UI test uses `sleep`.
- UI result: 9 passed, 0 failed, all on first iterations.
- Default result: 638 tests passed with 2 existing known issues and no failures.
- SwiftLint result: 468 files checked, 0 violations.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
