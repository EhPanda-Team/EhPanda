---
phase: 13
slug: deep-link-hardening-code-review-the-current-deep-link-implem
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-07-23
---

# Phase 13 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| External URL → parser | Arbitrary URLs from any app (`ehpanda://` scheme), web pages (share sheet), or clipboard cross into `GalleryURLParser.parse` | Untrusted URL strings (may carry userinfo, ports, query, fragment) |
| Other apps → `ehpanda://` scheme | Arbitrary payloads reach `handleDeepLink` in both cold- and warm-launch lifecycles | Untrusted URL |
| Safari share sheet → ShareExtension → app | Arbitrary web URLs are scheme-rewritten and handed off cross-process | Untrusted URL |
| Failure diagnostics → `ErrorInfoView`/`Context` | Untrusted URL content crosses into persisted, user-visible diagnostics | Access-bearing URL components (credentials, tokens, query secrets) |
| View layer → reducer | Sheet-dismissal-completion fact crosses from SwiftUI into reducer state | UI presentation timing |
| Launch environment → app process | Test-only env keys select DEBUG behavior; fixture dir supplies stub responses | Test configuration + stub payloads |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-13-01 | Spoofing | `GalleryURLParser.parse` host check; every migrated recognizer call site | high | mitigate | Exact case-insensitive membership test against a closed host set (`recognizedHosts.contains(host)`, `GalleryURLParser.swift:28-29,86-93`) — no substring matching survives. Spoof fixture `https://evil.com/g/123/token?ref=https://e-hentai.org/` asserted rejected (`GalleryURLParserTests.swift:83`). | closed |
| T-13-02 | Denial of Service | `GalleryURLParser.parse` / `handleDeepLink` on arbitrary input | medium | mitigate | Optional-returning parse with guard-only control flow; no force-unwraps, no unchecked subscripts (iterator-based path walk, `GalleryURLParser.swift:26-80`). Malformed-shape fixtures (`/g//token`, `/g/abc/token`, bare host, relative path) asserted `nil`; scheme-open malformed matrix proven no-crash end-to-end by `DeepLinkSchemeUITests`. | closed |
| T-13-03 | Information Disclosure | `Context.unsupportedLink` sanitized rendering; D-01 toast context | high | mitigate | `sanitizedUnsupportedLink` rebuilds a fresh `URLComponents` carrying only scheme + host + first path component (`AppError+Context.swift:83-110`) — userinfo, port, remaining path, query and fragment are structurally dropped, not filtered. `UnsupportedDeepLinkErrorTests` asserts the exact rendering, the exact key set `[.action, .reason, .link]`, and the absence of 11 forbidden secret values. No raw-URL `ContextKey` slot exists. | closed |
| T-13-04 | Elevation of Surface | UI-test stub seam in release builds | high | mitigate | Every seam body is `#if DEBUG`-gated: `UITestAutomation.shouldDetectClipboardURL` returns `false` and `prepareIfNeeded()` is a no-op in release; the whole `Configuration`/`resolve`/`prepare` surface and the entire `UITestStubURLProtocol` file sit inside `#if DEBUG`. Fixtures live in the UI-test bundle (`EhPandaUITests/Fixtures`), outside the app product. | closed |
| T-13-05 | Tampering | `ShareViewController` scheme rewrite; share-sheet hand-off integrity | medium | mitigate | Component-scoped mutation (`components.scheme = "ehpanda"` on a parsed `URLComponents`, `ShareViewController.swift:22-35`) replaces the former whole-string replacement; both the parse and the re-serialization are guarded, failing closed to `completeRequest`. `ShareSheetUITests` proves the real extension delivers the exact gallery route end-to-end. | closed |
| T-13-06 | Tampering | test fidelity (real parsing vs. stubs) | low | accept | Tests exercise real parsing instead of stubs — a behavior-visibility gain. Residual risk is fixture drift only, caught by the suite itself. See AR-01. | closed |
| T-13-07 | Denial of Service (UI race) | sheet re-present coordination; toast replacement | medium | mitigate | Completion-gated presentation: `isAwaitingDetailDismissal` + `pendingGalleryLink` in `PresentationFeature.State` (`PresentationFeature.swift:41-42`), with `detailDismissalCompleted` guarding on both flags before re-presenting (`:166-173`) and a documented last-writer-wins reset for a link arriving mid-dismissal (`:190-193`). Both orderings and the user-dismissal no-op are pinned by `PresentationFeatureTests`. Toast replacement is identity-keyed with a `.task(id:)` timer that restarts per id. | closed |
| T-13-08 | Tampering | fixture-dir content injection | low | accept | DEBUG-only, simulator-only, developer-machine test runs; unreachable in release (see T-13-04 gating). See AR-02. | closed |
| T-13-09 | Repudiation | flaky single-run UI-test evidence masking regressions | medium | mitigate | `-retry-tests-on-failure -test-iterations 3` present on every scripted UI-test invocation across plans 13-08, 13-09 and 13-10 (verified in each plan's `<automated>` gates and the recorded summary commands) — required because Xcode 26 ignores test-plan retry settings. Event-driven waits only; hermetic app-side marker-title assertions separate flake from failure. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-13-06 | Migrating call sites off stubs onto real parsing raises behavior visibility; the only residual exposure is test-fixture drift, which the suite itself detects. Low severity, no production surface. | Phase 13 plan 13-03 | 2026-07-23 |
| AR-02 | T-13-08 | The fixture directory is supplied via `launchEnvironment` on a developer-machine simulator run, behind a `#if DEBUG` seam that compiles out of release. An attacker able to set it already controls the build host. | Phase 13 plan 13-07 | 2026-07-23 |
| AR-03 | — | `ShareExtension/ShareViewController.swift:63-85` routes the extension→app hand-off through the private `LSApplicationWorkspace` API (`NSSelectorFromString` + `unsafeBitCast`). No public route exists on iOS 26.5 — all three candidates were measured dead. This build does not ship to the App Store, and `ShareSheetUITests` drives the real share sheet end-to-end so breakage is loud. Revisit if distribution intent changes or a sanctioned route appears. | Chihchy | 2026-07-23 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-07-23 | 9 | 9 | 0 | Claude (/gsd-secure-phase, ASVS L1) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-07-23
