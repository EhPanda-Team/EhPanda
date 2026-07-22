---
phase: 12-cloudflare-login-restoration
plan: 06
subsystem: setting
tags: [swift, tca, cloudflare, wkwebview, privacy, uat, turnstile]

# Dependency graph
requires:
  - phase: 12-cloudflare-login-restoration
    provides: the whole challenge flow built by plans 12-01 … 12-05
  - phase: 07-root-privacy-mask-auto-lock-removal
    provides: the durable privacy-mask coverage contract this plan reconciles
  - phase: 08-cookie-keychain-privacy
    provides: check-cookie-logging.sh, the taint-tracking cookie-logging gate re-run here
provides:
  - "A reconciled 07-PRIVACY-MASK-INVENTORY.md: 42 runtime roots / 42 mask sites / 43 presentations / 2 exclusions, bijective"
  - "Owner-signed live C1 pass through the real Cloudflare wall"
  - "Seven UAT-found defect fixes in the challenge flow, each with regression coverage"
  - "AppError.loginCaptchaRequired — a named, separately-recoverable failure for a Turnstile-gated login form"
  - "Parser.parseLoginErrorMessage / Parser.loginFormRequiresCaptcha — the login response body is read instead of discarded"
affects: [13-deep-link-hardening, any future work on native login or the web-login fallback]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cookie capture from a WKWebView store polls on a timer; the store observer and didFinish are fast-path nudges, not the mechanism"
    - "A reducer that both presents and programmatically dismisses an @ReducerCaseIgnored destination reads the destination BEFORE BindingReducer applies the write, so a user swipe is distinguishable from the reducer's own dismissal"
    - "Credentials from a login response are applied before didLogin is consulted — the verdict must never be read from a jar the request has not yet written to"

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/LoginRejectionSurfacingTests.swift
    - AppPackage/Tests/ParserFeatureTests/Other/LoginErrorMessageParserTests.swift
  modified:
    - .planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md
    - AppPackage/Sources/SettingFeature/Login/LoginReducer.swift
    - AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/ParserFeature/Parser+ResponseError.swift
    - AppPackage/Sources/AppModels/Support/AppError.swift
    - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
    - AppPackage/Sources/SystemNotification/ToastMessageView.swift

key-decisions:
  - "The clearance is captured by polling the web view's cookie store; WKHTTPCookieStoreObserver alone never fired for page-set cookies on the live wall"
  - "A swipe-dismissal of the challenge sheet is detected by reading the destination before BindingReducer runs — every Destination case is @ReducerCaseIgnored, so PresentationAction.dismiss is never routed"
  - "loginDone applies the response's credentials before consulting didLogin, because the clearance-carrying retry disables URLSession cookie handling"
  - "A Turnstile-gated login form gets its own AppError case rather than folding into cloudflareChallengeFailed — both are Cloudflare, but only one is clearable by the in-app challenge surface, so conflating them would point at the wrong recovery"
  - "The Turnstile gate is reported, not solved: producing a cf-turnstile-response token needs the form rendered in a web view, which the existing web-login flow already is"

patterns-established:
  - "Every login failure raises a toast: a failure arm with no on-screen surface presents as silence and hides its own cause"
  - "The login response body is parsed for the forum's own error box under both of its labels; passing the text through verbatim (markup-stripped, length-bounded) reports messages this app has never seen"

requirements-completed: [C1, C5]

