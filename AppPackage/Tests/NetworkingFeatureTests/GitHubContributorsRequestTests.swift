import AppModels
import Foundation
@testable import NetworkingFeature
import Testing

// The About page's contributors request: one body-less GET for GitHub's largest page, decoded into
// `GitHubContributor` values. Every case uses a token-isolated stubbed session, so no socket opens.
@Suite
struct GitHubContributorsRequestTests {
    private static let contributorsURLString =
        "https://api.github.com/repos/EhPanda-Team/EhPanda/contributors?per_page=100"

    /// Extra keys GitHub sends (`avatar_url`, `contributions`) are ignored, and a bot decodes as a bot.
    private static let contributorsFixture = Data(
        """
        [
          {
            "login": "aalberrty", "id": 101, "type": "User", "contributions": 42,
            "avatar_url": "https://avatars.githubusercontent.com/u/101?v=4",
            "html_url": "https://github.com/aalberrty"
          },
          {
            "login": "dependabot[bot]", "id": 102, "type": "Bot", "contributions": 7,
            "avatar_url": "https://avatars.githubusercontent.com/in/29110?v=4",
            "html_url": "https://github.com/apps/dependabot"
          }
        ]
        """.utf8
    )

    /// One GET for `per_page=100`, no body, a single attempt, and the entries decoded in order.
    @Test
    func requestLocksAssemblyAndDecoding() async throws {
        let url = try #require(URL(string: Self.contributorsURLString))
        let (session, handle) = makeStubbedSession(
            script: StubScript([url: [.http(status: 200, data: Self.contributorsFixture)]])
        )
        defer {
            session.invalidateAndCancel()
            handle.tearDown()
        }

        let contributors = try await capture { () async throws(AppError) -> [GitHubContributor] in
            try await GitHubContributorsRequest(urlSession: session).response()
        }
        .get()
        let received = try #require(handle.receivedRequests.first)

        expectEquivalentURL(received.url, url)
        #expect(received.httpMethod == "GET")
        #expect(received.httpBody == nil)
        #expect(handle.attempts(for: url) == 1)
        #expect(
            contributors == [
                GitHubContributor(
                    id: 101,
                    login: "aalberrty",
                    htmlURL: try #require(URL(string: "https://github.com/aalberrty")),
                    accountType: "User"
                ),
                GitHubContributor(
                    id: 102,
                    login: "dependabot[bot]",
                    htmlURL: try #require(URL(string: "https://github.com/apps/dependabot")),
                    accountType: "Bot"
                )
            ]
        )
        #expect(contributors.map(\.isBot) == [false, true])
    }
}
