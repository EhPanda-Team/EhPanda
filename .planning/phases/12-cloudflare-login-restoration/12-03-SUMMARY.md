---
phase: 12-cloudflare-login-restoration
plan: 03
subsystem: setting
tags: [swift, swiftui, webkit, wkwebview, cloudflare, tca, dependencies]

# Dependency graph
requires:
  - phase: 12-cloudflare-login-restoration
    provides: CloudflareClearance (cookieValue, userAgent) from plan 12-01
  - phase: 12-cloudflare-login-restoration
    provides: LoginRequest.init(username:password:clearance:urlSession:) from plan 12-02
  - phase: 11-lint-and-lifecycle
    provides: the lifecycle_modifiers ban that keeps observer setup in UIKit controller lifecycle
provides:
  - "ChallengeWebView — UIViewControllerRepresentable WKWebView on a non-persistent data store that observes its own cookie store and reports (cf_clearance, exact navigator.userAgent) exactly once through onClearance"
  - "ChallengeWebViewController — the controller that is its own WKHTTPCookieStoreObserver, with idempotent teardown reachable from dismantleUIViewController"
  - "LoginClient — injectable login endpoint (username, password, clearance) whose live path calls LoginRequest.response()"
  - "LoginClientKey: DependencyKey and DependencyValues.loginClient"
affects: [12-04 login reducer flow, 12-05 reducer tests, 12-06 owner UAT]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Cookie-store observation: the view controller conforms to WKHTTPCookieStoreObserver itself, since the store does not retain observers"
    - "Representable teardown through dismantleUIViewController rather than deinit, which cannot touch MainActor-bound WebKit APIs"
    - "Named static function as a Dependencies endpoint so a typed throws(AppError) survives the closure conversion"

key-files:
  created:
    - AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift
    - AppPackage/Sources/SettingFeature/Login/LoginClient.swift
  modified: []

key-decisions:
  - "The controller is the observer: WKHTTPCookieStore explicitly does not retain observers, so pairing registration with an object the view hierarchy already keeps alive removes the whole class of silently-stopped-callback bugs — no separate observer object to own"
  - "Teardown lives in dismantleUIViewController, not deinit — a MainActor-isolated deinit cannot call WKHTTPCookieStore.remove — and also runs the moment the pair is captured, so the observation window closes as early as possible"
  - "A failed navigator.userAgent read leaves the one-shot latch open: half a pair is worthless because the clearance is UA-bound, so the next cookie change retries rather than reporting an unbindable clearance"
  - "LoginClient.live is a named function rather than a closure literal, because a closure literal infers `any Error` and silently downgrades LoginRequest's typed throws(AppError)"
  - "LoginClient is internal to SettingFeature — it exists to make the reducer testable, not to widen NetworkingFeature's public surface"

patterns-established:
  - "A WebKit surface reports its result through a plain closure payload, so the reducer half of a flow stays TestStore-testable while the WebKit half rides owner UAT"

requirements-completed: [C3, C4]

coverage:
  - id: D5
    description: "The challenge surface loads a URL, watches its own cookie store, and reports the (cf_clearance, exact User-Agent) pair upward exactly once — covering interactive walls and zero-interaction auto-pass alike"
    requirement: "C3"
    verification:
      - kind: build
        ref: "xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "source assertion: ChallengeWebView.swift contains UIViewControllerRepresentable, WKHTTPCookieStoreObserver, nonPersistent, navigator.userAgent and onClearance (plan acceptance criteria)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The User-Agent replayed on the retried POST is the live navigator.userAgent of the very web view that earned the clearance, read before the surface can be dismissed — never a constant or a reconstruction"
    requirement: "C4"
    verification:
      - kind: other
        ref: "source assertion: the UA is read via webView.evaluateJavaScript(\"navigator.userAgent\") inside the cookie-change handler, on the same instance that owns the observed store"
        status: pass
    human_judgment: false
  - id: D7
    description: "The challenge run writes nothing into the shared system cookie jar and persists nothing to disk"
    requirement: "C3"
    verification:
      - kind: other
        ref: "grep gate: zero non-comment HTTPCookieStorage matches in ChallengeWebView.swift; websiteDataStore is WKWebsiteDataStore.nonPersistent()"
        status: pass
      - kind: other
        ref: "grep gate: zero onAppear / .task( matches — observation lives in UIKit controller lifecycle, per lifecycle_modifiers"
        status: pass
    human_judgment: false
  - id: D8
    description: "The login fetch is reachable through an injectable dependency, so 12-05 can drive the bounded-retry state machine offline"
    verification:
      - kind: build
        ref: "xcodebuild build … -skipMacroValidation (LoginClient, LoginClientKey and DependencyValues.loginClient compile and register)"
        status: pass
      - kind: unit
        ref: "xcodebuild test … -only-testing:SettingFeatureTests -skipMacroValidation — 35 tests, 10 suites, no regression from the new dependency"
        status: pass
    human_judgment: false
  - id: D9
    description: "The observer actually fires against a live Cloudflare wall, the auto-dismiss lands, and the captured UA is accepted by the edge"
    verification: []
    human_judgment: true
    rationale: "WKWebView cookie-store behavior cannot run under TestStore; only the owner's live login UAT (12-06 Task 2) can exercise it"