coverage:
  - id: D26
    description: "The privacy-mask coverage contract reconciles one-to-one with runtime roots after the two new login presentation roots"
    verification:
      - kind: manual_procedural
        ref: "07-PRIVACY-MASK-INVENTORY.md derived-count audit — 42 roots / 42 mask sites / 43 presentations / 2 exclusions"
        status: pass
    human_judgment: false
  - id: D27
    description: "Static gates hold: no shared-jar write in the challenge wrapper, no domain-fronting conditional, cookie-logging gate green, clearance key in-memory"
    verification:
      - kind: other
        ref: "grep gates 1–4 + ./scripts/check-cookie-logging.sh — all recorded in Verification Evidence"
        status: pass
    human_judgment: false
  - id: D28
    description: "Username/password login succeeds end-to-end against the live Cloudflare-fronted forums host"
    requirement: "C1"
    verification:
      - kind: manual_procedural
        ref: "owner live UAT on device, final round — PASS (see Owner UAT Results; qualified by the Turnstile finding)"
        status: pass
    human_judgment: true
    rationale: "The clearance is TLS-fingerprint-bound; no offline substitute exists for the live edge accepting the captured pair over URLSession"
  - id: D29
    description: "Silent cancel via both exits from the challenge sheet — Cancel button and swipe-down"
    verification:
      - kind: manual_procedural
        ref: "owner live UAT step 1 — PASS (swipe path failed first round, fixed, re-verified)"
        status: pass
      - kind: unit
        ref: "LoginChallengeFlowTests.swipingTheChallengeAwayAbortsTheAttemptSilently"
        status: pass
    human_judgment: true
    rationale: "The swipe path routes through SwiftUI's presentation binding, which no TestStore drives"
  - id: D30
    description: "The challenge sheet is masked in the App Switcher (ROOT-41)"
    verification:
      - kind: manual_procedural
        ref: "owner live UAT step 3 — PASS"
        status: pass
    human_judgment: true
    rationale: "Snapshot concealment is an OS behavior no static check or test can observe"
  - id: D31
    description: "cf_clearance does not survive a force-quit and relaunch"
    requirement: "C5"
    verification:
      - kind: manual_procedural
        ref: "owner live UAT — PASS; the relaunched app re-presented the wall"
        status: pass
      - kind: other
        ref: "source assertion: SharedKey.cloudflareClearance is an InMemoryKey, no appStorage/fileStorage consumer"
        status: pass
    human_judgment: true
    rationale: "Process-lifetime behavior needs a real force-quit"
  - id: D32
    description: "Session reuse: a second login in the same run auto-passes with the held pair"
    verification:
      - kind: manual_procedural
        ref: "owner live UAT step 4 — PASS, wall skipped"
        status: pass
      - kind: unit
        ref: "LoginChallengeFlowTests.heldClearanceIsAttachedToTheVeryFirstPost"
        status: pass
    human_judgment: false
  - id: D33
    description: "A CAPTCHA-gated refusal is detected and presented with its own message and recovery route"
    verification:
      - kind: unit
        ref: "LoginRejectionSurfacingTests, LoginErrorMessageParserTests, AppErrorStructuredTests"
        status: pass
      - kind: manual_procedural
        ref: "owner live UAT failure-surface item — PASS"
        status: pass
    human_judgment: true
    rationale: "The gate is a live site condition; its appearance on screen is only observable against the real host"

# Metrics
duration: ~2 days elapsed (Task 1 ~35 min; Task 2 owner UAT across several rounds)
completed: 2026-07-23
status: complete
---

# Phase 12 Plan 06: Phase Close — Privacy-Mask Reconciliation and Live Login UAT Summary

**The owner signed off a live end-to-end username/password login through the real Cloudflare wall (C1), the privacy-mask contract now reconciles bijectively at 42 roots, and seven defects the live wall exposed — none of them reachable offline — were fixed with regression coverage; UAT also caught the forum putting Cloudflare Turnstile inside its own login form, which this plan reports as a named error with a working fallback rather than pretending to solve.**

## Performance

- **Duration:** Task 1 ~35 min; Task 2 owner UAT ran across several rounds over two days
- **Started:** 2026-07-22T07:50Z
- **Completed:** 2026-07-23
- **Tasks:** 2
- **Files modified:** 16 source/test files + 2 planning documents

## Accomplishments

