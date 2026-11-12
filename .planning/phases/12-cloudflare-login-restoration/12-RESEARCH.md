# Phase 12: Cloudflare Login Restoration - Research

**Researched:** 2026-07-22
**Domain:** iOS networking + WKWebView challenge clearance (Cloudflare `cf-mitigated`), TCA reducer flow
**Confidence:** HIGH (codebase seams + SDK-verified WebKit/Foundation APIs); MEDIUM (Cloudflare header/cookie semantics — official docs + community)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The `WKWebView` challenge sheet **presents immediately** when a challenge is detected — no hidden/invisible pre-attempt. Auto-pass walls show briefly (~1–2s) and self-dismiss the moment `cf_clearance` lands; interactive walls are ready with zero delay. Reuses LoginView's existing sheet-presentation pattern.
- **D-02:** The sheet carries a **cancellation-role toolbar button at the stable `cancellationAction` placement** (Phase 5 reusable-sheet convention), plus swipe-down. Dismissing mid-challenge **aborts the login attempt**: `loginState` returns to `.idle`, no retry fires, no error toast (user-initiated cancel is silent).
- **D-03:** No new explanatory states/strings on the login form: `loginState = .loading` spans the entire detect → solve → retry flow. The login button's chevron reads as a **spinner for the whole processing span** — the existing `ProgressView`-overlay treatment extended across the challenge flow. Exact swap mechanism (overlay vs. content swap) is planner detail.
- **D-04:** `cf_clearance` is carried as a **flow-scoped value**: held as plain state, attached explicitly (Cookie header + User-Agent header) to the retried login POST. It **never enters `HTTPCookieStorage.shared`** — the most literal reading of criterion 5's "in memory only", zero cleanup, smallest blast radius.
- **D-05:** Challenge detection is a **generic NetworkingFeature helper** — classify any `(data, response)` as challenged via 403 + `cf-mitigated: challenge` — but **only the login flow wires it to the clearance UI this phase**.
- **D-06:** The captured **(cf_clearance, User-Agent) pair is kept in memory for the app session** (they travel together). A later login POST in the same session **proactively attaches the held pair**; an expired one comes back challenged, the normal flow re-runs and **replaces** the pair. Never persisted across launches; no expiry timer.
- **D-07:** (Locked by ROADMAP criterion 4) The web view's exact UA applies to the **retried login POST only** — general app traffic keeps its User-Agent unchanged.
- **D-08:** The challenge flow is **purely response-driven with zero DF conditionals**. Under "bypass SNI filtering", `DFURLProtocol` sends the login POST directly to the hardcoded origin IP (not a Cloudflare edge), so a challenge realistically never arrives — DF login keeps working or fails as `networkingFailed` as today. If a challenge ever did arrive under DF, the sheet presents normally (webview uses normal DNS/TLS) and the bounded retry/failure path covers it. No login-POST exemption from DF, no DF-gated blocking of challenge UI.
- **D-09:** **At most 2 challenge-surface presentations per login attempt.** Wall → solve → retry; if re-challenged, present once more → solve → retry; a third challenge fails the attempt.
- **D-10:** Exhausted retries throw a **new dedicated `AppError` case** (e.g. `cloudflareChallengeFailed`) with its own localized description and `recoverySuggestion` pointing at the working alternatives (in-app web login / manual cookie entry). New `.xcstrings` keys follow the labeled-format-argument and non-translated-key conventions (AGENTS.md).
- **D-11:** The failure presents through the **Phase 9 standard path**: persistent tappable failure toast → `ErrorInfoView` detail surface (Description / Suggested Solution / Context). Existing error notification haptic kept. LoginView gains no inline error text.

### Claude's Discretion

- The mechanism for observing `cf_clearance` appearing in the web view's cookie store (`WKHTTPCookieStoreObserver` vs. polling), and how the web view's exact UA string is read out.
- Whether the challenge surface reuses/extends `WebView.swift` or gets a dedicated wrapper (it needs cookie-store observation + UA readout that the web-login wrapper lacks).
- Where the session-lifetime (clearance, UA) holder lives (in-memory `@Shared` à la Phase 7 privacy-mask, an injected client, or parent-reducer state) — within Phase 8 no-singletons rule.
- Reducer decomposition: challenge flow as a child feature (new reducers carry `Feature` suffix) or folded into `LoginReducer`.
- `ErrorInfo` context rows carried by the new error case (attempt count, host, …) — Phase 9 D-06 planning detail.
- How the retried POST suppresses shared-jar cookie interference (e.g. `httpShouldHandleCookies`) so the explicit Cookie header is authoritative — research detail within D-04.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. Wiring the generic challenge detector to non-login requests (e.g. gallery hosts) is explicitly future work enabled by D-05, not part of this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

ROADMAP lists **Requirements: TBD (none mapped)** for Phase 12. The scope contract is ROADMAP §Phase 12's **five success criteria** (reproduced below). No REQUIREMENTS.md IDs map to this phase — it is a milestone follow-on restoring a regressed capability, not a v1 modernization requirement.

