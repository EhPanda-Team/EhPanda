---
phase: 15-continued-background-downloads
plan: 07
subsystem: infra
tags: [backgroundtasks, invariant, static-analysis, roadmap, phase-gates]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plans 15-01 through 15-06 — the deletions this invariant guards, the client seam it scopes, and the session coverage the gates confirm still passes"
provides:
  - "A permanent source-tree invariant that fails if any deleted background-execution spelling reappears in the app target, the package sources, the package tests, the extension, or the app plist"
  - "A scheduler-scope assertion naming the client seam as the only module allowed to reference the system task scheduler, with the one plist exemption paid for by a stricter count assertion"
  - "A roadmap Phase 15 entry that states the shipped contract and records its open scope question as answered"
  - "The phase's green automated gates, plus the owner's device observation script staged as the manual half"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A deletion decision with no surviving symbol is enforced by reading the source tree at test time, because there is nothing left for an ordinary unit test to call"
    - "A scanned token is assembled from fragments at run time, so the scanner is not a self-match and the repository grep gates can still read zero"
    - "An unavoidable exemption is narrowed rather than waived: the exempt file stays in every other scan and gains an assertion no unexempted form could express"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  modified:
    - .planning/ROADMAP.md

key-decisions:
  - "The invariant reads the repository from `#filePath` upward until it finds the directory holding both `App` and `AppPackage`, so it works from any contributor's checkout rather than from a machine-specific absolute path."
  - "`App/Info.plist` stays fully in scope for the forbidden-token scan and is exempt only from the scheduler-scope assertion, because the system key name contains the scheduler type name by construction. The exemption is paid for by requiring that every plist line mentioning the scheduler is that one key, so a second mention diverges the counts and fails."
  - "Every scanned token — including the scheduler name and the permitted-identifiers key — is concatenated from fragments at run time. A literal would make the file its own violation and would put the repository grep gates permanently above zero."
  - "The roadmap's open scope question is rewritten as answered rather than deleted, so a later reader sees the question and its resolution instead of a gap."

patterns-established:
  - "Demonstrating the invariant on a deliberate scratch violation before accepting it, so a check that has never been seen to fail is not mistaken for a check that works"

requirements-completed: [SC1, SC2, SC3, SC4]

coverage:
  - id: D1
    description: "No spelling from either deleted background-execution mechanism survives anywhere in the app target, the package sources, the package tests, the extension, or the app plist"
    requirement: SC3
    verification:
      - kind: unit
        ref: "BackgroundExecutionInvariantTests#testNoDeletedBackgroundExecutionSpellingSurvivesAnywhere — eight forbidden tokens scanned across every in-scope file, plist presence in the scan asserted explicitly"
        status: pass
      - kind: other
        ref: "The same test fails on a deliberate scratch violation under AppPackage/Sources and returns to green when it is removed (see Verification Evidence)"
        status: pass
      - kind: other
        ref: "Repository gates: deleted symbols 0, deleted identifiers 0, banned concurrency spellings 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "The system task scheduler is named by exactly one module, the client seam, and the app plist's only mention of it is the permitted-identifiers key"
    requirement: SC4
    verification:
      - kind: unit
        ref: "BackgroundExecutionInvariantTests#testTheSystemSchedulerIsNamedOnlyByTheClientSeam — scope assertion with a named `schedulerScopeExemptions` constant, plus the paired plist count assertion"
        status: pass
      - kind: other
        ref: "grep -rn --include='*.swift' scheduler-name over App AppPackage ShareExtension lists only AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        status: pass
      - kind: other
        ref: "grep -c on App/Info.plist for the scheduler name and for the permitted-identifiers key both return 1"
        status: pass
    human_judgment: false
  - id: D3
    description: "No planning artifact contradicts the shipped code: the roadmap states the superseded contract and records its scope question as answered"
    verification:
      - kind: other
        ref: "'Open for discuss-phase' count 1 -> 0; 'Resolved in discuss-phase' count 0 -> 1; '### Phase' count unchanged at 16; SC1 and SC2 byte-identical (git diff shows 4 changed lines only)"
        status: pass
      - kind: other
        ref: "Phase 15 SC3 no longer contains 'falls back'; SC4 no longer contains the register/schedule/cancel shape wording and does contain 'coordinator'"
        status: pass
    human_judgment: false
  - id: D4
    description: "The whole test plan and a clean app-scheme build stay green with the invariant in place"
    verification:
      - kind: unit
        ref: "Full FeatureTests plan, all 22 targets => ** TEST SUCCEEDED ** [62.799 sec], zero failure lines; DownloadsFeatureTests at 286 tests in 55 suites; DownloadSchedulingTests passed"
        status: pass
      - kind: other
        ref: "xcodebuild clean build -scheme EhPanda => ** BUILD SUCCEEDED **, zero warning: and zero error: lines, so the SwiftLint build-tool plugin reported no violations"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a device, a queue large enough to outlast the old grace window keeps downloading while backgrounded and the system card's counts advance"
    requirement: SC1
    verification: []
    human_judgment: true
    rationale: "The Simulator does not support background processing, so no simulator run can make the system grant a session. Covered by steps 1-4 of the device observation script below."
  - id: D6
    description: "On a device, the card shows the neutral title and count subtitle with no gallery title, persists across a foreground return, and its cancel leaves every gallery paused exactly as an in-app pause would"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "The card is system UI outside the app process and is unavailable in the Simulator. Covered by steps 3, 5, 6 and 8 of the device observation script below."
  - id: D7
    description: "Force-quitting from the app switcher mid-session and relaunching produces no crash and no duplicated pages"
    requirement: SC1
    verification: []
    human_judgment: true
    rationale: "Process lifecycle is not reproducible in unit tests. Covered by step 7 of the device observation script below."

