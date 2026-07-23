---
phase: 13-deep-link-hardening
plan: 07
subsystem: ui-test-infrastructure
tags: [swift, urlprotocol, dependencies, swift-testing, accessibility]

requires:
  - phase: 13-deep-link-hardening
    plan: 06
    provides: Timing-free deep-link and toast presentation behavior
  - phase: 04-concurrency-migration
    provides: URLSession.shared request defaults across the deep-link request path
provides:
  - DEBUG-only fixture URLProtocol armed before the app processes its first action
  - Launch-environment clipboard override that preserves production clipboard writes
  - In-process route and environment regressions for the UI-test seam
  - Stable detail, reading, comments, toast, and error assertion identifiers
affects: [13-08-ui-test-harness, 13-09-deep-link-scheme-ui-tests, 13-10-entry-ui-tests]

tech-stack:
  added: []
  patterns: [DEBUG launch-environment seam, Mutex-protected URLProtocol configuration, identifier-only UI metadata]

key-files:
  created:
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
  modified:
    - App/EhPandaApp.swift
    - AppPackage/Sources/ClipboardClient/ClipboardClient.swift
    - AppPackage/Sources/DetailFeature/DetailView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/SystemNotification/ToastMessageView.swift
    - AppPackage/Sources/AppComponents/ErrorInfoView.swift

key-decisions:
  - "UITestStubURLProtocol keeps its synchronous fixture-directory configuration in Synchronization.Mutex, preserving checked Sendable safety without unsafe annotations."
  - "The clipboard override replaces only url and changeCount; all three save operations remain the live ClipboardClient implementations."
  - "The reading-page identifier lives on the existing numeric Text in ControlPanel, the actual visible page-index element, rather than on an unrelated reader container."

patterns-established:
  - "UI-test process seams resolve trimmed EHPANDA_UITEST_* launch values under DEBUG and leave Release binaries free of fixture keys and routing code."
  - "XCUITest hooks use accessibilityIdentifier only, preserving existing VoiceOver labels, values, and traits."

requirements-completed: [SC-2]

coverage:
  - id: D1
    description: "Fixture responses hermetically cover gallery, alternate gallery, single-page, front-page, and unmatched routes without network fallback."
    requirement: SC-2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/UITestStubTests.swift#fixtureRoutesStayHermetic"
        status: pass
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -configuration Release -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Launch environment resolution is opt-in and supplies deterministic network and clipboard overrides while preserving live clipboard writes."
    requirement: SC-2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/UITestStubTests.swift#environmentResolutionIsOptInAndBuildsClipboardOverride"
        status: pass
      - kind: integration
        ref: "Release binary string scan finds no EHPANDA_UITEST keys, fixture names, or UITestStubURLProtocol symbol"
        status: pass
    human_judgment: false
  - id: D3
    description: "Every deep-link destination exposes its planned locale-independent accessibility identifier without changing labels, values, or traits."
    requirement: SC-2
    verification:
      - kind: integration
        ref: "Seven-identifier source gate plus full default EhPanda test plan"
        status: pass
    human_judgment: true
    rationale: "The identifiers compile and are attached to the intended stable elements; end-to-end accessibility-tree discovery is intentionally exercised by Plans 13-08 through 13-10."

duration: 16 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 07: Hermetic UI-Test Seam Summary

**DEBUG-only URLProtocol fixtures and clipboard injection now keep deep-link routing deterministic while stable assertion identifiers expose every destination**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-23T03:26:34Z
- **Completed:** 2026-07-23T03:42:27Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments

- Added `EHPANDA_UITEST_STUB_NETWORK`, `EHPANDA_UITEST_FIXTURE_DIR`, and `EHPANDA_UITEST_CLIPBOARD_URL` handling at the app's earliest owned initialization point.
- Added a hermetic fixture route table: `/g/2930572` → `GalleryDetailAlt.html`, other `/g/` → `GalleryDetail.html`, `/s/` → `GallerySinglePage.html`, root/list queries → `FrontPageList.html`, and all unmatched paths → empty 404.
- Proved the route table and opt-in environment resolution in process using a UUID-scoped fixture directory and a session-scoped URLProtocol registration.
- Added `detail_view`, `reading_view`, `reading_page_indicator`, `comments_view`, per-row `comment_cell_<id>`, `toast_message`, and `error_info_view` identifiers without altering accessibility semantics.
- Verified the DEBUG build, AppFeatureTests, full default unit plan, Release build, Release binary seam absence, and strict no-cache lint across all 464 repository-owned Swift files.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fixture-serving URLProtocol, environment resolution, and clipboard override** - `8cb736e9` (feat)
2. **Task 2: App arm point and in-process seam regressions** - `8b56e56d` (test)
3. **Task 3: Accessibility-identifier assertion hooks** - `8575b295` (feat)

## Files Created/Modified

