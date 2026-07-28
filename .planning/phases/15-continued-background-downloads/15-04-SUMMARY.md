---
phase: 15-continued-background-downloads
plan: 04
subsystem: infra
tags: [localization, dependency-injection, test-double, asyncstream, backgroundtasks]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plan 15-03's three-endpoint session seam, its event vocabulary and its .noop value — this plan injects that exact seam and builds a spy against its signatures"
provides:
  - "Two localized card keys in six locales whose only arguments are labeled integer counts"
  - "A DownloadCoordinator that stores the session client as an injected dependency defaulting to .noop"
  - "Coordinator session state: hasLiveContinuedSession, continuedSessionTask, lastPushedCompletedPageCount"
  - "The live composition root injecting BackgroundProcessingClient.live straight into the coordinator"
  - "A Mutex-backed BackgroundProcessingClientSpy with a drivable, self-finishing event continuation"
  - "DownloadContinuedSessionTests seeded with the seam's contract coverage"
affects: [15-05, 15-06, 15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A numeric card argument is declared as a named %#@variable@ substitution so the generated symbol carries a labeled Int parameter; a bare %lld never reaches a module-local outer value"
    - "A stored client dependency with a `.noop` default keeps every pre-existing test construction compiling while the live composition root injects the real value"
    - "A test spy takes and clears its continuation in one critical section, so a terminal transition can never be applied twice to the same stream"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Package.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "The subtitle's `completed` substitution is other-only in all six locales while `total` and `galleries` carry one/other in en and de: only the two counts that are followed by a noun need a plural category, and the bare leading number needs none."
  - "DownloadClient.swift takes an explicit `import BackgroundProcessingClient` rather than relying on the same-module import in DownloadClient+Manager.swift, because Swift imports are file-scoped."
  - "The spy's contract case drains the stream after `expire()` rather than from a concurrent task: AsyncStream buffers the yielded event, so the assertion is deterministic and still proves the loop terminates without external cancellation."

patterns-established:
  - "A private `takeContinuation()` helper on a test spy, so both `expire()` and `finish` clear the continuation atomically with reading it"

requirements-completed: [SC2, SC4]

coverage:
  - id: D1
    description: "The card's title and subtitle are localized keys whose only inputs are integer counts; no gallery title, tag, category or identifier is reachable from the string builder"
    requirement: SC2
    verification:
      - kind: other
        ref: "Generated symbols are `.continuedSessionTitle` (no parameter) and `.continuedSessionSubtitle(completed: Int, total: Int, galleries: Int)` — three Int parameters and no String parameter, so no content-identifying text has a path into the card"
        status: pass
      - kind: other
        ref: "Structural catalog script: no locale's outer stringUnit.value on either key contains %lld or %d; the subtitle's substitution set is exactly {completed, total, galleries} in all six locales, each formatSpecifier lld => exit 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every new localized key carries all six catalog locales, and every numeric argument is a named substitution rather than a bare numeric format specifier"
    requirement: SC2
    verification:
      - kind: other
        ref: "Catalog script asserts the localizations key set equals {en, de, ja, ko, zh-Hans, zh-Hant} for both keys; plural category sets of `total` and `galleries` are equal between en and de, and exactly {other} in ja/ko/zh-Hans/zh-Hant => exit 0"
        status: pass
      - kind: other
        ref: "Clean app-scheme build => BUILD SUCCEEDED with zero warning:/error: lines, proving the catalog parses and the symbols generate"
        status: pass
    human_judgment: false
  - id: D3
    description: "The unimplemented test value reports an issue when any of its three endpoints is called, so an unexpected call fails a test loudly rather than silently succeeding"
    requirement: SC4
    verification:
      - kind: unit
        ref: "testUnimplementedClientReportsAnIssueForEveryEndpoint wraps each of start/updateProgress/finish in withKnownIssue; the run reports exactly 3 known issues, and withKnownIssue itself fails when no issue is recorded"
        status: pass
    human_judgment: false
  - id: D4
    description: "The download coordinator stores the session client as an injected dependency defaulting to the no-op value, so every existing test-constructed coordinator still compiles unchanged"
    requirement: SC4
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests after Task 2 => Test run with 259 tests in 53 suites passed, with zero test-source edits in that commit"
        status: pass
      - kind: other
        ref: "grep -c 'public let backgroundProcessingClient: BackgroundProcessingClient' => 1; grep -c 'backgroundProcessingClient: BackgroundProcessingClient = .noop' => 1; grep -c 'backgroundProcessingClient: .live' DownloadClient.swift => 1"
        status: pass
    human_judgment: false
  - id: D5
    description: "The system card renders and, where necessary, truncates the localized title and subtitle under system policy; the app declares no length limit of its own on either string"
    verification:
      - kind: other
        ref: "The app supplies both strings verbatim to the client and neither the catalog nor any Swift source imposes a character budget; the actual rendering and truncation happen in system UI on device"
        status: pass
    human_judgment: true
    rationale: "Backstop criterion. The Simulator does not support background processing, so no automated check can render the card; the source-level claim (no app-declared limit) is verifiable, the visual outcome is not until plan 15-06's device pass."
  - id: D6
    description: "The existing queue behavior is unchanged by the injection and the test-support additions"
    verification:
      - kind: unit
        ref: "Full DownloadsFeatureTests after Task 3 => Test run with 262 tests in 54 suites passed (259 baseline + the 3 new cases)"
        status: pass
      - kind: other
        ref: "Clean app-scheme build after Task 3 => BUILD SUCCEEDED, zero warning:/error: lines, so the SwiftLint build-tool plugin reported no violations"
        status: pass
    human_judgment: false

# Metrics
duration: 13min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 04: Card Strings, Client Injection and the Session Spy Summary

**The download coordinator now holds the continued-processing session client as an injected dependency, the system card's counts-only vocabulary exists in six locales as labeled integer parameters, and a drivable spy plus a contract suite are in place for every later behavior plan.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-28T00:30:18Z
- **Completed:** 2026-07-28T00:43:20Z
- **Tasks:** 3
- **Files modified:** 7 (1 created)

## Accomplishments

- `continued_session.title` is a plain six-locale `stringUnit` key with no substitution and no argument at all. Its English value is `Downloading galleries`; the other five locales say the same thing and nothing more. There is deliberately no way to parameterize it.
- `continued_session.subtitle` carries three named substitutions — `completed` (argNum 1), `total` (argNum 2), `galleries` (argNum 3) — each with `formatSpecifier` `lld`. Every locale's outer value is `%#@completed@ / %#@total@ · %#@galleries@`; only the substitution variations differ by language. `completed` is `other`-only everywhere (it is a bare number with no following noun), while `total` and `galleries` carry `one` and `other` in `en` and `de` and are `other`-only in the four CJK locales.
- The generated symbols came out exactly as the plan predicted: `.continuedSessionTitle` and `.continuedSessionSubtitle(completed: Int, total: Int, galleries: Int)`. Three `Int` parameters, no `String` parameter — the card's vocabulary is structurally incapable of carrying a gallery title, tag or identifier (T-15-01).
- `DownloadCoordinator` gained `public let backgroundProcessingClient: BackgroundProcessingClient` in the same block as its other injected collaborators, sitting in the slot the deleted execution assertion occupied, with an initializer parameter defaulting to `.noop`.
- Its doc comment records the deliberate divergence: the assertion client had no dependency-key registration and therefore nowhere for an unimplemented test value to live, whereas this client keeps both its key registration and its `DependencyValues` accessor while still being injected directly, because download-start calls flow synchronously from user actions into this actor and it is the only place that knows real queue progress.
- Session state landed next to the other mutable coordinator state: `hasLiveContinuedSession`, `continuedSessionTask` and `lastPushedCompletedPageCount`. The flag's doc comment states why one boolean suffices where the assertion needed two — it is set synchronously before the start path's first suspension point and is never rolled back — and why the guard matters at all: a second registration of the same identifier terminates the app, and two live sessions would put two cards on screen.
- `DownloadClient.live(rootURL:urlSession:fileManager:)` now passes `backgroundProcessingClient: .live` in the argument position matching the initializer. No behavior was added: nothing calls the client yet.
- `BackgroundProcessingClientSpy` keeps its whole state behind a single `Mutex` from `Synchronization` and exposes read-only computed properties for the start count, the recorded titles and subtitles, the ordered progress records, the finish count and the recorded success flags. `emit(_:)` yields on the live continuation; `expire()` yields `.expired` and finishes, mirroring the real client's self-finishing contract.
- `makeBlockingCoordinator` gained a `backgroundProcessingClient: BackgroundProcessingClient = .noop` parameter forwarded into the coordinator, so the session suites can drive the fixture through the spy while every existing caller stays untouched.
- `DownloadContinuedSessionTests` seeds three contract cases that depend on no coordinator behavior at all: the unimplemented test value reports an issue at each of its three endpoints, the no-op value's `start` hands back an already-finished stream while its other two endpoints complete without effect, and the spy records what was pushed and terminates its own stream on expiration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the neutral card title and count subtitle to the module catalog** - `763ef0eb` (feat)
2. **Task 2: Inject the session client and its state into the download coordinator** - `60442914` (feat)
3. **Task 3: Add the session client spy and the seam contract suite** - `0381ac21` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` (modified, 6 keys -> 8) - The two card keys, each in all six locales.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` (modified) - The stored client, its documented divergence, the three session-state fields and the initializer parameter/assignment.
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` (modified) - `import BackgroundProcessingClient` and the `.live` injection in the composition root.
- `AppPackage/Package.swift` (modified) - `.module(.backgroundProcessingClient)` added to the `downloadClient` target; the stale `.module(.appModels)` removed from the `backgroundProcessingClient` target.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` (modified, +88 lines) - `BackgroundProcessingClientSpy` and its `ProgressUpdate` record.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` (modified) - The fixture's injectable client parameter.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` (created, 74 lines) - The seam's contract coverage.

## Decisions Made

- **The `completed` substitution is `other`-only in every locale, unlike its two siblings.** The plan fixed this shape and the reason is worth recording: `completed` renders as a bare number immediately followed by a separator, so it has no noun to agree with and no plural category to get wrong. `total` and `galleries` are each followed by a counted noun, so they carry `one`/`other` in `en` and `de` — and, per the repo rule, those two category sets are equal to each other, which the structural check asserts directly rather than assuming.
- **`DownloadClient.swift` takes its own `import BackgroundProcessingClient`.** `DownloadClient+Manager.swift` already imports the module, but Swift imports are file-scoped, so the implicit-member expression `.live` needs the type visible in the file that writes it. The alternative — relying on transitive visibility — is exactly the kind of accident that breaks on an unrelated import change later.
- **The spy's contract case drains the stream after `expire()`, not from a concurrent task.** `AsyncStream`'s default buffering keeps the yielded events, so consuming afterwards is deterministic: no task, no timeout, no polling. It still proves the loop terminates on its own, because nothing cancels it and a stream left open would hang the case rather than pass it. A concurrent-consumer variant would have added a wall-clock deadline for no additional evidence.
- **Both `expire()` and the spy's `finish` route through one private `takeContinuation()`.** Reading and clearing the continuation in the same critical section is what makes a second terminal transition structurally impossible, which is the same discipline `ContinuedProcessingSession.endSession` uses in production. A spy that could double-finish would let a later plan's bug pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `import BackgroundProcessingClient` to `DownloadClient.swift`**

- **Found during:** Task 2
- **Issue:** The plan specified only the `.live` argument in the composition root, but Swift imports are file-scoped, so the implicit-member expression could not resolve its base type in that file.
- **Fix:** Added the import in sorted position (after `AppTools`, before `ComposableArchitecture`), matching the `sorted_imports` error-severity rule.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient.swift`
- **Commit:** `60442914`

## Carried-Forward Cleanup

The `backgroundProcessingClient` target's `.module(.appModels)` dependency, deferred here by plan 15-03, is removed. The import it backed was already dead before that plan — `grep -rn 'AppModels' AppPackage/Sources/BackgroundProcessingClient` returns nothing — so the entry was pure build-graph weight. `swift package dump-package` now reports the target's dependencies as `OSLogExt` plus the ComposableArchitecture product, and the clean app-scheme build is unaffected.

## Deferred Items

None.

## Acceptance-Criteria Notes

- The structural catalog check was written as a throwaway script under the session scratch directory and run with `python3`; it exits `0`. It asserts the locale set, the substitution set and `formatSpecifier`, the absence of `%lld`/`%d` in every outer value, the en/de category equality for `total` and `galleries`, and the `{other}`-only sets in the four CJK locales.
- Task 3's criterion "three or more cases executed" is satisfied exactly: the targeted run reports `Test run with 3 tests in 1 suite passed ... with 3 known issues`. The three known issues are the deliberate `withKnownIssue` expectations against the unimplemented test value, not failures.

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands were run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5); the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed — project, scheme, test plan and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.
- The Simulator does not support background processing, so nothing in this plan exercises the framework end to end. Everything asserted here is seam shape, catalog structure and test-double behavior.

## Issues Encountered

None.

## Verification Evidence

- `python3 <scratch>/check_catalog.py` -> `PASS: both keys structurally valid; catalog holds 8 keys`, exit `0`.
- `python3 -c "import json;print(len(json.load(open('AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings'))['strings']))"` -> `8`.
- `grep -c 'continued_session.title' …/Localizable.xcstrings` -> `1`.
- Generated symbol source (`DownloadClient.build/DerivedSources/GeneratedStringSymbols_Localizable.swift`) declares `static func continuedSessionSubtitle(completed: Int, total: Int, galleries: Int) -> LocalizedStringResource` and `static var continuedSessionTitle: LocalizedStringResource`.
- `grep -c 'public let backgroundProcessingClient: BackgroundProcessingClient' …/DownloadClient+Manager.swift` -> `1`.
- `grep -c 'backgroundProcessingClient: BackgroundProcessingClient = .noop' …/DownloadClient+Manager.swift` -> `1`.
- `grep -c 'hasLiveContinuedSession' …/DownloadClient+Manager.swift` -> `1`.
- `grep -c 'backgroundProcessingClient: .live' …/DownloadClient.swift` -> `1`.
- `swift package dump-package --package-path AppPackage` -> exit `0`; the `DownloadClient` target lists `BackgroundProcessingClient`, and the `BackgroundProcessingClient` target no longer lists `AppModels`.
- `grep -c 'final class BackgroundProcessingClientSpy' …/DownloadFeatureTestSupportTypes.swift` -> `1`; `grep -c 'NSLock'` on the same file -> `0`.
- `grep -c 'withKnownIssue' …/DownloadContinuedSessionTests.swift` -> `3`.
- `grep -c 'backgroundProcessingClient' …/DownloadFeatureTestHelpers.swift` -> `2`.
- `awk 'length > 120'` over every file this plan created or modified -> no output.
- Task 2 test run: `xcodebuild test -testPlan FeatureTests -only-testing:DownloadsFeatureTests` -> `Test run with 259 tests in 53 suites passed`, `** TEST SUCCEEDED **`, with no test-source changes in that commit.
- Task 3 targeted run: `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` -> `Test run with 3 tests in 1 suite passed ... with 3 known issues`, `** TEST SUCCEEDED **`.
- Task 3 full target: `-only-testing:DownloadsFeatureTests` -> `Test run with 262 tests in 54 suites passed ... with 3 known issues`, `** TEST SUCCEEDED **`.
- `xcodebuild clean build -scheme EhPanda` (run after Task 2 and again after Task 3) -> `** BUILD SUCCEEDED **`, zero `warning:`/`error:` lines both times.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-05 has the state it needs already declared: `hasLiveContinuedSession` for the start guard, `continuedSessionTask` for the consuming task's handle, `lastPushedCompletedPageCount` for the progress throttle. Nothing in this plan reads or writes any of them, so 15-05 is a pure behavior change.
- The card strings are callable as `.continuedSessionTitle` and `.continuedSessionSubtitle(completed:total:galleries:)` with no shared-resources prefix; the consuming file needs `import Resources`, as `DownloadStore+Operations.swift` does.
- `makeBlockingCoordinator(gid:title:backgroundProcessingClient:)` is the fixture the session suites drive, and `BackgroundProcessingClientSpy` records every string and count the coordinator pushes, so plan 15-06's behavioral assertion on the exact card strings (T-15-01's behavioral half) has its instrument ready.
- The spy's `emit(_:)` can deliver `.granted` or `.unavailable` without ending the session, and `expire()` delivers D-11's pause-all trigger and then finishes, so a consuming loop under test ends the same way it will in production.

## Self-Check: PASSED

All seven files exist on disk with the expected contents, and all three task commits (`763ef0eb`, `60442914`, `0381ac21`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