- **C1 is proven.** The owner completed a username/password login end-to-end against the live Cloudflare-fronted forums host, on device, from a logged-out state — the one criterion no automated test can reach, because the clearance is TLS-fingerprint-bound.
- **The privacy-mask contract is bijective again**, and two independent pre-existing drifts were found and closed on the way (see Deviations).
- **The live wall broke seven things the offline suite had proven.** Every one of them was a correct test over an assumption the live path invalidated: cookie handling on the retry, cookie propagation timing inside WebKit, and SwiftUI's routing of a swipe on an `@ReducerCaseIgnored` destination. All seven are fixed, and the ones that are reachable offline now carry a regression test that starts from the state the live path actually presented.
- **The login response is no longer discarded.** A refused login is an HTTP 200 carrying an ordinary forum page: the status line and the cookie jar cannot distinguish a wrong password from a lockout from a missing field. The forum's own error box is the only thing that can, and it is now read — under both of the labels the forum uses, which is what made the Turnstile gate invisible through several rounds of diagnosis.
- **A newly-appeared site condition is named instead of misattributed.** `AppError.loginCaptchaRequired` tells the user the form is behind a CAPTCHA and routes them to the web-login flow where it can be solved, instead of sending them back to re-check a password that was never the problem.

## Task Commits

Commits are listed by **subject** as well as hash: this repository runs a `+0900`→`+0800` commit-date normalisation that rewrites hashes, so a hash recorded today may not resolve later.

**Task 1 — Privacy-mask inventory reconciliation + phase static gates + full suite**

1. `9c192632` — `docs(12-06): reconcile privacy-mask inventory with the two new login roots`
2. `5b6d5c90` — `docs(12-06): record checkpoint position at Task 2 live-login UAT`

**Task 2 — Owner live end-to-end login UAT (checkpoint, blocking).** No commits of its own; the following landed *from* the UAT, in order:

3. `5345a9d9` — `fix(12-06): raise the login failure log to warning level`
4. `b56cd8cc` — `fix(12-06): report login success truthfully after a clearance-carrying retry`
5. `7ddb89ae` — `fix(12-06): capture the Cloudflare clearance by polling, not by notification`
6. `bad6905a` — `fix(12-06): drop the challenge sheet's opaque toolbar strip`
7. `83c8d475` — `fix(12-06): abort the login when the challenge sheet is swiped away`
8. `0d3e1338` — `fix(12-06): read the login response instead of discarding it`
9. `2828b6e3` — `diag(12-06): record whether the forum returned credentials at all`
10. `066ba289` — `diag(12-06): dump the whole login exchange instead of one probe at a time`
11. `00b4172b` — `fix(12-06): read the forum's other error label, and name a CAPTCHA gate`
12. `1ad8bbba` — `fix(12-06): hold the toast to one line of title over one of subtitle`
13. `23aad8a1` — `feat(12-06): report a CAPTCHA-gated login form as its own failure`
14. `81bc899d` — `Fix toast height` — **owner-authored**, not agent work: toast bottom padding 64 → 88.

## Files Created/Modified