- `AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift` - Resolves the three DEBUG launch keys, registers the protocol, and prepares the clipboard dependency.
- `AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift` - Serves fixture files by URL path with a hermetic empty-404 default.
- `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift` - Exercises every route class and the opt-in environment contract without shared-session pollution.
- `App/EhPandaApp.swift` - Arms automation before app actions resolve dependencies or issue requests.
- `AppPackage/Sources/ClipboardClient/ClipboardClient.swift` - Exposes construction so another module can preserve live writes while overriding reads.
- `AppPackage/Sources/DetailFeature/DetailView.swift` - Identifies the detail scroll surface as `detail_view`.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Identifies the reader root as `reading_view`.
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` - Identifies the visible numeric page indicator as `reading_page_indicator`.
- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` - Identifies the comments list and each distinct comment row.
- `AppPackage/Sources/SystemNotification/ToastMessageView.swift` - Identifies the combined toast surface as `toast_message`.
- `AppPackage/Sources/AppComponents/ErrorInfoView.swift` - Identifies the root error form as `error_info_view`.

## Decisions Made

- Protected synchronous URLProtocol configuration with `Synchronization.Mutex`; an actor would force asynchronous access into Foundation's synchronous protocol callbacks.
- Kept fixture content outside the application bundle and Swift literals. The UI-test runner supplies the directory, so test HTML does not ship in Release.
- Derived the clipboard change count from the launch timestamp and preserved the live save closures, limiting the override exactly to the un-automatable paste read.
- Attached `reading_page_indicator` directly to the existing numeric `Text` in `ControlPanel.swift`, where its label naturally remains the current-page/total-page string.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Exposed ClipboardClient construction across its module boundary**

- **Found during:** Task 1 build verification
- **Issue:** Swift's synthesized memberwise initializer was internal, so AppFeature could not construct the planned read-only override while preserving live save closures.
- **Fix:** Added an explicit public initializer covering the existing five endpoints.
- **Files modified:** `AppPackage/Sources/ClipboardClient/ClipboardClient.swift`
- **Verification:** DEBUG and Release application builds succeeded; AppFeature seam tests passed.
- **Committed in:** `8cb736e9`

**2. [Rule 2 - Missing Critical] Attached the page identifier to the actual indicator implementation**

- **Found during:** Task 3 target-view inspection
- **Issue:** The page-index element is implemented by `UpperPanel` in `ControlPanel.swift`, not directly in `ReadingView.swift`; identifying only the reader container would not expose the required page string.
- **Fix:** Added `reading_page_indicator` to the existing numeric `Text` while retaining `reading_view` on the reader root.
- **Files modified:** `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift`
- **Verification:** The seven-identifier source gate, full tests, and strict lint passed.
- **Committed in:** `8575b295`

**3. [Rule 1 - Bug] Used failable UTF-8 decoding in the route regression**

- **Found during:** Final strict lint
- **Issue:** The first test draft used non-failable `String(decoding:as:)`, which violated the project's optional-data conversion rule under strict lint.
- **Fix:** Required `String(data:encoding:)` through Swift Testing's `#require`, making invalid fixture bytes an explicit test failure.
- **Files modified:** `AppPackage/Tests/AppFeatureTests/UITestStubTests.swift`
- **Verification:** AppFeatureTests and the strict 464-file lint scan passed.
- **Committed in:** `8b56e56d`

---

**Total deviations:** 3 auto-fixed (1 blocking API-access issue, 1 missing assertion-hook placement, 1 lint correctness issue).
**Impact on plan:** Every change was necessary to make the specified seam constructible, observable, and compliant; no production routing or UI behavior changed.

## Issues Encountered

- Xcode required `-skipMacroValidation` because resolved dependency macros had an interactive approval gate after their package revision changed. The same flag used by prior Phase 13 verification allowed builds and tests to run without bypassing compile, test, or lint checks.
- SwiftLint is supplied by the resolved Swift package artifact rather than shell PATH. Its strict no-cache repository scan completed with zero violations.

## Known Stubs

None. The only marker bodies are test-owned temporary fixture files; production responses always come from the runner-supplied fixture directory, and no placeholder data flows to the application UI.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 13-08 can create the UI-test target and pass a fixture directory through the three documented launch keys.
- Plans 13-09 and 13-10 can query every destination by stable identifier and distinguish comment rows by their own IDs.
- Release builds contain none of the environment-key strings, fixture names, or URLProtocol stub implementation. No blockers remain.

## Self-Check: PASSED

- Confirmed all 11 created or modified implementation/test files exist.
- Confirmed task commits `8cb736e9`, `8b56e56d`, and `8575b295` exist in order.
- Confirmed all five fixture outcomes, all three launch keys, and all seven identifier forms are present and tested or source-gated.
- Confirmed final AppFeatureTests, the full default unit plan, DEBUG and Release builds, Release binary seam absence, and strict repository lint pass.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