| Criterion | Behavior | Research Support |
|-----------|----------|------------------|
| C1 | Username/password login succeeds end-to-end against the live Cloudflare-fronted forums host | Detection + clearance + UA-bound retry (all sections); owner-driven live UAT gate |
| C2 | Challenge detection dynamic per-response (403 + `cf-mitigated: challenge`), non-challenged responses proceed with no extra UI | Detection helper (Standard Stack, Code Examples); `cf-mitigated` header confirmed by Cloudflare docs |
| C3 | On challenge, in-app WKWebView loads challenged URL; auto-dismiss the moment `cf_clearance` appears; covers interactive + zero-interaction walls | `WKHTTPCookieStoreObserver.cookiesDidChangeInCookieStore` (SDK-verified); dedicated webview wrapper |
| C4 | Retried POST carries captured `cf_clearance` + webview's exact UA; existing `setCredentials`/`didLogin` proceed unchanged | UA-binding (cf_clearance research); `evaluateJavaScript("navigator.userAgent")`; explicit Cookie/UA headers + `httpShouldHandleCookies=false` |
| C5 | `cf_clearance` in memory only, never persisted; no expiry timer; re-challenged retry re-presents (bounded), then fails via `AppError` | Flow-scoped state (D-04); bounded retry (D-09); new `AppError` case (D-10/D-11) |
</phase_requirements>

## Summary

This phase restores username/password login, broken because `forums.e-hentai.org/index.php?act=Login` now returns **HTTP 403 with `cf-mitigated: challenge`** on both GET and POST. The fix is a detect → clear → replay loop entirely inside the existing TCA login flow: classify the login POST's response as a Cloudflare challenge, present an interactive `WKWebView` at the challenged URL, watch that web view's cookie store for `cf_clearance`, then replay the login POST carrying the clearance cookie **and the exact User-Agent the challenge web view used** (Cloudflare binds the clearance to the UA — verified). All of this is bounded to two challenge presentations, keeps `cf_clearance` in memory only (never in `HTTPCookieStorage.shared`), and leaves the in-app web login and manual-cookie login methods untouched.

