# Phase 12: Cloudflare Login Restoration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 12-cloudflare-login-restoration
**Areas discussed:** Challenge surface UX, Clearance scope, Domain-fronting policy, Retry & failure

---

## Challenge surface UX

### Q1 — When does the WKWebView surface appear after a challenged login POST?

| Option | Description | Selected |
|--------|-------------|----------|
| Present immediately (Recommended) | Sheet appears the moment the challenge is detected; auto-pass walls show briefly (~1–2s) then self-dismiss; interactive walls ready with zero delay | ✓ |
| Invisible attempt first | Off-screen web view with ~2–3s grace window; present only if cf_clearance hasn't appeared | |

**User's choice:** Present immediately

### Q2 — Sheet chrome and mid-challenge dismissal

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel button + abort (Recommended) | Cancellation-role toolbar button at the stable cancellationAction placement (Phase 5 convention) plus swipe-down; dismissal cancels the attempt, loginState returns to idle | ✓ |
| Bare sheet, swipe-only | Reuse the bare WebView sheet as web login presents today; swipe-down is the only escape | |
| Non-dismissable until solved | interactiveDismissDisabled + no cancel; user must solve or wait | |

**User's choice:** Cancel button + abort

### Q3 — Login screen state during the challenge and replayed POST

| Option | Description | Selected |
|--------|-------------|----------|
| Stay in .loading (Recommended) | Existing loginState = .loading spinner covers the whole detect → solve → retry span; no new states or strings | ✓ |
| Explain the wall | Distinct state/caption (e.g. "Passing Cloudflare check…") with new localized keys | |

**User's choice:** Stay in .loading
**Notes:** Owner added: make the login button's chevron icon a spinner when processing — the existing ProgressView-overlay treatment (chevron cleared, spinner shown) extended across the whole flow.

---

## Clearance scope

### Q1 — Where the captured cf_clearance lives and how the retried POST carries it

| Option | Description | Selected |
|--------|-------------|----------|
| Flow-scoped value (Recommended) | Plain value in the login flow's state; attached explicitly (Cookie + User-Agent headers) to the retried POST only; never enters HTTPCookieStorage.shared | ✓ |
| Session-only shared cookie | Stored via CookieClient as sessionOnly (discard=TRUE) for forums.e-hentai.org; attached automatically | |
| Ephemeral URLSession | Dedicated .ephemeral URLSession with its own isolated cookie jar | |

**User's choice:** Flow-scoped value

### Q2 — Detection seam breadth

| Option | Description | Selected |
|--------|-------------|----------|
| Generic detect, login-only wiring (Recommended) | NetworkingFeature helper classifies any response as challenged (403 + cf-mitigated); only login wires it to the clearance UI this phase | ✓ |
| Strictly login-local | Detection lives inside the login request/reducer only | |

**User's choice:** Generic detect, login-only wiring

### Q3 — Clearance lifetime after the flow concludes

| Option | Description | Selected |
|--------|-------------|----------|
| Discard with the flow (Recommended) | Clearance dies when the login attempt ends; a later login re-runs the challenge | |
| Keep for the app session | Retain in memory (never persisted) so a repeat login in the same session skips the wall | ✓ |

**User's choice:** Keep for the app session
**Notes:** Consequences captured: the holder stores the (cf_clearance, User-Agent) pair (UA-bound); later login POSTs proactively attach the held pair; an expired clearance re-challenges and replaces it. Criterion 4's UA scope (retried POST only, not general traffic) was treated as locked by ROADMAP and not re-asked.

---

## Domain-fronting policy

### Q1 — Challenge-flow behavior when "bypass SNI filtering" is enabled

| Option | Description | Selected |
|--------|-------------|----------|
| Response-driven, no special-case (Recommended) | No DF coupling; the flow reacts only to an actual 403 + cf-mitigated, which the direct-to-origin DF path realistically never produces | ✓ |
| Block challenge UI under DF | Mirror the web-login precedent: fail immediately with a structured error if challenged under DF | |
| Exempt login from DF | Route login POST + retry around DFURLProtocol via normal DNS/TLS | |

**User's choice:** Response-driven, no special-case
**Notes:** Evidence surfaced during discussion: DFURLProtocol sends the login POST to hardcoded origin IP 94.100.18.243 (not a Cloudflare edge), and the web-login toolbar button is already `.disabled(setting.bypassSNIFiltering)`.

---

## Retry & failure

### Q1 — Challenge-surface presentations per login attempt before failing

| Option | Description | Selected |
|--------|-------------|----------|
| 2 presentations (Recommended) | Wall → solve → retry; if re-challenged, present once more; a third challenge fails the attempt | ✓ |
| 3 presentations | One more round of tolerance before failing | |

**User's choice:** 2 presentations

### Q2 — AppError shape on exhausted retries

| Option | Description | Selected |
|--------|-------------|----------|
| New dedicated case (Recommended) | e.g. AppError.cloudflareChallengeFailed with its own localized description + recoverySuggestion pointing at web login / manual cookies | ✓ |
| Existing case + context | Reuse authenticationRequired/networkingFailed with ErrorInfo context rows only | |

**User's choice:** New dedicated case

### Q3 — Failure presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 9 toast → ErrorInfoView (Recommended) | Persistent tappable failure toast opening the ErrorInfoView detail surface; error haptic kept; user-cancelled challenges stay silent | ✓ |
| Toast + inline hint | Same toast path plus an inline error caption on the login form | |

**User's choice:** Phase 9 toast → ErrorInfoView

---

## Claude's Discretion

- Cookie-store observation mechanism (WKHTTPCookieStoreObserver vs. polling) and UA readout.
- Whether the challenge surface reuses/extends WebView.swift or gets a dedicated wrapper.
- Placement of the session-lifetime (clearance, UA) holder (in-memory @Shared vs. injected client vs. parent-reducer state), within the no-singletons rule.
- Reducer decomposition (child Feature vs. folded into LoginReducer).
- ErrorInfo context rows for the new error case.
- Suppressing shared-jar cookie interference on the retried POST so the explicit Cookie header is authoritative.

## Deferred Ideas

None — discussion stayed within phase scope. (Wiring the generic challenge detector to non-login requests is future work enabled by the detection decision, not part of this phase.)
