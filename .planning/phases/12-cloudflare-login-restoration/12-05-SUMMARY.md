---
phase: 12-cloudflare-login-restoration
plan: 05
subsystem: setting
tags: [swift, tca, testing, cloudflare, sharing]

# Dependency graph
requires:
  - phase: 12-cloudflare-login-restoration
    provides: CloudflareClearance and SharedKey.cloudflareClearance from plan 12-01
  - phase: 12-cloudflare-login-restoration
    provides: isCloudflareChallenge(_:) from plan 12-02
  - phase: 12-cloudflare-login-restoration
    provides: the LoginClient dependency seam from plan 12-03
  - phase: 12-cloudflare-login-restoration
    provides: the LoginReducer challenge state machine from plan 12-04
provides:
  - "LoginChallengeFlowTests — ten exhaustive TestStore cases over the challenge state machine"
  - "A scripted LoginClient stub that records the clearance argument of every POST"
  - "A per-case InMemoryStorage isolation pattern for @Shared in-memory keys under test"
affects: [12-06 owner UAT — the only criterion left unproven offline is the live wall itself]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Overriding \\.defaultInMemoryStorage per TestStore so a process-wide @Shared in-memory key cannot leak between cases"
    - "Seeding a @Shared in-memory holder before the store exists, through a local @Shared handle inside withDependencies"
    - "Proving an absence (no retry, no toast) with an exhaustive TestStore that receives nothing"

key-files:
  created:
    - AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift
  modified: []

key-decisions:
  - "Each case gets its own InMemoryStorage rather than resetting the shared holder afterwards — isolation by construction beats cleanup that a future case can forget"
  - "The scripted stub carries responses only, not responses-or-errors: no criterion in this plan drives a thrown AppError, and an unexercised error arm is dead test scaffolding"
  - "Responses are built through #require rather than force-unwrapped, so a malformed fixture fails as a named requirement instead of trapping the process (force_unwrapping is at error)"

patterns-established:
  - "A seam recorder (LockIsolated log of the clearance each call received) turns 'the retry carried the pair' from an inference about state into a direct assertion about the request"

requirements-completed: [C2, C3, C5]

coverage:
  - id: D17
    description: "A non-challenged login response reaches loginDone with no challenge destination and no toast"
    requirement: "C2"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.unchallengedLoginReachesLoginDoneWithNoChallengeSurface"
        status: pass
    human_judgment: false
  - id: D18
    description: "A challenged response presents the surface immediately while the attempt stays .loading"
    requirement: "C2, C3"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.challengedLoginPresentsTheSurfaceWhileStillLoading"
        status: pass
    human_judgment: false
  - id: D19
    description: "Capturing the pair auto-dismisses the surface and replays the POST carrying that exact pair"
    requirement: "C3, C4"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.capturedClearanceDismissesTheSurfaceAndRetriesCarryingThePair — receivedClearances == [nil, firstClearance]"
        status: pass
    human_judgment: false
  - id: D20
    description: "At most two presentations per attempt; the third challenge yields cloudflareChallengeFailed with the persistent toast"
    requirement: "C5"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.thirdChallengeExhaustsTheBoundAndFailsThroughTheStructuredError"
        status: pass
    human_judgment: false
  - id: D21
    description: "A pair held from earlier in the session rides the very first POST, so an unexpired clearance skips the wall"
    requirement: "C5"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.heldClearanceIsAttachedToTheVeryFirstPost — receivedClearances == [heldClearance], challengeRounds == 0"
        status: pass
    human_judgment: false
  - id: D22
    description: "Both ways out of the sheet abort silently — .idle, no retry, no toast — and a fresh tap gets a full round budget"
    requirement: "C5"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.swipingTheChallengeAwayAbortsTheAttemptSilently, .cancellingTheChallengeIsSilentAndLeavesTheNextAttemptAFullBudget"
        status: pass
    human_judgment: false
  - id: D23
    description: "A capture arriving with no challenge on screen writes nothing and starts nothing"
    requirement: "C5"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.captureWithNoChallengePresentedIsIgnored (T-12-17)"
        status: pass
    human_judgment: false
  - id: D24
    description: "The web-login destination still presents and tears down unchanged; the challenge dismiss guard did not widen"
    requirement: "C2"
    verification:
      - kind: unit
        ref: "LoginChallengeFlowTests.webLoginPresentationAndDismissalAreUnaffectedByTheChallengeHandling"
        status: pass
    human_judgment: false
  - id: D25
    description: "The end-to-end pass against the live Cloudflare wall"
    requirement: "C1"
    verification:
      - kind: other
        ref: "owner UAT in 12-06 — no offline substitute exists for the edge accepting the captured UA"
        status: deferred
    human_judgment: true

