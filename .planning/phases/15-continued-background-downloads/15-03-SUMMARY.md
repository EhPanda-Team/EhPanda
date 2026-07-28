---
phase: 15-continued-background-downloads
plan: 03
subsystem: infra
tags: [backgroundtasks, concurrency, main-actor, dependency-client, asyncstream]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plan 15-02 left exactly one file naming the discretionary tier, so this plan's repository-wide zero-gate had a single file to clear"
provides:
  - "A main-actor-confined ContinuedProcessingSession owning the system continued-processing task, its Progress and the event continuation"
  - "A three-endpoint BackgroundProcessingClient seam (start / updateProgress / finish) over a self-finishing AsyncStream<BackgroundProcessingEvent>"
  - "An unimplemented testValue on the module's DependencyKey, so an unexpected call fails loudly in tests"
  - "The BackgroundProcessingClient module as the only Swift source in the tree referencing the system task scheduler"
affects: [15-04, 15-05, 15-06, 15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Register the launch handler with `using: .main` and confine the whole store to `@MainActor`, so a non-Sendable system object never crosses an isolation boundary and needs no unchecked escape"
    - "Clear the held task and continuation before any terminal call, so a second completion (or a completion racing an expiration) is structurally a no-op"
    - "A per-session UUID-suffixed identifier minted under the runtime bundle-identifier prefix, registered immediately before submission"

key-files:
  created:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift

key-decisions:
  - "Both the launch-handler closure and the expiration handler inherited main-actor isolation directly; no MainActor.assumeIsolated form was needed anywhere (settles RESEARCH.md Assumption A3 in the favourable direction)."
  - "The rewritten client keeps no file-local logger: every log line moved with the runtime into the session store, and the repo convention declares a logger only in files that log."
  - "The client's three live closures carry no logic beyond the await, so the main-actor hop is the only thing the seam adds."

patterns-established:
  - "A one-shot cancel-all-requests call on the first session of a process, documented inline as clearing a previous build's orphaned request rather than an over-broad sweep"

requirements-completed: [SC4]

coverage:
  - id: D1
    description: "Every touch of the system task and its Progress happens on the main actor, with no unchecked-Sendable escape, unsafe-nonisolated annotation or lint suppression anywhere in the module"
    requirement: SC4
    verification:
      - kind: other
        ref: "grep -rn '@unchecked Sendable\\|nonisolated(unsafe)\\|swiftlint:disable' AppPackage/Sources/BackgroundProcessingClient | wc -l => 0"
        status: pass
      - kind: other
        ref: "grep -c '@MainActor' ContinuedProcessingSession.swift => 1 (on the class, so every member inherits); clean app-scheme build => BUILD SUCCEEDED, zero warning:/error: lines"
        status: pass
    human_judgment: false
  - id: D2
    description: "Session completion performs at most one terminal transition: a second completion, or a completion after expiration, yields nothing and finishes nothing twice"
    requirement: SC4
    verification:
      - kind: other
        ref: "endSession(yielding:success:) clears `task`/`continuation` before calling setTaskCompleted or finishing the stream; a second call finds both nil (source-verified, single private terminal helper — the only caller of setTaskCompleted on the held task)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The seam exposes exactly three endpoints plus a three-case event vocabulary, and the stream finishes itself after expiration, unavailability or completion"
    requirement: SC4
    verification:
      - kind: other
        ref: "grep -n 'public var' BackgroundProcessingClient.swift => start, updateProgress, finish (the fourth hit is the DependencyValues accessor outside the struct); grep 'case granted|expired|unavailable' => 3"
        status: pass
      - kind: other
        ref: "grep -c 'public static let testValue = BackgroundProcessingClient()' => 1 (macro-synthesized unimplemented value)"
        status: pass
    human_judgment: false
  - id: D4
    description: "BackgroundProcessingClient is the only module whose Swift sources reference the system task scheduler, and the plist's single non-Swift mention is the permitted-identifiers key"
    requirement: SC4
    verification:
      - kind: other
        ref: "grep -rn --include='*.swift' 'BGTaskScheduler' App AppPackage ShareExtension | cut -d: -f1 | sort -u => only AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        status: pass
      - kind: other
        ref: "grep -c 'BGTaskScheduler' App/Info.plist => 1; grep -c 'BGTaskSchedulerPermittedIdentifiers' App/Info.plist => 1 (equal counts, so nothing hides behind the exemption)"
        status: pass
      - kind: other
        ref: "grep -rn 'downloads[.]processing\\|BGProcessingTask' App AppPackage ShareExtension | wc -l => 0 (the repository-wide zero 15-02 deferred here)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Each session registers a freshly minted UUID-suffixed identifier under the bundle-identifier prefix, and no identifier is registered twice within a process"
    verification:
      - kind: other
        ref: "grep -c 'UUID()' ContinuedProcessingSession.swift => 1, inside the single identifier expression; start() guards on task == nil, continuation == nil and !isAwaitingTask before registering anything"
        status: pass
    human_judgment: true
    rationale: "A second registration of the same identifier terminates the process with no catchable error, and the Simulator does not support background processing, so the guard's effect is only observable on device across repeated download-start taps in one launch."
  - id: D6
    description: "The existing queue behavior is unchanged by the rebuild"
    requirement: SC4
    verification:
      - kind: unit
        ref: "xcodebuild test -testPlan FeatureTests -only-testing:DownloadsFeatureTests => Test run with 259 tests in 53 suites passed"
        status: pass
      - kind: unit
        ref: "xcodebuild test -testPlan FeatureTests (full plan) => ** TEST SUCCEEDED **"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 03: Rebuild the Client as a Session Seam Summary

**`BackgroundProcessingClient` is now a three-endpoint continued-processing session seam over a main-actor-confined store, and that store's file is the only Swift source in the tree that names the system task scheduler.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-28T00:20:28Z
- **Completed:** 2026-07-28T00:26:21Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 rewritten)