- `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md` — two new ROOT rows for the login challenge sheet and the login error-info sheet, plus every derived count re-derived (see Deviations: the reconciliation was 39 → 42, not 39 → 41).
- `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` — credentials applied before `didLogin` is consulted; every failure arm raises a toast; the swipe-dismissal hook reads the destination ahead of `BindingReducer`; classification logging on the login POST; failure log raised to `warning`.
- `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift` — clearance capture rebuilt on a 500 ms poll of the web view's cookie store, with the store observer and `didFinish` retained as fast-path nudges.
- `AppPackage/Sources/SettingFeature/Login/LoginView.swift` — the challenge sheet's opaque toolbar strip removed.
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` — the login response body is read and classified instead of discarded; DEBUG-only redacted dump of the exchange.
- `AppPackage/Sources/ParserFeature/Parser+ResponseError.swift` — `parseLoginErrorMessage(content:)` (both forum error labels, markup-stripped, 200-char bounded) and `loginFormRequiresCaptcha(content:)`.
- `AppPackage/Sources/AppModels/Support/AppError.swift`, `AppPackage/Sources/AppComponents/AppError+Symbol.swift`, `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` — `AppError.loginCaptchaRequired` with strings in all six locales, and both exhaustive switches outside the enum updated.
- `AppPackage/Sources/DownloadFeature/DownloadClient+PageDownload.swift` — the new case classified on the fatal-account side, for the same reason the unsolved wall is: it blocks every request and retrying cannot clear it.
- `AppPackage/Sources/SystemNotification/ToastMessageView.swift` — the toast held to one line of title over one of subtitle, the shape its own header comment already specified.
- `AppPackage/Sources/SystemNotification/View+Toast.swift` — owner-authored bottom-padding change.
- Tests: `AppPackage/Tests/NetworkingFeatureTests/LoginRejectionSurfacingTests.swift` and `AppPackage/Tests/ParserFeatureTests/Other/LoginErrorMessageParserTests.swift` (new); `LoginChallengeFlowTests.swift`, `AppErrorStructuredTests.swift`, `ToastInteractionTests.swift` (extended).

## Owner UAT Results (Task 2 checkpoint)

**Round 0 — VOID.** The owner's first UAT run was made against commit `54c7140f`, the last Phase 11 commit, which contains no Phase 12 code at all. The reported symptom (a fast, silent "Login failed." with no challenge sheet) was the *pre-Phase-12 baseline*, not a defect in this phase. Recorded here explicitly so the phase history does not imply C1 was tested twice.

**Final owner verdict on the current build: PASS on every item.**

| Item | Verdict |
|------|---------|
| Silent cancel via the sheet's Cancel button | PASS |
| Silent cancel via swipe-down | PASS (failed initially; fixed by `83c8d475`, re-verified) |
| Live end-to-end username/password login through the wall (C1) | PASS |
| Privacy mask on the App Switcher while the challenge sheet is presented (ROOT-41) | PASS |
| `cf_clearance` does not survive a force-quit and relaunch (C5) | PASS |
| Session reuse within one run: second login auto-passes with the held pair (D-06) | PASS |
| Failure surface: a CAPTCHA-gated refusal is detected and presented with a proper message | PASS |

## Critical Finding: the forum's login form is now gated behind Cloudflare Turnstile

**This appeared during this phase's UAT and is distinct from the edge challenge the phase clears.** The edge challenge sits in front of the host and is cleared by the in-app challenge surface. Turnstile lives *inside* the forum's own login form and contributes a `cf-turnstile-response` field to the submission. A credential POST cannot produce that field, so while the gate is active a native username/password login cannot complete, whatever the password.

**Evidence:** a captured login response returned HTTP 200 carrying `<div class="cf-turnstile" data-sitekey="…">` and the message "The captcha was not entered correctly. Please try again.", with only `ipb_session_id` set and no credential cookies.

**This is reported, not solved.** `23aad8a1` (`feat(12-06): report a CAPTCHA-gated login form as its own failure`) adds `AppError.loginCaptchaRequired`, with strings in all six locales, whose recovery suggestion routes the user to the existing web-login flow — where the form is rendered and the CAPTCHA can actually be solved. It is deliberately not folded into `.cloudflareChallengeFailed`: both involve Cloudflare, but one is cleared by the in-app challenge surface and the other never can be, so conflating them would point at the wrong recovery. A refusal carrying the same error block but *no* widget stays generic, because that one really might be the password.

**C1's status, stated precisely:**

- C1 **was verified PASS by the owner on the live host**, before the Turnstile gate appeared. The phase's goal was met.
- A **newly-introduced site condition can now block native login**. It is correctly detected, explained to the user in their own language, and has a working fallback (web login).
- C1 is therefore **not currently reproducible while the gate is active** — and that is a change in the site, not a failure of this phase. Neither "C1 is reproducible today" nor "the phase failed" would be an accurate statement.

Producing a Turnstile token requires the form rendered in a web view, which is exactly what the existing web-login flow already is. Any future work to make native login survive an active Turnstile gate belongs in a new phase, not here.

## Decisions Made

- **Poll for the clearance; do not wait to be told.** Capture originally hung off `WKHTTPCookieStoreObserver` alone. Observed live: the observer never fired for page-set cookies, and a `didFinish` check read an empty jar before WebKit had propagated it. Capture is now a 500 ms poll, with the observer and navigation-finished kept as fast-path nudges — they make the common case immediate but are no longer load-bearing.
- **Read the destination before `BindingReducer` applies the write.** Every `Destination` case is `@ReducerCaseIgnored`, so SwiftUI never routes `PresentationAction.dismiss`; a swipe arrives as a plain binding write. SwiftUI also echoes the reducer's *own* dismissals through that same binding, and after a capture the two are indistinguishable — unless the hook reads the destination first.
- **Apply credentials before consulting `didLogin`.** `didLogin` reads the shared cookie jar. That was harmless while every POST used default cookie handling, because URLSession filed the response's `Set-Cookie` before the reducer ran. 12-02's clearance-carrying retry sets `httpShouldHandleCookies = false` so the clearance is the authoritative outbound cookie — which also stops URLSession filing the *response's* cookies, so a genuinely successful post-challenge login always reported failure.
- **Every failure arm raises a toast.** Only the Cloudflare arm had one. A plain rejected login changed nothing on screen, which is why the `didLogin` bug presented as total silence rather than as a wrong error message — the missing surface hid the defect as much as the defect itself did.
- **Pass the forum's error text through verbatim** (markup-stripped, 200-char bounded) rather than matching known phrasings: the useful part is whatever the server chose to say, including messages this app has never seen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The inventory reconciliation was 39 → 42, not the planned 39 → 41**
- **Found during:** Task 1
- **Issue:** The document was already stale in two independent ways before this phase: an app-level error-info sheet added in Phase 9 was never recorded, and a New Dawn preview exclusion was removed by Phase 10's `#Preview` migration.
- **Fix:** Re-derived every count from the document's own ROOT rows rather than pattern-replacing the planned numbers. Final state: 42 runtime roots / 42 mask sites / 43 presentations / 2 exclusions, bijective.
- **Files modified:** `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md`
- **Commit:** `9c192632` — `docs(12-06): reconcile privacy-mask inventory with the two new login roots`

