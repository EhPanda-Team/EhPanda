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

    // The login endpoint is where the wall was observed; any URL would do — classification never
    // reads it (D-08).
    private static let probeURL = Defaults.URL.login

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