The codebase already provides every seam this needs. `LoginRequest.response()` (NetworkingFeature) currently fetches the POST and returns `HTTPURLResponse?` that **nothing status-checks today** — that is the exact insertion point for a generic `(data, response)` challenge classifier (D-05). `LoginReducer` already presents a `WKWebView` sheet via `Destination.webView(URL)` with haptics + `.privacyMask()` wiring; the challenge surface slots in as a second presented destination. The Phase 9 error machinery (`AppError` + `ErrorInfo` + `AppAlertState.error(_:)` toast + `ErrorInfoView`) supplies the D-10/D-11 failure surface as an extension, not new infrastructure. `WebView.swift` is a working `UIViewControllerRepresentable` WKWebView precedent, but it lacks the two capabilities this needs — cookie-store observation and UA readout — so a dedicated wrapper is the cleaner path (Claude's discretion, recommended).

**Primary recommendation:** Add a generic `NetworkingFeature` challenge classifier keyed on `HTTPURLResponse.statusCode == 403 && cf-mitigated == "challenge"`; expose it at the `LoginRequest` seam; drive a new challenge-webview surface (dedicated `UIViewControllerRepresentable` with a `WKHTTPCookieStoreObserver`) from `LoginReducer` (or a `Feature`-suffixed child); on `cf_clearance` appearance read the web view's UA via `evaluateJavaScript("navigator.userAgent")`, hold `(clearance, UA)` in flow/session state, and replay the POST with an explicit `Cookie` + `User-Agent` header and `httpShouldHandleCookies = false`. Bound to 2 presentations; on exhaustion throw a new `AppError.cloudflareChallengeFailed` surfaced through the Phase 9 toast → `ErrorInfoView` path.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Challenge detection (403 + `cf-mitigated`) | API / Backend (NetworkingFeature request layer) | — | It classifies an HTTP response; belongs beside `fetch`/`mapAppError`, not in the view (D-05) |
| Challenge surface presentation | Frontend (SettingFeature reducer + view) | — | Presentation-driven lifecycle via reducer (Phase 11 lint); a WKWebView sheet is a UI concern |
| `cf_clearance` capture / cookie-store observation | Browser / Client (WKWebView cookie store) | Frontend (reducer holds captured pair) | `cf_clearance` is minted inside the web view's own `WKWebsiteDataStore`, observed there, then lifted into reducer/session state |
| UA readout | Browser / Client (WKWebView JS context) | — | `navigator.userAgent` is the effective UA of that web view instance |
| Retried POST (clearance + UA headers) | API / Backend (NetworkingFeature request) | — | A new request variant carrying explicit headers; the retry is a networking op |
| Credential persistence after success | API/Backend → `CookieClient` | — | `setCredentials`/`didLogin` unchanged (C4) |
| Failure surface | Frontend (toast → `ErrorInfoView`) | AppModels (`AppError` case) | Phase 9 standard path (D-10/D-11) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WebKit (`WKWebView`, `WKHTTPCookieStore`, `WKHTTPCookieStoreObserver`) | iOS 17+ SDK (Xcode 26.6, iPhoneOS26.5 SDK) | Interactive challenge clearance + cookie-store observation | Only first-party way to render an interactive Cloudflare challenge and observe its cookie jar `[VERIFIED: iPhoneOS26.5 SDK WKHTTPCookieStore.h]` |
| Foundation (`URLRequest`, `HTTPURLResponse`, `URLSession`) | iOS SDK | POST, header inspection, explicit Cookie/UA headers, `httpShouldHandleCookies` | Already the entire request layer (`Request.fetch`) `[VERIFIED: NSURLRequest.h]` |
| ComposableArchitecture | pinned `from: 1.26` w/ deprecation traits (Phase 4) | Reducer flow, presented destination, typed effects | Project standard; login already a `@Reducer` `[VERIFIED: codebase grep]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| HapticsClient | in-repo | Challenge-surface + failure haptics | Reuse existing `.haptics(unwrapping:case:)` on the destination and the error-notification haptic (D-11) |
| CookieClient | in-repo | `setCredentials`/`didLogin` post-success (unchanged) | C4 downstream; do NOT route `cf_clearance` through it (D-04) |
| SystemNotification (`.toast`) + AppComponents (`ErrorInfoView`, `AppAlertState`) | in-repo | D-11 failure surface | On exhausted retries only |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `WKHTTPCookieStoreObserver` | Timer polling `getAllCookies` | Observer is event-driven, SDK-sanctioned, and fires on the exact mutation; polling adds latency + a timer to tear down. Recommend the observer. `[VERIFIED: SDK]` |
| Dedicated challenge webview wrapper | Extending `WebView.swift` | `WebView.swift`'s coordinator is hardwired to the web-login `code=01` query-item detection and pushes cookies into `HTTPCookieStorage.shared` (forbidden by D-04). A parallel wrapper avoids overloading it and keeps D-04's "never touch the shared jar" invariant clean. Recommend a dedicated wrapper. |
| New `LoginRequest` variant carrying headers | Mutating shared `LoginRequest` | A separate initializer / optional `(clearance, userAgent)` parameter preserves the existing no-clearance path (the no-wall case, C2) unchanged. |

**Installation:** No new packages. All capabilities are first-party frameworks already linked. `npm/pip/cargo` verification is N/A (Swift, no dependency added).

## Package Legitimacy Audit

Not applicable — this phase installs **no external packages**. Every capability (WebKit, Foundation, ComposableArchitecture) is already a linked dependency. No `Package.swift` change is anticipated.

## Architecture Patterns

### System Architecture Diagram

```
LoginView (chevron→spinner while loginState==.loading, D-03)
   │ store.send(.login)
   ▼
LoginReducer.login ──> LoginRequest.response()  [NetworkingFeature]
   │                        │ POST forums…?act=Login via fetch (4-attempt transport retry)
   │                        ▼
   │                 (data, HTTPURLResponse)
   │                        │
   │              ┌─────────┴──────────── classifyChallenge(response) [D-05 generic helper]
   │              │                          403 && cf-mitigated:challenge ?
   │        NO (no-wall, C2)              YES
   │              │                          │
   │              ▼                          ▼
   │   loginDone(.success)      LoginReducer presents Challenge Surface (D-01)
   │   → setCredentials/didLogin      │  Destination.challenge(URL)  (sheet, .privacyMask, haptics)
   │   → dismiss                      ▼
   │                          ChallengeWebView (UIViewControllerRepresentable)
   │                          WKWebView loads challenged URL
   │                          WKHTTPCookieStoreObserver.cookiesDidChangeInCookieStore
   │                                   │ cf_clearance appears?
   │                                   ▼ YES → read navigator.userAgent (evaluateJavaScript)
   │                          send(.clearanceCaptured(clearance, userAgent))
   │                                   │ auto-dismiss surface (C3)
   │                                   ▼
   │              hold (clearance, UA) in session state (D-06)
   │                                   │ presentations < 2 ? (D-09)
   │                                   ▼
   │              LoginRequest(clearance:, userAgent:).response()
   │                 explicit Cookie + User-Agent headers, httpShouldHandleCookies=false (D-04)
   │                                   │
   │                    ┌──────────────┴─────────────┐
   │            challenged again?                 not challenged
   │            present once more (round 2)      loginDone(.success)
   │            then 3rd challenge → fail          → setCredentials/didLogin/dismiss
   │                                   ▼
   │              throw AppError.cloudflareChallengeFailed (D-10)
   │              → persistent tappable toast → ErrorInfoView (D-11)
   ▼
(cancel mid-challenge → loginState=.idle, silent, no retry) (D-02)
```

### Component Responsibilities
| Component | File (existing or new) | Responsibility |
|-----------|------------------------|----------------|
| Challenge classifier | `NetworkingFeature/Request.swift` (new helper) | Pure `(HTTPURLResponse?) -> Bool` (or richer enum): 403 + `cf-mitigated == "challenge"` |
| `LoginRequest` surfacing | `NetworkingFeature/Request+Account.swift` (edit) | Return response headers/status for classification; add a clearance-carrying variant |
| Challenge webview wrapper | new file in `SettingFeature/Components/` | `UIViewControllerRepresentable` + `WKHTTPCookieStoreObserver`; reports `(clearance, UA)` |
| Login flow orchestration | `LoginReducer.swift` (edit) or new `Feature`-suffixed child | New destination case, clearance-captured action, bounded-retry counter, session holder |
| Session holder | in-memory `@Shared(.inMemory)` (Phase 7 precedent) OR reducer state | Hold `(clearance, UA)` for app session (D-06) |
| New error case | `AppModels/Support/AppError.swift` (edit) + `.xcstrings` | `cloudflareChallengeFailed` + description + `recoverySuggestion` |

### Pattern 1: Response-driven challenge classification (D-05)
**What:** A generic helper classifying any `(data, response)` as challenged, wired only to login this phase.
**When to use:** After `fetch` returns (a 403 is a *successful transport response*, so it is returned immediately, not retried by the 4-attempt loop).
**Example:**
```swift
// Source: Cloudflare docs — cf-mitigated header [CITED: developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response]
// NetworkingFeature — generic, per-response (C2, D-05)
public func isCloudflareChallenge(_ response: URLResponse?) -> Bool {
    guard let http = response as? HTTPURLResponse, http.statusCode == 403 else { return false }
    // Header names are case-insensitive; value(forHTTPHeaderField:) is case-insensitive on iOS 13+.
    let mitigated = http.value(forHTTPHeaderField: "cf-mitigated")
    return mitigated?.caseInsensitiveCompare("challenge") == .orderedSame
}
```

### Pattern 2: Observe `cf_clearance` in the web view's own cookie store (C3)
**What:** Register a `WKHTTPCookieStoreObserver` on the challenge web view's `WKWebsiteDataStore.httpCookieStore`; on each change, query for `cf_clearance`.
**When to use:** For the auto-dismiss trigger — covers both the interactive wall and a zero-interaction auto-pass.
**Example:**
```swift
// Source: iPhoneOS26.5 SDK WKHTTPCookieStore.h [VERIFIED: SDK header]
// Observer is NOT retained by the store — unregister before it invalidates.
final class ChallengeCookieObserver: NSObject, WKHTTPCookieStoreObserver {
    // All WKHTTPCookieStore ops + callbacks are main-thread (WK_SWIFT_UI_ACTOR).
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { cookies in
            guard let clearance = cookies.first(where: { $0.name == "cf_clearance" && !$0.value.isEmpty })
            else { return }
            // Read the exact effective UA of THIS web view (Cloudflare binds clearance to it).
            self.webView.evaluateJavaScript("navigator.userAgent") { value, _ in
                let userAgent = value as? String
                self.onClearance(clearance.value, userAgent) // → reducer action
            }
        }
    }
}
// Register: cookieStore.add(observer)   Unregister: cookieStore.remove(observer)
// Swift method name maps to ObjC cookiesDidChangeInCookieStore:.
```
Note: the SDK declares `cookiesDidChangeInCookieStore(_:)`; the Swift-imported selector is `cookiesDidChange(in:)`. Verify the exact Swift signature at implementation time in Xcode.

### Pattern 3: Authoritative explicit headers on the retried POST (D-04, C4)
**What:** Attach `cf_clearance` and the captured UA as explicit headers and disable shared-jar cookie handling so the header is authoritative.
**Example:**
```swift
// Source: NSURLRequest.h — HTTPShouldHandleCookies default YES [VERIFIED: SDK header]
var request = URLRequest(url: Defaults.URL.login)
request.httpMethod = "POST"
request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
request.setURLEncodedContentType()
// D-04: keep cf_clearance out of HTTPCookieStorage.shared; make the explicit Cookie header authoritative.
request.httpShouldHandleCookies = false           // stop the shared jar injecting/overwriting
request.setValue("cf_clearance=\(clearance)", forHTTPHeaderField: "Cookie")
request.setValue(userAgent, forHTTPHeaderField: "User-Agent") // exact challenge-webview UA (C4)
```
Caveat: with `httpShouldHandleCookies = false`, the existing login cookies the shared jar would normally attach are **not** sent. For the login POST this is correct (login establishes credentials from the response, not from sent cookies), but confirm no other cookie (e.g. an existing session) is required on this specific POST. The response's `Set-Cookie` still flows to `setCredentials` via the returned `HTTPURLResponse` (C4), independent of `httpShouldHandleCookies`.

### Anti-Patterns to Avoid
- **Host-assuming detection.** Do not branch on hostname or `bypassSNIFiltering`. Detection is per-response only (C2, D-08). `e-hentai.org`/`exhentai.org` currently pass unchallenged; that can change — stay response-driven.
- **Writing `cf_clearance` into `HTTPCookieStorage.shared`.** Violates D-04 and criterion 5's "in memory only". The existing `WebView.swift` does exactly this for the web-login flow — do NOT copy that behavior into the challenge wrapper.
- **View-side lifecycle for the challenge surface.** `lifecycle_modifiers` is at error (Phase 11). No `.onAppear`/`.task` to drive the challenge; presentation-driven via reducer.
- **Retrying the challenged 403 inside `fetch`.** The 4-attempt loop retries transport failures only; a 403 returns immediately. Challenge rounds (D-09, max 2) are a distinct, reducer-level concept — do not conflate with the transport retry count.
- **Persisting the clearance.** No disk, no Keychain, no `UserDefaults`. Session-lifetime in-memory only (D-06). No expiry timer (C5).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detect cookie appearance in the web view | Timer polling loop | `WKHTTPCookieStoreObserver` | Event-driven, SDK-sanctioned, fires on the exact mutation `[VERIFIED: SDK]` |
| Read the web view's UA | Hardcode a UA string | `evaluateJavaScript("navigator.userAgent")` | Cloudflare binds clearance to the *exact* UA; a guessed string mismatches and re-challenges/blocks `[VERIFIED: cf_clearance research]` |
| Error surface for exhausted retries | Custom alert/inline text | Phase 9 `AppError` + `AppAlertState.error(_:)` toast + `ErrorInfoView` | Established path; D-11 mandates it |
| Cookie-header parsing after success | New parser | `CookieClient.setCredentials(response:)` (unchanged) | C4 keeps it identical |
| Challenge classification | Ad-hoc per-callsite check | One generic `NetworkingFeature` helper | D-05; reusable when the wall spreads |

**Key insight:** Nearly everything is already in the tree. The phase is a wiring exercise across three existing seams (request-layer classification, reducer-driven sheet, Phase 9 error surface) plus one genuinely new artifact — a cookie-observing WKWebView wrapper — and one new `AppError` case.

## Runtime State Inventory

Not a rename/refactor/migration phase — this adds a runtime flow. The relevant *live* state considerations:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `cf_clearance` must NOT be stored (D-04, C5). Existing login cookies (`ipb_member_id`, `ipb_pass_hash`, `igneous`) continue via `setCredentials` unchanged. | Code: ensure clearance stays in memory; no persistence added |
| Live service config | None — Cloudflare challenge is a live remote behavior, not app-managed config | None |
| OS-registered state | None | None — verified: no scheduler/daemon involvement |
| Secrets/env vars | None — no keys, no tokens beyond the transient in-memory clearance | None |
| Build artifacts | None | None |

**Session-lifetime holder (D-06):** the `(cf_clearance, UA)` pair persists across login attempts *within one app launch* and is dropped on relaunch. If implemented as `@Shared(.inMemory(...))` (Phase 7 privacy-mask precedent, `AppSharedKeys.swift`), it resets to nil each launch automatically — matching "never persisted across launches" with zero cleanup code.

## Common Pitfalls

### Pitfall 1: UA read from the wrong web view (or too late)
**What goes wrong:** Reading `navigator.userAgent` from a fresh/other WKWebView, or after the challenge web view is torn down, yields a UA that doesn't match the one that solved the challenge → retried POST re-challenged or blocked.
**Why it happens:** Cloudflare binds `cf_clearance` to the exact UA (+IP+TLS) of the solving client `[VERIFIED: cf_clearance research]`.
**How to avoid:** Read the UA from the **same** web view instance, inside the `cookiesDidChange` callback, *before* dismissing the surface. Capture `(clearance, UA)` atomically.
**Warning signs:** Login retry returns another 403 + `cf-mitigated` even though the wall visibly passed.

### Pitfall 2: WebView UA ≠ URLSession UA (TLS/JA3 mismatch)
**What goes wrong:** Even with the matching UA header, `URLSession`'s TLS fingerprint differs from WKWebView's, and Cloudflare's clearance is also TLS-bound `[VERIFIED: cf_clearance research]`. The retried POST may still be challenged.
**Why it happens:** The clearance was minted by WebKit's network stack; `URLSession` is a different client fingerprint on the same device.
**How to avoid:** This is the load-bearing risk for criterion 1. The design tolerates it via bounded retry (D-09) then a clean failure (D-10). But it means the **owner-driven live UAT (C1) is the authoritative proof** — plan must not assume automated tests can prove end-to-end success. If the live pass fails on TLS binding, an alternative (issuing the retried POST *through the web view* rather than `URLSession`) may be needed; flag as an Open Question for the planner to keep a fallback in scope.
**Warning signs:** Auto-pass + correct UA header, yet retry still challenged in device testing.

### Pitfall 3: Observer retained/leaked, or callback off main thread
**What goes wrong:** The store does not retain the observer (SDK note); if the wrapper doesn't hold it, callbacks stop. Conversely, failing to `removeObserver` before teardown risks a stale callback.
**How to avoid:** Wrapper owns the observer strongly; unregister in the controller's teardown. Keep all cookie-store work main-thread (`WK_SWIFT_UI_ACTOR`). `[VERIFIED: SDK]`
**Warning signs:** Clearance never triggers dismissal; or a crash/warning after the sheet closes.

### Pitfall 4: `httpShouldHandleCookies = false` drops a needed cookie
**What goes wrong:** Disabling shared-jar handling to make the explicit `Cookie` header authoritative also suppresses any other cookie the POST legitimately needs.
**How to avoid:** Confirm the login POST needs only `cf_clearance` on the way out (login credentials come back in `Set-Cookie`, not sent). If another cookie is needed, compose the full `Cookie` header explicitly rather than re-enabling the jar. `[VERIFIED: NSURLRequest.h]`
**Warning signs:** Retry fails differently (not a challenge) once `httpShouldHandleCookies` is disabled.

### Pitfall 5: Privacy-mask coverage regression
**What goes wrong:** The phase adds **two** new presentation roots — the challenge sheet and the error-info detail sheet — and Phase 7 reconciled privacy-mask coverage against a fixed count of explicit runtime roots. A new root without `.privacyMask()` is a content-leak gap.
**How to avoid:** Attach `.privacyMask()` to both new sheets exactly like the existing web-login sheet; update every derived count in the Phase 7 coverage reconciliation for the two new roots: 39 runtime roots → 41, 38 production modal roots → 40, 41 presentation modifiers → 43 (reconciled in plan 12-06).
**Warning signs:** App Switcher snapshot shows the challenge web view (or the error-info sheet) unmasked.

### Pitfall 6: Cancel semantics leak an error
**What goes wrong:** User-initiated dismissal mid-challenge fires the retry or an error toast.
**How to avoid:** D-02 — cancel returns `loginState` to `.idle`, cancels the in-flight login effect (`CancelID.login` already exists), no retry, no toast (silent). Only *exhausted retries* surface the error.
**Warning signs:** Swipe-down on the challenge sheet produces a failure toast.

## Code Examples

### Existing login effect (the seam to extend) — `LoginReducer.login`
```swift
// Source: AppPackage/Sources/SettingFeature/Login/LoginReducer.swift [VERIFIED: codebase]
case .login:
    guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
    state.focusedField = nil
    state.loginState = .loading
    return .merge(
        .run { _ in await hapticsClient.generateFeedback(.soft) },
        .run { [state] send in
            do throws(AppError) {
                let response = try await LoginRequest(
                    username: state.username, password: state.password
                ).response()
                await send(.loginDone(.success(response)))
            } catch { await send(.loginDone(.failure(error))) }
        }
        .cancellable(id: CancelID.login)   // <-- reuse for D-02 cancel
    )