## Accomplishments

- `ContinuedProcessingSession.swift` adds a `@MainActor public final class` with a `shared` instance and a private initializer, holding the optional system task, the optional event continuation, the awaiting-task window flag, the one-shot stale-request flag, and the last pushed `Int64` counts.
- `start(title:subtitle:)` guards single-session re-entry (returning an already-finished stream), stores the continuation before anything can yield, performs the one-shot `cancelAllTaskRequests()`, resolves `Bundle.main.bundleIdentifier` without force-unwrapping, mints `<bundle>.continued.<UUID>`, registers a main-queue launch handler for exactly that identifier, and submits a `.queue`-strategy request inside a `do`/`catch`. Every failure path resolves to a logged `unavailable` and a finished stream.
- Adoption stores the task, seeds `totalUnitCount`/`completedUnitCount` from the last pushed values, installs an expiration handler that performs nothing but the terminal transition, clears the awaiting flag and yields `granted`. The handler adopts and returns — with main-queue delivery, looping there would freeze the UI.
- `updateProgress(completedUnitCount:totalUnitCount:subtitle:)` records both counts first (so a task adopted later seeds correctly), then assigns the total before the completed count so the fraction never transiently exceeds one, and refreshes only the subtitle via `updateTitle(_:subtitle:)`. No child `Progress` objects.
- The private `endSession(yielding:success:)` helper clears `task` and `continuation` **before** calling `setTaskCompleted` or finishing the stream, which is what makes a second terminal transition structurally impossible rather than merely unlikely; it also resets the awaiting flag and both cached counts.
- `BackgroundProcessingClient.swift` lost the `BackgroundProcessing` namespace enum, the fixed `app.ehpanda.downloads.processing` identifier, the `register`/`schedule`/`cancel` endpoints, the entire discretionary live value and the matching `noop` members. It now declares exactly `start`, `updateProgress` and `finish`, each documented, with the empty-stream default the macro requires for the value-returning endpoint.
- The `BackgroundProcessingClientKey` block is structurally unchanged: `liveValue` / `previewValue: .noop` / `testValue = BackgroundProcessingClient()` — SC4's literal requirement — and the `DependencyValues` accessor survives.
- All three live closures are one `await ContinuedProcessingSession.shared` call and nothing else. Only `Int64`, `String` and `Bool` cross that hop.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the main-actor continued-processing session store** - `f2cf25a5` (feat)
2. **Task 2: Rewrite the client seam as a session API** - `de269646` (refactor)

## Files Created/Modified

- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` (created, 193 lines) - The `BackgroundProcessingEvent` vocabulary and the main-actor store; the only Swift file in the tree that touches the system task scheduler.
- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` (rewritten, 36 insertions / 53 deletions) - The three-endpoint session seam, its live and `noop` values, and the unchanged dependency-key block.

## Decisions Made

- **Isolation was inherited, not assumed (Assumption A3 settled).** The plan pre-authorised a `MainActor.assumeIsolated` fallback if the imported signatures marked the launch-handler closure or the `expirationHandler` property `@Sendable`. Neither did: a closure formed in the `@MainActor` method body inherits the isolation, and the expiration handler assignment compiles the same way. The store therefore contains no `assumeIsolated` at all, which is the stronger outcome — the compiler is checking the confinement rather than being told to trust it. Nothing in the module needed an unchecked-`Sendable` conformance, an unsafe-nonisolated annotation, or a lint exemption, and no rule was suppressed.
- **The rewritten client declares no logger.** The old file carried `private let logger` because its live value logged submission outcomes. All of that runtime moved into the session store, which declares its own file-local logger the module's usual way. Keeping an unused logger in the client would have contradicted the repo's file-local-logger-where-you-log convention.
- **`import AppModels` was dropped from the client.** The rewrite uses no `AppModels` symbol — and neither did the previous version, so the import was already orphaned. `import BackgroundTasks` and `import OSLogExt` moved to the store with the runtime that needs them, leaving the client on `ComposableArchitecture` alone.

