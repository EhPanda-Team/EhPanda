---
phase: 13-deep-link-hardening
plan: 10
subsystem: deep-link-entry-coverage
tags: [swift, xctest, xcuitest, deep-links, share-extension, ipad, private-api]

requires:
  - phase: 13-deep-link-hardening
    plan: 09
    provides: Lifecycle helpers, deterministic locale, route constants, and stable destination markers
provides:
  - Clipboard and comments-view entry coverage
  - True end-to-end share-sheet coverage through Safari, the real share sheet, and the real extension
  - iPad tab-modal entry coverage including deep-link replacement of an open modal
  - A working ShareExtension hand-off to the containing app on iOS 26.5
affects: [share-extension, deep-link-regression-coverage, ipad-presentation]

tech-stack:
  added: []
  patterns: [cross-app XCUITest drives, probe-and-pin system chrome identifiers, idiom-guarded test classes]

key-files:
  created:
    - EhPandaUITests/ShareSheetUITests.swift
    - EhPandaUITests/DeepLinkPadUITests.swift
  modified:
    - EhPandaUITests/DeepLinkEntryUITests.swift
    - ShareExtension/ShareViewController.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift

key-decisions:
  - "The share-sheet test serves its own link fixture from a loopback listener inside the test process, so the Safari leg never contacts the gallery host."
  - "Safari's chrome identifiers are probed and pinned per release rather than assumed; on iOS 26.5 the address bar is a TextField named TabBarItemTitle and the link action is titled with a horizontal ellipsis."
  - "The ShareExtension hand-off routes through LSApplicationWorkspace. Every public route is dead on iOS 26.5 and Apple's position is that the capability is not offered; this build does not ship to the App Store, and the share-sheet test is what keeps the private route honest."
  - "The iPad class is guarded by an idiom skip so the shared UI plan stays runnable on both destinations."

patterns-established:
  - "Cross-app tests assert arrival hermetically on the app side (marker title), so a flaky cross-process leg cannot fake a pass."
  - "System-chrome lookups carry the probed release in a comment, so drift is diagnosable rather than mysterious."

requirements-completed: [SC-2]

coverage:
  - id: D1
    description: "The clipboard entry lands on detail from a cold launch without touching the real pasteboard, and a gallery link inside a comment pushes the linked gallery's detail."
    requirement: SC-2
    verification:
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkEntryUITests.swift: clipboard and comment-link tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Sharing a gallery link from Safari through the real share sheet and the real extension foregrounds the app on the linked gallery's detail."
    requirement: SC-2
    verification:
      - kind: e2e
        ref: "EhPandaUITests/ShareSheetUITests.swift: testShareSheetHandoffLandsOnDetail"
        status: pass
      - kind: other
        ref: "Simulator log: the extension's LSApplicationWorkspace open returns true; the prior responder-chain route logged 'BUG IN CLIENT OF UIKIT ... Force returning false'"
        status: pass
    human_judgment: false
  - id: D3
    description: "Tapping a gallery from a tab on iPad presents the modal detail, and a deep link arriving over it replaces it with the linked gallery."
    requirement: SC-2
    verification:
      - kind: automated_ui
        ref: "EhPandaUITests/DeepLinkPadUITests.swift: testPadTabModalReplacedByDeepLink"
        status: pass
      - kind: e2e
        ref: "xcodebuild test -scheme EhPanda -testPlan UITests -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' -skipMacroValidation -retry-tests-on-failure -test-iterations 3 -only-testing:EhPandaUITests/DeepLinkPadUITests"
        status: pass
    human_judgment: false
  - id: D4
    description: "The phase's automated exit evidence is green across the unit plan, the complete UI plan on iPhone, and the iPad class on iPad."
    requirement: SC-2
    verification:
      - kind: integration
        ref: "Default FeatureTests plan: 5 bundles, 0 failures; complete UITests plan on iPhone Air: 12 passed, 1 skipped, 0 failed; SwiftLint --strict: 470 files, 0 violations"
        status: pass
    human_judgment: false