# Metrics
duration: 13min
completed: 2026-07-22
status: complete
---

# Phase 12 Plan 03: Challenge Surface and Login Seam Summary

**A `WKWebView` wrapper that watches its own non-persistent cookie store and, the instant `cf_clearance` lands, reads that same view's exact `navigator.userAgent` and reports the pair upward once — plus a `LoginClient` dependency that puts the login POST behind a substitutable seam.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-07-22T07:34Z
- **Completed:** 2026-07-22T07:47Z
- **Tasks:** 2
- **Files modified:** 2 (2 created)

## Accomplishments

- `ChallengeWebView` is a `UIViewControllerRepresentable` whose controller owns a `WKWebView` built on `WKWebsiteDataStore.nonPersistent()` — the clearance the run mints never reaches WebKit's on-disk cookie database, so C5's no-persistence claim needs no cleanup code to be true.
- The controller conforms to `WKHTTPCookieStoreObserver` itself. The store does not retain observers, so making the observer an object the view hierarchy already keeps alive removes the failure mode where the callback silently stops firing.
- On every cookie change the handler looks for a non-empty `cf_clearance`, then reads `navigator.userAgent` from that same web view before anything can dismiss the surface, and reports a `CloudflareClearance` through `onClearance` behind a one-shot latch.
- Capture closes the observation window immediately: the successful path unregisters the observer as well as latching, and SwiftUI's `dismantleUIViewController` covers the cancelled and never-solved paths.
- No shared-jar write anywhere — the `getAllCookies` → `HTTPCookieStorage.shared.setCookie` loop that `WebView.swift` runs on navigation finish is deliberately absent, and a comment-filtered grep gate locks that.
- `LoginClient` wraps `LoginRequest(username:password:clearance:).response()` as a single `@Sendable` endpoint with `live`, an unimplemented `testValue`, and a `DependencyValues.loginClient` accessor, following the repo's `UserDefaultsClient` registration shape.

## Task Commits

1. **Task 1: cookie-observing Cloudflare challenge web view** — `6c3df259` (feat)
2. **Task 2: LoginClient dependency seam** — `f3ec22a3` (feat)

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift` — the representable, the controller/observer, and the capture path, doc-commented with the two invariants (no shared jar, non-persistent store) that must survive any edit.
- `AppPackage/Sources/SettingFeature/Login/LoginClient.swift` — the endpoint, `live` via a named function, `LoginClientKey`, the `DependencyValues` accessor, and the unimplemented misuse guard.

## Decisions Made

- **The controller is the observer.** The plan offered "controller owns the observer strongly"; collapsing the two removes an object whose only job would have been to be retained. Registration in `viewDidLoad`, unregistration in an idempotent `stopObservingCookieStore()`.
- **`dismantleUIViewController` for teardown, not `deinit`.** `WKHTTPCookieStore` is `MainActor`-bound and a `deinit` is not isolated, so a `deinit`-based unregistration would not compile under Swift 6 without an isolated-deinit workaround. The representable's own dismantle hook is deterministic and runs on the main actor already.
- **The latch is set only after a complete pair.** Because Cloudflare binds the clearance to the UA, a clearance without its UA is not a partial success but a value that would be rejected — so a failed JS read logs and returns with the latch open, letting the next cookie change try again.
- **`LoginClient.live` is a function, not a closure literal.** A closure literal in that position infers `any Error` and rejects the assignment; naming the function preserves `throws(AppError)` end to end.
- **No accessibility modifiers on the wrapper.** WebKit vends its own accessibility tree for the challenge page; attaching a label or grouping to the hosting view would collapse that tree and make an interactive wall *less* reachable, not more.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Context` resolved to AppModels' `Context` typealias**

