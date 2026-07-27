---
phase: 15-continued-background-downloads
plan: 01
subsystem: infra
tags: [backgroundtasks, bgtaskscheduler, bgcontinuedprocessingtask, info-plist, tca, swift-package-manager]

# Dependency graph
requires:
  - phase: 14-analytics-and-privacy
    provides: AppDelegate/AppReducer launch and scene-phase wiring this plan edits
provides:
  - "Info.plist permitting exactly one background-task identifier pattern: $(PRODUCT_BUNDLE_IDENTIFIER).continued.*"
  - "An AppFeature free of BGTaskScheduler registration, scheduling, and drain wiring"
  - "A package graph where appFeature no longer depends on BackgroundProcessingClient"
  - "Observed proof that build-setting tokens expand inside a nested Info.plist array string (RESEARCH.md Assumption A2 settled)"
affects: [15-02, 15-03, 15-04, 15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Background-execution surface is declared once, bundle-prefixed plus one semantic segment, never a bare wildcard"
    - "Plist build-setting expansion is asserted on the built product, not assumed from the source plist"

key-files:
  created: []
  modified:
    - App/Info.plist
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Package.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundProcessingTests.swift

key-decisions:
  - "UIBackgroundModes keeps `processing`, with an XML comment recording the asymmetric-failure rationale (RESEARCH.md A1/Q6)."
  - "Assumption A2 settled by observation: $(PRODUCT_BUNDLE_IDENTIFIER) expands inside a BGTaskSchedulerPermittedIdentifiers array entry, so the literal fallback was not needed."
  - "AppDelegateReducer's file-scoped logger and its OSLogExt import were removed with handleProcessingTask — nothing in that file logs any more."
  - "The stale suite-level @MainActor rationale comment in DownloadBackgroundProcessingTests was removed with the last @MainActor case in the file."

patterns-established:
  - "Deleted tiers leave no stranded machinery: imports, loggers, test helpers, and package dependencies die with their call sites."

requirements-completed: [SC3, SC4]

coverage:
  - id: D1
    description: "App/Info.plist permits exactly one background-task identifier, and the built app resolves it to the literal app.ehpanda.continued.*"
    requirement: SC4
    verification:
      - kind: other
        ref: "plutil -p \"$BUILT_PRODUCTS_DIR/EhPanda.app/Info.plist\" | grep -c 'app[.]ehpanda[.]continued[.][*]' => 1"
        status: pass
      - kind: other
        ref: "/usr/libexec/PlistBuddy -c \"Print :BGTaskSchedulerPermittedIdentifiers\" App/Info.plist => single-element array"
        status: pass
    human_judgment: false
  - id: D2
    description: "No launch-time registration, scene-phase scheduling, or drain handler for a discretionary background task remains in AppFeature"
    requirement: SC3
    verification:
      - kind: other
        ref: "grep -rn 'BackgroundProcessingClient' AppPackage/Sources/AppFeature => 0; grep -rn 'handleProcessingTask' App AppPackage => 0"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests (full plan, all suites) => TEST SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D3
    description: "appFeature no longer declares a package dependency on the BackgroundProcessingClient module"
    requirement: SC3
    verification:
      - kind: other
        ref: "swift package dump-package --package-path AppPackage => succeeds; appFeature dependency list no longer names the module"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme EhPanda => BUILD SUCCEEDED, zero warnings, zero SwiftLint violations"
        status: pass
    human_judgment: false
  - id: D4
    description: "The background-URLSession launch handler is byte-identical to its pre-phase form"
    requirement: SC3
    verification:
      - kind: other
        ref: "git diff HEAD~1 HEAD -- AppDelegateReducer.swift shows no change inside application(_:handleEventsForBackgroundURLSession:completionHandler:)"
        status: pass
    human_judgment: false

# Metrics
duration: 7min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 01: Retire the Discretionary Background Tier Summary

**The app shell now permits only `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` background-task identifiers and carries no `BGTaskScheduler` registration, scheduling, or drain wiring at all, with the plist token's expansion proven on the built product.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-27T23:49:36Z
- **Completed:** 2026-07-27T23:56:26Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- `App/Info.plist` now permits exactly one identifier pattern, `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, replacing the discretionary `app.ehpanda.downloads.processing` entry. `UIBackgroundModes` still declares `processing`, now with an XML comment recording why that keep is deliberate.
- RESEARCH.md Assumption A2 is settled by observation, not inference: `plutil -p` on the built `EhPanda.app/Info.plist` prints the expanded literal `app.ehpanda.continued.*`, so the build-setting form is safe and no literal fallback was needed. No later plan inherits this as an open risk.
- `AppDelegateReducer` lost the launch-time `BackgroundProcessingClient.live.register` call and the whole `handleProcessingTask(_:)` drain handler, together with the `BackgroundTasks`/`BackgroundProcessingClient`/`OSLogExt` imports and the file-scoped logger those were the only users of. `application(_:handleEventsForBackgroundURLSession:completionHandler:)` is untouched.
- `AppReducer` lost its `\.backgroundProcessingClient` dependency and the `.background` scene-phase `hasPendingWork()`/`schedule()` conditional. The three-line comment that named the `beginBackgroundTask` execution assertion is replaced by one sentence describing the new topology, so plan 15-02's repository-wide zero-gate on that name has nothing to trip over here.
- `appFeature` no longer depends on the `backgroundProcessingClient` module in `AppPackage/Package.swift`; the target definition and the `downloadsFeatureTests` dependency stay for the rebuild in later plans.
- The two orphaned scene-phase scheduling test cases and their `makeBackgroundStore` helper are gone from `DownloadBackgroundProcessingTests`, along with the six imports they alone justified.

## Task Commits

Each task was committed atomically:

1. **Task 1: Repoint the permitted-identifier surface at continued-processing tasks** - `28d7fe13` (chore)
2. **Task 2: Delete the discretionary task wiring from AppFeature** - `1d6f17ce` (refactor)

## Files Created/Modified

- `App/Info.plist` - Permitted-identifier array now holds only the continued-processing wildcard; `UIBackgroundModes` gains a keep-rationale comment.
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` - Registration call and `handleProcessingTask(_:)` deleted; background-URLSession handler untouched.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Client dependency and `.background` scheduling deleted; topology comment rewritten.
- `AppPackage/Package.swift` - `appFeature` no longer depends on `backgroundProcessingClient`.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundProcessingTests.swift` - Two scheduling cases, `makeBackgroundStore`, the orphaned imports, and the now-false suite-level `@MainActor` rationale comment removed.

## Decisions Made

- **Keep `UIBackgroundModes: processing`.** Followed the plan and RESEARCH.md's definitive recommendation: no Apple source states the mode is unnecessary for continued-processing submissions, and a wrong removal fails every submission with `notPermitted`. The rationale now lives beside the key so a future reader cannot mistake it for leftover from the deleted tier.
- **Delete the AppDelegateReducer logger, not just its call sites.** `handleProcessingTask` held the only two `logger.notice` calls in the file. Leaving an unreferenced `private let logger` (and its `OSLogExt` import) would be exactly the stranded machinery the plan's prohibition forbids.
- **Delete the stale `@MainActor` rationale comment** in the test file. It explained why *the annotated cases* needed the annotation; after the two annotated cases went, it described code that no longer exists.

## Deviations from Plan

None - plan executed exactly as written. The three items under "Decisions Made" are the plan's own "dead code is deleted, never stranded" prohibition applied to what the deletions orphaned, not scope changes.

## Environment Notes

- The plan's `<automated>` verify blocks pin `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. Every command was run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5) instead; the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed — project, scheme, test plan, and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.