# Metrics
duration: 16min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 07: Topology Invariant, Roadmap Amendment and Phase Gates Summary

**The phase's deletion decision is now enforced by a test that reads the source tree rather than by a document nobody's build opens, the roadmap says what was actually built, and every automated gate is green with the device-only half handed to the owner as an unambiguous script.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-28T01:29:00Z
- **Completed:** 2026-07-28T01:45:00Z
- **Tasks:** 3
- **Files modified:** 2 (1 created)

## Accomplishments

- `BackgroundExecutionInvariantTests` scans every `.swift` file under `App`, `AppPackage/Sources`, `AppPackage/Tests` and `ShareExtension`, plus `App/Info.plist`, for eight forbidden spellings: the discretionary processing-task class, the UIKit execution-assertion method, the deleted assertion client type, the deleted drain method, the two deleted task identifiers, and the two concurrency escape hatches the linter bans. A deletion leaves no symbol to call, so there was nothing an ordinary unit test could have asserted against; the suite reads the sources instead.
- The scan is asserted to be non-empty before anything is asserted about its contents, and the plist's presence in the file list is asserted by name. A check that silently finds nothing to read passes for the wrong reason, which is worse than having no check.
- The positive half asserts the system task scheduler is named only by files under the client-module directory. `App/Info.plist` is exempt from that assertion alone, through a named `schedulerScopeExemptions` constant carrying a prose rationale: the system key's *name* contains the scheduler type name by construction, so an unexempted form would be permanently unsatisfiable rather than stricter. The exemption is paid for in the same test — every plist line mentioning the scheduler must be that one key declaration, so a second, different mention makes the counts diverge and fails. The plist also stays fully in scope for the forbidden-token scan, which is where a returning identifier string would show up first.
- Every scanned token is concatenated from fragments at run time, with the reason stated at the constant: a literal would make this file its own violation, and the repository-wide grep gates could then never read zero. That applies to the scheduler name and the permitted-identifiers key too, which is why the Swift-scoped scheduler gate still lists exactly one path.
- The invariant was demonstrated to fail before it was accepted. A one-line scratch file under `AppPackage/Sources/BackgroundProcessingClient/` carrying one forbidden token made the suite fail, naming both the token's description and the offending path; removing the file returned it to green. An invariant that has never been seen to fail is not yet an invariant.
- The repository root is derived by walking up from `#filePath` until a directory holding both `App` and `AppPackage` is found, and the walk failing is a loud `#require` failure. Nothing about the check depends on where the checkout lives.
- The roadmap's Phase 15 entry now states the shipped contract. SC3 says there is no fallback tier and that the two mechanisms are deleted rather than fallen back to; SC4 describes the session seam and names the coordinator alongside reducers; the goal sentence no longer promises the discretionary window as a destination. SC1 and SC2 are byte-identical to their pre-edit text, and the other fifteen phase entries are untouched.
- The open scope question is rewritten as **Resolved in discuss-phase** rather than deleted. A question recorded with its answer tells the next reader more than a question that vanished.

