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