## Issues Encountered

None.

## Verification Evidence

- `plutil -p` on the built `EhPanda.app/Info.plist`: `BGTaskSchedulerPermittedIdentifiers => [0 => "app.ehpanda.continued.*"]`, occurrence count `1`; `UIBackgroundModes => [0 => "processing"]`.
- `grep -c 'downloads[.]processing' App/Info.plist` → `0`.
- `grep -rn 'BackgroundProcessingClient' AppPackage/Sources/AppFeature` → 0 lines; `grep -rn 'handleProcessingTask' App AppPackage` → 0 lines.
- `grep -c 'backgroundProcessingClient\|beginBackgroundTask\|hasPendingWork' AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` → `0`.
- `grep -c 'handleEventsForBackgroundURLSession' .../AppDelegateReducer.swift` → `1`.
- `swift package dump-package --package-path AppPackage` → succeeds.
- `xcodebuild test … -only-testing:DownloadsFeatureTests` → `Test run with 267 tests in 54 suites passed`, `** TEST SUCCEEDED **`.
- Full `FeatureTests` plan → `** TEST SUCCEEDED **` across all 22 suite groups (the two "known issue" records are pre-existing `withKnownIssue` expectations).
- `xcodebuild build -scheme EhPanda` → `** BUILD SUCCEEDED **` with zero `warning:`/`error:` lines, so the SwiftLint build-tool plugin reported no violations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-02 can run its repository-wide zero-gate on the `beginBackgroundTask` assertion name without a surviving comment in `AppReducer.swift` holding it red.
- Plan 15-03's rebuilt client can mint `app.ehpanda.continued.<uuid>` identifiers knowing the permitted-identifier pattern resolves correctly in the built product.
- Open item carried forward from the threat register (T-15-02, unchanged by this plan): any previously submitted `app.ehpanda.downloads.processing` request is now unserviceable; the one-shot cancel-all lands in plan 15-03.
- Between the discretionary tier's removal here and the continued-processing session's arrival in later plans, backgrounded downloads suspend with the process. That is the intended D-01/D-02 topology, not a regression.

## Self-Check: PASSED

All five modified files and the SUMMARY exist on disk; both task commits (`28d7fe13`, `1d6f17ce`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
