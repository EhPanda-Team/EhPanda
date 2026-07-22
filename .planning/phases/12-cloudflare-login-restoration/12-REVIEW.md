---
phase: 12-cloudflare-login-restoration
reviewed: 2026-07-22T17:05:42Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - AppPackage/Sources/AppComponents/AppError+Symbol.swift
  - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
  - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
  - AppPackage/Sources/AppModels/Support/AppError.swift
  - AppPackage/Sources/AppModels/Support/CloudflareClearance.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/NetworkingFeature/Request+Account.swift
  - AppPackage/Sources/NetworkingFeature/Request.swift
  - AppPackage/Sources/ParserFeature/Parser+ResponseError.swift
  - AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift
  - AppPackage/Sources/SettingFeature/Login/LoginClient.swift
  - AppPackage/Sources/SettingFeature/Login/LoginReducer.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Sources/SystemNotification/ToastMessageView.swift
  - AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift
  - AppPackage/Tests/NetworkingFeatureTests/LoginRejectionSurfacingTests.swift
  - AppPackage/Tests/ParserFeatureTests/Other/LoginErrorMessageParserTests.swift
  - AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-07-22T17:05:42Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Reviewed the Cloudflare login-restoration implementation: challenge detection (`isCloudflareChallenge`),
the in-app challenge surface (`ChallengeWebView`), the clearance-carrying retry (`LoginRequest`), the
reducer state machine (`LoginReducer`), rejection parsing (`Parser+ResponseError`), and the supporting
error/localization/test files.

**Security invariants all hold.** `cf_clearance` lives only in the `InMemoryKey`-backed
`@Shared(.cloudflareClearance)` holder (`AppSharedKeys.swift:80-84`); `ChallengeWebView` runs on
`WKWebsiteDataStore.nonPersistent()` and never touches `HTTPCookieStorage.shared`; the retried POST
sets `httpShouldHandleCookies = false` and applies `setCredentials` before reading `didLogin`
(`LoginReducer.swift:171-184`); no cookie *value* reaches any log — I re-ran
`scripts/check-cookie-logging.sh` and it passes. The DEBUG dump's `redactedCredentialHeader` drops
all values for RFC 6265-compliant cookies (see IN-04 for its residual weakness). The six new
`.xcstrings` keys carry all six supported locales, fully translated, with no numeric format
arguments — catalog rules satisfied.

**The tests genuinely constrain behavior** rather than restating the implementation: the
`TestStore` suite is exhaustive (silences are assertions), the swipe test sends the binding write
SwiftUI actually produces rather than the `.dismiss` it doesn't, the echo test deliberately steps
around `TestStore`'s inability to model a nil-to-nil write, and the credentials-before-verdict
regression test starts from an *empty* jar specifically so the ordering bug it pins cannot pass by
accident. The outbound-request tests assert the wire shape (`Cookie`, `User-Agent`,
`httpShouldHandleCookies`) at the URLProtocol level, not the model level.

Three defects found, none Critical: a double-fire window in the challenge web view's one-shot latch
(currently masked by a downstream guard), a re-entrant `.login` while loading, and a long-standing
form-encoding bug that silently breaks credential login for passwords containing `&`, `=`, or `+`.

## Warnings

### WR-01: `ChallengeWebView`'s one-shot latch can double-fire across suspension points

**File:** `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift:186-228`
**Issue:** `reportClearanceIfPresent` checks `hasReportedClearance` only on entry (line 187), then
crosses two suspension points (`await cookieStore.allCookies()` at line 188 and
`await webView.evaluateJavaScript(...)` at line 208) before setting the latch at line 224. The poll
task, `cookiesDidChange`, and `didFinish` all invoke this method on the main actor, and main-actor
serialization does not prevent interleaving at `await`: two invocations can both pass the entry
guard, both fetch the cookie and the UA, and both reach lines 224-227 — firing `onClearance` twice.
The doc comment promises the pair is handed up "exactly once"; it is not. Today the duplicate is
absorbed by `LoginReducer`'s straggler guard (`state.destination?.is(\.challenge) == true`,
`LoginReducer.swift:158`), so the defect is latent — but the latch's contract is broken and any
future consumer of `ChallengeWebView` without that exact guard inherits a double-report.
**Fix:** Re-check the latch after the last suspension point, immediately before committing:
```swift
userAgent = string
// ... catch block unchanged ...

guard !hasReportedClearance else { return }
hasReportedClearance = true
stopObservingCookieStore()
```
(One line before line 224 suffices; the earlier entry guard can stay as a cheap fast-path.)

