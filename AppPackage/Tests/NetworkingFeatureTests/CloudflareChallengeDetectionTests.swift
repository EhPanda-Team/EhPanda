import AppModels
import AppTools
import Foundation
@testable import NetworkingFeature
import Testing

// Phase 12 (C2, D-05, D-08): classification is response-driven only. Every case below is built
// from a directly-constructed `HTTPURLResponse` — no host, no setting, and no network.
@Suite
struct CloudflareChallengeDetectionTests {
    @Test
    func forbiddenResponseCarryingTheMitigationHeaderIsAChallenge() throws {
        let response = try makeResponse(status: 403, headers: ["cf-mitigated": "challenge"])

        #expect(isCloudflareChallenge(response))
    }

    @Test(arguments: ["Challenge", "CHALLENGE", "cHaLlEnGe"])
    func mitigationHeaderValueIsComparedCaseInsensitively(value: String) throws {
        let response = try makeResponse(status: 403, headers: ["cf-mitigated": value])

        #expect(isCloudflareChallenge(response))
    }

    @Test(arguments: [[:], ["cf-mitigated": "bypass"], ["cf-mitigated": ""]] as [[String: String]])
    func forbiddenResponseWithoutTheMitigationValueIsNotAChallenge(headers: [String: String]) throws {
        let response = try makeResponse(status: 403, headers: headers)

        #expect(!isCloudflareChallenge(response))
    }

    @Test(arguments: [200, 401, 429, 503])
    func mitigationHeaderOutsideForbiddenIsNotAChallenge(status: Int) throws {
        let response = try makeResponse(status: status, headers: ["cf-mitigated": "challenge"])

        #expect(!isCloudflareChallenge(response))
    }

    @Test
    func absentAndNonHTTPResponsesAreNotChallenges() {
        let nonHTTPResponse = URLResponse(
            url: Self.probeURL,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        #expect(!isCloudflareChallenge(nil))
        #expect(!isCloudflareChallenge(nonHTTPResponse))
    }

    // MARK: - Retried login POST (C4, D-04, D-07)

    @Test
    func clearanceCarryingLoginRequestSendsTheCookieAndItsBoundUserAgent() async throws {
        let (session, handle) = makeStubbedLoginSession()
        defer { cleanUp(session: session, handle: handle) }

        _ = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(
                username: "challenged-user",
                password: "dummy-password",
                clearance: CloudflareClearance(cookieValue: "abc", userAgent: "UA-X"),
                urlSession: session
            )
            .response()
        }
        let request = try #require(handle.receivedRequests.first)

        #expect(request.value(forHTTPHeaderField: "Cookie") == "cf_clearance=abc")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "UA-X")
    }

    @Test
    func clearanceCarryingLoginRequestDisablesSharedJarCookieHandling() async throws {
        let (session, handle) = makeStubbedLoginSession()
        defer { cleanUp(session: session, handle: handle) }

        _ = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(
                username: "challenged-user",
                password: "dummy-password",
                clearance: CloudflareClearance(cookieValue: "abc", userAgent: "UA-X"),
                urlSession: session
            )
            .response()
        }
        let request = try #require(handle.receivedRequests.first)

        // Without this the shared jar would inject its own Cookie header and overwrite the
        // clearance the challenge web view just earned (D-04).
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test
    func loginRequestWithoutClearanceCarriesNoChallengeHeaders() async throws {
        let (session, handle) = makeStubbedLoginSession()
        defer { cleanUp(session: session, handle: handle) }

        _ = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(
                username: "plain-user",
                password: "dummy-password",
                urlSession: session
            )
            .response()
        }
        let request = try #require(handle.receivedRequests.first)

        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == nil)
        // Both paths keep the shared jar out of the login POST, not just the clearance-carrying one.
        // On the bare path URLSession would otherwise file a rejection page's Set-Cookie tombstones
        // automatically, clobbering a session the user still had; `setCredentials` applies the real
        // ones on success instead.
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.httpMethod == "POST")
        #expect(
            request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded"
        )
    }

    @Test(arguments: [nil, CloudflareClearance(cookieValue: "abc", userAgent: "UA-X")])
    func bothLoginRequestVariantsPostToTheLoginURL(clearance: CloudflareClearance?) async throws {
        let (session, handle) = makeStubbedLoginSession()
        defer { cleanUp(session: session, handle: handle) }

        _ = await capture { () async throws(AppError) -> HTTPURLResponse? in
            try await LoginRequest(
                username: "any-user",
                password: "dummy-password",
                clearance: clearance,
                urlSession: session
            )
            .response()
        }
        let request = try #require(handle.receivedRequests.first)

        #expect(request.url == Defaults.URL.login)
        #expect(request.httpMethod == "POST")
    }

    // MARK: - Fixtures

    // The login endpoint is where the wall was observed; any URL would do — classification never
    // reads it (D-08).
    private static let probeURL = Defaults.URL.login

    /// A single 200 step suffices: these cases assert the *outbound* request, not the response.
    private func makeStubbedLoginSession() -> (session: URLSession, handle: StubHandle) {
        makeStubbedSession(
            script: StubScript([Defaults.URL.login: [.http(status: 200, data: Data())]])
        )
    }

    private func cleanUp(session: URLSession, handle: StubHandle) {
        session.invalidateAndCancel()
        handle.tearDown()
    }

    private func makeResponse(
        status: Int,
        headers: [String: String]
    ) throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: Self.probeURL,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
        )
    }
}
