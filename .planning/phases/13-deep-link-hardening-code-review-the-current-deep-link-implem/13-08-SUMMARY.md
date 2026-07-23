---
phase: 13-deep-link-hardening
plan: 08
subsystem: ui-test-infrastructure
tags: [swift, xctest, xcuitest, xcodeproj, test-plans, hermetic-fixtures]

requires:
  - phase: 13-deep-link-hardening
    plan: 07
    provides: DEBUG-only fixture interception, launch-environment seams, and stable accessibility identifiers
provides:
  - EhPandaUITests UI-automation target with a dedicated non-default retrying test plan
  - Runner-bundle HTML fixtures and one shared constant set for the Phase 13 UI matrix
  - Evidence-pinned cold and warm deep-link delivery helpers
  - Green hermetic cold-gallery smoke coverage without changing the default unit plan
affects: [13-09-deep-link-scheme-ui-tests, 13-10-entry-ui-tests, ui-automation]

tech-stack:
  added: []
  patterns: [runner-owned fixtures, evidence-pinned launch delivery, separate non-default UI test plan]

key-files:
  created:
    - UITests.xctestplan
    - EhPandaUITests/.swiftlint.yml
    - EhPandaUITests/Support/UITestConstants.swift
    - EhPandaUITests/Support/DeepLinkLauncher.swift
    - EhPandaUITests/Fixtures/GalleryDetail.html
    - EhPandaUITests/Fixtures/GalleryDetailAlt.html
    - EhPandaUITests/Fixtures/GallerySinglePage.html
    - EhPandaUITests/Fixtures/FrontPageList.html
    - EhPandaUITests/DeepLinkSmokeUITests.swift
  modified:
    - EhPanda.xcodeproj/project.pbxproj
    - EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme

key-decisions:
  - "Cold delivery is pinned to XCUIApplication.open(_:): the Xcode 26.6 / iOS 26.5 probe delivered both the custom-scheme URL and the hermetic launch environment."
  - "Warm delivery calls XCUIDevice.shared.system.open exactly; cold delivery uses the closest system-open mechanism that also preserves the D-06 fixture environment."
  - "UI fixtures live only in the runner bundle, while the synchronized-group exception prevents the module's SwiftLint configuration from becoming a bundle resource."
  - "The fixture matrix is anchored by primary 3103480/0000000000, alternate 2930572/daf4b9880d, page 2, and comment 6894060."

patterns-established:
  - "UI automation owns its resources and resolves the fixture directory from the UI test bundle before launching the app."
  - "FeatureTests remains the sole default test plan; GUI automation is selected explicitly through UITests.xctestplan."

requirements-completed: [SC-2]

coverage:
  - id: D1
    description: "EhPanda has a buildable UI-test target, a second non-default retrying test plan, lint coverage, and four runner-owned fixtures."
    requirement: SC-2
    verification:
      - kind: integration
        ref: "xcodebuild build-for-testing -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "xcodebuild -list plus scheme/default-plan and built-bundle resource inspection"
        status: pass
    human_judgment: false
  - id: D2
    description: "A cold ehpanda:// gallery open reaches detail_view and renders the bundled marker through the real app routing seam."
    requirement: SC-2
    verification:
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkSmokeUITests.swift#testColdGalleryDeepLinkUsesHermeticFixture"
        status: pass
      - kind: e2e
        ref: "xcodebuild test -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone Air' -retry-tests-on-failure -test-iterations 3 -skipMacroValidation"
        status: pass
    human_judgment: false
  - id: D3
    description: "The ordinary scheme invocation remains unit-only and green after adding the UI target."
    requirement: SC-2
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "Default xcresult contains only the FeatureTests plan and unit-test bundles: 635 tests, 0 failures, 0 UI tests"
        status: pass
    human_judgment: false

duration: 23 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 08: Hermetic Deep-Link UI Test Harness Summary

**A dedicated non-default XCUITest plan now proves cold custom-scheme routing against runner-bundled HTML fixtures while everyday unit testing remains unchanged.**

## Performance

- **Duration:** 23 min
- **Started:** 2026-07-23T03:50:51Z
- **Completed:** 2026-07-23T04:13:46Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added the `EhPandaUITests` product target (`A13080000000000000000006`), app dependency, SwiftLint plugin, synchronized source group, and dedicated `UITests.xctestplan`.
- Bundled four internally consistent parser fixtures with shared route constants for primary, alternate, single-page, page-index, and comment-entry scenarios.
- Probed and pinned cold delivery to `XCUIApplication.open(_:)`, retained `XCUIDevice.shared.system.open` for warm delivery, and passed the hermetic marker smoke test with the required retry flags.
- Kept `FeatureTests.xctestplan` as the sole default: the ordinary scheme run passed 635 tests with no UI bundle execution.

## Probe Outcome

