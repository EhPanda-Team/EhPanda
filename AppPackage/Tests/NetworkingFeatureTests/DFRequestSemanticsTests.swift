import Foundation
import Testing
import AppModels
@testable import NetworkingFeature

// Wave 0 semantics lock for DEP-06 (D-14). Domain fronting rewrites the network host to a resolved
// IP while keeping every request property tied to the *original* domain. These fixtures freeze that
// contract before any DeprecatedAPI removal spike, so a later change that drifts host replacement,
// Host-header behavior, cookie attachment, POST body preservation, or the original-domain recovery
// used for redirects and TLS trust fails loudly.
//
// The tests are fully deterministic and never open a socket: they exercise the pure request
// transforms (`domainIPReplaced()`, `domain`, `domainWithScheme`, `HTTPBody()`) and construct a
// `DFRequest` only to observe header assembly — `resume()` (which schedules the stream) is never
// called. Real China/SNI end-to-end behavior stays a manual verification per D-13.
@Suite
struct DFRequestSemanticsTests {
    private func isIPv4(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
    }

    // MARK: Host replacement

    /// A resolvable domain has its URL host swapped to a numeric IP while scheme and path are kept,
    /// and the original domain is preserved in an added `Host` header.
    @Test
    func domainIPReplacementSwapsHostToIPAndAddsHostHeader() throws {
        let request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/g/123/abc")))

        let replaced = request.domainIPReplaced()

        let host = try #require(replaced.url?.host)
        #expect(isIPv4(host))
        #expect(host != "e-hentai.org")
        #expect(replaced.value(forHTTPHeaderField: "Host") == "e-hentai.org")
        #expect(replaced.url?.scheme == "https")
        #expect(replaced.url?.path == "/g/123/abc")
    }

    /// An unresolvable domain is left completely untouched — no host swap and no injected Host header.
    @Test
    func domainIPReplacementLeavesUnresolvableDomainUnchanged() throws {
        let url = try #require(URL(string: "https://example.com/x"))
        let request = URLRequest(url: url)

        let replaced = request.domainIPReplaced()

        #expect(replaced.url == url)
        #expect(replaced.value(forHTTPHeaderField: "Host") == nil)
    }

    /// A pre-existing Host header is honored and never duplicated: the resolver still swaps the URL
    /// host to an IP, but exactly one Host header carrying the original domain remains.
    @Test
    func domainIPReplacementDoesNotDuplicateExistingHostHeader() throws {
        var request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/x")))
        request.setValue("e-hentai.org", forHTTPHeaderField: "Host")

        let replaced = request.domainIPReplaced()

        let host = try #require(replaced.url?.host)
        #expect(isIPv4(host))
        #expect(replaced.value(forHTTPHeaderField: "Host") == "e-hentai.org")
    }

    // MARK: Original-domain recovery (redirect + TLS trust)

    /// After the host is swapped to an IP, `domain` and `domainWithScheme` still resolve to the
    /// original host via the Host header. This is the invariant the stream handler relies on to
    /// rebuild redirect targets against the real domain and to pin TLS trust to the real host.
    @Test
    func originalDomainIsRecoverableAfterIPReplacement() throws {
        let request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/popular")))

        let replaced = request.domainIPReplaced()

        #expect(replaced.domain == "e-hentai.org")
        #expect(replaced.domainWithScheme == "https://e-hentai.org")
        #expect(replaced.isHTTPS)
    }