## Task Commits

Each task was committed atomically:

1. **Task 1: Encode the topology decision as a permanent invariant** - `a5cc93b5` (test)
2. **Task 2: Amend the roadmap entry to the shipped contract** - `c3e93900` (docs)
3. **Task 3: Run the phase gates and stage the device observation** - no commit; the task changes no source unless a gate fails, and none did. Its record is this summary, committed with it.

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift` (created, 266 lines) - The two-test invariant suite, its scan scope, its assembled tokens, and the documented scheduler-scope exemption.
- `.planning/ROADMAP.md` (modified, 4 lines changed) - Phase 15 goal, SC3, SC4, and the open-scope line.

## Phase Gate Results

| Gate | Result |
|------|--------|
| Full `FeatureTests` plan (22 targets) | `** TEST SUCCEEDED ** [62.799 sec]`, zero failure lines, no target skipped |
| `DownloadsFeatureTests` | `Test run with 286 tests in 55 suites passed` (284 baseline + 2 new) |
| `DownloadSchedulingTests` | `✔ Suite DownloadSchedulingTests passed after 3.447 seconds` |
| `BackgroundExecutionInvariantTests` | `✔ Suite BackgroundExecutionInvariantTests passed after 3.417 seconds` |
| Clean app-scheme build (runs SwiftLint via its build plugin) | `** BUILD SUCCEEDED **`, `warning:` count 0, `error:` count 0 |
| Deleted-symbol zero-gate | `0` |
| Deleted-identifier zero-gate | `0` |
| Banned-concurrency-spelling zero-gate | `0` |
| Swift-scoped scheduler gate | one path: `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` |
| Plist paired count gate | scheduler-name lines `1`, permitted-identifiers-key lines `1` |

Nothing failed, so no source was changed in Task 3.

## What the Automated Gates Do and Do Not Cover

The split runs straight down the seam, and it is inherent to the API rather than a gap in the work.

**Covered — everything the app decides.** Whether a session is started, and from which taps. That a second tap while a session is live starts no second session. The arithmetic the card is handed: completed pages over total pages across every schedulable gallery, monotonic within a session, never zero-denominator. That the pushed strings carry counts only, with no gallery title and no identifier. That the session is completed exactly once when the queue actually drains, and never on a foreground return. That an expiration leaves the queue in the state a per-gallery in-app pause produces, compared against that path's real output. That an unavailable session is indistinguishable from having no session client at all. And, from this plan, that no deleted mechanism has come back and that the scheduler is reachable from one module only.

**Not covered — everything the system decides.** The iOS SDK states the Simulator does not support background processing, so no simulator run can show that the system *grants* a session, that the card *appears*, what the card *renders*, or where its cancel affordance *routes from*. SC1's second half (a real queue outlasting the old grace window while backgrounded) and SC2's second half (the card's actual appearance and its cancel) are device-only by construction. No claim in this phase's artifacts asserts them from a simulator run.

## Device Observation Script (owner-run, end-of-phase manual gate)

Reproduced verbatim from `15-VALIDATION.md` § Manual-Only Verifications. Run on a physical device on the current OS with a release-configuration build installed.

1. Queue ≥ 3 galleries totalling ≥ 300 pages.
2. Tap start; confirm downloads begin **immediately** (work must not wait on the session).
3. Background the app. Confirm the system card appears with the neutral title + count subtitle and **no gallery title**.
4. Leave backgrounded past ~60s (comfortably beyond the old grace window). Confirm the card's counts advance.
5. Foreground; confirm the card persists (D-08) and in-app progress matches the card.
6. Background again, tap **cancel** on the card. Foreground; confirm every gallery is Paused, identical to having tapped pause on each.
7. Separately: force-quit from the app switcher mid-session and relaunch; confirm no crash and no duplicated pages.
8. Optional: capture a screenshot of the card for the phase record, confirming no content-identifying text is visible.

Reply with the observed outcome of each numbered step.

## Retained Background-Modes Declaration and Its Optional Follow-Up

`App/Info.plist` still declares `UIBackgroundModes: processing`, kept deliberately in plan 15-01 with the rationale recorded as an XML comment beside the key. No Apple source settles whether a continued-processing submission consults that declaration, and the failure modes are asymmetric: an unnecessary declaration costs one stray key, while a wrong removal makes every submission fail with the scheduler's not-permitted error — which would cost SC1 outright.

The follow-up probe, deliberately not attempted here: remove the declaration as an isolated, one-line, revertible plist edit and verify on a device that submission still succeeds — that is, that it does not fail with the scheduler's not-permitted error. It is a device experiment of its own, and nothing in this phase depends on its outcome. Leaving the key in place is the safe default until someone runs it.

## Decisions Made

- **The invariant reads the tree from `#filePath` upward.** It walks parent directories until one holds both `App` and `AppPackage`, and fails loudly with `#require` if the walk runs out. No machine-specific path appears anywhere in the file, so it works from any checkout.
- **The plist is exempt from one assertion and from one assertion only.** The exemption lives in a named constant with the reasoning written out, because the next reader's most likely mistake is to see an exemption and "helpfully" delete it. The prose says plainly that deleting it makes the assertion permanently unsatisfiable rather than stricter, and the paired count assertion in the same test makes the exemption a narrowing rather than a waiver.
- **Tokens are assembled at run time.** Deliberate obfuscation for a mechanical reason, stated at the site: a literal is a self-match. The scheduler name is assembled for the same reason, which is what keeps the Swift-scoped scheduler gate down to a single path.
- **Task 3 committed nothing.** The plan scopes it to running gates and changing source only if one fails. None did, so the honest outcome is no commit and a recorded result.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The roadmap's Phase 15 progress row carried Phase 16's name**

