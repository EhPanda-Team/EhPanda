# DEP-06 Evidence: DeprecatedAPI Removal Spike

**Requirement:** DEP-06 — remove `DeprecatedAPI` only if a warning-free, non-deprecated
replacement preserves every domain-fronting (DF) request semantic (D-14); otherwise document the
D-12/D-13 skip path without weakening domain fronting.

**Spike date:** 2026-07-10
**Status:** Resolved — the Task 2 human decision checkpoint selected `document-skip`.
**Selected Branch:** `document-skip` — `DeprecatedAPI` is deliberately retained (see Section 5).
**Scope of this document:** technical viability evidence plus the recorded branch decision. No
package was removed and no production DF source behavior was changed at any point.

---

## 1. What `DeprecatedAPI` actually is

`DeprecatedAPI` is a one-function shim:

```swift
public struct DeprecatedAPI {
    public static func getCFReadStream(_ alloc: CFAllocator?, _ request: CFHTTPMessage) -> Unmanaged<CFReadStream> {
        CFReadStreamCreateForHTTPRequest(alloc, request)
    }
}
```

It exists solely to move one deprecated CFNetwork call — `CFReadStreamCreateForHTTPRequest` — into a
separate module so the app target does not surface the SDK deprecation warning. The wrapper is not
"suspicious"; it is functionally obsolete. Removing the *package* is trivial; removing the
*deprecated call it hides* without regressing DF behavior is the hard part.

Consumed at exactly one call site: `AppPackage/Sources/NetworkingFeature/DFExtensions.swift`
(`InputStream.create(from:)`), which builds a `CFHTTPMessage`, sets header fields (including an
arbitrary `Host`), attaches the body, then calls `DeprecatedAPI.getCFReadStream` to obtain a
read stream that is scheduled on a run loop and drives `DFStreamEventHandler`.

## 2. The D-14 semantics that any replacement must preserve

Reconstructed from `DFRequest.swift`, `DFExtensions.swift`, `DFStreamHandler.swift`, and
`DFURLProtocol.swift`:

| # | Semantic | Where implemented | Why it matters for the SNI bypass |
|---|----------|-------------------|-----------------------------------|
| S1 | **Domain → IP host replacement** | `URLRequest.domainIPReplaced()` rewrites the URL host to a resolved IP from `DomainResolver`'s static pool. | The TCP/TLS connection targets an IP, so the TLS ClientHello carries no censored SNI hostname. This is the core of the bypass. |
| S2 | **Original `Host` header** | `domainIPReplaced()` injects `Host: <original-domain>` when absent; `InputStream.create` re-adds it to the CFHTTPMessage. | The server's virtual-host routing needs the real domain in the (encrypted) HTTP `Host` header even though the URL host is an IP. |
| S3 | **Cookies sourced from the original URL** | `DFRequest.init` reads `HTTPCookieStorage.shared.cookies(for: originalURL)` — before IP replacement — and sets them as request headers. | Cookies are keyed by domain; the IP URL matches nothing, so they must be looked up against the original domain. |
| S4 | **Arbitrary header + body preservation** | `InputStream.create` copies `allHTTPHeaderFields`; `URLRequest.HTTPBody()` materializes explicit and streamed POST bodies. | Search/login POST payloads and auth headers must reach the fronted origin unchanged. |
| S5 | **Custom trust against the original domain** | `stream.invalidatesCertChain(for:)` disables automatic CFStream chain validation; `DFStreamEventHandler.evaluate` re-validates with `SecPolicyCreateSSL(true, originalDomain)`. | The cert is valid for the domain, not the IP. Standard validation against the IP URL host would reject; validation must be pinned to the original domain. |
| S6 | **Redirect reconstruction + propagation** | `DFStreamEventHandler.endEncountered` reads `Location`, rebuilds site-root targets (`/`, `/popular`, `/watched`, `/?f_search`) against `domainWithScheme`, and propagates via the delegate → `URLProtocolClient`. | Redirects returned relative to the origin must be rebuilt against the real domain, not the IP. |
| S7 | **Response propagation** | `CFHTTPMessage.httpResponse()` builds an `HTTPURLResponse` against the original request URL; propagated with `cacheStoragePolicy: .notAllowed`. | The `URLProtocol` client must see a response tied to the original URL. |

## 3. Local technical verification (this spike)

`AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift` was expanded from 7 to 10
DF-semantics tests (all deterministic, no socket opened — `DomainResolver` is a static IP pool, and
`resume()` is never called). Full `NetworkingFeatureTests` run: **14 tests passed** via
`xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' test -only-testing:NetworkingFeatureTests`.

Coverage now locked as an executable D-14 contract:

- S1 host→IP swap, scheme/path kept, `Host` added (`domainIPReplacementSwapsHostToIPAndAddsHostHeader`).
- S1 unresolvable domain left untouched (`domainIPReplacementLeavesUnresolvableDomainUnchanged`).
- S2 no duplicate `Host` header (`domainIPReplacementDoesNotDuplicateExistingHostHeader`).
- S2/S5 original-domain recovery after swap (`originalDomainIsRecoverableAfterIPReplacement`).
- S2/S5 `Host` header overrides URL host for `.domain` (`hostHeaderOverridesURLHostForDomain`).
- S4 explicit + streamed POST body preservation (`httpBodyIsPreservedFromDataAndStream`).
- S3 cookies for the original URL attached to `DFRequest` (`cookiesForOriginalURLAreAttachedToDFRequest`).
- S4 **new:** arbitrary non-Host headers preserved through the swap (`arbitraryRequestHeadersArePreservedThroughIPReplacement`).
- S5 **new:** the `SecPolicyCreateSSL` host binds to the original domain, not the IP (`trustPolicyHostResolvesToOriginalDomainNotIP`).
- S6 **new:** site-root redirect recovery source and rebuilt host resolve to the original domain (`siteRootRedirectRebuildsAgainstOriginalDomain`).

**Local-proof limitation (D-13):** the *live* pieces — the actual `SecTrust` evaluation (S5), the
CFHTTPMessage response parse (S7), and the socket-driven redirect flow (S6) — only run when a stream
is scheduled against a real server under SNI-filtering conditions. Those cannot be exercised
deterministically in a unit test and remain manual verification. The tests lock the *observable pure
inputs* those live paths consume (the trust-host, the redirect recovery source, the response URL).

## 4. Replacement-candidate analysis

### Candidate A — URLSession / URLProtocol (warning-free, drop-in-shaped)

**Verdict: NOT viable — cannot preserve S2 + S1/S5 together.**

- **`Host` header is reserved (S2).** URLSession/CFNetwork derive the `Host` header from the URL host
  and treat `Host` as a reserved header; overriding it via `setValue(_:forHTTPHeaderField:)` is
  officially unsupported and unreliable. Domain fronting *requires* a `Host` that differs from the
  URL host. This is the specific reason the current code drops to `CFReadStreamCreateForHTTPRequest`,
  which accepts an arbitrary `Host` on a hand-built `CFHTTPMessage`.
- **SNI is derived from the URL host (S1).** Connecting to `https://<IP>` yields no SNI hostname
  (IP literals are not sent as SNI). That is desirable for the bypass, but with URLSession you cannot
  simultaneously suppress SNI *and* set a differing `Host` reliably; you would either leak the
  domain in SNI (defeating the bypass) or fail server virtual-host routing.
- **Trust (S5) is the one part URLSession *can* do:** a `URLSession(delegate:)` server-trust
  challenge lets you call `SecPolicyCreateSSL(true, originalDomain)` and override the decision — this
  matches the current `evaluate`. But recovering only S5 while losing S1/S2 does not preserve D-14.

URLSession preserves S3/S4/S5/S7 but breaks the two semantics that *are* domain fronting (S1 host
control + S2 arbitrary Host). It is therefore not a warning-free replacement that preserves **all**
D-14 semantics.

### Candidate B — Network.framework (`NWConnection` + `sec_protocol_options`)

**Verdict: technically constructible, but NOT a "warning-free replacement" in the low-risk sense —
it is a from-scratch hand-rolled HTTP/1.1 + TLS client.**

`Network.framework` *can*, in principle, preserve every D-14 semantic:

- S1: connect an `NWConnection` directly to the resolved IP:port.
- S1/SNI: `sec_protocol_options_set_tls_server_name` to control or omit the SNI value.
- S5: `sec_protocol_options_set_verify_block` to run custom trust against the original domain
  (mirroring `SecPolicyCreateSSL(true, originalDomain)` + `SecTrustEvaluateWithError`).
- S2/S4: write raw HTTP/1.1 request bytes, including an arbitrary `Host:` header and the body.

