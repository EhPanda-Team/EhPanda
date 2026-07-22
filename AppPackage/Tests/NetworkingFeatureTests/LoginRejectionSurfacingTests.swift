import AppModels
import AppTools
import Foundation
@testable import NetworkingFeature
import Testing

// The login POST used to discard its response body, which left every rejection indistinguishable:
// a wrong password, a lockout after repeated failures and a missing field are all HTTP 200s that
// set no auth cookie, so the caller saw one undifferentiated "not logged in" and could report
// nothing about it. These cases pin the body actually being read — and the one case where it
// deliberately is not.
@Suite
struct LoginRejectionSurfacingTests {
    @Test
    func forumErrorPageIsSurfacedAsAFailureRatherThanASilentSuccess() async {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: Self.rejectionPage)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }

        // Previously `.success` carrying a 200, with the reason discarded unread.
        #expect(result == .failure(.unknown))
    }

    @Test
    func aRecognisedResponseErrorKeepsItsOwnCaseInsteadOfCollapsingToUnknown() async {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: Self.quotaPage)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }

        // The existing site-wide parser runs first, so conditions the app already models keep their
        // structured case and their tailored recovery suggestion.
        #expect(result == .failure(.quotaExceeded))
    }

    @Test
    func challengedResponseIsNeverReadAsALoginRejection() async throws {
        // A Cloudflare interstitial is not a forum page. Throwing on its body would break detection
        // (C2): the caller must still receive the 403 to classify and route into the challenge flow.
        // The body here is deliberately one that *would* parse as a rejection.
        let (session, handle) = makeStubbedSession(
            script: StubScript([
                Defaults.URL.login: [
                    .http(status: 403, data: Self.rejectionPage, headers: ["cf-mitigated": "challenge"])
                ]
            ])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }
        let response = try #require(try result.get())

        #expect(isCloudflareChallenge(response))
    }

    @Test
    func anOrdinaryPageCarryingNoErrorBoxStillSucceeds() async throws {
        let page = Data("<html><body><p>Welcome back.</p></body></html>".utf8)
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: page)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }
        let response = try #require(try result.get())

        #expect(response.statusCode == 200)
    }

    // The forum counts login attempts and locks the account out past a threshold — the very lockout
    // the cases above exist to surface. A POST the forum received but whose response was lost on the
    // way back is indistinguishable here from one it never saw, so a transport retry spends attempts
    // the user never made: four recorded tries for one tap, against a budget they cannot see.
    @Test
    func aLostLoginResponseIsNotRetriedIntoTheForumsAttemptLockout() async {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.transportFailure(.timedOut)]])
        )
        defer { cleanUp(session: session, handle: handle) }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }

        #expect(result == .failure(.networkingFailed))
        #expect(handle.attempts(for: Defaults.URL.login) == 1)
    }

    // MARK: - Fixtures

    private static let rejectionPage = Data(
        """
        <html><body><div class="maintitle">Board Message</div>
        <div class="pformstrip">The error returned was:</div>
        <div class="pformleft">You must enter a username</div>
        </body></html>
        """.utf8
    )

    private static let quotaPage = Data(
        "<html><body><p>You have exceeded your image viewing limits.</p></body></html>".utf8
    )

    private func cleanUp(session: URLSession, handle: StubHandle) {
        session.invalidateAndCancel()
        handle.tearDown()
    }
}

// The login dump exists so a single attempt answers every question at once. It is only safe to be
// that complete because the credential-setting header is reduced to names first — those values are
// the account's session, and a dump nobody can share is a dump nobody can use.
@Suite
struct CredentialHeaderRedactionTests {
    @Test
    func valuesAreDroppedAndNamesKept() {
        let header = "ipb_member_id=SECRET-ID; path=/, ipb_pass_hash=SECRET-HASH; path=/"

        let redacted = redactedCredentialHeader(header, for: Self.dumpURL)

        #expect(redacted.contains("ipb_member_id"))
        #expect(redacted.contains("ipb_pass_hash"))
        #expect(!redacted.contains("SECRET-ID"))
        #expect(!redacted.contains("SECRET-HASH"))
    }