### WR-02: `.login` is re-entrant while a login is already in flight

**File:** `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift:133,278` and `AppPackage/Sources/SettingFeature/Login/LoginView.swift:40-59`
**Issue:** The guard `guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }`
*admits* `.login` while `loginState == .loading` (the `||` clause makes the condition true even with
empty fields — the logic reads inverted). The view does not close the gap: the login button is only
`.disabled(store.loginButtonDisabled)` (empty-field check); while loading it turns `.clear` but stays
tappable under the `ProgressView` overlay. A tap during a pending POST therefore passes the guard,
resets `challengeRounds` to 0 mid-flow, and starts a *second* concurrent login effect —
`.cancellable(id: CancelID.login)` at line 278 defaults to `cancelInFlight: false`, so the first
effect keeps running. Both effects then deliver `.loginDone`: duplicate credential application,
duplicate haptics, and `await dismiss()` invoked twice (a TCA runtime issue and a possible extra
pop). The guard line predates this phase, but the phase's challenge state machine (round counter,
shared cancel ID, dismiss-on-success) raises the cost of the re-entry considerably.
**Fix:** Block re-entry and make the effect self-defending:
```swift
case .login:
    guard !state.loginButtonDisabled, state.loginState != .loading else { return .none }
```
and/or `.cancellable(id: CancelID.login, cancelInFlight: true)` in `loginEffect`.

### WR-03: Login form values are not individually percent-encoded — passwords containing `&`, `=`, or `+` break the POST

**File:** `AppPackage/Sources/NetworkingFeature/Request.swift:222-229` (used at `Request+Account.swift:63`)
**Issue:** `dictString()` joins raw `key=value` pairs with `&`, and the single `urlEncoded` pass over
the joined string uses `.urlQueryAllowed`, which *permits* `&`, `=`, and `+`. So none of the
structural characters inside a value are escaped: a password containing `&` truncates the `PassWord`
field and injects a stray parameter; `=` corrupts the pair; `+` is decoded server-side as a space
per `application/x-www-form-urlencoded`. The user sees an unexplained login rejection — exactly the
"wrong password that was never the problem" failure mode this phase's error-surfacing work exists to
prevent. The helper predates the phase, but it sits at the heart of the flow being restored and is
shared by every form POST in `Request+Account.swift`.
**Fix:** Encode each key and value separately with a form-safe character set before joining:
```swift
public func dictString() -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return map { key, value in
        let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(k)=\(v)"
    }
    .joined(separator: "&")
}
```
(and drop the now-redundant outer `.urlEncoded` at each call site).

## Info

### IN-01: Comment overstates what the rejection throw prevents

**File:** `AppPackage/Sources/NetworkingFeature/Request+Account.swift:86-90`
**Issue:** The comment claims "throwing here also stops the failure page's Set-Cookie tombstones from
reaching the jar". That is only true of the reducer's explicit `setCredentials` call. On the bare
(no-clearance) path `httpShouldHandleCookies` is `true`, so URLSession files the response's
Set-Cookie into `HTTPCookieStorage.shared` automatically when the response arrives — before and
regardless of the throw. Tombstones from a rejection page can still clobber an existing session on
that path.
**Fix:** Correct the comment (the throw prevents the *second*, explicit filing only), or set
`httpShouldHandleCookies = false` on the bare POST too and rely solely on `setCredentials` — which
would also make the two paths symmetric.

