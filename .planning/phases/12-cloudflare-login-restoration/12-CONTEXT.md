# Phase 12: Cloudflare Login Restoration - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Restore the broken username/password login: detect the Cloudflare challenge on the login
POST (an HTTP 403 carrying `cf-mitigated: challenge`), clear it through an in-app
`WKWebView` the user can interact with, capture `cf_clearance` **in memory only**, and
replay the login POST carrying the clearance plus the challenge-solving web view's exact
User-Agent. The other two login methods — in-app web login and manual cookie entry — stay
unchanged.

Scope anchor is **ROADMAP.md §Phase 12's five success criteria** (detection is
response-driven, not host-assumed; the surface auto-dismisses the moment `cf_clearance`
appears, covering interactive and zero-interaction walls; the retry carries clearance + UA
and then flows into the unchanged `setCredentials`/`didLogin` handling; the clearance is
never persisted across launches; expiration needs no timer — a re-challenged retry
re-presents the surface within bounded retries, then fails through the structured
`AppError` surface).

Live evidence (2026-07-20): GET and POST on `forums.e-hentai.org/index.php?act=Login`
both return 403 + `cf-mitigated: challenge`; `e-hentai.org`/`exhentai.org` currently pass
unchallenged (though `server: cloudflare`).

</domain>

<decisions>
## Implementation Decisions

### Challenge surface UX
- **D-01:** The `WKWebView` challenge sheet **presents immediately** when a challenge is
  detected — no hidden/invisible pre-attempt. Auto-pass walls show briefly (~1–2s) and
  self-dismiss the moment `cf_clearance` lands; interactive walls are ready with zero
  delay. Reuses LoginView's existing sheet-presentation pattern.
- **D-02:** The sheet carries a **cancellation-role toolbar button at the stable
  `cancellationAction` placement** (the Phase 5 reusable-sheet convention), in addition to
  swipe-down. Dismissing mid-challenge **aborts the login attempt**: `loginState` returns
  to `.idle`, no retry fires, and no error toast presents (user-initiated cancel is
  silent).
- **D-03:** No new explanatory states or strings on the login form: `loginState =
  .loading` spans the entire detect → solve → retry flow. The login button's chevron
  reads as a **spinner for the whole processing span** — the existing
  `ProgressView`-overlay treatment (chevron cleared, spinner shown) extended across the
  challenge flow. The exact swap mechanism (overlay vs. content swap) is planner detail.

### Clearance handling & scope
- **D-04:** `cf_clearance` is carried as a **flow-scoped value**: held as plain state and
  attached explicitly (Cookie header + User-Agent header) to the retried login POST. It
  **never enters `HTTPCookieStorage.shared`** — the most literal reading of criterion 5's
  "in memory only", with zero cleanup and the smallest blast radius.
- **D-05:** Challenge detection is a **generic NetworkingFeature helper** — classify any
  `(data, response)` as challenged via 403 + `cf-mitigated: challenge` — but **only the
  login flow wires it to the clearance UI this phase**. If the wall ever spreads to the
  gallery hosts, detection is ready and only presentation needs wiring.
- **D-06:** The captured **(cf_clearance, User-Agent) pair is kept in memory for the app
  session** (they travel together — Cloudflare binds the clearance to the UA). A later
  login POST in the same session **proactively attaches the held pair**, so an unexpired
  clearance skips the wall entirely; an expired one comes back challenged and the normal
  flow re-runs and **replaces** the pair. Never persisted across launches; no expiry
  timer (criterion 5).
- **D-07:** Locked by ROADMAP criterion 4 (not re-discussed): the web view's exact UA
  applies to the **retried login POST only** — general app traffic keeps its User-Agent
  unchanged.

### Domain-fronting policy
- **D-08:** The challenge flow is **purely response-driven with zero DF conditionals**.
  Under "bypass SNI filtering", `DFURLProtocol` sends the login POST directly to the
  hardcoded origin IP (not a Cloudflare edge), so a challenge response realistically
  never arrives — DF login either keeps working (origin accepts direct connections) or
  fails as `networkingFailed` exactly as today. If a challenge ever *did* arrive under
  DF, the sheet presents normally (the webview uses normal DNS/TLS) and the bounded
  retry/failure path covers a webview that can't get through. No exemption of the login
  POST from DF, no DF-gated blocking of the challenge UI.