- **Found during:** Task 3, immediately after `roadmap update-plan-progress 15` wrote `7/7` into that row
- **Issue:** The progress table row tracking this phase read `| 15. Dynamic Type Accessibility | 6/7 | In Progress| |` — Phase 16's name on Phase 15's row. It predates this plan, and the tooling this plan is required to run writes into that exact row, so leaving it would have shipped a row asserting this phase's plan count under another phase's name, against this plan's own success criterion that no planning artifact contradicts the code.
- **Fix:** One-word label correction to `| 15. Continued Background Downloads | 7/7 | In Progress| |`. No other row touched, no count changed by hand.
- **Files modified:** `.planning/ROADMAP.md`
- **Committed in:** the final metadata commit

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** None on scope. Task 2's acceptance criteria are unaffected — the Phase 15 detail section is exactly as the plan specified, and `grep -c '^### Phase'` is still `16`.

Two further roadmap staleness findings in the same table were left alone as genuinely out of scope and logged to `deferred-items.md` in this phase directory: the table has no Phase 16 row, and the execution-order line still stops at 15.

One local adjustment that is not a plan deviation is recorded under Environment Notes: this machine has no `iPhone 17` simulator, so every `xcodebuild` invocation ran against a locally available destination. Only the destination changed.

## Issues Encountered

- The first compile of the invariant file failed with `method must be declared private because its result uses a private type`: `scannedFiles(under:)` sat in a `private extension`, whose members land at file scope, while its `ScannedFile` result type is private to the enclosing struct. Fixed by marking the method `private` explicitly rather than by widening the nested type, which keeps both the helper and its result invisible outside the suite.

## Acceptance-Criteria Notes