### IN-02: Stale dismissal echo can be misread as a swipe if it lands after a round-2 challenge

**File:** `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift:98-105`
**Issue:** The pre-`BindingReducer` hook distinguishes swipe from echo by whether the challenge is
still in state. That discriminator assumes the echo of the reducer's own dismissal always arrives
*before* the next challenge is presented. If a retry ever completed faster than SwiftUI delivers the
echo (stubbed session, cached response, instant edge), the echo's nil write would land with the
round-2 challenge already in `destination` and `loginState == .loading` — the hook would cancel the
attempt and `BindingReducer` would tear down the new sheet. In production the network round-trip
makes this window effectively unreachable, so this is recorded as a known limitation rather than a
defect.
**Fix:** No action required now; if it ever manifests, tagging each presentation (e.g. a
monotonically increasing challenge ID compared in the hook) would close the window.

### IN-03: The four-attempt transport retry applies to the credential POST

**File:** `AppPackage/Sources/NetworkingFeature/Request.swift:63-79`
**Issue:** `fetch` retries up to four times on any transport error. A POST that the server received
but whose response was lost (timeout, connection reset) is replayed up to three more times — up to
four recorded login attempts for one tap, which feeds the forum's "exceeded the number of login
attempts" lockout that this phase's parser now surfaces. The policy predates the phase and is fine
for idempotent GETs; the login POST is the one place it can actively harm the account.
**Fix:** Consider a non-retrying fetch variant (or attempt count of 1) for `LoginRequest`.

### IN-04: `redactedCredentialHeader` splits on `,` only and can emit attribute fragments as "names"

**File:** `AppPackage/Sources/NetworkingFeature/Request+Account.swift:16-27`
**Issue:** Splitting the coalesced header on `,` lands mid-`expires` attribute, so chunks like
`22-Jul-2026 10:00:00 GMT; path=/` yield "names" such as `22-Jul-2026 10:00:00 GMT; path` — noisy
but not secret. Value safety rests entirely on RFC 6265 forbidding `,` in cookie-octets; a
non-compliant server emitting a comma inside a value could leak the post-comma fragment into the
"names" list. DEBUG-only and low risk, but the redactor is the sole guard on that dump.
**Fix:** Split each comma-chunk on `;` and take only the first segment's name, e.g.
`chunk.split(separator: ";").first` before locating `=`; fragments without a plausible
`name=` prefix (as chunk start) should be dropped rather than surfaced.

### IN-05: `parseLoginErrorMessage` scans the entire page for its marker phrases

**File:** `AppPackage/Sources/ParserFeature/Parser+ResponseError.swift:36-57`
**Issue:** The markers ("the error returned was" / "the following errors were found") are searched
across the whole stripped page rather than scoped to the forum's board-message/error containers. Any
page that *echoes* one of those phrases in ordinary content — e.g. a post-login landing page quoting
an error in a thread title — would misclassify a successful login as a rejection and throw before
`setCredentials` runs; on the clearance path (`httpShouldHandleCookies = false`) the session cookies
from that response would be lost entirely. The login POST's response is normally a bare board
message, so the practical risk is low, but the failure mode is a persistent false "login failed".
**Fix:** Anchor the search to the error container markup (e.g. only consider text following a
`pformstrip`/`formsubtitle` element) before falling back to the page-wide scan.

### IN-06: `AppErrorStructuredTests` assert locale-dependent display strings

**File:** `AppPackage/Tests/AppModelsTests/AppErrorStructuredTests.swift:13-92`
**Issue:** The expectations compare `String(localized:)` output against hard-coded English text, so
the suite fails when the test runner's locale/language is not English. This makes the tests
environment-sensitive rather than wrong; the phase-added cases (`cloudflareChallengeFailed`,
`loginCaptchaRequired`) sensibly assert non-emptiness/distinctness instead.
**Fix:** Pin the test bundle's language (test plan `-AppleLanguages (en)`) or convert the older
string-equality cases to the non-emptiness style the new cases use.

---

_Reviewed: 2026-07-22T17:05:42Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
