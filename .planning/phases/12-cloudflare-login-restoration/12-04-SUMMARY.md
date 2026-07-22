---
phase: 12-cloudflare-login-restoration
plan: 04
subsystem: setting
tags: [swift, swiftui, tca, cloudflare, sharing, error-handling]

# Dependency graph
requires:
  - phase: 12-cloudflare-login-restoration
    provides: CloudflareClearance, AppError.cloudflareChallengeFailed, SharedKey.cloudflareClearance from plan 12-01
  - phase: 12-cloudflare-login-restoration
    provides: isCloudflareChallenge(_:) and the clearance-carrying LoginRequest from plan 12-02
  - phase: 12-cloudflare-login-restoration
    provides: ChallengeWebView and the LoginClient dependency from plan 12-03
  - phase: 09-correctness-structured-error-handling
    provides: the persistent tappable failure toast and ErrorInfoView detail surface
provides:
  - "LoginReducer.Destination.challenge(URL) and .errorInfo(ErrorInfo)"
  - "LoginReducer.Action.challengeDetected / .challengeClearanceCaptured / .cancelChallenge / .presentErrorInfo / .toast"
  - "LoginReducer.State.challengeRounds, .toast, and the @Shared(.cloudflareClearance) session holder"
  - "LoginReducer.loginEffect(state:) — the single POST effect shared by the first attempt and every retry"
  - "LoginView challenge sheet, failure toast, and ErrorInfo detail sheet"
affects: [12-05 reducer behavior suite, 12-06 owner UAT and privacy-mask inventory]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One effect factory shared by the first attempt and every retry, so the clearance attachment and the challenge classification cannot drift apart"
    - "Sheet dismissal and an explicit cancel action collapse onto the same reducer-owned abort"
    - "A presentation destination inspected with `is(\\.case)` while still populated inside the parent Reduce, before `.ifLet` clears it"

key-files:
  created: []
  modified:
    - AppPackage/Sources/SettingFeature/Login/LoginReducer.swift
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift

key-decisions:
  - "Folded into LoginReducer rather than a child feature: the surface is one destination, one counter and four actions, and a child would have to reach back for username, password, loginState and the CancelID it needs to cancel — composition with no isolation"
  - "The challenge classification lives in the shared effect, not at the two call sites, so a retry can never take a path that skips detection"
  - "Swipe-down and the cancel button share one handler guarded on the challenge case, so the two ways out of the sheet cannot diverge"
  - "The failure branch keys off the result, not off challengeRounds, so the toast can only appear on the typed failure the state machine actually emitted"

patterns-established:
  - "A bounded-round presentation loop: rounds reset at the start of an attempt, incremented at presentation, checked before presenting, and exhausted into a typed AppError rather than a silent stall"

requirements-completed: [C2, C3, C4, C5]

