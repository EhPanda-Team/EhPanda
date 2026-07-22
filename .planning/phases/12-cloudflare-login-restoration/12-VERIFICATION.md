---
phase: 12-cloudflare-login-restoration
verified: 2026-07-22T17:13:17Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 12: Cloudflare Login Restoration Verification Report

**Phase Goal:** Restore the broken username/password login: detect the Cloudflare challenge on the login POST, clear it through an in-app WKWebView the user can interact with, capture cf_clearance in memory only, and replay the login POST — leaving the other two login methods (in-app web login, manual cookie entry) unchanged.
**Verified:** 2026-07-22T17:13:17Z
**Status:** passed
**Re-verification:** No — initial verification

## Verification Method

Every claim below was checked against the current tree, not the SUMMARYs. Static gates were re-run independently by this verifier, and the full test suite was executed fresh during verification — this closes the deferred item 12-06-SUMMARY.md recorded ("a single post-fix full-suite run … belongs to phase verification"): **TEST SUCCEEDED, 611 Swift Testing tests across 18 targets, 0 failures**, with all seven phase-relevant suites (`LoginChallengeFlowTests`, `CloudflareChallengeDetectionTests`, `LoginRejectionSurfacingTests`, `CredentialHeaderRedactionTests`, `CaptchaGatedLoginTests`, `LoginErrorMessageParserTests`, `AppErrorStructuredTests`) present in the run.