duration: 3 h 20 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 10: Entry-Path Coverage and the Share Hand-off Summary

**The deep-link entry matrix is complete at 13 green tests, and the share-sheet test caught — then drove the fix for — a share extension that had silently stopped opening the app.**

## Performance

- **Duration:** 3 h 20 min
- **Tasks:** 3
- **Files created:** 2
- **Files modified:** 3

## Accomplishments

- Added the clipboard and comments-view entry representatives, both hermetic and both proving real routing rather than launch state.
- Added the D-10 true end-to-end share test: it serves its own link page from a loopback listener, drives Safari to it, opens the real share sheet, taps the real EhPanda extension, and asserts arrival on detail by the fixture marker title.
- Added the D-08 iPad test: a tab-rooted gallery tap presents the modal detail, then a deep link arriving over it replaces it with the alternate gallery, exercising the dismissal-completion coordination end to end.
- Fixed the ShareExtension hand-off, which the new test proved was dead on iOS 26.5.
- Passed all three gate invocations plus a strict lint sweep across 470 files.

## Entry Matrix

| Entry | Test | Result |
| --- | --- | --- |
| Custom scheme (8 routes) | `DeepLinkSchemeUITests` | Pass |
| Cold smoke | `DeepLinkSmokeUITests` | Pass |
| Clipboard | `testClipboardGalleryLinkColdLaunchLandsOnDetail` | Pass |
| Comments view | `testCommentLinkTapPushesLinkedGallery` | Pass |
| Share sheet (true E2E) | `testShareSheetHandoffLandsOnDetail` | Pass |
| iPad tab modal | `testPadTabModalReplacedByDeepLink` | Pass on iPad, skipped on iPhone |

## Task Commits

1. **Task 1: Clipboard + comments-entry representatives** — `f18d8ab9` (test)
2. **Task 2: Share-sheet true E2E** — `3059d054` (test), `0f85d6e2` and `02638d17` (fix)
3. **Task 3: iPad tab-modal coverage + phase test gate** — `edddc658` (test)

## Files Created/Modified

- `EhPandaUITests/ShareSheetUITests.swift` — Drives the Safari → share sheet → extension → app hand-off and serves its own loopback link fixture.
- `EhPandaUITests/DeepLinkPadUITests.swift` — Covers the iPad tab-modal entry and its replacement by a deep link; skips on the phone idiom.
- `EhPandaUITests/DeepLinkEntryUITests.swift` — Adds the clipboard and comments-view entry representatives.
- `ShareExtension/ShareViewController.swift` — Routes the app hand-off through `LSApplicationWorkspace`.
- `AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift` — Serves the front-page gallery-list fixture for `/popular` as well.

## Probed-and-Pinned Safari Identifiers (iOS 26.5)

Re-probe `safari.debugDescription` if any of these stop resolving:

| Element | Lookup | Note |
| --- | --- | --- |
| Address bar | `textFields["TabBarItemTitle"]` | A **TextField**, not a Button as in earlier releases; type through the raised keyboard |
| Start-page onboarding card | `buttons["close"]` | Its dimming overlay covers the capsule toolbar |
| Feature tip popover | `buttons["xmark.circle.fill"]` | Covers the page content |
| Link menu preview toggle | `staticTexts["Hide preview"]` | Without collapsing it the menu extends past the bottom of the screen |
| Link share action | `buttons` where `label BEGINSWITH "Share"` | Titled `Share…` with a horizontal ellipsis |

## Decisions Made

- Served the share fixture from a loopback listener rather than navigating to the real gallery URL, so the only network the Safari leg needs is its own loopback.
- Kept the share test's arrival assertion on the app side and hermetic (marker title from the stub), so a flaky cross-process leg cannot produce a false pass.
- Reached the iPad tab-modal through Home's Frontpage list, which is the tab-rooted tap the modal entry is for.