**2. [Rule 1 — Bug] Login success was reported from a jar the request never wrote to**
- **Found during:** Task 2 UAT (live login died fast and silently — no spinner, no error, only "Login failed." in the log)
- **Fix:** `loginDone` applies the response's credentials before reading `didLogin`; regression test starts from an empty jar. The no-clearance path's behavior is identical.
- **Commit:** `b56cd8cc` — `fix(12-06): report login success truthfully after a clearance-carrying retry`

**3. [Rule 1 — Bug] The clearance was never captured on the live wall**
- **Found during:** Task 2 UAT
- **Fix:** Capture rebuilt as a 500 ms poll of the web view's cookie store; observer and `didFinish` demoted to fast-path nudges.
- **Commit:** `7ddb89ae` — `fix(12-06): capture the Cloudflare clearance by polling, not by notification`

**4. [Rule 1 — Bug] Swiping the challenge sheet away left the login button spinning forever**
- **Found during:** Task 2 UAT
- **Fix:** The dismissal hook reads the destination before `BindingReducer` applies the binding write, so a user swipe is distinguishable from the reducer's own dismissal. Regression case added to `LoginChallengeFlowTests`.
- **Commit:** `83c8d475` — `fix(12-06): abort the login when the challenge sheet is swiped away`

**5. [Rule 2 — Missing Critical] The login response body was discarded**
- **Found during:** Task 2 UAT
- **Issue:** The response body is the only place the forum says *why* a login was refused; without it every refusal is indistinguishable and unexplainable.
- **Fix:** `Parser.parseLoginErrorMessage(content:)` reads the forum's error box under both labels it uses — a board-level message for a malformed submission and a form-level list when the form came back with errors. Reading only the first is how the CAPTCHA requirement went unreported through several rounds of diagnosis.
- **Commits:** `0d3e1338` — `fix(12-06): read the login response instead of discarding it`; `00b4172b` — `fix(12-06): read the forum's other error label, and name a CAPTCHA gate`