Commit hashes in the six SUMMARYs were cross-checked by subject against current `git log` (the repository's timezone-normalisation rewrite makes hashes unstable); every listed subject resolves, and the currently-recorded hashes happen to match the current history.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria C1–C5 + goal clause)

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | **C1:** Username/password login succeeds end-to-end against the live Cloudflare-fronted forums host | ✓ VERIFIED (owner-attested) | Owner-signed live UAT, final round on the current build: PASS (12-06-SUMMARY.md, coverage item D28, `human_judgment: true`). The clearance is TLS-fingerprint-bound, so no automated substitute exists; the owner's device run is the phase's designed authoritative gate. An earlier UAT round was VOID (run against pre-phase commit `54c7140f`) and is correctly excluded. See "C1 qualification" below for the post-verification Turnstile condition. |
| 2 | **C2:** Challenge detection is dynamic per-response, not assumed per-host; non-challenged responses proceed with no extra UI | ✓ VERIFIED | `isCloudflareChallenge(_:)` at `AppPackage/Sources/NetworkingFeature/Request.swift:46-54` — pure function of status 403 + case-insensitive `cf-mitigated: challenge`; zero host/setting conditionals (independent grep gate: 0 `bypassSNIFiltering` hits across the four challenge-flow files). 9-test classification matrix (`CloudflareChallengeDetectionTests`) passing in this run, incl. negative cases (non-403, absent/other header values, non-HTTP). No-wall pass-through proven behaviorally by `unchallengedLoginReachesLoginDoneWithNoChallengeSurface` (passing). |
| 3 | **C3:** On challenge an in-app WKWebView loads the challenged URL; the moment cf_clearance appears it auto-dismisses and the POST retries — interactive and auto-passing walls both covered | ✓ VERIFIED | `ChallengeWebView.swift` (229 lines, substantive): 500 ms cookie-store poll as the guarantee with `WKHTTPCookieStoreObserver` + `didFinish` as fast-path nudges; `navigator.userAgent` read from the solving view; one-shot `onClearance`. Reducer: `.challengeDetected` presents `.challenge(Defaults.URL.login)` immediately (D-01); `.challengeClearanceCaptured` nils the destination and fires the retry (`LoginReducer.swift:155-163`). Behavioral: `challengedLoginPresentsTheSurfaceWhileStillLoading`, `capturedClearanceDismissesTheSurfaceAndRetriesCarryingThePair` passing. Live WebKit half (real wall auto-dismiss) owner-attested in UAT. |
| 4 | **C4:** Retry carries captured cf_clearance + the web view's exact User-Agent; existing `setCredentials`/`didLogin` proceed unchanged | ✓ VERIFIED | `Request+Account.swift:65-78`: explicit `Cookie: cf_clearance=…` + verbatim UA headers, `httpShouldHandleCookies = false` so they are authoritative; nil-clearance path byte-identical (asserted by `loginRequestWithoutClearanceIsConstructedExactlyAsBefore`). Wire-level tests (`clearanceCarryingLoginRequestSendsTheCookieAndItsBoundUserAgent`, `…DisablesSharedJarCookieHandling`) passing at the URLProtocol level. `CookieClient` (owner of `setCredentials`/`didLogin`) has **zero phase-12 commits** — last touched in Phase 11 (git evidence). `credentialsFromTheResponseApplyBeforeSuccessIsJudged` regression passing. Live retry accepted by the edge, owner-attested. |
| 5 | **C5:** cf_clearance is memory-only, never persisted; no expiry timer — re-challenge re-presents within bounded retries, then fails through structured AppError | ✓ VERIFIED | `SharedKey.cloudflareClearance` is `InMemoryKey<CloudflareClearance?>` defaulting to nil (`AppSharedKeys.swift:80-84`); independent grep: no `appStorage`/`fileStorage` consumer; challenge web view runs on `WKWebsiteDataStore.nonPersistent()`; cookie-logging gate re-run by verifier — passes. `maxChallengeRounds = 2` (`LoginReducer.swift:21`), third challenge → `.loginDone(.failure(.cloudflareChallengeFailed))` → persistent tappable toast → ErrorInfoView, proven by `thirdChallengeExhaustsTheBoundAndFailsThroughTheStructuredError` (passing). Force-quit relaunch re-presented the wall, owner-attested (D31). |
| 6 | Goal clause: the other two login methods (in-app web login, manual cookie entry) are unchanged | ✓ VERIFIED | Git: no phase-12 commits touch `WebView.swift` (web login), `CookieClient/`, or the AccountSetting cookie-entry surface. `LoginView` web-login sheet path intact (`.sheet(item: $store.destination.webView…)`, still sends `.loginDone(.success(nil))`, which skips `setCredentials` and consults `didLogin` exactly as before). Behavioral regression `webLoginPresentationAndDismissalAreUnaffectedByTheChallengeHandling` passing. |

**Score:** 6/6 truths verified (0 present-but-behavior-unverified)

### C1 qualification (external condition, not a phase gap)

C1 was owner-verified PASS live. **After** that pass, the forum enabled a Cloudflare Turnstile CAPTCHA *inside its own login form* — distinct from the edge wall this phase clears. While active, it blocks native credential login regardless of password, because the submission requires a `cf-turnstile-response` field only a rendered form can produce. The phase detects this condition (`Parser.loginFormRequiresCaptcha` → `AppError.loginCaptchaRequired`, localized in all six catalog locales, recovery suggestion routing to the working web-login fallback) rather than misreporting it as a bad password. Verified in code (`Request+Account.swift:95-106`, `Parser+ResponseError.swift:36-70`, `AppError.swift:20`) and behaviorally (`CaptchaGatedLoginTests`, `LoginErrorMessageParserTests` passing). C1 is met; its live reproducibility is currently gated by a site-side condition that is detected, named, and has a working fallback. Any work to make native login survive an active Turnstile gate is new scope for a future phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `AppPackage/Sources/AppModels/Support/AppError.swift` | `cloudflareChallengeFailed` wired into all five members | ✓ VERIFIED | Case at line 19; present in `isRetryable` (non-retryable, line 34), description, alertText, solution switches. Bonus `loginCaptchaRequired` (line 20) equally wired, plus `AppError+Symbol.swift` and `DownloadClient+PageDownload.swift` exhaustive switches. |
| `AppPackage/Sources/AppModels/Support/CloudflareClearance.swift` | Sendable (cookieValue, userAgent) pair | ✓ VERIFIED | 23 lines, `Equatable, Hashable, Sendable`, both fields, doc-comment carries the never-persist/never-log invariants. |
| `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` | InMemoryKey session holder defaulting to nil | ✓ VERIFIED | `InMemoryKey<CloudflareClearance?>.Default`, `default: nil`. |
| `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` | Three `app_error.cloudflare_challenge_*` keys, six locales | ✓ VERIFIED | All three keys plus three `app_error.login_captcha_*` keys, each localized in de/en/ja/ko/zh-Hans/zh-Hant (parsed from catalog JSON). |
| `AppPackage/Sources/NetworkingFeature/Request.swift` | Generic response-driven classifier | ✓ VERIFIED | `public func isCloudflareChallenge(_ response: URLResponse?) -> Bool`. |
| `AppPackage/Sources/NetworkingFeature/Request+Account.swift` | Clearance-carrying LoginRequest variant | ✓ VERIFIED | Optional `clearance: CloudflareClearance?` parameter; explicit headers; body parsing for rejection surfacing. |
| `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift` | Cookie-observing WKWebView wrapper | ✓ VERIFIED | 229 lines; `WKHTTPCookieStoreObserver` + poll + `didFinish`; non-persistent store; UA readout. |
| `AppPackage/Sources/SettingFeature/Login/LoginClient.swift` | Injectable login seam | ✓ VERIFIED | `struct LoginClient` with typed `throws(AppError)`; `liveValue` calls `LoginRequest(…).response()`; `testValue` unimplemented. |
| `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` | Challenge state machine | ✓ VERIFIED | `challengeDetected`/`challengeClearanceCaptured`/`cancelChallenge`; bounded rounds; pre-BindingReducer swipe hook; `@Shared(.cloudflareClearance)` session holder; toast on every failure arm. |
| `AppPackage/Sources/SettingFeature/Login/LoginView.swift` | Challenge sheet + toast + ErrorInfoView | ✓ VERIFIED | `.sheet(item: $store.destination.challenge…)` hosting `ChallengeWebView` with `cancellationAction` toolbar button and `.privacyMask()`; errorInfo sheet; `.toast` with tap-through to `presentErrorInfo`. |
| `AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` | Classifier matrix + header assertions, ≥60 lines | ✓ VERIFIED | 9 `@Test`s incl. parameterized negatives; uses `makeStubbedSession`/URLProtocol-level request capture. Passing in this run. |
| `AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift` | Exhaustive TestStore coverage, ≥150 lines | ✓ VERIFIED | 20,813 bytes, 12 test functions covering pass-through, rounds, capture-retry, session pair, cancel/swipe silence, toast tap-through, web-login regression, credentials-before-verdict. Passing in this run. |
| `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md` | Both new roots recorded, counts reconciled | ✓ VERIFIED | ROOT-41 (challenge sheet) and ROOT-42 (login error-info sheet) rows present; 42 ROOT rows counted independently; derived counts (42/42/43/2) internally consistent; `LoginView.swift | 3` matches the 3 actual `.privacyMask()` sites. See IN-line-drift note below. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| AppError.swift | Localizable.xcstrings | `appErrorCloudflareChallenge*` symbols | ✓ WIRED | 3 `String(localized:)` uses (lines 57, 93, 118). |
| AppSharedKeys.swift | CloudflareClearance.swift | `InMemoryKey<CloudflareClearance?>` | ✓ WIRED | Line 80. |
| Request+Account.swift | CloudflareClearance.swift | optional clearance parameter | ✓ WIRED | Init param + header attachment. |
| CloudflareChallengeDetectionTests | CountingStubProtocol | `makeStubbedSession` | ✓ WIRED | Present; wire-level request assertions. |
| ChallengeWebView.swift | CloudflareClearance.swift | `onClearance` callback payload | ✓ WIRED | `onClearance(.init(cookieValue:userAgent:))` at line 227. |
| LoginClient.swift | Request+Account.swift | `LoginRequest(…).response()` | ✓ WIRED | `performLogin` at lines 32-39. |
| LoginReducer.swift | LoginClient.swift | `@Dependency(\.loginClient)` | ✓ WIRED | Drives both initial POST and retry via shared `loginEffect`. |
| LoginReducer.swift | Request.swift | `isCloudflareChallenge` after fetch | ✓ WIRED | Line 240; classification post-fetch, outside the transport retry loop. |
| LoginView.swift | ChallengeWebView.swift | `challengeClearanceCaptured` | ✓ WIRED | Sheet content sends the action with the captured pair (line 87). |
| LoginChallengeFlowTests | LoginReducer.swift | `TestStore(…, reducer: LoginReducer.init)` + overridden loginClient | ✓ WIRED | Present in harness. |
| 07-PRIVACY-MASK-INVENTORY.md | LoginView.swift | ROOT rows mapping each new sheet to its mask site | ✓ WIRED | ROOT-40/41/42 rows reference LoginView.swift; count matches actual masks. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| LoginView challenge sheet | `store.destination.challenge` URL | `challengeDetected` sets `Defaults.URL.login` | Yes — real challenged URL loaded by WKWebView | ✓ FLOWING |
| ChallengeWebView → reducer | `CloudflareClearance` | Live cookie store poll + `navigator.userAgent` | Yes — real cookie value + real UA (no hardcoding) | ✓ FLOWING |
| Retry POST | `state.cloudflareClearance` | `@Shared(.cloudflareClearance)` written on capture, read proactively on every POST | Yes — pair travels to `LoginRequest` headers | ✓ FLOWING |
| Failure toast / ErrorInfoView | `state.toast` / `destination.errorInfo` | `loginDone` failure arm with whitelisted context rows | Yes — real `AppError` + context; clearance value never carried | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Full suite, post-UAT-fix tree (deferred run from 12-06) | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation` (run once, output saved and grepped) | **TEST SUCCEEDED** — 611 Swift Testing tests / 18 targets, 0 failed test runs; all 7 phase suites present and green | ✓ PASS |
| Shared-jar gate (D-04) | grep `HTTPCookieStorage` in ChallengeWebView.swift | 1 hit, comment-only; 0 in code | ✓ PASS |
| Response-driven gate (D-08) | grep `bypassSNIFiltering` in LoginReducer/LoginClient/ChallengeWebView/Request.swift | 0 hits | ✓ PASS |
| Cookie-logging gate (Phase 8, covers cf_clearance) | `./scripts/check-cookie-logging.sh` | "Cookie logging audit passed.", exit 0 | ✓ PASS |
| No-persistence gate (C5) | grep `cloudflareClearance` consumers for `appStorage`/`fileStorage` | 0 hits; key declared `InMemoryKey` | ✓ PASS |

### Requirements Coverage

Phase has no REQUIREMENTS.md mapping (confirmed by grep — no "Phase 12" rows); the scope contract is the five roadmap success criteria, referenced by plans as C-labels.

| C-label | Source Plans | Status | Evidence |
| ------- | ------------ | ------ | -------- |
| C1 | 12-06 | ✓ SATISFIED | Owner-attested live UAT (truth 1). |
| C2 | 12-02, 12-04, 12-05 | ✓ SATISFIED | Truth 2. |
| C3 | 12-03, 12-04, 12-05 | ✓ SATISFIED | Truth 3. |
| C4 | 12-02, 12-03, 12-04 | ✓ SATISFIED | Truth 4. |
| C5 | 12-01, 12-04, 12-05, 12-06 | ✓ SATISFIED | Truth 5. |

Union of plan `requirements` fields = {C1…C5} — no orphaned criteria.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| 07-PRIVACY-MASK-INVENTORY.md | ROOT-41/42 rows | Stale file:line refs — ROOT-41 mask recorded at LoginView.swift:96 (actual :101); ROOT-42 at :98/:100 (actual :103/:105). Drift introduced by fixes (`bad6905a` onward) landing after the reconciliation commit (`9c192632`). Root↔mask mapping and all derived counts remain correct. | ℹ️ Info | Future line-level audits will mismatch by a few lines; content contract intact. |
| — | — | No TBD/FIXME/XXX/TODO/HACK markers in any phase-modified source file. `placeholder` hits are a test-double `unimplemented` (standard IssueReporting pattern) and a domain-terminology comment — not stubs. | — | — |

Carried context from 12-REVIEW.md (0 Critical, 3 Warning, 6 Info — verified still open in code, none goal-blocking): WR-01 latent double-fire window in the ChallengeWebView latch (masked by the reducer's straggler guard at `LoginReducer.swift:158`, which I confirmed present); WR-02 re-entrant `.login` guard reads inverted (`LoginReducer.swift:133` — pre-existing guard, cost raised by the phase); WR-03 form values not individually percent-encoded (pre-dates the phase). These are quality follow-ups, not phase-goal gaps.

### Human Verification Required

None. The phase's one inherently-human gate (C1 live login, plus the WebKit live-wall behaviors, App Switcher mask, force-quit persistence check) was designed as a blocking owner checkpoint in 12-06 Task 2 and has been executed and owner-attested, with results recorded per-item in 12-06-SUMMARY.md (final round: PASS on all seven items, on the current build; round 0 correctly voided as pre-phase).

### Gaps Summary

No gaps. All five success criteria are observably true in the codebase (C1 by recorded owner attestation, C2–C5 by code + independently re-run gates + fresh behavioral test evidence), and the goal's "other two login methods unchanged" clause is proven by git history plus a passing regression test. The deferred post-fix full-suite run flagged in 12-06-SUMMARY.md was executed during this verification and is green. The one noteworthy external development — the forum's Turnstile gate inside its own login form — arose after the C1 pass, is detected and named by the phase (`AppError.loginCaptchaRequired`), and routes users to the working web-login fallback; making native login survive it is explicitly future scope.

---

_Verified: 2026-07-22T17:13:17Z_
_Verifier: Claude (gsd-verifier)_