# Metrics
duration: 14min
completed: 2026-07-22
status: complete
---

# Phase 12 Plan 05: Login Challenge Flow Tests Summary

**Every phase criterion that does not need the live wall is now proven by an exhaustive `TestStore`: the no-wall passthrough, immediate presentation, capture-and-replay with the exact pair, the two-round bound failing into `cloudflareChallengeFailed`, silent cancel, and the untouched web-login path — ten cases, all offline through the `LoginClient` seam.**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-07-22T08:00Z
- **Completed:** 2026-07-22T08:14Z
- **Tasks:** 2
- **Files created:** 1 (0 modified)

## Accomplishments

- The stub does not merely answer the POST — it *records* the `clearance` argument of every call. That turns the two claims hardest to prove from state alone into direct assertions about the request: the retry carried the pair the user just earned (`[nil, firstClearance]`), and a pair held from earlier in the session rode the very first POST with no wall ever presented (`[heldClearance]`, `challengeRounds == 0`).
- The bound is walked end to end rather than asserted on the counter: two full rounds of detect → capture → retry, then a third challenge that presents nothing, increments nothing, and lands on `.loginDone(.failure(.cloudflareChallengeFailed))` with the persistent toast and `.failed(.cloudflareChallengeFailed)` login state. The recorded call log also shows the second round replaced the first round's pair, which is D-06's replacement half.
- D-02's silence is proven the only way silence can be: an exhaustive store that receives nothing after the dismissal. A retry would surface as an unasserted action and a toast as an unasserted state change, so the test fails if either ever appears — no negative assertion to keep in sync with the reducer.
- Each case builds its own `InMemoryStorage` and overrides `\.defaultInMemoryStorage`, so the process-wide `@Shared(.cloudflareClearance)` holder cannot carry a pair from one case into the next (T-12-20). A held pair is seeded into that storage *before* the store exists, through a local `@Shared` handle inside `withDependencies` — which is also what an earlier-in-session pair actually looks like from the reducer's point of view.
- The web-login regression case pins the pre-existing `.destination(.dismiss)` semantics, so the challenge guard added in 12-04 cannot have widened that handler's blast radius without a test failing.

## Task Commits

1. **Task 1: Challenge state-machine TestStore suite** — `89b46f4a` (test)
2. **Task 2: Cancel-silence, tap-through, and web-login regression** — `ec43b50f` (test)

## Files Created/Modified

- `AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift` — ten `@MainActor` cases, a scripted-`LoginClient` harness with a clearance recorder and a dismiss counter, and per-case in-memory storage isolation.

## Decisions Made

- **Isolation by construction, not cleanup.** 12-04 flagged that the in-memory holder is process-wide and suggested resetting it between cases. Overriding `\.defaultInMemoryStorage` per store is strictly better: there is no teardown a future case can forget, and the isolation survives parallel execution (the Phase 11 de-serialization rule).
- **Responses only in the script, no error steps.** The plan sketched "HTTPURLResponse-or-error steps", but no criterion in this plan drives a thrown `AppError` through the reducer — the failure path under test is the *reducer-emitted* `cloudflareChallengeFailed`, not a transport failure. An unexercised error arm would be scaffolding no test reads.
- **`#require` rather than force unwrapping for the fixture responses.** `HTTPURLResponse.init` is failable and `force_unwrapping` is at error; `#require` makes a malformed fixture a named test requirement rather than a process trap, and costs only a `throws` on the case.
- **Assert whole actions (`.loginDone(.success(response))`) instead of case key paths.** The scripted response instance flows through unchanged, so equality is exact and the assertion names both the action *and* which scripted response answered it.