## Deviations from Plan

None - plan executed exactly as written.

## Deferred Items

- `AppPackage/Package.swift` still lists `.module(.appModels)` among the `backgroundProcessingClient` target's dependencies, now visibly unused. The import it backed was already dead before this plan, and `Package.swift` is outside this plan's file scope; plan 15-04 edits that file for the `downloadClient` target and can drop the stale entry in passing. It is a build-graph wart with no runtime or lint effect.

## Acceptance-Criteria Notes

- Task 2's criterion "the struct declares exactly three `public var` endpoints" is satisfied: `grep -n 'public var'` on the file returns four lines, three inside the struct (`start`, `updateProgress`, `finish`) and one for the `backgroundProcessingClient` accessor in the `DependencyValues` extension, which is not a struct member.
- Task 1's criterion "the summary records whether the launch handler and expiration handler inherited main-actor isolation directly or needed the assume-isolated form" is answered under Decisions Made: **both inherited directly**.

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands were run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5); the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed - project, scheme, test plan and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.
- The Simulator does not support background processing (the scheduler reports its unavailable error there), so no automated check in this plan exercises the framework end to end. The seam, the confinement and the zero-gates are what the automated evidence covers; SC1/SC2 device verification arrives with plan 15-06's integration.

## Issues Encountered

None.

## Verification Evidence

- `grep -c 'enum BackgroundProcessingEvent' ContinuedProcessingSession.swift` -> `1`, with exactly the three cases `granted`, `expired`, `unavailable` at lines 13, 18, 22.
- `grep -c '@MainActor' ContinuedProcessingSession.swift` -> `1` (on the class declaration, so every member is isolated).
- `grep -rn '@unchecked Sendable\|nonisolated(unsafe)\|swiftlint:disable' AppPackage/Sources/BackgroundProcessingClient | wc -l` -> `0`.
- `grep -c 'UUID()' ContinuedProcessingSession.swift` -> `1`; `grep -c 'try?' ContinuedProcessingSession.swift` -> `0`.
- `grep -rn '@available\|#available' AppPackage/Sources/BackgroundProcessingClient | wc -l` -> `0`.
- `test -f AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml && grep -c parent_config …` -> `1`.
- `grep -rn 'downloads[.]processing\|BGProcessingTask' App AppPackage ShareExtension | wc -l` -> `0` (repository-wide, un-narrowed).
- `grep -rn --include='*.swift' 'BGTaskScheduler' App AppPackage ShareExtension | cut -d: -f1 | sort -u` -> exactly one path, `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift`.
- `grep -c 'BGTaskScheduler' App/Info.plist` -> `1` and `grep -c 'BGTaskSchedulerPermittedIdentifiers' App/Info.plist` -> `1`; the equal counts prove the plist's only scheduler mention is the permitted-identifiers key.
- `grep -c 'public static let testValue = BackgroundProcessingClient()' BackgroundProcessingClient.swift` -> `1`; `grep -c 'ContinuedProcessingSession.shared' BackgroundProcessingClient.swift` -> `3`.
- No line in either file exceeds 120 characters (`awk 'length > 120'` -> no output).
- `xcodebuild -scheme EhPanda clean build` -> `** BUILD SUCCEEDED **` with zero `warning:`/`error:` lines, so the SwiftLint build-tool plugin reported no violations.
- `xcodebuild test -testPlan FeatureTests -only-testing:DownloadsFeatureTests` -> `Test run with 259 tests in 53 suites passed`, `** TEST SUCCEEDED **` (unchanged from 15-02's count).
- Full `FeatureTests` plan -> `** TEST SUCCEEDED **`; the reported "known issues" are the pre-existing `withKnownIssue` expectations, and the `DownloadCoordinator` "Network Error" lines are the suite's expected noise.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-04 gets a compiled, lint-clean seam to inject: `BackgroundProcessingClient.noop` is a valid default for the coordinator's stored dependency, and `.live` is ready for the composition root.
- Plan 15-05's coordinator guard layers on top of the store's own single-session guard rather than replacing it; both are needed, because the store cannot see queue state and the coordinator cannot see the scheduler.
- The event vocabulary plan 15-06 consumes is fixed: `granted` needs no action (work is already running), `expired` drives D-11's pause-all, `unavailable` is silent. Falling out of the `for await` loop needs no cancellation — the store finishes the stream itself.
- Assumption A3 is retired. Downstream plans can form main-actor closures against the scheduler without budgeting for an `assumeIsolated` workaround.

## Self-Check: PASSED

Both files exist on disk with the expected contents, and both task commits (`f2cf25a5`, `de269646`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