- Task 1 asked for the invariant to be demonstrated failing on a deliberate violation, with both outcomes recorded. Both are in Verification Evidence below: the failing run names the offending path, and the run after removal is green.
- Task 2's criterion that SC1 and SC2 stay byte-identical is checked by the diff itself — `git diff` on the roadmap reports 4 insertions and 4 deletions, none of them on the SC1 or SC2 lines.
- Task 3's criterion that no target is skipped is met: the run reports 22 test-run summaries, one per target in the plan. The two `Skipped assertions.` lines in the log belong to pre-existing `withKnownIssue` cases in `SettingReducerTests` and `SettingPresentationTests`, not to skipped targets.

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands ran with a locally available iPhone Air (iOS 26.5) destination pinned by simulator id, because the device name alone is ambiguous here. Only the destination changed — project, scheme, test plan and `-only-testing` flags are exactly as the plan specifies. This is a local environment fact, not a plan deviation, and no machine-specific simulator id appears in the device observation script above, which the owner runs on real hardware.
- Bare `swift build` / `swift test` in `AppPackage` fail on the macOS host because the package targets iOS; all building and testing went through the Xcode project and the iOS Simulator.
- The suite uses Swift Testing, so the `Executed 0 tests` line from the empty XCTest counter is expected and is not a failure. The `Network Error` lines in the `DownloadsFeatureTests` log are deliberate stub failures, also expected.
- The known issues the runs report (1 in `AppFeatureTests`, 3 in `DownloadsFeatureTests`, 2 each in two setting targets) are pre-existing seeded expectations, not regressions.

## Verification Evidence

- Targeted run, `-only-testing:DownloadsFeatureTests/BackgroundExecutionInvariantTests` -> `✔ Test run with 2 tests in 1 suite passed after 0.496 seconds`, `** TEST SUCCEEDED **`.
- Deliberate-violation run, with a one-line scratch file under `AppPackage/Sources/BackgroundProcessingClient/` containing one forbidden token -> `✘ Test testNoDeletedBackgroundExecutionSpellingSurvivesAnywhere() recorded an issue … the deleted UIKit execution-assertion method name reappeared in: AppPackage/Sources/BackgroundProcessingClient/ScratchInvariantProbe.swift`, `** TEST FAILED **`.
- Scratch file removed; re-run -> `✔ Test run with 2 tests in 1 suite passed after 0.539 seconds`, `** TEST SUCCEEDED **`. `git status --short` confirms no scratch file remains.
- Full `FeatureTests` plan -> exit `0`, `** TEST SUCCEEDED ** [62.799 sec]`, 22 test-run summaries, zero `✘` lines.
- `xcodebuild clean build -project EhPanda.xcodeproj -scheme EhPanda` -> `** CLEAN SUCCEEDED **`, `** BUILD SUCCEEDED **`, `grep -c 'warning:'` -> `0`, `grep -c 'error:'` -> `0`.
- Deleted-symbol gate over `App AppPackage ShareExtension` -> `0`.
- Deleted-identifier gate over `App AppPackage ShareExtension` -> `0`.
- Banned-concurrency-spelling gate over `App AppPackage ShareExtension` -> `0`.
- Swift-scoped scheduler gate -> a single path, `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift`.
- `grep -c` on `App/Info.plist` for the scheduler name -> `1`; for the permitted-identifiers key -> `1`.
- `grep -c 'Open for discuss-phase' .planning/ROADMAP.md` -> `1` before, `0` after. `grep -c 'Resolved in discuss-phase'` -> `0` before, `1` after. `grep -c '^### Phase'` -> `16` before and after.
- Phase 15 section: `grep -c 'falls back'` -> `0`; register/schedule/cancel shape wording -> `0`; `grep -c 'coordinator'` -> `1`.
- `awk 'length > 120'` over the new test file -> no output.
- `grep -c 'swiftlint:disable'` over the new test file -> `0`.

## User Setup Required

None - no external service configuration required. The device observation script above is the owner's manual gate, not a setup step.

## Next Phase Readiness

- Every automated gate this phase can run is green, and the invariant makes the topology decision self-enforcing for future phases: reintroducing any deleted mechanism fails the standing test suite rather than merely contradicting a document.
- What remains before the phase can be called verified is the owner's device observation, which covers the framework half of SC1 and SC2 and the force-quit case. It is device-only by construction, not by omission.
- One optional follow-up is staged and explicitly not blocking: the background-modes probe described above.
- No deferred items.

## Self-Check: PASSED

`AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift` and `.planning/ROADMAP.md` both exist on disk with the expected contents, and both task commits (`a5cc93b5`, `c3e93900`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