coverage:
  - id: D10
    description: "A challenged login POST presents the challenge surface immediately, while a non-challenged response proceeds through the existing loginDone path with no extra UI"
    requirement: "C2"
    verification:
      - kind: build
        ref: "xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "source assertion: the sole classification point is `isCloudflareChallenge(response)` inside loginEffect; the else branch is the untouched `.loginDone(.success(response))` send"
        status: pass
      - kind: unit
        ref: "12-05 LoginChallengeFlowTests (next wave) drives the detect/no-detect split through a TestStore"
        status: deferred
    human_judgment: false
  - id: D11
    description: "Capturing the pair auto-dismisses the surface and retries the POST carrying clearance + exact UA, flowing into unchanged setCredentials/didLogin handling"
    requirement: "C3, C4"
    verification:
      - kind: build
        ref: "xcodebuild build … -skipMacroValidation"
        status: pass
      - kind: other
        ref: "diff inspection: the `.loginDone` didLogin / haptics / dismiss / setCredentials body is unchanged apart from the added cloudflareChallengeFailed branch inside the existing else"
        status: pass
      - kind: unit
        ref: "12-05 covers capture → dismiss → retry-with-pair; the live edge accepting the UA stays owner UAT in 12-06"
        status: deferred
    human_judgment: false
  - id: D12
    description: "At most 2 challenge presentations per attempt; a third challenge fails through AppError.cloudflareChallengeFailed surfaced as a persistent tappable toast opening ErrorInfoView"
    requirement: "C5"
    verification:
      - kind: build
        ref: "xcodebuild build … -skipMacroValidation"
        status: pass
      - kind: other
        ref: "source assertion: maxChallengeRounds = 2, checked before every presentation; the exhausted branch sends .loginDone(.failure(.cloudflareChallengeFailed)), which sets the toast and the .failed(.cloudflareChallengeFailed) login state"
        status: pass
      - kind: unit
        ref: "12-05 asserts the round bound and the toast; T-12-16"
        status: deferred
    human_judgment: false
  - id: D13
    description: "Dismissing the sheet mid-challenge silently aborts — loginState returns to .idle, no retry, no toast — and a stray capture with no challenge on screen is ignored"
    requirement: "C5"
    verification:
      - kind: build
        ref: "xcodebuild build … -skipMacroValidation"
        status: pass
      - kind: other
        ref: "source assertion: both `.cancelChallenge` and `.destination(.dismiss)` on the challenge case return `.cancel(id: CancelID.login)` and set `.idle` with no toast; `.challengeClearanceCaptured` guards on the challenge destination (T-12-17)"
        status: pass
      - kind: unit
        ref: "12-05 proves silence with a send that receives nothing"
        status: deferred
    human_judgment: false
  - id: D14
    description: "No clearance value reaches the error surface, and both new presentation roots carry the privacy mask"
    requirement: "C5"
    verification:
      - kind: other
        ref: "grep gate: the ErrorInfo context carries only `.action` and `.statusCode`; the challenge sheet and the ErrorInfo sheet each carry `.privacyMask()` (T-12-14, T-12-15)"
        status: pass
    human_judgment: false
  - id: D15
    description: "The spinner spans detect → solve → retry with zero login-button changes"
    requirement: "C2"
    verification:
      - kind: other
        ref: "diff inspection: LoginView.swift is 29 pure insertions across 2 hunks; no hunk touches the Button/overlay/glassEffect block or the webView sheet"
        status: pass
    human_judgment: false
  - id: D16
    description: "The flow stays purely response-driven — no domain-fronting conditional gates detection, presentation or retry"
    requirement: "C2"
    verification:
      - kind: other
        ref: "grep gate: zero non-comment `bypassSNIFiltering` matches in LoginReducer.swift (D-08)"
        status: pass
    human_judgment: false

# Metrics
duration: 11min
completed: 2026-07-22
status: complete
---

# Phase 12 Plan 04: Login Challenge Flow Summary

**LoginReducer now detects the wall on its own POST response, puts the challenge web view on screen, replays the attempt with the captured pair, and gives up into a typed failure after two rounds — with the login button, the web-login sheet and the whole credential downstream untouched.**

## Performance

- **Duration:** ~11 min
- **Started:** 2026-07-22T07:47Z
- **Completed:** 2026-07-22T07:58Z
- **Tasks:** 2
- **Files modified:** 2 (0 created)

## Accomplishments

- Both the first login POST and every post-challenge retry go through one `loginEffect(state:)`, which attaches whatever clearance the session already holds and classifies the response with `isCloudflareChallenge`. A retry therefore cannot take a path that skips detection, and the D-06 "attach it proactively" behaviour needs no separate code path — an unexpired pair simply never produces a challenge.
- `challengeRounds` resets on every `.login`, increments at each presentation, and is checked before presenting. A third challenge sends `.loginDone(.failure(.cloudflareChallengeFailed))` rather than presenting again, so the loop is bounded by construction rather than by a timeout.
- Capture writes the pair into `@Shared(.cloudflareClearance)`, nils the destination and returns the same effect — the surface disappears the moment the proof lands, which is what makes a zero-interaction wall flash by and an interactive one feel finished.
- Cancel and swipe-down share one abort: `loginState = .idle` plus `.cancel(id: CancelID.login)`, with no toast and no retry. The sheet's toolbar button sends the reducer action instead of dismissing the environment, so the in-flight POST is actually cancelled and not merely hidden.
- The exhausted-retry failure rides the Phase 9 path unchanged: `AppAlertState.error(_:)`'s persistent variant, tapped through to `ErrorInfoView`, with context limited to the whitelisted `Action` and `Status Code` rows.
- `loginState` never leaves `.loading` between detection and the retry's answer, so the existing chevron-clearing plus `ProgressView` overlay reads as one continuous spinner across the whole flow — LoginView's changes are 29 pure insertions and do not touch the button at all.

## Task Commits