The Xcode 26.6 / iOS 26.5 probe passed both required legs. `XCUIApplication.open(_:)` foregrounded the app on `detail_view`, and its launch environment activated the bundled `GalleryDetail.html`, whose title appeared as the `EhPanda UITest Fixture` button. Cold delivery is therefore pinned to `XCUIApplication.open(_:)`; fallback launch automation is retained only as a shared constant for later entry-path coverage.

## Fixture Constant Set

| Purpose | Value |
| --- | --- |
| Primary gallery | `3103480` / `0000000000` |
| Alternate gallery | `2930572` / `daf4b9880d` |
| Single-page token | `0000000000` |
| Page index | `2` |
| Last comment ID | `6894060` |
| Primary marker | `EhPanda UITest Fixture` |
| Alternate marker | `EhPanda UITest Fixture Alt` |

## Task Commits

Each task was committed atomically:

1. **Task 1: UI-test target, test plan, scheme wiring, lint config, fixtures** — `27d6b039` (feat)
2. **Task 2: Cold-delivery probe + hermetic smoke test** — `d30a1f43` (test)

## Files Created/Modified

- `EhPanda.xcodeproj/project.pbxproj` — Registers the UI bundle, dependency, settings, plugin, synchronized group, and resource exception.
- `EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme` — Adds the explicitly selected UI plan without changing the default unit plan.
- `UITests.xctestplan` — Selects `EhPandaUITests` and retries failures up to three times.
- `EhPandaUITests/.swiftlint.yml` — Inherits the repository SwiftLint rules.
- `EhPandaUITests/Support/UITestConstants.swift` — Centralizes fixture identities, environment keys, and URL builders.
- `EhPandaUITests/Support/DeepLinkLauncher.swift` — Applies hermetic launch configuration and encapsulates pinned cold/warm delivery.
- `EhPandaUITests/Fixtures/*.html` — Supplies gallery, alternate-gallery, single-page, and front-page fixture responses.
- `EhPandaUITests/DeepLinkSmokeUITests.swift` — Proves a full cold custom-scheme round trip and marker render.

## Decisions Made

- Selected `XCUIApplication.open(_:)` only after result-bundle evidence showed both the URL and launch environment were honored on the active toolchain.
- Kept warm delivery on `XCUIDevice.shared.system.open` to follow D-05 literally where it does not conflict with D-06 hermeticity.
- Queried the marker as a button because the production detail title is interactive in the accessibility tree; the assertion remains locale-independent and fixture-specific.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented the lint configuration from becoming a test resource**
- **Found during:** Task 1 (UI-test target, test plan, scheme wiring, lint config, fixtures)
- **Issue:** Xcode's synchronized group initially copied `EhPandaUITests/.swiftlint.yml` into the UI test bundle alongside the intended HTML fixtures.
- **Fix:** Added a synchronized-build-file exception for the lint file; all four HTML fixtures remain runner resources.
- **Files modified:** `EhPanda.xcodeproj/project.pbxproj`
- **Verification:** A clean `build-for-testing` removed the stale lint resource and retained all four fixture files.
- **Committed in:** `27d6b039`

**2. [Rule 1 - Bug] Matched the fixture marker's actual accessibility element type**
- **Found during:** Task 2 (Cold-delivery probe + hermetic smoke test)
- **Issue:** The first assertion queried the interactive gallery title as `StaticText`, so the probe reported failure even though result-bundle hierarchies proved the URL and fixture environment both arrived.
- **Fix:** Queried the marker as the `Button` exposed by the real detail view, preserving the same fixture-only title assertion.
- **Files modified:** `EhPandaUITests/DeepLinkSmokeUITests.swift`
- **Verification:** The smoke test and the full retry-configured UI plan each passed on the first run.
- **Committed in:** `d30a1f43`

---

**Total deviations:** 2 auto-fixed bugs.
**Impact on plan:** Both corrections were limited to harness correctness; the planned architecture and scope remained unchanged.

## Issues Encountered

- The installed `plutil` rejects JSON `.xctestplan` files, including the existing default plan, as non-property-list input. JSON syntax was validated directly, and Xcode successfully loaded, built, and executed the plan.
- Xcode emitted a non-fatal debugger-version snapshot warning during UI-test launches; it did not affect delivery or test results.

## Known Stubs

None. Placeholder attributes and empty JavaScript fields found in the copied HTML are real parser-fixture content, not unwired app or test behavior.

## User Setup Required

None — the UI suite is offline, credential-free, and fully configured in the repository.

## Next Phase Readiness

- Plans 13-09 and 13-10 can build their route and entry matrices on the committed launcher, constants, fixtures, and UI plan.
- No blockers remain; both the explicit UI plan and default unit plan are green.

## Self-Check: PASSED

- All 11 created or modified plan files exist.
- Task commits `27d6b039` and `d30a1f43` exist in repository history.
- SwiftLint reports zero violations across the three UI-test Swift files.
- UI result: 1 passed, 0 failed; default result: 635 tests, 0 failed, 0 UI tests.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