    @Test
    func cookieAttributesCarryingCommasCannotLeakAValue() {
        // `expires` embeds a comma, so a naive split lands mid-attribute. Whatever the split
        // produces, no fragment of a value may survive.
        let header = "ipb_pass_hash=SECRET-HASH; expires=Wed, 22-Jul-2026 10:00:00 GMT; path=/"

        #expect(!redactedCredentialHeader(header, for: Self.dumpURL).contains("SECRET-HASH"))
    }

    // The same comma used to split the attribute into pieces that were then printed as though each
    // were a cookie the forum had set — `22-Jul-2026 10:00:00 GMT; path` among them. Nothing but a
    // real cookie's name belongs in this dump.
    @Test
    func attributeFragmentsAreNotReportedAsCookieNames() {
        let header = "ipb_pass_hash=SECRET-HASH; expires=Wed, 22-Jul-2026 10:00:00 GMT; path=/"

        let redacted = redactedCredentialHeader(header, for: Self.dumpURL)

        #expect(redacted == "<values redacted; names set: ipb_pass_hash>")
    }

    // RFC 6265 forbids a comma inside a cookie value, which is the whole reason splitting on one
    // was ever tenable. A server that breaks the rule must still not get any part of the value
    // printed back out.
    @Test
    func aCommaInsideAValueLeaksNoPartOfThatValue() {
        let header = "ipb_pass_hash=SECRET,TAIL-OF-SECRET; path=/"

        #expect(!redactedCredentialHeader(header, for: Self.dumpURL).contains("TAIL-OF-SECRET"))
    }

    @Test
    func anEmptyHeaderYieldsNoNames() {
        #expect(redactedCredentialHeader("", for: Self.dumpURL) == "<values redacted; names set: >")
    }

    // No URL means no domain to attach a cookie to, so nothing is parsed and nothing is named —
    // the one thing that must never happen is a value reaching the dump for want of a URL.
    @Test
    func aMissingURLNamesNothingRatherThanFallingBackToTheRawHeader() {
        let header = "ipb_pass_hash=SECRET-HASH; path=/"

        #expect(redactedCredentialHeader(header, for: nil) == "<values redacted; names set: >")
    }

    private static let dumpURL = Defaults.URL.login
}

// The forum began gating its login form behind Cloudflare Turnstile, which contributes a
// `cf-turnstile-response` field to the submission. A credential POST cannot produce that field, so
// the refusal is not about the password and no retry resolves it.
@Suite
struct CaptchaGatedLoginTests {
    @Test
    func aTurnstileGatedRefusalGetsItsOwnCase() async {
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: Self.captchaRefusal)]])
        )
        defer { session.invalidateAndCancel(); handle.tearDown() }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }

        #expect(result == .failure(.loginCaptchaRequired))
    }

    @Test
    func anUngatedRefusalStaysGeneric() async {
        // Same error block, no widget: this one really might be the password, so it must not claim
        // a CAPTCHA is in the way.
        let refusal = Data(
            """
            <html><body>
            <div class="formsubtitle">The following errors were found:</div>
            <div class="tablepad"><span class="postcolor">Bad password.</span></div>
            </body></html>
            """.utf8
        )
        let (session, handle) = makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: refusal)]])
        )
        defer { session.invalidateAndCancel(); handle.tearDown() }

        let result = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(username: "u", password: "p", urlSession: session).response()
        }

        #expect(result == .failure(.unknown))
    }

    /// Trimmed from the real refusal captured during UAT.
    private static let captchaRefusal = Data(
        """
        <html><head>
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
        </head><body>
        <div class="formsubtitle">The following errors were found:</div>
        <div class="tablepad"><span class="postcolor">The captcha was not entered correctly. \
        Please try again.</span></div>
        <form name="LOGIN"><div class="cf-turnstile" data-sitekey="0x4AAAAAAC"></div></form>
        </body></html>
        """.utf8
    )
}