1. **Task 1: LoginReducer challenge state machine** — `01c16708` (feat)
2. **Task 2: LoginView challenge sheet, error toast, ErrorInfo sheet** — `7c733c59` (feat)

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` — three new destinations' worth of surface (challenge, errorInfo, toast), the round counter and session holder, five new actions, and the shared login effect; the `.loginDone` body is otherwise verbatim.
- `AppPackage/Sources/SettingFeature/Login/LoginView.swift` — the privacy-masked challenge sheet with its `cancellationAction` toolbar button, the failure toast with its `onErrorTap`, and the `ErrorInfoView` sheet.

## Decisions Made

- **Folded into `LoginReducer`, no child feature.** The plan left the choice open. A child would need `username`, `password`, `loginState` and the parent's `CancelID` to do its job, so it would have been a delegate-heavy shell around the same four actions — composition without isolation. Nothing new is named, so the `Feature`-suffix rule is not engaged.
- **`.destination(.dismiss)` is handled inside the parent `Reduce`, guarded on `state.destination?.is(\.challenge)`.** The destination is still populated at that point because `.ifLet` clears it after the base reducer runs; guarding on the case keeps the web-login sheet's dismissal on its existing `.none` path.
- **The failure branch keys off the `result`, not off `challengeRounds`.** Reading the counter would let an unrelated failure that happened to follow two rounds masquerade as a challenge failure; matching `.failure(.cloudflareChallengeFailed)` ties the toast to the exact typed error the state machine emitted.
- **A named `maxChallengeRounds` constant with the reasoning attached**, so the next reader does not confuse the reducer's two rounds with `fetch`'s four transport attempts — the two counters look alike and mean nothing alike.
- **No navigation title or explanatory chrome on the challenge sheet.** D-03 rules out new explanatory strings, and a title would be one; an auto-passing wall is on screen for a second and an interactive wall explains itself. The `cancellationAction` button carries the system's own localized Cancel label, so the sheet still has a reachable, correctly-labelled escape for assistive technology.

## Deviations from Plan

None — both tasks were executed as written. The plan's suggested `guard case .challenge = state.destination` was spelled `state.destination?.is(\.challenge) == true` instead, which is the same test written the way the repo's own lint guidance points at for `@CasePathable` values; the semantics are identical.

## Issues Encountered

None. The build was clean on the first compile of each task, and the pre-existing `SettingFeatureTests` target stayed at 35 tests / 10 suites with no new failures — adding `@Shared` state and a toast to `LoginReducer.State` did not disturb `SettingReducer`'s composition of it.

Environment note, fourth confirmation: every `xcodebuild` invocation on this machine needs `-skipMacroValidation`.

## Verification Evidence

- `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator' -skipMacroValidation` → **BUILD SUCCEEDED**, zero warnings, SwiftLint clean at error severity, after each task.
- `xcodebuild test … -only-testing:SettingFeatureTests -skipMacroValidation` → **TEST SUCCEEDED**, 35 tests in 10 suites.
- Reducer acceptance greps: `case challenge(URL)` 1, `case errorInfo(ErrorInfo)` 1, `challengeRounds` 4, `@Shared(.cloudflareClearance)` 1, `@Presents public var toast` 1, `challengeDetected` 3, `challengeClearanceCaptured` 2, `cancelChallenge` 2, `presentErrorInfo` 2, `isCloudflareChallenge` 1; non-comment `bypassSNIFiltering` 0.
- View acceptance greps: `destination.challenge` 1, `ChallengeWebView` 1, `placement: .cancellationAction` 1, `Button(role: .cancel` 1, `.privacyMask()` 3, `.toast(` 1, `presentErrorInfo` 1, `destination.errorInfo` 1, `ErrorInfoView` 1.
- `git diff --stat` on `LoginView.swift`: 29 insertions, 0 deletions, across two hunks (the import block and the modifier block after the existing webView sheet) — the login button and the webView sheet are byte-identical.

## Known Stubs

None. The flow is complete end to end in code; what remains is coverage, not behaviour — `LoginChallengeFlowTests` lands in 12-05.

## Threat Flags

None. The two new presentation roots and the new error surface were the threats the plan already registered (T-12-14, T-12-15), and both are mitigated in this plan's own code; nothing else in the diff opens a network endpoint, an auth path or a file access pattern.

## Next Phase Readiness

- 12-05 can drive the whole machine through a `TestStore` with `\.loginClient` overridden: the round bound, the silent cancel, the stray-capture guard, and the toast on exhaustion are all reducer-level and need no host. Remember `@Shared(.cloudflareClearance)` is process-wide in-memory state, so a suite that writes it should reset it between cases.
- 12-06 must count two new presentation roots (challenge, errorInfo) in the Phase 7 privacy-mask inventory — 39 → 41, not 40 as the earlier note assumed.
- The end-to-end pass against the live wall — observer firing, auto-dismiss timing, and whether the edge accepts the captured UA over URLSession's TLS fingerprint — remains the owner UAT in 12-06 Task 2.

## Self-Check: PASSED

Both modified files exist on disk with the asserted content; both task commit hashes resolve in git history.

---
*Phase: 12-cloudflare-login-restoration*
*Completed: 2026-07-22*