- **Found during:** Task 1
- **Issue:** `func makeUIViewController(context: Context)` failed the `UIViewControllerRepresentable` conformance — the unqualified `Context` binds to AppModels' `Context` (`[ContextKey: AnyHashableBox]`), which SettingFeature imports, rather than the representable's associated type. The compiler reported it as a non-matching candidate, not as a name collision.
- **Fix:** Spelled both signatures `Self.Context` (the same qualification `WebView.swift` already uses) and left a comment naming the collision so the next reader does not "simplify" it back.
- **Files modified:** `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift`
- **Commit:** `6c3df259`

**2. [Rule 3 - Blocking] typed `throws(AppError)` lost through a closure literal**

- **Found during:** Task 2
- **Issue:** `login: { username, password, clearance in try await LoginRequest(...).response() }` failed with *invalid conversion of thrown error type 'any Error' to 'AppError'* — a closure literal does not infer a typed thrown error here.
- **Fix:** Moved the body into a `private static func performLogin(...) async throws(AppError) -> HTTPURLResponse?` and passed the function reference, with a comment explaining why the closure form is not equivalent.
- **Files modified:** `AppPackage/Sources/SettingFeature/Login/LoginClient.swift`
- **Commit:** `f3ec22a3`

Both are compile-time discoveries with no behavioral consequence; the plan's design is unchanged.

## Issues Encountered

None beyond the two compile-time fixes above. The `IssueReporting.unimplemented(placeholder:)` fallback the plan flagged as uncertain composed with the typed-throws endpoint on the first try, so no hand-written `reportIssue` guard was needed.

Environment note, third confirmation: every `xcodebuild` invocation on this machine needs `-skipMacroValidation` (a local Xcode macro-trust artifact, not a code defect).

## Verification Evidence

- `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator' -skipMacroValidation` → **BUILD SUCCEEDED**, zero warnings, SwiftLint clean at error severity.
- `xcodebuild test … -only-testing:SettingFeatureTests -skipMacroValidation` → **TEST SUCCEEDED**, 35 tests in 10 suites; the new dependency registration breaks nothing.
- Acceptance greps on `ChallengeWebView.swift`: `UIViewControllerRepresentable` 1, `WKHTTPCookieStoreObserver` 1, `nonPersistent` 1, `navigator.userAgent` 2, `onClearance` 10; non-comment `HTTPCookieStorage` 0; `onAppear`/`.task(` 0.
- Acceptance greps on `LoginClient.swift`: `struct LoginClient` 1, `CloudflareClearance?` 2, `LoginClientKey` 3, `var loginClient` 1; non-comment `bypassSNIFiltering` 0.

## Known Stubs

None. Both artifacts are complete; their only missing piece is a caller, which 12-04 supplies by design.

## Next Phase Readiness

- 12-04 can present `ChallengeWebView(url:onClearance:)` from a `Destination.challenge(URL)` sheet and translate the callback straight into `.challengeClearanceCaptured(CloudflareClearance)`. Remember `.privacyMask()` on the new sheet root (Pitfall 5, reconciled in 12-06).
- 12-04 should route the login effect through `@Dependency(\.loginClient)` instead of calling `LoginRequest` directly, or 12-05's `TestStore` cases will need a live host.
- The WebKit half — observer firing, auto-dismiss, and whether the live edge accepts the captured UA over URLSession's TLS fingerprint (research assumption A2) — remains gated on the owner UAT in 12-06 Task 2.

## Self-Check: PASSED

Both created files exist on disk; both task commit hashes resolve in git history.

---
*Phase: 12-cloudflare-login-restoration*
*Completed: 2026-07-22*