```
The challenge branch inserts between `LoginRequest.response()` and `loginDone`: classify the response, and on challenge, send a `presentChallenge(URL)` action instead of `loginDone`.

### Existing challenge-shaped test harness — `CountingStubProtocol`
```swift
// Source: AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift [VERIFIED: codebase]
// Stub a 403 + cf-mitigated challenge, then a 200 on retry, to unit-test detection + bounded rounds:
let script = StubScript([
    Defaults.URL.login: [
        .http(status: 403, data: Data(), headers: ["cf-mitigated": "challenge"]),
        .http(status: 200, data: successHTML, headers: ["Set-Cookie": "ipb_member_id=123; ipb_pass_hash=abc"])
    ]
])
let (session, handle) = makeStubbedSession(script: script)
```
This harness already models per-URL step sequences with headers — ideal for testing classification, the no-wall pass-through (C2), and the 2-round bound (D-09) without a live host.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `forums.e-hentai.org` login served origin HTML directly | Fronted by Cloudflare; 403 + `cf-mitigated: challenge` on the login endpoint | Observed 2026-07-20 | Login POST must detect + clear the challenge; the old direct-response assumption is dead |
| Detect challenge by scraping page HTML/markers | `cf-mitigated: challenge` response header (Cloudflare's sanctioned signal) | Cloudflare-documented | Reliable, content-type-independent detection `[CITED: Cloudflare docs]` |

**Deprecated/outdated:**
- Host-assumed challenge handling: obsolete — detection must be per-response (C2).
- Reading UA via `value(forKey: "userAgent")` (private-ish KVC): prefer `evaluateJavaScript("navigator.userAgent")` for the effective UA `[CITED: Apple docs]`.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The login POST needs only `cf_clearance` as an outbound cookie; disabling `httpShouldHandleCookies` won't drop a required cookie | Pattern 3 / Pitfall 4 | Retry fails for a non-challenge reason; planner must verify what cookies the POST currently sends |
| A2 | `URLSession`'s TLS/JA3 fingerprint is close enough to WKWebView's that a UA+clearance-matched retry passes Cloudflare | Pitfall 2 | Criterion 1 (live login) fails on TLS binding; fallback = issue retry through the web view. Owner UAT is the authoritative gate |
| A3 | `cf_clearance` is issued into the challenge web view's `WKWebsiteDataStore.httpCookieStore` (default, non-persistent enough) and observable there | Pattern 2 | If issued to a data store the observer doesn't watch, auto-dismiss never fires; verify the web view uses the default data store |
| A4 | The challenged URL to load in the web view is the login URL itself (`Defaults.URL.login` / `forum?act=Login`) | Diagram | Wrong URL loads a non-challenged page; the challenge is on the login endpoint per the 2026-07-20 evidence — low risk |
| A5 | Cloudflare clearance validity (30–60 min typical) exceeds a single login attempt's duration | cf_clearance research | If it expires between capture and retry, the re-challenge path (D-06/D-09) handles it — low risk |
| A6 | Swift-imported selector for the observer is `cookiesDidChange(in:)` (ObjC `cookiesDidChangeInCookieStore:`) | Pattern 2 | Compile-time mismatch only; verified against SDK header, confirm exact Swift signature in Xcode |

## Open Questions (RESOLVED)

All three questions were resolved during planning; the plans record the choices.

1. **TLS-fingerprint binding of `cf_clearance` (the load-bearing risk).**
   - What we know: clearance is bound to UA + IP + TLS/JA3; we can match UA and (same device) IP, but `URLSession` ≠ WKWebView TLS stack.
   - What's unclear: whether e-hentai's Cloudflare config enforces TLS binding strictly enough to reject a UA-matched `URLSession` retry.
   - Recommendation: plan the primary design (URLSession retry with UA+clearance headers) but keep a **fallback in scope** — replaying the POST through the challenge web view (`WKWebView` load of a POST, or `URLSession` bound to the web view's `WKWebsiteDataStore` cookies). Treat the owner-driven live UAT (C1) as the go/no-go gate, per the Validation Architecture section.
   - **RESOLVED (12-02/12-04/12-06):** Plans build the primary `URLSession` design (retried POST with explicit clearance + exact-UA headers). The blocking owner live-login UAT (12-06 Task 2) is the go/no-go gate; the web-view-replay fallback is pre-identified for gap closure (12-06 threat T-12-25 and the step-5 repeated-challenge signal in the checkpoint), not built speculatively.

2. **Session holder location (Claude's discretion, D-06).**
   - What we know: `@Shared(.inMemory)` (Phase 7), injected client (Phase 8), or reducer state are all viable and within the no-singletons rule.
   - Recommendation: `@Shared(.inMemory("cloudflareClearance"))` mirrors the privacy-mask precedent, auto-resets per launch (satisfies "never persisted"), and is readable by a retried-request builder without threading state through. Planner picks; note the no-singletons and lint constraints.
   - **RESOLVED (12-01):** `@Shared(.inMemory("cloudflareClearance"))` — an `InMemoryKey<CloudflareClearance?>` declared in AppModels (`AppSharedKeys.swift`), following the Phase 7 precedent; resets to nil on every launch with zero cleanup code.

3. **Reducer decomposition (Claude's discretion).**
   - Recommendation: given the bounded-retry counter + destination + clearance action, a small `Feature`-suffixed child (e.g. `CloudflareChallengeFeature`) keeps `LoginReducer` focused, but folding in is acceptable given the modest surface. Either satisfies the `Feature`-suffix rule.
   - **RESOLVED (12-04):** Folded into `LoginReducer` — no new child reducer. The surface (one destination case pair, one counter, four actions) does not justify separate composition; the `Feature`-suffix rule applies only to new reducers, and none is created.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WebKit framework | Challenge surface + cookie observation | ✓ | iPhoneOS26.5 SDK (Xcode 26.6) | — |
| Foundation URLSession/URLRequest | POST + headers | ✓ | iOS SDK | — |
| ComposableArchitecture | Reducer flow | ✓ | pinned (Phase 4) | — |
| Live Cloudflare-fronted host (`forums.e-hentai.org`) + real credentials | Criterion 1 end-to-end UAT | ✓ (network) | live | Owner-driven device gate; no automated substitute |

**Missing dependencies with no fallback:** None. Criterion 1's end-to-end pass depends on live Cloudflare behavior + real credentials, which only the owner can exercise — this is a UAT gate, not a missing build dependency.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`/`@Suite`) + TCA `TestStore` |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` |
| Quick run command | `xcodebuild test -scheme EhPanda -only-testing:NetworkingFeatureTests/<Suite> -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone 16'` (565-test suite, parallel across 18 targets post-Phase 11) |

