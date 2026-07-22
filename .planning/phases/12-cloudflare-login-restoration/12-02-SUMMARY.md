---
phase: 12-cloudflare-login-restoration
plan: 02
subsystem: networking
tags: [swift, urlsession, cloudflare, swift-testing, urlprotocol]

# Dependency graph
requires:
  - phase: 12-cloudflare-login-restoration
    provides: CloudflareClearance (cookieValue, userAgent) from plan 12-01
  - phase: 10-networking-async-migration
    provides: the injected-urlSession request convention and the CountingStubProtocol harness
provides:
  - "isCloudflareChallenge(_:) — public free function classifying any URLResponse as a Cloudflare challenge from status + cf-mitigated alone"
  - "LoginRequest.init(username:password:clearance:urlSession:) — clearance-carrying variant whose explicit Cookie and User-Agent headers are authoritative"
  - "CloudflareChallengeDetectionTests — 9 offline tests covering the classification matrix and both LoginRequest constructions"
affects: [12-04 login reducer flow, 12-05 reducer tests]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Response-driven classification: a free function taking URLResponse?, so any call site can classify without a Request instance"
    - "Authoritative explicit headers: httpShouldHandleCookies = false paired with a hand-built Cookie header"
    - "Parameterized Swift Testing cases (@Test(arguments:)) for classification matrices"

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift
  modified:
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift

key-decisions:
  - "The classifier is a free function, not a Request extension member: SettingFeature's reducer classifies a response it already holds and must not need a request instance"
  - "Empty cf-mitigated value is treated as not-a-challenge and locked by a test, alongside the missing-header and wrong-value cases"
  - "The no-clearance path asserts nil Cookie AND nil User-Agent on the recorded request — the URLProtocol harness proves the construction is unchanged rather than merely equivalent"

patterns-established:
  - "Untrusted response headers are matched exactly: fixed status plus a case-insensitive value compare, never body inspection"

requirements-completed: [C2, C4]

coverage:
  - id: D1
    description: "Any response is classified as a Cloudflare challenge purely from status 403 plus a case-insensitive cf-mitigated: challenge header — no host, path, body or setting is consulted"
    requirement: "C2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#forbiddenResponseCarryingTheMitigationHeaderIsAChallenge"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#mitigationHeaderValueIsComparedCaseInsensitively"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#forbiddenResponseWithoutTheMitigationValueIsNotAChallenge"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#mitigationHeaderOutsideForbiddenIsNotAChallenge"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#absentAndNonHTTPResponsesAreNotChallenges"
        status: pass
      - kind: other
        ref: "source assertion: zero non-comment bypassSNIFiltering matches in Request.swift (plan acceptance criterion)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A login POST built with a clearance pair carries Cookie: cf_clearance=<value> and the solving web view's exact User-Agent, with shared-jar cookie handling disabled so those headers are authoritative"
    requirement: "C4"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#clearanceCarryingLoginRequestSendsTheCookieAndItsBoundUserAgent"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#clearanceCarryingLoginRequestDisablesSharedJarCookieHandling"
        status: pass
    human_judgment: false
  - id: D3
    description: "A login POST built without a clearance is constructed exactly as before — the no-wall path is unchanged"
    requirement: "C2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#loginRequestWithoutClearanceIsConstructedExactlyAsBefore"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift#bothLoginRequestVariantsPostToTheLoginURL"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift#loginRequestLocksFormAssemblyAndHTTPResponse"
        status: pass
    human_judgment: false
  - id: D4
    description: "The retried POST is actually accepted by the live Cloudflare edge (URLSession's TLS fingerprint versus the solving web view's)"
    verification: []
    human_judgment: true
    rationale: "Research assumption A2 — only the owner's live login UAT (12-06 Task 2) can settle whether clearance survives the transport switch; no offline test can assert it"

# Metrics
duration: 13min
completed: 2026-07-22
status: complete
---

# Phase 12 Plan 02: Networking Seams Summary

**A free `isCloudflareChallenge(_:)` that classifies any response from status 403 plus `cf-mitigated: challenge` alone, and a `LoginRequest` clearance variant whose explicit `Cookie` / `User-Agent` headers are made authoritative by disabling shared-jar cookie handling — both proven offline by nine URLProtocol-stubbed tests.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-07-22T07:22Z
- **Completed:** 2026-07-22T07:35Z
- **Tasks:** 2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments

- `isCloudflareChallenge(_ response: URLResponse?) -> Bool` as a public *free* function beside the `Request` extension: the login reducer holds a response, not a request, and detection must stay callable from anywhere the wall spreads to (D-05).
- Classification consults status and one header, nothing else. No hostname branch, no `bypassSNIFiltering`, no body inspection — the anti-pattern RESEARCH called out and threat T-12-04 targets.
- `LoginRequest` gained an optional `clearance: CloudflareClearance?`. Non-nil sets `httpShouldHandleCookies = false`, an explicit `Cookie: cf_clearance=…`, and the clearance's bound User-Agent; nil changes nothing at all.
- Nine tests in one suite, all offline: five parameterized/plain classification cases over hand-built `HTTPURLResponse` fixtures, four request-construction cases reading `handle.receivedRequests` from the existing `CountingStubProtocol` harness.
- The no-wall path is proven, not assumed: the recorded no-clearance request carries neither explicit header, keeps `httpShouldHandleCookies` true, and the pre-existing `AccountRequestBaselineTests` form-assembly lock still passes untouched.

## Task Commits

1. **Task 1 (RED): failing classification matrix** — `2e4de0ca` (test)
2. **Task 1 (GREEN): response-driven challenge classifier** — `b6f3c3e2` (feat)
3. **Task 2 (RED): failing header-carriage assertions** — `4e2610df` (test)
4. **Task 2 (GREEN): clearance-carrying LoginRequest** — `faeb7bd0` (feat)

## Files Created/Modified

- `AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` — new suite; classification matrix plus both `LoginRequest` constructions.
- `AppPackage/Sources/NetworkingFeature/Request.swift` — the classifier, doc-commented with the 403 + `cf-mitigated` contract and why a challenged 403 never enters `fetch`'s four-attempt retry budget.
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` — `LoginRequest.clearance` plus the guarded header block, commented with the Pitfall-4 rationale.

## Decisions Made

- **Free function over a `Request` extension member.** The plan mandated it and the reason held up: the consumer (12-04's reducer) has a response in hand and no request instance. It also makes the classifier trivially testable without a stub session.
- **Empty `cf-mitigated` value counts as not-a-challenge.** Added as a third case to the negative parameterized test alongside the absent header and a `bypass` value. `caseInsensitiveCompare` already gives this, but locking it stops a future refactor to a truthy `!= nil` check.
- **`httpShouldHandleCookies == false` asserted as its own test.** It is the whole mitigation for threat T-12-05, and folding it into the header test would let a header-only regression pass silently.
- **`User-Agent` scoped to this one request.** Set on the `URLRequest`, never on `URLSessionConfiguration.httpAdditionalHeaders`, so the app's general traffic keeps its default UA (D-07).

## Deviations from Plan

None — plan executed exactly as written. The Pitfall-4 shared-jar caveat (research assumption A1) is discharged in code comments rather than by a behavior change: the login POST needs no outbound cookie, since credentials arrive as `Set-Cookie` on the response.

## Issues Encountered

None. Both RED gates failed for exactly the intended reason — `Cannot find 'isCloudflareChallenge' in scope`, then `extra argument 'clearance' in call` — and no downstream call site broke, because the new parameter is defaulted.

One environment note carried over from 12-01: every `xcodebuild` invocation needs `-skipMacroValidation` on this machine (a local Xcode macro-trust artifact, not a code defect).

## Verification Evidence

- `xcodebuild test … -only-testing:NetworkingFeatureTests/CloudflareChallengeDetectionTests -skipMacroValidation` → **TEST SUCCEEDED**, 9 tests in 1 suite.
- `xcodebuild test … -only-testing:NetworkingFeatureTests -skipMacroValidation` → **TEST SUCCEEDED**, 86 tests in 10 suites; the account baseline locks are unaffected.
- `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator' -skipMacroValidation` → **BUILD SUCCEEDED**, zero warnings, SwiftLint clean at error severity.
- Acceptance grep: `Request.swift` declares `public func isCloudflareChallenge(_ response: URLResponse?) -> Bool` and has zero non-comment `bypassSNIFiltering` matches.

## Known Stubs

None. Both artifacts are complete; their only missing piece is a caller, which 12-04 supplies by design.

## Next Phase Readiness

- 12-04 can call `isCloudflareChallenge(response)` on the value `LoginRequest.response()` returns and pass a captured `CloudflareClearance` straight back into `LoginRequest(username:password:clearance:)`.
- 12-03's challenge web view must produce the *exact* `navigator.userAgent` of the solving view; the retried POST replays whatever string it captures verbatim.
- Live acceptance of the retried POST (research assumption A2, TLS fingerprint) remains open and is gated on the owner UAT in 12-06.

## Self-Check: PASSED

The created test file exists on disk; all four task commit hashes resolve in git history.

---
*Phase: 12-cloudflare-login-restoration*
*Completed: 2026-07-22*