**6. [Owner request] The login failure log sat at `notice`, level with routine lifecycle events**
- **Commit:** `5345a9d9` — `fix(12-06): raise the login failure log to warning level`

**7. [Owner request] The challenge sheet's opaque toolbar strip**
- **Commit:** `bad6905a` — `fix(12-06): drop the challenge sheet's opaque toolbar strip`

**8. [Rule 1 — Bug] The toast grew past the two-line shape its own header comment specified**
- **Commit:** `1ad8bbba` — `fix(12-06): hold the toast to one line of title over one of subtitle`

**9. [Rule 2 — Missing Critical] A Turnstile-gated refusal was reported as a generic login failure**
- See the Critical Finding section above.
- **Commit:** `23aad8a1` — `feat(12-06): report a CAPTCHA-gated login form as its own failure`

**10. [Housekeeping] Unrelated files swept into `5345a9d9`**
- `.planning/phases/12-cloudflare-login-restoration/12-PATTERNS.md` and three `.planning/research/.cache/*.json` documentation-cache files were staged alongside the one-line log-level change. They are inert artifacts, but they do not belong to that commit, and `.planning/research/.cache/` is a tool cache that arguably should not be tracked at all. Left in place rather than rewritten — the history is already published and the content is harmless. Flagged for a future `.gitignore` decision.

---

**Total deviations:** 10 recorded — 5 auto-fixed bugs, 2 missing-critical additions, 2 owner-requested refinements, 1 housekeeping note.
**Impact on plan:** All within scope. Every code change originated in the live UAT the plan exists to run, and each is a correctness or explainability fix on the path the plan was verifying. No scope creep: the Turnstile gate is reported and routed to an existing fallback, not solved.

## Diagnostic commits

Two `diag(12-06)` commits landed during the investigation and remain in the tree:

- `2828b6e3` — `diag(12-06): record whether the forum returned credentials at all`
- `066ba289` — `diag(12-06): dump the whole login exchange instead of one probe at a time`

The full-exchange dump is **DEBUG-only** and redacts credential-cookie values to names, so no cookie value can reach a log in a release build. Both were necessary: the CAPTCHA gate was invisible to one-probe-at-a-time logging, which is precisely what motivated dumping the whole exchange.

## Owner-authored change

`81bc899d` — `Fix toast height` (toast bottom padding 64 → 88) was committed directly by the owner and is recorded here as owner work, not agent work.

## Issues Encountered

- **The offline suite could not have caught any of the seven defects.** Each was a correct test over an assumption the live path invalidated — URLSession's cookie handling under `httpShouldHandleCookies = false`, WebKit's cookie-propagation timing, and SwiftUI's routing of a swipe on an `@ReducerCaseIgnored` destination. This is the strongest available argument for keeping C1 as a blocking human checkpoint rather than a derived claim.
- **Round 0 of UAT was run against the wrong commit** (`54c7140f`, pre-Phase-12), costing a diagnosis cycle chasing a baseline symptom. Recorded as void above.
- Environment note, sixth confirmation: every `xcodebuild` invocation on this machine needs `-skipMacroValidation`.

## Verification Evidence

**Task 1 gates (all recorded at Task 1, commit `9c192632`):**