### Phase Requirements → Test Map
| Criterion | Behavior | Test Type | Automated Command | File Exists? |
|-----------|----------|-----------|-------------------|-------------|
| C2 | 403 + `cf-mitigated:challenge` classified as challenge; other responses not | unit | `NetworkingFeatureTests` challenge-classifier suite via `CountingStubProtocol` | ❌ Wave 0 |
| C2 | No-wall response proceeds to `loginDone` with no surface | reducer | `SettingFeatureTests` `LoginReducer` `TestStore` | ❌ Wave 0 |
| C3 | Clearance appearance → captured action → surface auto-dismiss | reducer | `TestStore` drives `.clearanceCaptured` → destination nil | ❌ Wave 0 |
| C4 | Retried POST carries `Cookie: cf_clearance` + `User-Agent` header | unit | `CountingStubProtocol` `receivedRequests` header assertion | ❌ Wave 0 |
| C5 | 3rd challenge → `cloudflareChallengeFailed` toast; clearance not persisted | reducer | `TestStore` two-round then fail; assert error toast state | ❌ Wave 0 |
| C1 | Live end-to-end login through the real wall | manual (owner UAT) | device/simulator against live host + real creds | N/A — owner gate |
| D-02 | Cancel mid-challenge → `.idle`, silent | reducer | `TestStore` dismiss action asserts no retry/toast | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** targeted `NetworkingFeatureTests` / `SettingFeatureTests` suite for the touched behavior.
- **Per wave merge:** both affected targets green.
- **Phase gate:** full suite green + owner-signed live UAT (C1) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` — covers C2, C4 (header on retry) via `CountingStubProtocol`
- [ ] `SettingFeatureTests/LoginChallengeFlowTests.swift` — covers C2 pass-through, C3 auto-dismiss, C5 bounded-fail, D-02 cancel via `TestStore`
- [ ] Note: the observer/webview UA readout is not unit-testable through `TestStore` (WebKit UI); isolate it behind an injectable seam so the reducer receives `(clearance, UA)` as a plain action — the reducer half is then fully testable, and the WebKit half rides the owner UAT.

## Security Domain

`security_enforcement` is enabled (config), ASVS level 1.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Login credentials handled by existing `LoginRequest`/`CookieClient`; unchanged (C4). No new credential storage. |
| V3 Session Management | yes | `cf_clearance` is a transient anti-bot token, held in memory only, never persisted (D-04/C5). Existing session cookies unchanged. |
| V4 Access Control | no | No authz surface changes |
| V5 Input Validation | yes | Response header parsing (`cf-mitigated`) — treat as untrusted input; exact-match the value, do not eval page content. Challenge URL loaded is the app's own login URL, not attacker-supplied. |
| V6 Cryptography | no | No crypto; do not hand-roll anything TLS-related — rely on WebKit/URLSession |
| V7 Error Handling & Logging | yes | New `AppError` case must not log `cf_clearance` value (Phase 8 cookie-privacy gate applies: no cookie value at `.public` log privacy — the static gate covers `cf_clearance` too, per canonical refs) |

### Known Threat Patterns for iOS WKWebView + networking
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `cf_clearance` leaked to disk/logs | Information Disclosure | In-memory only (D-04); no `.public` log of cookie values (Phase 8 gate) |
| Malicious page in challenge web view exfiltrates credentials | Tampering / Info Disclosure | Load only the app's own login URL; no credential injection into the web view; the web view solves the challenge, it does not receive username/password |
| Clearance reuse across UA/IP mismatch → block | Denial of Service (self-inflicted) | Capture + send the exact web-view UA (C4); bounded retry then clean failure (D-09/D-10) |
| Shared-jar cookie confusion | Tampering | `httpShouldHandleCookies = false` + explicit authoritative header (D-04) |

## Sources

### Primary (HIGH confidence)
- iPhoneOS26.5 SDK `WebKit.framework/Headers/WKHTTPCookieStore.h` — `WKHTTPCookieStoreObserver` protocol, `cookiesDidChangeInCookieStore:`, `addObserver:`/`removeObserver:` (observer not retained), main-thread actor annotation `[VERIFIED]`
- iPhoneOS26.5 SDK `Foundation.framework/Headers/NSURLRequest.h` — `HTTPShouldHandleCookies` default YES semantics `[VERIFIED]`
- Codebase: `LoginReducer.swift`, `LoginView.swift`, `WebView.swift`, `Request.swift`, `Request+Account.swift`, `CookieClient.swift`, `AppError.swift`, `CountingStubProtocol.swift` `[VERIFIED: read this session]`

### Secondary (MEDIUM confidence)
- Cloudflare docs — Detect a Challenge Page response (`cf-mitigated: challenge`) [CITED: developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response]
- Cloudflare Challenges — clearance concepts (`cf_clearance` UA/IP/TLS binding, Challenge Passage validity) [CITED: developers.cloudflare.com/cloudflare-challenges/concepts/clearance]
- Apple docs / forums — `WKWebView.customUserAgent`, reading `navigator.userAgent` via `evaluateJavaScript` [CITED: developer.apple.com/documentation/webkit/wkwebview/customuseragent]

### Tertiary (LOW confidence)
- Community write-ups on `cf_clearance` fingerprint binding and re-challenge loops (corroborate the TLS/UA/IP binding claim; treated as directional, cross-checked against Cloudflare's own clearance docs)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all first-party, SDK-verified; no packages added
- Architecture: HIGH — every seam confirmed in the codebase this session
- Challenge/cookie semantics: MEDIUM — Cloudflare docs confirm the `cf-mitigated` header and UA binding; exact TLS-binding strictness for this host is unverified (Open Question 1 — resolved by disposition: owner live UAT is the go/no-go gate, fallback pre-identified for gap closure)
- Pitfalls: HIGH for codebase-derived (privacy-mask root, cancel, observer lifetime); MEDIUM for the TLS-fingerprint risk

**Research date:** 2026-07-22
**Valid until:** 2026-08-21 for SDK/codebase facts; ~2026-07-29 for Cloudflare behavior (anti-bot systems change fast — re-confirm the live 403 + header before UAT)
