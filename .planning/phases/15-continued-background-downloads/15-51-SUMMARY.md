---
phase: 15-continued-background-downloads
plan: 51
subsystem: downloads
tags: [background-processing, continued-session, bgtaskscheduler, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-50's run-work basis, taken as the head this plan's full-suite total is measured against — no file overlap, only xcodebuild serialization and run attribution"
  - phase: 15-continued-background-downloads
    provides: "15-37's WR-08 identity-before-hand-over ordering in `start`, which the new registration branch had to leave intact"
provides:
  - "ContinuedProcessingSession.registeredIdentifier — the one identifier this process registers a launch handler under, recorded only where `scheduling.register` returned true"
  - "A registration branch in `start` that reuses the stored identifier and skips the register call, replacing the unconditional per-session mint"
  - "testTwoSequentialSessionsRegisterOneIdentifierAndSubmitTwice — one distinct registered identifier against two submissions, observed RED first"
  - "testAStaleLaunchIsCompletedAndNeverDisplacesTheHeldTask — the rebuilt stale-launch case, staged behind adoption (renamed from ...TheAwaitedTask)"
  - "A rebuilt `testAStaleNilLaunchCannotEndALiveSession`, staged behind adoption for the same reason"
  - "An arrival-state enumeration on `handleLaunch` stating what the identity comparison can and cannot distinguish under a process-scoped identifier"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "An arm split expressed by the PLACEMENT of a single assignment rather than by a branch that classifies arms"
    - "A constraint met at its actual strength (uniqueness) rather than at a stronger one that happened to imply it (freshness)"
    - "When a change dissolves a case's staging, the case is rebuilt around the property that survives — never re-pointed at a new literal"
    - "A consequence with no available mitigation is enumerated in the doc of the function that owns it, with its harm assessed against the pre-change behaviour"

key-files:
  created: []
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift

# Decisions
decisions:
  - "The identifier is recorded only where `scheduling.register` returned true; that single placement is the whole arm split, so a refused registration records nothing and a successful one is never re-registered."
  - "A refused identifier is never re-attempted — the conservative reading of the store's own constraint, taken because departing from it needs device evidence this plan does not have."
  - "Registration ATTEMPTS stay unbounded while successful registrations are bounded at one; bounding attempts would let one transient refusal permanently disable background coverage."
  - "The awaiting-window loss of launch discrimination is dispositioned in writing rather than mitigated, because the SDK supplies nothing that could separate a leftover launch from a live one under one identifier."
  - "Both dissolved-subject cases are rebuilt by staging the stale delivery behind adoption, which reaches the surviving property without two identifiers."

metrics:
  duration: 32min
  completed: 2026-08-07
status: complete
---

# Phase 15 Plan 51: One Registered Identifier Per Process Summary

G-15-31 closed: `ContinuedProcessingSession` now registers one launch handler per process and
re-submits that identifier for every later session, with the two failure arms separated by where a
single assignment sits rather than by a branch that classifies them.

## What Was Built

`start` no longer mints an identifier per call. It reuses a stored `registeredIdentifier` when one
exists and skips the register call entirely; only when none exists does it mint, register, and — on
the path where `scheduling.register` returned true — record. The `live` note and `handleLaunch`'s doc
were rewritten to state the rule the code now follows and the consequence the reuse carries, and
every assertion in the lifecycle suite that pinned per-session minting was re-derived to the property
its case actually guards.

## Derivation A — the two failure arms, separately

| Arm | `register` reached | returned true | permanent handler now exists | request pending at exit |
|---|---|---|---|---|
| missing bundle identifier (`:130-134` pre-change) | no | — | no | no |
| refused registration (`:141-152` pre-change) | yes | **false** | **no** | no |
| throwing submit (`:167-184` pre-change) | yes | **true** | **YES** | no — the take-back at `endSession`'s `:297`/`:306-308` fires |
| ordinary success | yes | true | YES | yes, until adoption or the take-back |

A retry adds a permanent handler on the throwing-submit arm and on the ordinary success path. It
adds nothing on the missing-bundle-identifier and refused-registration arms.

**Where the unboundedness actually lived:** among the two failure arms, on the throwing-submit arm
alone — registration succeeded there and only the submission failed, so against a device refusing
submissions persistently every retry left another permanent handler no launch could ever adopt.
(Separately, the headline volume lived on the ordinary success path, one handler per session.)

**Post-change bounds.** Successfully registered handlers over one process: **at most one** — the
register call is reached only when nothing is stored, and a success stores. Registration
**attempts**: unbounded, one per consecutive refusal. The difference is accepted deliberately: a
refused attempt stores no handler, so its cost is a transient UUID string the scheduler does not
retain, whereas bounding attempts would let one transient refusal disable background coverage for the
rest of the process (T-15-51-04).

**The refused-identifier question, settled explicitly.** Direction taken: a refused identifier is
**never re-registered**; the refused arm keeps minting fresh. The reason is quoted from the store's
own doc rather than argued — `start`'s re-entry comment reads "A second registration of an identifier
kills the app", and the existing refused-registration case already reads that as covering a refused
identifier: "pins that the store mints FRESH identity rather than retrying the refused one:
re-registering an identifier is what the system kills the app for." Departing from that reading needs
device evidence this plan does not have, so the conservative direction was taken and written into the
new `registeredIdentifier` doc.

## Derivation B — what reuse costs launch discrimination

| Arrival state | `pendingIdentifier` / `task` | Task launch BEFORE | Task launch AFTER | `nil` launch BEFORE | `nil` launch AFTER |
|---|---|---|---|---|---|
| (i) no session live | nil / nil | turned away, completed `false` | unchanged | identity gate returns | unchanged |
| (ii) session AWAITING | identifier / nil | a leftover carried a DIFFERENT string, so it was turned away; the session's own launch was adopted | a leftover carries the SAME string and is **ADOPTED**; the session's own later launch is then turned away by `self.task == nil` | a leftover was turned away by the gate and the session survived; the session's own `nil` launch ended it `.unavailable` | a leftover `nil` launch now **ENDS** the awaiting session `.unavailable` |
| (iii) session HOLDING a task | nil (cleared by `adopt`) / non-nil | turned away | unchanged | gate returns | unchanged |

Only state (ii) changes, and both changed outcomes live there. **No mitigation is available:** the
handler closure captures one identifier for the life of the process and the launched task carries no
submission generation, so any discrimination beyond the string would have to come from a datum the
SDK does not supply. The disposition is therefore written, on `handleLaunch` — the entry point whose
doc carried the retired "tell its own launch from someone else's leftovers" sentence — with a pointer
added at `adopt`'s gate.

**The outcome that changes for the worse, named:** a leftover `nil` launch ending an awaiting
session. Harm assessed against what the store did before: the session loses background coverage it
previously kept. Reachability is doubly defensive — the `nil` arm exists only for a launch the seam
cannot read as a continued-processing task, and only `BGContinuedProcessingTaskRequest`s are ever
submitted under this identifier, and on top of that the launch must land inside a successor's
awaiting window. The consequence is `.unavailable`, which SC3 makes silent by contract: no page lost,
none duplicated, no visible error, and the next qualifying tap opens a new session.

**The other changed outcome costs nothing real.** An adopted leftover is this app's own earlier
request for the same work; `adopt` re-seeds progress from the LIVE session's snapshot, and the caller
supplies a constant localized title (`DownloadClient+ContinuedSession.swift:340`,
`String(localized: .continuedSessionTitle)`), so the only carried-over datum is a subtitle the next
steady progress push replaces. Both tasks existed under per-session minting too and one was completed
unsuccessfully either way; what changed is which one the store holds.

## Derivation C — every freshness assertion, by the property its case guards

The plan pre-derived "five assertions across four cases". The grep found **seven inequalities and
three count assertions across seven cases** — the plan's enumeration missed both nil-arm cases,
including the second dissolved-subject one. Recorded as a deviation below.

| Line (pre-change) | Case | Property the case guards | Verdict | Before → After |
|---|---|---|---|---|
| 254 | `…EndedSessionCancels…` | one registration for one start | **is the property** | `1` → `1` |
| 290, 292 | `…EndedSessionCancels…` | an abandoned request is taken back and the single-session guard is not wedged | constant the property produced | `count == 2` → `== 1`; `!=` → `==` |
| 293 | `…EndedSessionCancels…` | both sessions submitted | **is the property** | `[a, b]` → `[id, id]` |
| 335, 352 | `…StaleLaunch…NeverDisplaces…` | a launch the store is NOT awaiting is completed and turned away | **IS the property — dissolved** | rebuilt (below) |
| 482, 492 | `…StartWhileASessionIsHeld…` | re-entry returns nil without touching the scheduler | **is the property**, now carried by `submissions.count` | `1` → `1` |
| 506, 507 | `…StartWhileASessionIsHeld…` | a later start is genuinely usable | constant the property produced | `count == 2` → `== 1`; `!=` → `==` |
| 605, 620, 622 | `…ARefusedRegistration…` | the refused arm stores nothing, so the next start mints and attempts again | **is the property — UNCHANGED** | `2` → `2`; `!=` → `!=` |
| 670 | `…AThrowingSubmission…` | registration succeeded and only the submission failed | **is the property** | `1` → `1` |
| 685, 686 | `…AThrowingSubmission…` | the arm releases the store and a later start works | constant, **plus a new arm-split pin** | `!=` → `==`, with `count == 1` added after the retry |
| 690 | `…AThrowingSubmission…` | each session takes its own request back | **is the property** | `[f, g]` → `[id, id]` |
| 741, 742 | `…ANilLaunchForTheAwaitedRequest…` | the awaited `nil` launch ends the session honestly | constant the property produced | `!=` → `==` |
| 779, 797 | `…AStaleNilLaunchCannotEndALiveSession` | a `nil` launch the store is not awaiting must not tear down a session whose card the system is still showing | **IS the property — dissolved** | rebuilt (below) |

**One assertion weakened as evidence and was re-sourced rather than left silent.** At `:492` the
registration count no longer proves the refused re-entry touched no scheduler, because a start that
DID reach the scheduler would register nothing either way under a reused identifier. The submission
count at `:493` still discriminates fully and now carries the proof; a comment at the site says so.
Nothing was removed.

**The two rebuilt cases.** Both dissolve for the same reason and rebuild by the same move: the stale
delivery is staged **behind adoption**, so the store is in arrival state (iii) rather than (ii).

- `testAStaleLaunchIsCompletedAndNeverDisplacesTheHeldTask` (renamed from `…TheAwaitedTask`, since
  the store now holds rather than awaits). Property pinned: **a launch the store is not awaiting is
  completed and turned away without displacing the held task.** Staging: session A ends, session B
  starts and adopts `liveTask`, then A's leftover arrives under the shared identifier.
  Discrimination: without `adopt`'s gate the stale task replaces the held one, so
  `staleTask.completionSuccesses == [false]` fails and `liveTask.completionSuccesses == [true]` fails
  with the displaced task completed instead.
- `testAStaleNilLaunchCannotEndALiveSession` keeps its name and its subject. Property pinned: **a
  `nil` launch arriving once the store holds its task is ignored.** Discrimination: without
  `handleLaunch`'s identity gate the live session is ended, so `liveTask.completionSuccesses` reads
  `[false]` instead of `[true]` and the stream drains `[.granted, .unavailable]` instead of
  `[.granted]`.

No case was deleted, and no assertion was replaced by one that would pass against either behaviour.

## The RED reading, verbatim

Task 1's targeted invocation over `DownloadsFeatureTests/ContinuedProcessingSessionTests` exited
non-zero on the new case alone — 13 tests, 12 passing, 1 failing with 2 issues:

```
ContinuedProcessingSessionTests.swift:352: Expectation failed: (Set(spy.registeredIdentifiers).count → 2) == 1
ContinuedProcessingSessionTests.swift:354: Issue recorded: Difference: …

  ␣ [
  ␣   [0]: "com.apple.dt.xctest.tool.continued.B3FDFEE8-DE20-49C1-A668-21B72F941F2F",
  −   [1]: "com.apple.dt.xctest.tool.continued.D78AC0EC-1C6A-498C-A9FA-81347B681E3A"
  +   [1]: "com.apple.dt.xctest.tool.continued.B3FDFEE8-DE20-49C1-A668-21B72F941F2F"
  ␣ ]

(First: −, Second: +)
```

Observed `2` beside expected `1` on the identifier count, and the second submission observed under a
different identifier where the same one was expected. Both halves of the case discriminate, and every
pre-existing case in the suite passed in that same run, so the non-zero exit is attributable only to
the new case.

## The storage placement, with the register call's return value beside it

```swift
            let registered = scheduling.register(mintedIdentifier) { [weak self] task in
                guard let self else { return }
                …
                handleLaunch(task, expecting: mintedIdentifier)
            }
            guard registered else {
                logger.error("Identifier \(mintedIdentifier, privacy: .public) is not permitted by Info.plist.")
                endSession(yielding: .unavailable, success: false)
                return session
            }
            registeredIdentifier = mintedIdentifier
            identifier = mintedIdentifier
```

The assignment sits below the `guard registered else` that returns on refusal, so it is reachable on
exactly one path and that path is the one where registration succeeded. The arm split is shown by
placement, not claimed: no branch anywhere classifies arms.

`scheduling.register` is reached from exactly one site in the module
(`ContinuedProcessingSession.swift:166`; the only other match is the doc reference at `:70`). What
bounds how many times that site executes over one process: it is inside the `else` of
`if let registeredIdentifier`, and a successful execution assigns that property permanently — so it
executes at most once successfully, and otherwise once per consecutive refusal.

## The rewritten `live` note, quoted in full

```swift
        // Registration happens POST-LAUNCH, at the first session start.
        // `ContinuedProcessingSession.start` mints ONE identifier per process as
        // "\(bundleIdentifier).continued.\(UUID().uuidString)", under the
        // `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` wildcard declared in App/Info.plist's
        // `BGTaskSchedulerPermittedIdentifiers`; a handler is registered for it at the first
        // successful registration, and that same identifier is submitted again for every later
        // session. No concrete identifier exists before a session starts, so there is nothing to
        // register at `didFinishLaunching`, and this closure has exactly one caller.
        //
        // The constraint that binds is UNIQUENESS, not repetition: a handler can never be
        // unregistered and a second registration of one identifier kills the app. That is why the
        // store keeps its identifier rather than re-deriving one per session — re-deriving met the
        // same rule while leaving one permanent handler behind per download burst (G-15-31).
        //
        // The design is device-proven rather than merely unfalsified: 15-UAT.md test 1 reads
        // `result: pass` on physical iOS 26 hardware, with pages continuing to land well past the
        // deleted 60-second grace window — an outcome reachable only if this post-launch
        // registration was honoured and the system actually launched the task. That record covers
        // registration and launch; no device run has yet exercised a reused identifier's second
        // submission, so it must not be read as evidence for that.
```

The device evidence is kept with its UAT reference and bounded to what it establishes. The asymmetry
paragraph is gone: it argued from the per-session choice and could not outlive it. `start`'s own
comment is rewritten too and opens with the registration rule rather than the freshness claim.

## The three residue checks

**(a) The freshness rule survives nowhere as a rule.** `grep -rniE "fresh(ly)? ?minted|minted (a )?fresh|fresh UUID|per session as|identifier per session|mints? .*(fresh|per session)"` over both
`AppPackage/Sources/BackgroundProcessingClient` and `AppPackage/Tests/DownloadsFeatureTests` returns
one hit: `ContinuedProcessingSessionTests.swift:656`, the refused-registration case's doc stating
that the store "mints FRESH identity rather than retrying the refused one". That is not the retired
rule — it is the surviving per-ARM behaviour Derivation A's conservative reading kept, and the
paragraph added immediately below it says so explicitly. The remaining word-level matches
(`ContinuedProcessingSession.swift:72,74` and the new case's doc) state the retired rule in the past
tense as the reason it was replaced.

**(b) No orphaned state.** `registeredIdentifier` has one writer (`:178`) and two readers (`:162`,
`:163`) plus its doc reference; nothing else in the module was left without a reader.

**(c) The seam shape is unmoved by construction.** `ContinuedTaskScheduling` still declares exactly
four closures with unchanged signatures — `cancelAllRequests`, `register`, `submit`, `cancel` — and
`BackgroundProcessingClient` still exposes exactly three endpoints (`start`, `updateProgress`,
`finish`). SC4's criterion is untouched.

**WR-08 ordering intact.** `pendingIdentifier = identifier` and `isAwaitingTask = true` sit at
`:192-193`, immediately above `try scheduling.submit(identifier, title, subtitle)` at `:196`, and
nothing assigns either property after the call returns.

**Untouched by diff.** `didCancelStaleRequests`, its once-per-process guard and `endSession`'s
per-request take-back are byte-unchanged — a grep over the diff for added or removed lines mentioning
`didCancelStaleRequests`, `cancelAllRequests`, `abandonedIdentifier` or `scheduling.cancel` returns
nothing.

## File-length budget

Checked before writing, and no relocation was taken. `ContinuedProcessingSessionTests.swift` went
820 → 873 lines after Task 1 and 820 → 914 after Task 2, against the 1000-line `file_length` ERROR
limit — 86 lines of headroom. The other two changed files are at 370 and 155 lines.

## Verification

- **Task 1, targeted:** `-only-testing:DownloadsFeatureTests/ContinuedProcessingSessionTests` — 13
  tests, 1 failure, exactly the new case. RED as designed.
- **Task 2, full unfiltered `FeatureTests`:** `** TEST SUCCEEDED **`, exit `0`. **884 tests, 0
  failures** (877 passed, 7 expected failures, 0 skipped).
- **Movement against the starting head** (`f157e2e7`, 883 tests / 0 failures): **+1**, accounted for
  case by case — the one addition is
  `testTwoSequentialSessionsRegisterOneIdentifierAndSubmitTwice`. Every other change was an edit or a
  rename in place: `testAStaleLaunchIsCompletedAndNeverDisplacesTheAwaitedTask` →
  `…TheHeldTask` keeps the count, and no case was deleted.
- **Lint:** SwiftLint over both changed source files and the changed suite — `Found 0 violations, 0
  serious in 5 files`. `awk 'length($0)>120'` over every changed Swift file returns nothing. No
  `swiftlint:disable`, `try?`, `try!`, `@unchecked Sendable`, `nonisolated(unsafe)` or
  `@preconcurrency` appears anywhere in the diff.
- **xcodebuild serialization:** two invocations, strictly one at a time; neither overlapped the
  other or anything else.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The plan's freshness-assertion enumeration was incomplete, and it missed a
second dissolved-subject case**

- **Found during:** Task 1, Derivation C
- **Issue:** the plan's `read_first` and `must_haves` name "five assertions across four cases" and
  anticipate exactly one dissolved subject (the stale TASK-launch case). The grep the plan itself
  mandates found seven inequalities and three count assertions across **seven** cases. The two
  omitted cases are both nil-arm cases, and one of them —
  `testAStaleNilLaunchCannotEndALiveSession` — is a **second** case whose whole subject is the
  two-identifier discrimination. Had it been left alone it would have failed outright: its stale
  `nil` delivery lands in arrival state (ii), where the identity gate now passes and the live session
  is torn down.
- **Fix:** Derivation C was taken from the grep rather than from the plan's count, and the second
  dissolved case was rebuilt on the same principle as the first — staged behind adoption, around the
  property that survives — rather than deleted or re-pointed.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift`
- **Commit:** `eb0f8b1e`

### Threat register outcomes

All seven `mitigate` dispositions landed as planned. T-15-51-03 (the `high` spoofing item) is the one
whose mitigation turned out to be unavailable rather than merely unwritten: Derivation B established
that the SDK supplies nothing capable of separating a leftover launch from a live one under a shared
identifier, so the mitigation is the written enumeration plus the rebuilt case that pins the property
which survives — which is what the register's own mitigation column specified as the fallback.

## Scope Notes

- **No criterion's verdict moves.** SC3's no-lost-work and no-visible-error guarantees hold either
  way, and SC4's seam shape is untouched by construction (check (c)). The two SC labels name the
  surfaces this plan touches, not a verdict it repairs.
- **The physical-device UAT re-run (15-UAT.md test 2) is an independent axis this plan does not
  discharge and does not claim.** Separately, no device run has yet exercised a reused identifier's
  second submission; the rewritten `live` note says so rather than extending test 1's record to cover
  it.

## Self-Check: PASSED

- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` — FOUND
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` — FOUND
- `.planning/phases/15-continued-background-downloads/15-51-SUMMARY.md` — FOUND
- commit `8afcfeee` — FOUND
- commit `eb0f8b1e` — FOUND