1. Shared-jar gate (D-04) — `HTTPCookieStorage` occurrences in `ChallengeWebView.swift` outside comments: **0**. PASS.
2. Response-driven gate (D-08) — `bypassSNIFiltering` occurrences across `LoginReducer.swift`, `LoginClient.swift`, `ChallengeWebView.swift`, `Request.swift` outside comments: **0**. PASS.
3. Cookie-logging gate (Phase 8, covers `cf_clearance`) — `./scripts/check-cookie-logging.sh` exit **0**. PASS.
4. No-persistence gate (C5) — `SharedKey.cloudflareClearance` is declared as an `InMemoryKey`; no consumer of `cloudflareClearance` uses `appStorage` or `fileStorage`. PASS. Independently re-confirmed live by the owner's force-quit test.
5. Full suite — `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'`: **682 test runs, 0 failed**, 3 pre-existing expected failures. PASS.
6. Inventory — 42 runtime roots / 42 mask sites / 43 presentations / 2 exclusions, internally consistent and bijective.

**Task 2:** owner live UAT, final verdict PASS on every item (table above).

**Scope note on the suite figure:** the 682-run result is Task 1's, and predates the seven UAT fixes. Each of those fixes landed with its own regression coverage (`LoginRejectionSurfacingTests`, `LoginErrorMessageParserTests`, and additions to `LoginChallengeFlowTests`, `AppErrorStructuredTests`, `ToastInteractionTests`), but a single post-fix full-suite run is not recorded in this plan. That run belongs to phase verification, not to this plan's close.

## Known Stubs

None. Every surface this plan touched is wired to a real data source. `AppError.loginCaptchaRequired` is a deliberately partial *capability* — it reports the Turnstile gate and routes to the web-login fallback rather than solving it — and that partiality is documented as a decision above, not hidden as a stub.

## Threat Flags

None new. The plan's registered threats are addressed:

- **T-12-22** (unmasked new roots) — closed by the bijective inventory and the owner's live App Switcher check.
- **T-12-23** (cookie values reaching logs) — cookie-logging gate green; the new DEBUG-only exchange dump redacts credential-cookie values to names.
- **T-12-24** (clearance persisted) — in-memory key asserted in source, non-persistent web view store, and the owner's force-quit test.
- **T-12-25** (UA/TLS mismatch causing permanent re-challenge) — did **not** materialise: the live login succeeded through URLSession with the captured pair. The bounded-rounds failure path is intact for when it does.
- **T-12-26** (package installs) — none this phase.

## Next Phase Readiness

- Phase 12's goal is met: native username/password login works through the Cloudflare edge challenge, owner-verified live.
- **Carry forward:** while the forum's Turnstile gate on the login form is active, native credential login cannot complete. It is detected, named, localized, and routed to the web-login fallback. Making native login survive an active Turnstile gate would require rendering the form in a web view to obtain a `cf-turnstile-response` token — that is new scope and belongs in its own phase, not a gap in this one.
- The two `diag(12-06)` commits remain in the tree. The DEBUG-only exchange dump is a useful diagnostic for exactly this class of problem; a future phase may want to decide whether it stays permanently or is removed once the login path is stable.
- `.planning/research/.cache/` is currently tracked. Worth a `.gitignore` decision before it accumulates.

## Self-Check: PASSED

- `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md`, `AppPackage/Sources/ParserFeature/Parser+ResponseError.swift`, `AppPackage/Tests/NetworkingFeatureTests/LoginRejectionSurfacingTests.swift` and `AppPackage/Tests/ParserFeatureTests/Other/LoginErrorMessageParserTests.swift` all exist on disk.
- Every commit hash listed above resolves in `git log`, and each was cross-checked against its subject line, which survives the repository's commit-date normalisation.

---
*Phase: 12-cloudflare-login-restoration*
*Completed: 2026-07-23*