## Deviations from Plan

**1. [Plan detail] The scripted stub carries responses only, not responses-or-errors**
- **Found during:** Task 1
- **Issue:** The plan's `<action>` sketched "a `LockIsolated` array of HTTPURLResponse-or-error steps", but none of the ten specified behaviors drives a thrown `AppError`.
- **Fix:** Scripted `[HTTPURLResponse]` only. Behavior coverage is unchanged; the omitted arm would have been unreachable test code.
- **Files modified:** `LoginChallengeFlowTests.swift`
- **Commit:** `89b46f4a`

**2. [Rule 3 - Blocking] `LockIsolated` mutates through `withValue`, not `withLock`**
- **Found during:** Task 1
- **Issue:** The first compile failed with "Value of type `LockIsolated<[CloudflareClearance?]>` has no dynamic member `withLock`". `withLock` is the `@Shared` projection's API; `LockIsolated` (ConcurrencyExtras) uses `withValue`.
- **Fix:** Switched the three recorder mutations to `withValue`, matching `AppActivityLogsReducerTests`' existing usage. The `@Shared` assertions keep `withLock`.
- **Files modified:** `LoginChallengeFlowTests.swift`
- **Commit:** `89b46f4a`

No production code was changed: every criterion in this plan was testable against the 12-04 state machine as built.

## Issues Encountered

None beyond the `withValue` compile error above. No `Package.swift` change was needed — `AppComponents`, `AppTools` and `HapticsClient` resolve transitively through the `SettingFeature` dependency, the same way `SettingPresentationTests` already imports `AppTools` and `LibraryClient`.

Environment note, fifth confirmation: every `xcodebuild` invocation on this machine needs `-skipMacroValidation`.

## Verification Evidence

- `xcodebuild test … -only-testing:SettingFeatureTests/LoginChallengeFlowTests -skipMacroValidation` → **TEST SUCCEEDED**, 10 tests in 1 suite, after Task 2.
- `xcodebuild test … -only-testing:SettingFeatureTests -only-testing:NetworkingFeatureTests -skipMacroValidation` → **TEST SUCCEEDED**. `SettingFeatureTests` 45 tests / 11 suites (was 35 / 10 — exactly the ten new cases in one new suite); `NetworkingFeatureTests` 86 tests / 10 suites with its 2 pre-existing known issues.
- Zero warnings and zero SwiftLint violations across both runs (the lint plugin runs at error severity inside the build).
- No `withExhaustivity(.off)` and no `.serialized` anywhere in the new file: every case is exhaustive and parallel-safe.

## Known Stubs

None. The suite exercises the production reducer end to end; the only substituted seam is `LoginClient`, which exists precisely so the wall can be scripted offline.

## Threat Flags

None. The suite opens no network endpoint, touches no live cookie store, and every credential and clearance value in it is a synthetic `*-fixture` string (T-12-19). Cross-case pollution of the in-memory holder (T-12-20) is closed by the per-case `InMemoryStorage`. No packages were installed (T-12-21).

## Next Phase Readiness

- The only unproven link left is the live Cloudflare interaction — observer firing, auto-dismiss timing, and whether the edge accepts the captured UA over `URLSession`'s TLS fingerprint. That is 12-06's owner UAT and has no offline substitute.
- 12-06's privacy-mask inventory still needs the 39 → 41 update for the two presentation roots 12-04 added.
- The `\.defaultInMemoryStorage` override is reusable by any future suite touching an in-memory `@Shared` key; it is the isolation answer the Phase 11 parallel-test rule wants.

## Self-Check: PASSED

`AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift` exists on disk with all ten cases; both task commit hashes (`89b46f4a`, `ec43b50f`) resolve in git history.

---
*Phase: 12-cloudflare-login-restoration*
*Completed: 2026-07-22*