    /// A Host header wins over the URL host when computing `domain`, so trust/redirect logic keys off
    /// the fronted domain rather than the raw IP in the URL.
    @Test
    func hostHeaderOverridesURLHostForDomain() throws {
        var request = URLRequest(url: try #require(URL(string: "https://192.0.2.1/path")))
        request.setValue("e-hentai.org", forHTTPHeaderField: "Host")

        #expect(request.hasHostField)
        #expect(request.domain == "e-hentai.org")
        #expect(request.domainWithScheme == "https://e-hentai.org")
    }

    // MARK: POST body preservation

    /// `HTTPBody()` returns an explicit POST body verbatim and materializes a streamed POST body,
    /// while a body-less GET yields nil. This guards search/login POST payloads across the rewrite.
    @Test
    func httpBodyIsPreservedFromDataAndStream() throws {
        let apiURL = try #require(URL(string: "https://e-hentai.org/api"))

        var explicitPost = URLRequest(url: apiURL)
        explicitPost.httpMethod = "POST"
        let explicitBody = Data("f_search=test".utf8)
        explicitPost.httpBody = explicitBody
        #expect(explicitPost.HTTPBody() == explicitBody)

        var streamedPost = URLRequest(url: apiURL)
        streamedPost.httpMethod = "POST"
        let streamedBody = Data("field=value".utf8)
        streamedPost.httpBodyStream = InputStream(data: streamedBody)
        #expect(streamedPost.HTTPBody() == streamedBody)

        let get = URLRequest(url: try #require(URL(string: "https://e-hentai.org/")))
        #expect(get.HTTPBody() == nil)
    }

    // MARK: Cookie handling

    /// A `DFRequest` attaches cookies stored for the *original* request URL as a `Cookie` header. A
    /// unique test domain keeps this isolated from the shared cookie store and other tests.
    @Test
    func cookiesForOriginalURLAreAttachedToDFRequest() throws {
        let cookieDomain = "cookie-test.example"
        let url = try #require(URL(string: "https://\(cookieDomain)/g/1/"))
        let cookie = try #require(HTTPCookie(properties: [
            .domain: cookieDomain,
            .path: "/",
            .name: "igneous",
            .value: "abc123"
        ]))
        HTTPCookieStorage.shared.setCookie(cookie)
        defer { HTTPCookieStorage.shared.deleteCookie(cookie) }

        let dfRequest = try #require(DFRequest(URLRequest(url: url)))

        let cookieHeader = try #require(dfRequest.request.value(forHTTPHeaderField: "Cookie"))
        #expect(cookieHeader.contains("igneous=abc123"))
    }

    // MARK: D-14 expansion for the DEP-06 removal spike
    //
    // These lock the remaining D-14 facets that a warning-free replacement candidate must preserve:
    // arbitrary-header pass-through, the trust-policy host binding, and the original-domain source the
    // redirect handler rebuilds against. They stay pure request transforms — the live SecTrust
    // evaluation and CFHTTPMessage response propagation are exercised only through a scheduled stream,
    // so their end-to-end proof remains the manual China/SNI verification (D-13/D-15).

    /// Arbitrary (non-Host) request headers survive the domain-to-IP rewrite verbatim. Domain fronting
    /// only rewrites the URL host and injects `Host`; every other header a caller set — user agent,
    /// accept, custom auth — must reach the fronted origin unchanged.
    @Test
    func arbitraryRequestHeadersArePreservedThroughIPReplacement() throws {
        var request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/g/1/")))
        request.setValue("EhPanda/Test", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let replaced = request.domainIPReplaced()

        #expect(replaced.value(forHTTPHeaderField: "User-Agent") == "EhPanda/Test")
        #expect(replaced.value(forHTTPHeaderField: "Accept") == "text/html")
        #expect(replaced.value(forHTTPHeaderField: "Host") == "e-hentai.org")
    }

    /// The value the stream handler feeds to `SecPolicyCreateSSL(true, domain)` is the *original*
    /// domain, never the raw IP now sitting in the URL host. This is the trust-host binding D-14
    /// depends on: custom trust is evaluated against the intended domain even though the socket
    /// connects to an IP. The live `SecTrust` evaluation itself needs a real handshake (manual, D-13).
    @Test
    func trustPolicyHostResolvesToOriginalDomainNotIP() throws {
        let request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/g/1/")))

        let replaced = request.domainIPReplaced()

        let urlHost = try #require(replaced.url?.host)
        #expect(isIPv4(urlHost))
        // `.domain` is exactly what DFStreamEventHandler.evaluate passes to SecPolicyCreateSSL.
        #expect(replaced.domain == "e-hentai.org")
        #expect(replaced.domain != urlHost)
    }

    /// The redirect handler rebuilds site-root `Location` targets against `domainWithScheme`, which
    /// must recover the original domain after IP replacement. This locks that recovery source and the
    /// rebuilt target's host, mirroring `DFStreamEventHandler.endEncountered` without opening a socket.
    @Test
    func siteRootRedirectRebuildsAgainstOriginalDomain() throws {
        let request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/g/1/")))

        let replaced = request.domainIPReplaced()

        let scheme = try #require(replaced.domainWithScheme)
        #expect(scheme == "https://e-hentai.org")

        // Reproduce the handler's reconstruction for a site-root redirect (e.g. Location: /popular).
        let originalURL = try #require(URL(string: scheme))
        let rebuilt = originalURL.appendingPathComponent("/popular")
        #expect(rebuilt.host == "e-hentai.org")
        #expect(rebuilt.scheme == "https")
        #expect(rebuilt.path == "/popular")
    }
}