### Retry bounds & failure surface
- **D-09:** **At most 2 challenge-surface presentations per login attempt.** Wall →
  solve → retry; if the retry is re-challenged, present once more → solve → retry; a
  third challenge fails the attempt. (Criterion 5's bounded retries, pinned to 2.)
- **D-10:** Exhausted retries throw a **new dedicated `AppError` case** (e.g.
  `cloudflareChallengeFailed`) with its own localized description and
  `recoverySuggestion` pointing the user at the working alternatives (in-app web login /
  manual cookie entry). Phase 9's "keep the case set" decision governed *replacement*,
  not growth; this is a genuinely new, user-actionable failure kind. New `.xcstrings`
  keys follow the labeled-format-argument and non-translated-key conventions (AGENTS.md).
- **D-11:** The failure presents through the **Phase 9 standard path**: persistent
  tappable failure toast → `ErrorInfoView` detail surface (Description / Suggested
  Solution / Context). The existing error notification haptic is kept. LoginView gains no
  inline error text.

### Claude's Discretion
- The mechanism for observing `cf_clearance` appearing in the web view's cookie store
  (`WKHTTPCookieStoreObserver` vs. polling), and how the web view's exact UA string is
  read out.
- Whether the challenge surface reuses/extends `WebView.swift` or gets a dedicated
  wrapper (it needs cookie-store observation + UA readout that the web-login wrapper
  lacks).
- Where the session-lifetime (clearance, UA) holder lives (in-memory `@Shared` state à la
  the Phase 7 privacy-mask precedent, an injected client, or parent-reducer state) —
  within the Phase 8 no-singletons rule.
- Reducer decomposition: whether the challenge flow is a child feature (new reducers
  carry the `Feature` suffix per repo convention) or folded into `LoginReducer`.
- `ErrorInfo` context rows carried by the new error case (attempt count, host, …) — per
  Phase 9 D-06 this is a planning detail.
- How the retried POST suppresses shared-jar cookie interference (e.g.
  `httpShouldHandleCookies`) so the explicit Cookie header is authoritative — research
  detail within D-04.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Authoritative scope
- `.planning/ROADMAP.md` §"Phase 12: Cloudflare Login Restoration" — the 5 success
  criteria (the scope contract) + the 2026-07-20 live evidence note.

### Login flow (the surfaces this phase changes)
- `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` — the reducer owning the
  username/password flow: `Destination.webView` sheet, `login`/`loginDone`,
  `setCredentials` call, `didLogin` check, dismiss-on-success.
- `AppPackage/Sources/SettingFeature/Login/LoginView.swift` — the login form, the
  chevron/ProgressView button treatment (D-03), the existing `.sheet` + `.privacyMask()`
  presentation pattern, and the web-login toolbar button already
  `.disabled(setting.bypassSNIFiltering)`.
- `AppPackage/Sources/SettingFeature/Components/WebView.swift` — the existing
  `WKWebView` wrapper (web-login cookie harvesting precedent; lacks cookie-store
  observation and UA readout).
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` — `LoginRequest` (the
  POST to `Defaults.URL.login`; returns `HTTPURLResponse?` that nothing status-checks
  today) and `IgneousRequest`.
- `AppPackage/Sources/NetworkingFeature/Request.swift` — the `Request` protocol,
  `fetch` (4-attempt policy), `mapAppError`; home of the D-05 generic detection helper.
- `AppPackage/Sources/AppTools/Defaults.swift` §URL — `forum`/`login`/`webLogin`
  constants.

### Cookie & error machinery (unchanged consumers)
- `AppPackage/Sources/CookieClient/CookieClient.swift` — `setCredentials(response:)`,
  `didLogin`; criterion 4 requires these proceed unchanged once a valid clearance gets
  the POST through. Also the Phase 8 cookie-privacy context: no cookie value at
  `.public` log privacy (the static gate applies to `cf_clearance` too).
- `AppPackage/Sources/AppModels/Support/AppError.swift` — the enum gaining the D-10
  case; description/`recoverySuggestion`/`ErrorInfo` context conventions from Phase 9.
- `.planning/phases/09-correctness-structured-error-handling/09-CONTEXT.md` — the
  error-surface conventions (toast → `ErrorInfoView`, per-site presentation at the
  owning reducer) that D-10/D-11 build on.

### Domain fronting (read, don't touch)
- `AppPackage/Sources/DFClient/DFClient.swift` — global `URLProtocol`
  registration when `bypassesSNIFiltering` is on.
- `AppPackage/Sources/NetworkingFeature/DFURLProtocol.swift` +
  `AppPackage/Sources/NetworkingFeature/DomainResolver.swift` — the interception path
  and the hardcoded `forums.e-hentai.org → 94.100.18.243` direct-origin IP that D-08's
  no-special-case reasoning rests on.

### Project rules that constrain this phase
- `CLAUDE.md` (repo root) — `Feature`-suffix reducer naming, SwiftLint-read-first +
  no-suppression rule, labeled localized-format arguments, non-translated keys filled
  for every locale, confirmation-dialog/alert placement.
- `.swiftlint.yml` (repo root) — all Phase 11 rules live at error; new code must be
  clean from the start (notably `lifecycle_modifiers` — challenge-surface lifecycle goes
  through reducers, `optional_try`, `single_line_trailing_closure`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LoginReducer.Destination` + sheet pattern** — the challenge surface slots in as a
  presented destination beside the existing `.webView(URL)` case; `.privacyMask()` and
  haptics wiring already demonstrated on the current sheet.
- **`WebView.swift`** — precedent for a `UIViewControllerRepresentable` WKWebView that
  harvests cookies; the challenge wrapper extends or parallels it with cookie-store
  observation + UA readout.
- **Phase 9 error machinery** — `AppError` description/solution structure,
  `ErrorInfoView`, persistent tappable failure toast: the D-10/D-11 failure surface is
  an extension, not new infrastructure.
- **`CookieClient.setCredentials` / `didLogin`** — the unchanged downstream of a
  successful retried POST (criterion 4).
- **Phase 7 in-memory `@Shared` precedent** (privacy-mask blur state) — a model for the
  D-06 session-lifetime clearance holder if shared state is chosen.

### Established Patterns
- **Response-driven behavior over host assumptions** — criterion 2 and D-08 both encode
  it; no per-host or per-setting conditionals in the challenge path.
- **Injected clients, no singletons (Phase 8)** — any new holder/observer is a
  dependency or reducer-owned state, never a global.
- **Typed `throws(AppError)` request layer (Phase 4)** — the login retry and the new
  failure case ride the existing typed-error shape; retry placement conventions
  (fetch-level 4-attempt policy is transport retries, distinct from D-09 challenge
  rounds).
- **Lint-as-error (Phase 11)** — no view-side `.onAppear`/`.task` for challenge
  lifecycle; presentation-driven lifecycle via reducers.

### Integration Points
- **`LoginRequest.response()`** returns `HTTPURLResponse?` that nothing inspects today —
  the D-05 detection helper hooks in at this seam (the request must also surface the
  response *data*/headers needed for classification).
- **`Request.fetch`'s 4-attempt transport retry** — a challenged 403 is a *successful*
  transport response; detection happens after fetch, not inside the retry loop.
- **New presentation root** — the challenge sheet adds a runtime presentation root;
  Phase 7's privacy-mask coverage reconciliation (39 explicit roots) must be updated to
  count it, and the sheet carries `.privacyMask()` like every other root.
- **UAT requires the live Cloudflare-fronted host** — criterion 1 is end-to-end against
  the real wall with real credentials; automated tests can cover detection
  classification, retry bounding, and state transitions, but the end-to-end pass is an
  owner-driven device/simulator gate (consistent with prior phases' owner-signed UAT).

</code_context>

<specifics>
## Specific Ideas

- **Chevron-to-spinner:** the owner explicitly wants the login button's chevron icon to
  read as a spinner while processing — the existing overlay treatment carried across the
  entire challenge span, not a new button design (D-03).
- **Fail toward the alternatives:** the dedicated error's suggested solution should
  steer the user to the two login methods that still work (in-app web login, manual
  cookie entry) rather than a generic "try again later" (D-10).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Wiring the generic challenge detector to
non-login requests, e.g. the gallery hosts, is explicitly future work enabled by D-05,
not part of this phase.)

</deferred>

---

*Phase: 12-Cloudflare Login Restoration*
*Context gathered: 2026-07-22*