## Deviations from Plan

### Escalated to the user

**1. [Rule 3 - Product defect outside plan scope] The ShareExtension could no longer open the app**

- **Found during:** Task 2 (Share-sheet true E2E)
- **Issue:** The extension walked the responder chain to the deprecated `UIApplication.openURL(_:)`. iOS 26.5 force-fails that call — `BUG IN CLIENT OF UIKIT ... Force returning false`, captured in the simulator log on every run — so sharing a gallery link to EhPanda silently did nothing. This is app code outside the plan's declared test-only file set, and the replacement is a design choice, so it was escalated rather than assumed.
- **Owner decision:** Fix it now, and use private API if that is what it takes, since this build does not ship to the App Store.
- **Fix:** Measured all three public candidates as dead before reaching for a private one. `NSExtensionContext.open(_:)` is honoured only for the Today and iMessage extension points. The `_UIHostedWindowScene` that terminates an extension's responder chain accepts `openURL:options:completionHandler:` but never invokes the completion or opens anything. The hand-off now goes through `LSApplicationWorkspace`, verified by both the green test and an `opened=1` result in the extension's log.
- **Files modified:** `ShareExtension/ShareViewController.swift`
- **Committed in:** `0f85d6e2`, `02638d17`

### Auto-fixed Issues

**2. [Rule 1 - Bug] The share test's fixture server produced an unparseable response**

- **Found during:** Task 2 (Share-sheet true E2E)
- **Issue:** The HTTP headers were built from a multi-line string literal, which drops the final newline, so the header block terminated with `\r\n\r` and Safari rejected the page with "cannot parse response".
- **Fix:** Joined the headers explicitly with CRLF.
- **Committed in:** `3059d054`

**3. [Rule 2 - Missing test support] The stub served no popular-list fixture**

- **Found during:** Task 3 (iPad tab-modal coverage)
- **Issue:** Home renders nothing until its popular section resolves, so under the stub the pad Home was a parse error and the tab-modal entry was unreachable — the plan had assumed Home was served by the front-page fixture.
- **Fix:** The DEBUG-only stub now serves the front-page gallery-list fixture for `/popular` as well.
- **Files modified:** `AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift`
- **Committed in:** `edddc658`

---

**Total deviations:** 1 escalated product defect, 2 auto-fixed issues.
**Impact on plan:** The test scope is exactly as planned. The escalated defect expanded the plan into `ShareExtension/`, with the owner's explicit decision on both the scope and the private-API route.

## Issues Encountered

- The share test is the slowest in the suite at roughly 160 s. Safari's link preview fetches the linked page before the context menu settles, and that wait dominates. It passes on its first iteration and did not need the retry budget, but the cost is real and was accepted as part of D-10.
- Xcode again required `-skipMacroValidation` for non-interactive runs, matching the established flag from Plan 13-08.

## Known Stubs

None.

## User Setup Required

None — every test is offline and credential-free apart from the share test's own loopback listener.

## Next Phase Readiness

- SC-2 is complete: every deep-link entry's arrival leg is machine-verified.
- The share hand-off now rests on private API by explicit owner decision. It is covered by a true end-to-end test, so a future iOS release breaking it surfaces as a red test rather than a silent regression — worth re-checking at each major iOS bump.
- No blockers remain; the unit plan, the complete UI plan on iPhone, the iPad class on iPad, and strict lint are all green.

## Self-Check: PASSED

- All five created or modified plan files exist.
- Task commits `f18d8ab9`, `3059d054`, `0f85d6e2`, `edddc658`, and `02638d17` exist in repository history.
- Complete UI plan on iPhone Air: 12 passed, 1 skipped (iPad class), 0 failed.
- iPad class on iPad Pro 11-inch (M5): 1 passed.
- Default FeatureTests plan: 5 bundles, 0 failures.
- SwiftLint `--strict`: 470 files, 0 violations.
- No UI test uses `sleep`.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