But doing so means **reimplementing everything `CFHTTPMessage` + `CFReadStream` provide for free**:
HTTP/1.1 request serialization, response header/status parsing (replacing `CFHTTPMessageCopy…`),
content-length/chunked body framing, persistent-connection handling
(`kCFStreamPropertyHTTPAttemptPersistentConnection`), and the redirect reconstruction loop. This is a
large, security-sensitive surface (raw TLS bytes + hand-rolled HTTP parsing). Trading one deprecated
but battle-tested SDK call for a bespoke HTTP/TLS stack is a net **increase** in risk, and — per D-13
— its correctness under real SNI-filtering conditions cannot be proven locally; it would need the
D-15 China/SNI tester loop before it could be trusted.

### Candidate C — inline `CFReadStreamCreateForHTTPRequest` into app code

**Verdict: NOT viable.** This removes the *package* but keeps the *deprecation warning* on the app
target, and CLAUDE.md forbids silencing it. It is a cosmetic dependency removal explicitly ruled out
by the research (Pitfall 4) and the plan.

## 5. Decision

**Selected Branch (Task 2 human checkpoint, 2026-07-10): `document-skip` — retain `DeprecatedAPI`.**
The user reviewed this evidence and selected `document-skip`: `DeprecatedAPI` and its
`.deprecatedAPI` target dependency stay in place, and no domain-fronting source behavior
(`DFExtensions` / `DFRequest` / `DFStreamHandler` / `DFURLProtocol`) is removed or weakened. The
justification below (D-12 through D-15) is the recorded basis for that decision — removing the
package would weaken D-14 because the S1 (host control) + S2 (arbitrary `Host`) + S5
(original-domain trust) triad cannot be preserved warning-free by any available replacement.

**Evidence-based recommendation (matches the selected branch): `document-skip` (retain `DeprecatedAPI`).**

- **D-12:** Research + this spike show the deprecated CFStream path is currently the only *viable*
  way to keep domain fronting working without weakening it. No warning-free drop-in replacement
  preserves the S1 (host control) + S2 (arbitrary `Host`) + S5 (original-domain trust) triad
  simultaneously. Per D-12, that means **skip** the `DeprecatedAPI` removal rather than remove or
  weaken domain fronting.
- **D-13:** The skip is backed by documented technical proof (Section 2/4) plus technical request
  verification (Section 3: 14 passing deterministic semantics tests). Full end-to-end proof is not
  locally feasible because the failure mode depends on China/SNI network conditions.
- **D-14:** Every request semantic (S1–S7) is enumerated and, where deterministically observable,
  locked by tests — including trust-host binding (S5) and cookie/header handling (S3/S4). A
  replacement is rejected precisely because it cannot preserve all of them warning-free.
- **D-15:** If — contrary to this recommendation — the `remove-deprecatedapi` branch is chosen (the
  Network.framework path in Candidate B), real-world verification is **mandatory** and must be
  handled by user-arranged testers physically in China under SNI-filtering conditions before the
  change can be trusted. Local green tests are necessary but not sufficient.

**Strongest evidence FOR viability (against skip):** Network.framework genuinely exposes the SNI and
custom-trust hooks (Candidate B), so a preserving replacement is not theoretically impossible.

**Strongest evidence AGAINST viability (for skip):** the only non-deprecated path is a large
hand-rolled HTTP/1.1 + TLS client that raises rather than lowers security risk and is unverifiable
locally (D-13); the low-risk URLSession path structurally cannot override the reserved `Host` header
or preserve the IP-connect-with-original-domain-trust model (Candidate A).

## 6. Options for the Task 2 checkpoint

| Option | Meaning | Consequence |
|--------|---------|-------------|
| `remove-deprecatedapi` | Adopt a warning-free Network.framework replacement (Candidate B) and remove the package. | DEP-06 fully met, but requires implementing + trusting a bespoke HTTP/TLS client and passing D-15 China/SNI tester confirmation. |
| `document-skip` (**SELECTED**) | Retain `DeprecatedAPI`; record this D-12/D-13 evidence as the justification. | Domain fronting preserved unchanged; the package stays because it is the only proven viable path. |

**Outcome:** the user selected `document-skip` at the Task 2 checkpoint. The `remove-deprecatedapi`
branch and any request for additional evidence were not chosen.

---

*Phase: 01-isolated-dependency-modernization · Plan 06 · DEP-06 spike*
